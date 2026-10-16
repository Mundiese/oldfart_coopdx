OF = OF or {}
OF.util = OF.util or {}

local util = OF.util

function util.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function util.byte(v)
    if type(v) ~= "number" then return 255 end
    if v < 0 then return 0 end
    if v > 255 then return 255 end
    return math.floor(v)
end

local HELP_LINE = 256

local function describe_budget(command)

    return HELP_LINE - (1 + #command + 1 + 2 + 1 + 2 + 1)
end

function util.describe(command, items, prose)
    if type(command) ~= "string" or command == "" then return false end
    if type(items) ~= "table" or #items == 0 then return false end
    if update_chat_command_description == nil then return false end

    local clean = {}
    for _, item in ipairs(items) do

        if type(item) == "string" and item ~= "" and not string.find(item, "%s") then
            table.insert(clean, item)
        end
    end
    if #clean == 0 then return false end
    table.sort(clean)

    local seen, unique = nil, {}
    for _, key in ipairs(clean) do
        if key ~= seen then table.insert(unique, key) end
        seen = key
    end
    clean = unique

    if prose ~= nil then
        if #prose > describe_budget(command) then return false end
        if string.find(prose, "[", 1, true) ~= nil
            or string.find(prose, "]", 1, true) ~= nil then
            return false
        end
    end

    local list = "[" .. table.concat(clean, "|") .. "]"
    update_chat_command_description(command,
        prose ~= nil and ("- " .. prose .. " " .. list) or list)
    return true
end

function util.alive(thing)
    if thing == nil then return false end
    if type(thing) ~= "userdata" then return true end
    local ok, dead = pcall(function() return ~thing end)
    if not ok then return true end
    return dead ~= true
end

util.handleSerial = util.handleSerial or 0
util.HANDLE_TOKEN_BASE = 0x6F660000

function util.handle(o, bhvId, field)
    if o == nil then return nil end
    field = field or "oBehParams"
    util.handleSerial = (util.handleSerial + 1) % 0xFFFF
    local token = util.HANDLE_TOKEN_BASE + util.handleSerial
    o[field] = token
    return { obj = o, bhv = bhvId, field = field, token = token }
end

function util.handle_alive(h)
    if h == nil then return false end
    local o = h.obj
    if o == nil or o.activeFlags == nil or o.activeFlags == 0 then return false end
    if o[h.field or "oBehParams"] ~= h.token then return false end
    if h.bhv ~= nil and obj_has_behavior_id ~= nil
        and obj_has_behavior_id(o, h.bhv) ~= 1 then
        return false
    end
    return true
end

function util.handle_obj(h)
    if util.handle_alive(h) then return h.obj end
    return nil
end

function util.handle_drop(h)
    if not util.handle_alive(h) then return false end
    if obj_mark_for_deletion ~= nil then obj_mark_for_deletion(h.obj) end
    return true
end

function util.has_flag(value, flag)

    if value == nil or flag == nil or flag == 0 then return false end
    return math.floor(value / flag) % 2 == 1
end

function util.add_flag(value, flag)
    if flag == nil or flag == 0 then return value end
    value = value or 0
    if util.has_flag(value, flag) then return value end
    return value + flag
end

function util.action_group(action)
    if action == nil then return nil end
    return math.floor(action / 0x40) % 8
end

function util.stopping(m)
    if m == nil or m.action == nil then return false end
    return m.action == ACT_TURNING_AROUND
        or m.action == ACT_BRAKING
        or m.action == ACT_DECELERATING
        or m.action == ACT_HOLD_DECELERATING
end

util.STRIDE_MOST = 4.0
util.strideTick = 0
util.stride = { tick = -10, k = 1.0 }
util.strideApplied = { tick = -10, k = 1.0 }

local STRIDE_WALK = 32

function util.stride_of(m, want)
    local now = tonumber(m.forwardVel) or 0
    local aim = math.min(tonumber(m.intendedMag) or 0, STRIDE_WALK)
    local base = math.max(now, aim, 1)
    local k = want / base
    if k > util.STRIDE_MOST then k = util.STRIDE_MOST end
    return k
end

function util.stride_now(m)
    if m == nil or m.playerIndex ~= 0 then return nil end
    local st = util.stride
    if st.tick < util.strideTick - 1 then return nil end
    if st.k <= 1.0 then return nil end
    return st.k
end

function util.speed_up(m, want, carry)
    if m == nil then return false end
    want = tonumber(want)
    if want == nil then return false end
    local now = tonumber(m.forwardVel) or 0
    if want <= now then return false end
    if carry ~= true and m.playerIndex == 0
        and not util.has_flag(m.action or 0, ACT_FLAG_AIR or 0x800)
        and not util.has_flag(m.action or 0, ACT_FLAG_SWIMMING or 0x2000) then

        local k = util.stride_of(m, want)
        if k <= 1.0 then return false end
        local st = util.stride
        if st.tick == util.strideTick then
            if k > st.k then st.k = k end
        else
            st.tick, st.k = util.strideTick, k
        end
        return true
    end
    if util.stopping(m) then return false end
    m.forwardVel = want
    return true
end

function util.ground_speed(m)
    if m == nil then return 0 end
    return (tonumber(m.forwardVel) or 0) * (util.stride_now(m) or 1.0)
end

function util.forget_stride()
    util.stride.tick, util.stride.k = -10, 1.0
    util.strideApplied.tick, util.strideApplied.k = -10, 1.0
    if util.strideScaled ~= nil then util.strideScaled.tick = -10 end
end
hook_event(HOOK_ON_LEVEL_INIT, function() util.forget_stride() end)

hook_event(HOOK_BEFORE_MARIO_UPDATE, function(m)
    if m ~= nil and m.playerIndex == 0 then util.strideTick = util.strideTick + 1 end
end, OF.LOCAL_MARIO)

util.strideScaled = { tick = -10, x = 0, z = 0, k = 1.0 }
function util.stride_step(m, stepType)
    if m == nil or m.playerIndex ~= 0 then return nil end
    if stepType ~= (STEP_TYPE_GROUND or 0) then return nil end
    local k = util.stride_now(m)
    if k == nil then return nil end
    local sc = util.strideScaled
    if sc.tick == util.strideTick then return nil end
    local v = m.vel
    if v == nil then return nil end
    v.x, v.z = (tonumber(v.x) or 0) * k, (tonumber(v.z) or 0) * k
    sc.tick, sc.x, sc.z, sc.k = util.strideTick, v.x, v.z, k
    util.strideApplied.tick, util.strideApplied.k = util.strideTick, k
    return nil
end

hook_event(HOOK_BEFORE_PHYS_STEP, function(m, stepType)
    util.stride_step(m, stepType)
end)

function util.stride_legs(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    local sc = util.strideScaled
    if sc.tick == util.strideTick and m.vel ~= nil and sc.k > 0
        and m.vel.x == sc.x and m.vel.z == sc.z then
        m.vel.x, m.vel.z = sc.x / sc.k, sc.z / sc.k
    end
    local a = util.strideApplied
    if a.tick ~= util.strideTick or a.k <= 1.0 then return false end
    local info = m.marioObj ~= nil and m.marioObj.header.gfx.animInfo or nil
    if info == nil or type(info.animAccel) ~= "number" or info.animAccel <= 0 then return false end
    info.animAccel = math.floor(info.animAccel * a.k)
    return true
end
hook_event(HOOK_MARIO_UPDATE, function(m) util.stride_legs(m) end)

function util.hex_to_rgb(hex)
    local r, g, b = string.match(hex or "", "#(%x%x)(%x%x)(%x%x)")
    if r == nil then return 255, 255, 255 end
    return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
end

function util.player_color(localIndex)
    return util.hex_to_rgb(network_get_player_text_color_string(localIndex))
end

function util.name_colour()
    return 255, 255, 255
end

function util.asks(from, name)
    return from ~= nil and from[name] ~= nil
end

function util.menu_has_screen()
    if util.asks(OF.panel, "is_open") and OF.panel.is_open() == true then return true end

    if util.asks(OF.pause, "owns_hud") and OF.pause.owns_hud() == true then return true end

    return util.asks(OF.mapvote, "owns_pad") and OF.mapvote.owns_pad() == true
end

function util.flag(value)
    if value == nil or value == false or value == 0 then return 0 end
    return 1
end

function util.is_host()
    return network_is_server()
end

function util.is_host_player(localIndex)
    return network_global_index_from_local(localIndex) == 0
end

function util.area_authority()
    local np = util.optional("get_network_player_smallest_global", nil)
    if np == nil then return nil end
    local at = np.localIndex
    if type(at) ~= "number" then return nil end
    if at < 0 or at >= MAX_PLAYERS then return nil end
    return at
end

function util.i_decide_here()
    return util.area_authority() == 0
end

local NO_COOPNET_ID = { ["-1"] = true, ["0"] = true, [""] = true }

function util.player_identities(localIndex)
    local coopnet = nil
    local id = get_coopnet_id(localIndex)
    if id ~= nil then
        id = tostring(id)
        if not NO_COOPNET_ID[id] then
            coopnet = "cn" .. id
        end
    end

    local named = nil
    local np = gNetworkPlayers[localIndex]
    if np ~= nil and np.name ~= nil and np.name ~= "" then
        named = "nm" .. string.lower(np.name)
    end
    return coopnet, named
end

function util.player_id(localIndex)
    local coopnet, named = util.player_identities(localIndex)
    return coopnet or named
end

function util.local_from_global(globalIndex)
    local li = network_local_index_from_global(globalIndex)
    if li == nil or li < 0 or li >= MAX_PLAYERS then return nil end
    if not gNetworkPlayers[li].connected then return nil end
    return li
end

local connectedCache = nil
local connectedFrame = nil

local function frame_now()
    if get_global_timer ~= nil then return get_global_timer() end
    return nil
end

util.seatForgetters = util.seatForgetters or {}

function util.on_forget_seat(name, drop)
    if type(name) ~= "string" or name == "" then return false end
    if type(drop) ~= "function" then return false end
    util.seatForgetters[name] = drop
    return true
end

function util.forget_seat(localIndex)
    if type(localIndex) ~= "number" then return 0 end
    local ran = 0
    for _, drop in pairs(util.seatForgetters) do
        pcall(drop, localIndex)
        ran = ran + 1
    end
    return ran
end

function util.forget_player_cache(m)
    connectedCache = nil
    connectedFrame = nil
    if m ~= nil and type(m.playerIndex) == "number" then
        util.forget_seat(m.playerIndex)
    end
end

local playerRow = {}

function util.connected_players()
    local now = frame_now()
    if connectedCache ~= nil and now ~= nil and now == connectedFrame then
        return connectedCache
    end

    local list = {}
    for i = 0, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[i]
        if np ~= nil and np.connected then
            local row = playerRow[i]
            if row == nil then
                row = { localIndex = i }
                playerRow[i] = row
            end
            row.np = np
            table.insert(list, row)
        end
    end

    connectedCache = list
    connectedFrame = now
    return list
end

hook_event(HOOK_ON_PLAYER_CONNECTED, util.forget_player_cache)
hook_event(HOOK_ON_PLAYER_DISCONNECTED, util.forget_player_cache)

function util.find_player_by_name(name)
    local needle = string.lower(util.plain(name or ""))
    if needle == "" then return nil end
    for _, entry in ipairs(util.connected_players()) do
        if string.lower(util.plain(entry.np.name)) == needle then
            return entry.localIndex
        end
    end
    for _, entry in ipairs(util.connected_players()) do
        if string.sub(string.lower(util.plain(entry.np.name)), 1, #needle) == needle then
            return entry.localIndex
        end
    end
    return nil
end

local askedDepth = 0
local askedFrame = nil

function util.answering(fn, ...)
    askedDepth = askedDepth + 1
    askedFrame = frame_now()
    local ok, first, second = pcall(fn, ...)
    askedDepth = askedDepth - 1
    if askedDepth <= 0 then
        askedDepth = 0
        askedFrame = nil
    end
    if not ok then error(first, 0) end
    return first, second
end

function util.asked_in_chat()
    if askedDepth <= 0 then return false end
    local now = frame_now()
    if now ~= nil and askedFrame ~= nil and now ~= askedFrame then
        askedDepth = 0
        askedFrame = nil
        return false
    end
    return true
end

util.RANK_REFUSAL = "Your rank cannot do that."
local function tier_suffix(feature)
    if not util.asks(OF.perms, "required") then return "" end
    return " (" .. OF.lang.t(OF.perms.tier_name(OF.perms.required(feature))) .. "+)"
end

local function rank_line(feature)
    if type(feature) ~= "string" or feature == "" then return nil end
    if not util.asks(OF.perms, "required") then return nil end
    if OF.perms.DEFAULTS == nil or OF.perms.DEFAULTS[feature] == nil then
        return nil
    end
    if OF.perms.can(feature) then return nil end

    local needs = OF.perms.required(feature)
    if needs >= OF.TIER.HOST then
        return OF.lang.t(
            "Host is whoever is running the lobby, not a rank to be given.")
    end

    return OF.lang.fill("You are @. The menu's Ask the host for @ row asks.",
        OF.lang.t(OF.perms.tier_name(OF.perms.my_tier())),
        OF.lang.t(OF.perms.tier_name(needs)))
end

local function say_rank_line(feature)
    local line = rank_line(feature)
    if line == nil then return false end
    util.chat(line, nil, { more = true })
    return true
end

local function say_where_the_ladder_is()
    if util.is_host() then return end
    util.chat(OF.lang.t(
        "A greyed row says the rank it wants, and offers to ask the host."), nil, { more = true })
end

function util.allowed(feature)
    if OF.perms.can(feature) then return true end
    local said = OF.lang.t(util.RANK_REFUSAL) .. tier_suffix(feature)

    if util.asked_in_chat() or not util.asks(OF.notify, "show") then
        util.chat(said, "warn")
        say_rank_line(feature)
    else
        OF.notify.show(said, "bad")
    end

    if util.asks(OF.trouble, "refused") then OF.trouble.refused(feature) end
    return false
end

function util.named_player(msg)
    local target = util.find_player_by_name(msg)
    if target ~= nil then return target end
    util.chat(OF.lang.fill("No player called '@'.", tostring(msg)), "warn")
    return nil
end

function util.keep_awake(m)
    if m == nil then return false end
    local act = m.action
    if act == ACT_IDLE then
        if (m.actionState or 0) >= 3 then
            m.actionState = 0
            m.actionTimer = 0
            return true
        end
        return false
    end
    if act ~= nil and (act == ACT_START_SLEEPING or act == ACT_SLEEPING
            or act == ACT_WAKING_UP) then
        set_mario_action(m, ACT_IDLE, 0)
        return true
    end
    return false
end

function util.can_play(localIndex, kind)
    if OF.util.asks(OF.speedrun, "is_excluded") and OF.speedrun.is_excluded(localIndex, kind) then return false end

    local scope = OF.roundscope
    if scope ~= nil and scope.taken_by_run ~= nil then
        local asked = kind
        if asked == nil and OF.util.asks(OF.speedrun, "kind_now") then asked = OF.speedrun.kind_now() end
        if asked ~= nil and OF.speedrun ~= nil and asked == OF.speedrun.KIND_RUN then
            if scope.round_dealt(localIndex) then return false end
        elseif scope.taken_by_run(localIndex) then
            return false
        end
    end

    if OF.util.asks(OF.spectate, "is_spectating") and OF.spectate.is_spectating(localIndex)
        and not (OF.util.asks(OF.harsh, "is_permadead") and OF.harsh.is_permadead(localIndex)) then
        return false
    end
    if OF.util.asks(OF.jail, "is_jailed") and OF.jail.is_jailed(localIndex) then return false end

    if OF.util.asks(OF.idle, "left_out") and OF.idle.left_out(localIndex) then
        return false
    end
    return true
end

local INTANGIBLE_VANISH = MARIO_VANISH_CAP or 0x00000002
local INTANGIBLE_CAP    = MARIO_CAP_ON_HEAD or 0x00000010

local intangibleHolders = {}

local intangibleOwned = { vanish = false, cap = false }

local function bit_on(value, bit)
    if util.has_flag(value, bit) then return value end
    return value + bit
end

local function bit_off(value, bit)
    if not util.has_flag(value, bit) then return value end
    return value - bit
end

function util.intangible_held(name)
    return intangibleHolders[name] == true
end

function util.intangible_any()
    return next(intangibleHolders) ~= nil
end

function util.intangible(name, on)
    local m = gMarioStates[0]
    if m == nil or name == nil then return false end

    if on then
        if not util.intangible_any() then
            intangibleOwned.vanish = util.has_flag(m.flags, INTANGIBLE_VANISH)
            intangibleOwned.cap    = util.has_flag(m.flags, INTANGIBLE_CAP)
        end
        intangibleHolders[name] = true
        m.flags = bit_on(bit_on(m.flags, INTANGIBLE_VANISH), INTANGIBLE_CAP)
        return true
    end

    if intangibleHolders[name] == nil then return false end
    intangibleHolders[name] = nil

    if util.intangible_any() then return true end

    if not intangibleOwned.vanish then m.flags = bit_off(m.flags, INTANGIBLE_VANISH) end
    if not intangibleOwned.cap then m.flags = bit_off(m.flags, INTANGIBLE_CAP) end
    return true
end

function util.intangible_borrowed(flag)
    if not util.intangible_any() then return false end
    if flag == INTANGIBLE_VANISH then return intangibleOwned.vanish == false end
    if flag == INTANGIBLE_CAP then return intangibleOwned.cap == false end
    return false
end

function util.own_flags(value)
    value = tonumber(value) or 0
    if util.intangible_borrowed(INTANGIBLE_VANISH) then
        value = bit_off(value, INTANGIBLE_VANISH)
    end
    if util.intangible_borrowed(INTANGIBLE_CAP) then
        value = bit_off(value, INTANGIBLE_CAP)
    end
    return value
end

function util.course_of_level(levelNum)
    for _, entry in ipairs(OF.COURSES) do
        if entry.level == levelNum then return entry.num end
    end
    return 0
end

util.CHAT_ROLES = {
    info = "\\#dcdcdc\\",
    warn = "\\#ffb060\\",
    mode = "\\#ff0000\\",

    joined = "\\#a0ffa0\\",
    left = "\\#ff6060\\",
}
util.CHAT_COMMAND = "\\#ffff00\\"
function util.chat_highlight(text, base)
    local lit = util.CHAT_COMMAND
    text = string.gsub(text, "^(/%a[%w_]*)", lit .. "%1" .. base)
    text = string.gsub(text, "([%s%(\"'])(/%a[%w_]*)", "%1" .. lit .. "%2" .. base)
    text = string.gsub(text, "(%[[%u%d][%u%d%- ]*%])", lit .. "%1" .. base)
    return text
end

function util.chat_name(name)
    return "\1" .. util.name_safe(tostring(name or "")) .. "\2"
end

function util.chat_paint(message, base, keep)
    local out, pos = {}, 1
    local function words(text)
        if not keep then text = util.plain(text) end
        return util.chat_highlight(text, base)
    end
    while true do
        local open = string.find(message, "\1", pos, true)
        local close = open ~= nil and string.find(message, "\2", open + 1, true) or nil
        if close == nil then break end
        out[#out + 1] = words(string.sub(message, pos, open - 1))
        local name = string.sub(message, open + 1, close - 1)

        if not string.find(name, string.char(92, 35), 1, true) then
            name = "\\#ffffff\\" .. name
        end
        out[#out + 1] = name .. base
        pos = close + 1
    end
    out[#out + 1] = words(string.sub(message, pos))
    return (string.gsub(table.concat(out), "[\1\2]", ""))
end

function util.chat_line(message, role, opts)
    local base = util.CHAT_ROLES[role or "info"] or util.CHAT_ROLES.info
    local text = util.chat_paint(tostring(message or ""), base, opts ~= nil and opts.keep)
    if opts ~= nil and opts.more then return "  " .. base .. text end
    if opts ~= nil and opts.bare then return base .. text end
    if role == "mode" then return base .. OF.PREFIX .. text end
    local brand = OF.BRAND
    if type(brand) ~= "table" or brand.r == nil then brand = { r = 255, g = 255, b = 0 } end
    return util.colour_escape(brand.r, brand.g, brand.b) .. OF.PREFIX .. base .. text
end

function util.say_buttons(text, keyboardOnly)
    if type(text) ~= "string" or text == "" then return text end
    local input = OF.input
    if input == nil or type(input.button_text) ~= "function" then return text end
    if keyboardOnly then
        local hud = OF.hud
        local set = hud ~= nil and type(hud.glyph_set) == "function" and hud.glyph_set() or nil
        if set ~= "kbm" then return text end
        return input.button_text(text, "kbm")
    end
    return input.button_text(text)
end

function util.chat(message, role, opts)

    if OF.input ~= nil and type(OF.input.button_text) == "function" then message = OF.input.button_text(message) end
    local line = util.chat_line(message, role, opts)
    djui_chat_message_create(line)
    return line
end

function util.report(ok, reason, feature)
    if ok then return true end
    if reason ~= nil and reason ~= "" then
        local rank = type(reason) == "string"
            and string.find(reason, util.RANK_REFUSAL, 1, true) ~= nil
        local named = type(feature) == "string" and feature ~= ""
        if OF.util.asks(OF.lang, "get") then reason = OF.lang.get(reason) end

        if rank and named and rank_line(feature) ~= nil
            and string.find(reason, "+)", 1, true) == nil then
            reason = reason .. tier_suffix(feature)
        end

        if util.asked_in_chat() or not OF.util.asks(OF.notify, "show") then
            util.chat(reason, "warn")
            if rank and named then

                say_rank_line(feature)
            elseif rank then
                say_where_the_ladder_is()
            end
            if OF.util.asks(OF.sounds, "play") then
                OF.sounds.play(OF.sounds.DENIED)
            end
        else

            OF.notify.show(reason, "bad")
        end
    end
    return false
end

local STORAGE_ESCAPES = {
    ["%"] = "%25",
    ["["] = "%5b",
    ["]"] = "%5d",
    ["="] = "%3d",
}

local ESCAPE_PERCENT = "%%25"
local ESCAPE_OPEN    = "%%5b"
local ESCAPE_CLOSE   = "%%5d"
local ESCAPE_EQUALS  = "%%3d"
do

local escapedOf, escapedCount = {}, 0

function util.storage_escape(text)
    if text == nil then return "" end
    local asString = type(text) == "string"
    if asString then
        local done = escapedOf[text]
        if done ~= nil then return done end
    end
    local was = text

    text = string.gsub(text, "%%", ESCAPE_PERCENT)
    text = string.gsub(text, "%[", ESCAPE_OPEN)
    text = string.gsub(text, "%]", ESCAPE_CLOSE)
    text = string.gsub(text, "=", ESCAPE_EQUALS)
    if asString then
        if escapedCount >= 512 then escapedOf, escapedCount = {}, 0 end
        escapedOf[was] = text
        escapedCount = escapedCount + 1
    end
    return text
end
end

function util.storage_key(prefix, id)
    return prefix .. util.storage_escape(id)
end

function util.storage_unescape(text)
    if text == nil then return "" end
    text = string.gsub(text, "%%5b", "[")
    text = string.gsub(text, "%%5d", "]")
    text = string.gsub(text, "%%3d", "=")

    text = string.gsub(text, "%%25", "%%")
    return text
end

function util.storage_value(text)
    if text == nil then return "" end
    return (string.gsub(tostring(text), "%c", " "))
end

local storageComplaint = 0

local function report_refusal(key)

    if util.asks(OF.stats, "on_refused_write") then OF.stats.on_refused_write() end
    if storageComplaint > 0 then return end
    storageComplaint = 300
    if not util.asks(OF.notify, "show") then

        util.chat("Could not save '" .. tostring(key)
            .. "'. The save file is full.", "warn")
        return
    end
    OF.notify.show("Could not save - the save file is full", "bad", 8)
end

local storageStamp = 0

function util.storage_stamp()
    return storageStamp
end

local tidy = { count = nil, check = true, job = nil }

local function key_exists(key)
    if mod_storage_exists ~= nil then return mod_storage_exists(key) == true end
    return mod_storage_load(key) ~= nil
end

local function stamp_writes()
    local WRITERS = {
        "mod_storage_save", "mod_storage_save_bool",
        "mod_storage_save_number", "mod_storage_save_integer",
        "mod_storage_remove", "mod_storage_clear",
    }
    for _, name in ipairs(WRITERS) do
        local engine = _G[name]
        if type(engine) == "function" and not util.stampedWriters then
            local removes = name == "mod_storage_remove"
            local clears = name == "mod_storage_clear"
            _ENV[name] = function(...)
                local key = ...
                if tidy.count == nil or clears or type(key) ~= "string" then
                    storageStamp = storageStamp + 1
                    local result = engine(...)
                    if clears and tidy.count ~= nil then tidy.count = 0 end
                    return result
                end

                local had = key_exists(key)
                storageStamp = storageStamp + 1
                local result = engine(...)
                if removes then
                    if had and result then tidy.count = tidy.count - 1 end
                elseif result and not had then
                    tidy.count = tidy.count + 1
                    tidy.check = true
                end
                return result
            end
        end
    end
    util.stampedWriters = true
end
stamp_writes()

function util.stored_count(memo, list, expiry_of)
    if type(memo) ~= "table" or type(list) ~= "function" then return 0 end
    local now = util.asks(OF.jail, "now") and OF.jail.now() or 0
    local ripe = memo.due ~= nil and memo.due > 0 and now > 0 and now >= memo.due
    if memo.stamp == storageStamp and not ripe then return memo.count or 0 end

    local entries = list()
    local due
    if type(expiry_of) == "function" then
        for _, entry in ipairs(entries) do
            local ends = expiry_of(entry)
            if type(ends) == "number" and ends > 0
                and (due == nil or ends < due) then due = ends end
        end
    end
    memo.stamp = storageStamp
    memo.due = due
    memo.count = #entries
    return memo.count
end

util.MAX_KEYS = 4096
util.TIDY_AT = 0.90
util.TIDY_TOURNEY_AT = 0.85
util.TIDY_TO = 0.75
util.TIDY_PER_FRAME = 2

util.TIDY_ORDER = {
    { key = "stats",    name = "old stat keys", from = function()
        return util.asks(OF.stats, "tidy_entries") and OF.stats.tidy_entries() or {} end },
    { key = "ranks",    name = "unused ranks",  from = function()
        return util.asks(OF.ranks, "tidy_entries") and OF.ranks.tidy_entries() or {} end },
    { key = "mutes",    name = "mutes",         from = function()
        return util.asks(OF.mute, "tidy_entries") and OF.mute.tidy_entries() or {} end },
    { key = "warnings", name = "warnings",      from = function()
        return util.asks(OF.jail, "tidy_warnings") and OF.jail.tidy_warnings() or {} end },
    { key = "notes",    name = "notes",         from = function()
        return util.asks(OF.notes, "tidy_entries") and OF.notes.tidy_entries() or {} end },
    { key = "settings", name = "settings",      from = function()
        return util.settings_tidy_entries() end },
    { key = "bans",     name = "bans and jail sentences", from = function()
        local list = util.asks(OF.jail, "tidy_entries") and OF.jail.tidy_entries() or {}
        if util.asks(OF.jail, "tidy_sentences") then
            for _, entry in ipairs(OF.jail.tidy_sentences()) do list[#list + 1] = entry end
        end
        return list end },
}

util.SETTINGS_PREFIX = "set_"
function util.settings_tidy_entries()
    local list = {}
    for key in pairs(mod_storage_load_all() or {}) do
        if string.sub(key, 1, #util.SETTINGS_PREFIX) == util.SETTINGS_PREFIX then
            list[#list + 1] = { keys = { key }, at = 0 }
        end
    end
    return list
end

function util.storage_keys()
    if tidy.count == nil then
        local n = 0
        for _ in pairs(mod_storage_load_all() or {}) do n = n + 1 end
        tidy.count = n
    end
    return tidy.count
end

function util.tidy_job()
    return tidy.job
end

local function tidy_protected()
    local keep = {}
    for _, entry in ipairs(util.connected_players()) do
        local coopnet, named = util.player_identities(entry.localIndex)
        if coopnet ~= nil then keep[coopnet] = true end
        if named ~= nil then keep[named] = true end
    end
    local coopnet, named = util.player_identities(0)
    if coopnet ~= nil then keep[coopnet] = true end
    if named ~= nil then keep[named] = true end
    return keep
end

function util.start_tidy(share)
    if tidy.job ~= nil then return false end
    share = tonumber(share) or util.TIDY_AT
    if util.storage_keys() < math.ceil(util.MAX_KEYS * share) then return false end
    local keep = tidy_protected()
    local queue = {}
    for rank, category in ipairs(util.TIDY_ORDER) do
        local ok, entries = pcall(category.from)
        local mine = {}
        for _, entry in ipairs(ok and type(entries) == "table" and entries or {}) do
            local spared = false
            for _, id in ipairs(entry.who or {}) do
                if keep[id] then spared = true end
            end
            if not spared and type(entry.keys) == "table" and #entry.keys > 0 then
                mine[#mine + 1] = { keys = entry.keys, at = tonumber(entry.at) or 0,
                                    first = tostring(entry.keys[1]), rank = rank }
            end
        end

        table.sort(mine, function(a, b)
            if a.at ~= b.at then return a.at < b.at end
            return a.first < b.first
        end)
        for _, entry in ipairs(mine) do queue[#queue + 1] = entry end
    end
    tidy.job = { queue = queue, entry = 1, key = 1, freed = 0, keysFreed = 0,
                 byRank = {},
                 target = math.floor(util.MAX_KEYS * util.TIDY_TO) }
    return #queue
end

function util.tidy_before_tournament()
    return util.start_tidy(util.TIDY_TOURNEY_AT)
end

util.TIDY_NOTHING = "nothing - all of it is in use"
local function tidy_report(job)
    local parts = {}
    for rank, category in ipairs(util.TIDY_ORDER) do
        local n = job.byRank[rank]
        if n ~= nil and n > 0 then
            parts[#parts + 1] = tostring(n) .. " " .. category.name
        end
    end
    local said = #parts > 0 and table.concat(parts, ", ") or util.TIDY_NOTHING
    job.said = said
    local nothing = #parts == 0
    if nothing and util.tidyFullSaid then return end
    util.tidyFullSaid = nothing or nil
    if util.asks(OF.actionlog, "auto") then
        OF.actionlog.auto(OF.lang.fill("Tidied the save file: freed @", said))
    end
    if nothing and util.is_host() then
        util.chat(OF.lang.t("Save file is full and nothing could be cleared - see /ofdiag"), "warn")
    end
end

function util.tidy_reading()
    local job = util.lastTidy
    if job == nil then return nil end
    return tostring(util.storage_keys()) .. " of " .. tostring(util.MAX_KEYS)
        .. " keys   last tidy freed " .. tostring(job.said or util.TIDY_NOTHING)
end

function util.tidy_step()
    local job = tidy.job
    if job == nil then return 0 end
    local removed = 0
    while removed < util.TIDY_PER_FRAME do
        local entry = job.queue[job.entry]
        if entry == nil or (job.key == 1 and util.storage_keys() <= job.target) then
            tidy.job = nil
            util.lastTidy = job
            tidy_report(job)
            return removed
        end
        local key = entry.keys[job.key]
        if key ~= nil then
            util.drop_pending(key)
            if mod_storage_remove(key) then job.keysFreed = job.keysFreed + 1 end
            removed = removed + 1
            job.key = job.key + 1
        end
        if entry.keys[job.key] == nil then
            job.byRank[entry.rank] = (job.byRank[entry.rank] or 0) + 1
            job.freed = job.freed + 1
            job.entry, job.key = job.entry + 1, 1
        end
    end
    return removed
end

function util.tidy_frame()
    if tidy.job ~= nil then return util.tidy_step() end
    if not tidy.check then return 0 end
    tidy.check = false
    util.start_tidy(util.TIDY_AT)
    return 0
end

local NOTHING = {}
local snapshotStamp = -1
local snapshot = nil
local answered = {}

local engineAll = _G.mod_storage_load_all

local function section()
    if snapshot ~= nil and snapshotStamp == storageStamp then return snapshot end
    if type(engineAll) ~= "function" then return nil end
    local all = engineAll()
    if all == nil then return nil end
    snapshot = all
    snapshotStamp = storageStamp
    answered = {}
    util.storageCopies = (util.storageCopies or 0) + 1
    return snapshot
end

local function loaded(key)
    local all = section()
    if all == nil then return nil, false end
    local held = answered[key]
    if held ~= nil then
        if held == NOTHING then return nil, true end
        return held, true
    end
    local raw = all[key]

    if raw == nil or raw == "" then
        answered[key] = NOTHING
        return nil, true
    end

    local text = string.sub(raw, 1, 1023)
    answered[key] = text
    return text, true
end

local function wrap_readers()
    if util.cachedReaders then return end
    util.cachedReaders = true

    local engineLoad = _G.mod_storage_load
    local engineInteger = _G.mod_storage_load_integer
    local engineNumber = _G.mod_storage_load_number
    local engineBool = _G.mod_storage_load_bool
    local engineExists = _G.mod_storage_exists
    local engineLoadAll = _G.mod_storage_load_all

    if type(engineLoad) == "function" then
        _ENV.mod_storage_load = function(key, ...)
            local given = select("#", ...)
            local fallback = ...
            if type(key) ~= "string" or given > 1
                or (given == 1 and type(fallback) ~= "string") then
                return engineLoad(key, ...)
            end
            local text, served = loaded(key)
            if not served then return engineLoad(key, ...) end
            if text ~= nil then return text end
            return fallback
        end
    end

    if type(engineInteger) == "function" then
        _ENV.mod_storage_load_integer = function(key, ...)
            local given = select("#", ...)
            local fallback = ...
            if type(key) ~= "string" or given > 1
                or (given == 1 and type(fallback) ~= "number"
                    and type(fallback) ~= "boolean") then
                return engineInteger(key, ...)
            end
            local text, served = loaded(key)
            if not served then return engineInteger(key, ...) end
            if text == nil then return fallback end

            local number = tonumber(text)
            if number == nil then return engineInteger(key, ...) end
            return math.floor(number)
        end
    end

    if type(engineNumber) == "function" then
        _ENV.mod_storage_load_number = function(key, ...)
            local given = select("#", ...)
            local fallback = ...
            if type(key) ~= "string" or given > 1
                or (given == 1 and type(fallback) ~= "number"
                    and type(fallback) ~= "boolean") then
                return engineNumber(key, ...)
            end
            local text, served = loaded(key)
            if not served then return engineNumber(key, ...) end
            if text == nil then return fallback end
            local number = tonumber(text)
            if number == nil then return engineNumber(key, ...) end
            return number
        end
    end

    if type(engineBool) == "function" then
        _ENV.mod_storage_load_bool = function(key, ...)
            local given = select("#", ...)
            local fallback = ...
            if type(key) ~= "string" or given > 1
                or (given == 1 and type(fallback) ~= "boolean") then
                return engineBool(key, ...)
            end
            local text, served = loaded(key)
            if not served then return engineBool(key, ...) end
            if text == nil then return fallback end
            return text == "true"
        end
    end

    if type(engineLoadAll) == "function" then
        _ENV.mod_storage_load_all = function(...)
            if select("#", ...) ~= 0 then return engineLoadAll(...) end
            local all = section()
            if all == nil then return engineLoadAll() end

            local out = {}
            for key, text in pairs(all) do out[key] = text end
            util.storageCopies = (util.storageCopies or 0) + 1
            return out
        end
    end

    if type(engineExists) == "function" then
        _ENV.mod_storage_exists = function(key, ...)
            if type(key) ~= "string" or select("#", ...) ~= 0 then
                return engineExists(key, ...)
            end
            local text, served = loaded(key)
            if not served then return engineExists(key) end
            return text ~= nil
        end
    end
end
wrap_readers()

util.storageCopies = util.storageCopies or 0

function util.storage_copies()
    return util.storageCopies or 0
end

hook_event(HOOK_UPDATE, function()
    if storageComplaint > 0 then storageComplaint = storageComplaint - 1 end

    util.flush_storage(false)

    util.tidy_frame()

    util.tick_frame()

    util.sweep_stale_rows()

    util.camera_behind_update()

    util.round_meter_step()
end)

hook_event(HOOK_ON_LEVEL_INIT, function() util.flush_storage(true) end)
hook_event(HOOK_ON_EXIT, function() util.flush_storage(true) end)

local function already_stored(key, text)
    if mod_storage_load == nil then return false end

    return util.stored(key) == text
end

util.storeWrites = util.storeWrites or 0

local function storing()
    util.storeWrites = util.storeWrites + 1
end

function util.store(key, value)
    local text = util.storage_value(value)
    if text == "" then return util.clear(key) end
    if already_stored(key, text) then return true end

    util.drop_pending(key)
    storing()
    local ok = mod_storage_save(key, text)
    if not ok then report_refusal(key) end
    return ok
end

local waiting = { byKey = {}, order = {}, count = 0 }

function util.storage_pending()
    return waiting.count
end

function util.forget_pending()
    local dropped = waiting.count
    waiting.byKey, waiting.order, waiting.count = {}, {}, 0
    return dropped
end

function util.drop_pending(key)
    if waiting.byKey[key] == nil then return false end
    waiting.byKey[key] = nil
    waiting.count = waiting.count - 1
    return true
end

function util.stored(key, default)
    local marked = waiting.byKey[key]
    if marked ~= nil then return marked end
    if default == nil then return mod_storage_load(key) end
    return mod_storage_load(key, default)
end

function util.stored_integer(key, default)
    local marked = waiting.byKey[key]
    if marked ~= nil then return math.floor(tonumber(marked) or 0) end
    return mod_storage_load_integer(key, default or 0)
end

function util.stored_all()
    local all = mod_storage_load_all()
    if all == nil then return nil end
    local out = {}
    for key, text in pairs(all) do out[key] = text end
    for key, text in pairs(waiting.byKey) do out[key] = text end
    return out
end

function util.store_soon(key, value)
    local text = util.storage_value(value)

    if text == "" then return util.clear(key) end

    if util.stored(key) == text then return true end
    if waiting.byKey[key] == nil then
        waiting.count = waiting.count + 1
        table.insert(waiting.order, key)
    end
    waiting.byKey[key] = text
    return true
end

function util.store_soon_integer(key, value)
    return util.store_soon(key, tostring(math.floor(tonumber(value) or 0)))
end

function util.flush_storage(everything)
    local wrote = 0
    while #waiting.order > 0 do
        local key = table.remove(waiting.order, 1)
        local text = waiting.byKey[key]

        if text ~= nil then
            waiting.byKey[key] = nil
            waiting.count = waiting.count - 1
            storing()
            if not mod_storage_save(key, text) then report_refusal(key) end
            wrote = wrote + 1
            if not everything then return wrote end
        end
    end
    return wrote
end

local PUBLISH_MAX = 256

function util.publish_to(syncTable, key, value)
    if syncTable == nil then return false end

    if value ~= value then return false end

    if type(value) == "string" then
        if value == "" then
            if OF.wireWatch then
                local was = syncTable[key]
                syncTable[key] = nil
                OF.note_sync(key, was ~= nil)
                return true
            end
            syncTable[key] = nil
            return true
        end
        if #value > PUBLISH_MAX then
            util.chat("Too much to send in '" .. tostring(key)
                .. "' (" .. #value .. " characters, " .. PUBLISH_MAX .. " is the limit).", "warn")
            return false
        end
    end

    if OF.wireWatch then
        local was = syncTable[key]
        syncTable[key] = value
        OF.note_sync(key, was ~= value)
        return true
    end

    syncTable[key] = value
    return true
end

util.publishHeld = nil

function util.publish(key, value)

    local held = util.publishHeld
    if held ~= nil then
        held[#held + 1] = { key = key, value = value }
        return true
    end
    local guard = OF.guard
    local watched = guard ~= nil and guard.remember ~= nil

    local was
    if watched then
        was = guard.truth[key]
        if value == "" then
            guard.remember(key, nil)
        else
            guard.remember(key, value)
        end
    end

    local ok = util.publish_to(gGlobalSyncTable, key, value)

    if watched then

        if not ok then guard.remember(key, was) end
        if ok then guard.begin(key) end
    end
    return ok
end

function util.chunk_parts(parts, width)
    local chunks, current = {}, ""
    for _, piece in ipairs(parts) do
        if #piece > width then return nil end
        if #current + #piece > width then
            table.insert(chunks, current)
            current = ""
        end
        current = current .. piece
    end
    if current ~= "" then table.insert(chunks, current) end
    return chunks
end

do

local joinedMemo = setmetatable({}, { __mode = "k" })
local rowMemo = setmetatable({}, { __mode = "k" })

function util.joined(keys, swap, to)
    local first, found, memo, dirty = nil, 0, joinedMemo[keys], false
    for index = 1, #keys do
        local key = keys[index]
        local piece = gGlobalSyncTable[key]
        if key == swap then piece = to end
        if type(piece) ~= "string" or piece == "" then break end
        found = found + 1
        if found == 1 then
            first = piece
        elseif memo == nil then
            memo = { first }
            joinedMemo[keys] = memo
            dirty = true
        end
        if memo ~= nil and memo[found] ~= piece then
            memo[found] = piece
            dirty = true
        end
    end
    if found <= 1 then
        if memo ~= nil then memo.n = found end
        if found == 0 then return "" end
        return first
    end
    if dirty or memo.n ~= found then
        memo.n = found
        memo.glued = table.concat(memo, "", 1, found)
    end
    return memo.glued
end

function util.joined_row(localIndex, keys)
    local row = gPlayerSyncTable[localIndex]
    if row == nil then return "" end
    local byRow = rowMemo[keys]
    local first, found, memo, dirty = nil, 0, byRow and byRow[localIndex], false
    for index = 1, #keys do
        local piece = row[keys[index]]
        if type(piece) ~= "string" or piece == "" then break end
        found = found + 1
        if found == 1 then
            first = piece
        elseif memo == nil then
            memo = { first }
            if byRow == nil then
                byRow = {}
                rowMemo[keys] = byRow
            end
            byRow[localIndex] = memo
            dirty = true
        end
        if memo ~= nil and memo[found] ~= piece then
            memo[found] = piece
            dirty = true
        end
    end
    if found <= 1 then
        if memo ~= nil then memo.n = found end
        if found == 0 then return "" end
        return first
    end
    if dirty or memo.n ~= found then
        memo.n = found
        memo.glued = table.concat(memo, "", 1, found)
    end
    return memo.glued
end
end

function util.pack_to_keys(list, row, widest, narrowest, separator, keys, width)
    separator = separator or ";"
    widest = widest or 12
    narrowest = math.min(narrowest or 6, widest)
    local at = widest
    while true do
        local parts = {}
        for _, entry in ipairs(list) do
            table.insert(parts, row(entry, at) .. separator)
        end

        local chunks = util.chunk_parts(parts, width)
        if chunks ~= nil and #chunks <= #keys then
            return chunks, #parts, at
        end

        if at > narrowest then
            at = at - 1
        else

            while #parts > 0 do
                table.remove(parts)
                chunks = util.chunk_parts(parts, width)
                if chunks ~= nil and #chunks <= #keys then
                    return chunks, #parts, at
                end
            end
            return {}, 0, at
        end
    end
end

local PACKET_TEXT_MAX = 256

util.PACKET_BYTES_MAX = 2500
util.PACKET_KEYS_MAX = 200

function util.lnt_size(v)
    local kind = type(v)
    if kind == "number" or kind == "nil" then return kind == "nil" and 1 or 9 end
    if kind == "boolean" then return 2 end
    if kind == "string" then return 3 + #v end
    return 9
end

function util.packet_cost(data)
    if type(data) ~= "table" then return 0, 0 end
    local bytes, keys = 16, 0
    for k, v in pairs(data) do
        keys = keys + 1
        bytes = bytes + util.lnt_size(k) + util.lnt_size(v)
    end
    return bytes, keys
end

function util.packet_fits(data)
    local bytes, keys = util.packet_cost(data)
    if bytes <= util.PACKET_BYTES_MAX and keys <= util.PACKET_KEYS_MAX then return true end
    if OF.record_fault ~= nil then
        OF.record_fault("packet " .. tostring(type(data) == "table" and data.ofp or "?"),
            "not sent: " .. bytes .. " bytes, " .. keys .. " keys")
    end
    return false
end

function util.packet_safe(data)
    if type(data) ~= "table" then return data end
    for key, value in pairs(data) do
        if type(value) == "string" then
            if value == "" or #value > PACKET_TEXT_MAX then data[key] = nil end
        end
    end
    return data
end

function util.send_all(data)
    if OF.wireWatch then OF.note_packet(data ~= nil and data.ofp or nil) end
    if not util.packet_fits(data) then return false end
    network_send(true, util.packet_safe(data))
    return true
end

function util.send_all_unreliable(data)
    if OF.wireWatch then OF.note_packet(data ~= nil and data.ofp or nil) end
    if not util.packet_fits(data) then return false end
    network_send(false, util.packet_safe(data))
    return true
end

function util.send_raw(localIndex, data)
    if localIndex == nil then return false end
    if localIndex <= 0 or localIndex >= MAX_PLAYERS then return false end
    data.from = network_global_index_from_local(0)
    if OF.wireWatch then OF.note_packet(data.ofp) end
    if not util.packet_fits(data) then return false end
    network_send_to(localIndex, true, util.packet_safe(data))
    return true
end

function util.tell_all(data)
    if not util.is_host() then return false end
    local sent = 0
    for _, entry in ipairs(util.connected_players()) do
        if entry.localIndex > 0 then
            local copy = {}
            for key, value in pairs(data) do copy[key] = value end
            if util.send_to_player(entry.localIndex, copy) then sent = sent + 1 end
        end
    end
    return true, sent
end

function util.from_host(data)
    if type(data) ~= "table" then return false end
    if util.is_host() then return false end
    if not util.asks(OF.pass, "is_mine") then return false end
    return OF.pass.is_mine(data.pk)
end

function util.from_host_effect(data)
    if type(data) ~= "table" then return false end
    if util.is_host() then return false end

    if util.from_host(data) then return true end

    return data.from == 0
end

function util.may_act_on(asker, target)
    if target == nil then
        return false, "They have left the lobby."
    end

    if util.is_host_player(target) then
        return false, "The host is not somebody you can do that to."
    end

    if OF.perms.shield(target) >= OF.perms.tier(asker) then
        if OF.util.asks(OF.perms, "is_shielded") and OF.perms.is_shielded(target) then
            return false, "The host has put them out of a moderator's reach."
        end
        return false, "They are your rank or above it."
    end
    return true
end

function util.tell_asker(askerGlobal, why)
    if askerGlobal == nil or why == nil then return false end
    if not OF.util.asks(OF.notify, "send_to") then return false end
    OF.notify.send_to(askerGlobal, "@", "bad", 5, tostring(why))
    return true
end

function util.asked_by(data)
    if type(data) ~= "table" then return nil end
    if not util.is_host() then return nil end
    if not util.asks(OF.pass, "owner") then return nil end
    local globalIndex = OF.pass.owner(data.pk)
    if globalIndex == nil then return nil end
    local localIndex = util.local_from_global(globalIndex)
    if localIndex == nil then return nil end

    if util.asks(OF.actionlog, "behalf") then
        local np = gNetworkPlayers[localIndex]
        if np ~= nil then OF.actionlog.behalf(np.name) end
    end

    return localIndex, globalIndex
end

function util.send_to_host(data, unreliable)
    if util.is_host() then return false end
    local li = util.local_from_global(0)

    if li == nil or li <= 0 then return false end

    data.from = network_global_index_from_local(0)

    if util.asks(OF.pass, "mine") then data.pk = OF.pass.mine() end
    if OF.wireWatch then OF.note_packet(data.ofp) end
    if not util.packet_fits(data) then return false end
    network_send_to(li, unreliable ~= true, util.packet_safe(data))
    return true
end

function util.send_anonymous(data)

    if util.is_host() then return false end
    local li = util.local_from_global(0)
    if li == nil or li <= 0 then return false end

    if OF.wireWatch then OF.note_packet(data ~= nil and data.ofp or nil) end
    if not util.packet_fits(data) then return false end
    network_send_to(li, true, util.packet_safe(data))
    return true
end

function util.send_to_player(localIndex, data, unreliable)
    if localIndex == nil then return false end
    if localIndex <= 0 or localIndex >= MAX_PLAYERS then return false end

    data.from = network_global_index_from_local(0)

    if util.is_host() and util.asks(OF.pass, "of") then
        local globalIndex = network_global_index_from_local(localIndex)
        data.pk = OF.pass.of(globalIndex)

        if data.pk == nil then
            if unreliable == true then return false end
            OF.pass.hold(globalIndex, data)
            return false, "They are still arriving - it will reach them."
        end
    end
    if OF.wireWatch then OF.note_packet(data.ofp) end
    if not util.packet_fits(data) then return false end
    network_send_to(localIndex, unreliable ~= true, util.packet_safe(data))
    return true
end

function util.publish_row(localIndex, key, value)

    if key == "ofScore" and value ~= util.PLAYER_ROW_DEFAULTS.ofScore
        and util.asks(OF.gamemodes, "is_waiting") and OF.gamemodes.is_waiting() then
        return false
    end

    if localIndex == 0 and not util.viewSwapped
        and OF.util.asks(OF.guard, "remember_mine") then
        OF.guard.remember_mine(key, value)
    end
    return util.publish_to(gPlayerSyncTable[localIndex], key, value)
end

function util.publish_limit()
    return PUBLISH_MAX
end

util.STORE_MAX = 1023

function util.pack_rows(rows, separator, limit)
    separator = separator or ";"
    limit = limit or PUBLISH_MAX
    local packed = ""
    local used = 0
    for _, row in ipairs(rows) do
        local candidate = (used == 0) and row or (packed .. separator .. row)
        if #candidate > limit then break end
        packed = candidate
        used = used + 1
    end
    return packed, used
end

function util.pack_to_fit(list, row, widest, narrowest, separator, limit)
    widest = widest or 12
    narrowest = math.min(narrowest or 6, widest)
    local width = widest
    while true do
        local parts = {}
        for _, entry in ipairs(list) do
            table.insert(parts, row(entry, width))
        end
        local packed, used = util.pack_rows(parts, separator, limit)
        if used >= #list or width <= narrowest then
            return packed, used, width
        end
        width = width - 1
    end
end

function util.clear(key)

    util.drop_pending(key)
    storing()
    if mod_storage_remove(key) then return true end
    if not mod_storage_exists(key) then return true end
    report_refusal(key)
    return false
end

function util.store_integer(key, value)
    if already_stored(key, tostring(math.floor(value or 0))) then return true end

    util.drop_pending(key)
    storing()
    local ok = mod_storage_save_integer(key, value)
    if not ok then report_refusal(key) end
    return ok
end

function util.store_bool(key, value)
    if already_stored(key, value and "true" or "false") then return true end

    util.drop_pending(key)
    storing()
    local ok = mod_storage_save_bool(key, value)
    if not ok then report_refusal(key) end
    return ok
end

function util.migrate_storage_keys()
    if mod_storage_load_all == nil then return 0 end
    local all = mod_storage_load_all()
    if all == nil then return 0 end

    local renames = {}
    for key, value in pairs(all) do
        if string.find(key, "%%") ~= nil then
            local prefix, id = string.match(key, "^(%w+_)(.*)$")
            if prefix ~= nil then

                local settled = util.storage_escape(util.storage_unescape(id)) == id
                local fresh = prefix .. util.storage_escape(id)
                if not settled and fresh ~= key and all[fresh] == nil then
                    renames[key] = { key = fresh, value = value }
                end
            end
        end
    end

    local count = 0
    for old, entry in pairs(renames) do
        mod_storage_save(entry.key, tostring(entry.value))
        mod_storage_remove(old)
        count = count + 1
    end
    return count
end

util.migrate_storage_keys()

util.PLAYER_ROW_DEFAULTS = {
    ofTier = nil,
    ofMuted = false,
    ofJailed = "",
    ofNoRace = false,
    ofNoRun = false,

    ofOnLine = 0,
    ofSpectating = false,
    ofRole = "",
    ofScore = 0,
    ofGmTime = 0,
    ofHpGrab = 0,
    ofSplits = "",
    ofRunTime = 0,
    ofRunGot = 0,

    ofSplitGot = 0,
    ofCheats = "",

    ofCheats2 = "",
    ofCheats3 = "",
    ofCheats4 = "",
    ofCheats5 = "",

    ofSmashPct = 0,
    ofSmashKOs = 0,
    ofSmashFall = "",

    ofSmashGrab = 0,
    ofSmashUse = "",
    ofSmashShare = "",

    ofShotFar = 0,

    ofGmBlastPress = 0,
    ofTeam = "",
    ofVoted = "",
    ofIdle = false,

    ofInMenu = false,

    ofPicking = false,

    ofSteerYaw = "",
    ofHsFresh = false,

    ofHsFrozen = false,

    ofMhDied = 0,

    ofMhCard = "",
    ofForgeSize = "",

    ofCostume = "",

    ofMyShape = "",

    ofCrownGave = 0,

    ofCrownDied = 0,

    ofBingoMarks = 0,

    ofEmote = 0,

    ofHold = "",

    ofHeld = "",

    ofPerch = "",

    ofScale = 1.0,

    ofUnseen = false,

    ofTasPlay = false,

    ofClones = 0,

    ofClonesGone = 0,

    ofInvisible = 0,

    ofClass = 0,

    ofGulp = 0,
    ofMouth = 0,

    ofCoinSpill = 0,

    ofStill = false,

    ofFacing = false,

    ofPresses = 0,

    ofForgeReach = "",
    ofForgeMoved = "",
    ofDoorMine = "",
    ofHat = "",

    ofPet = "",

    ofPetName = "",

    ofPossess = "",

    ofWorn = "",

    ofSpotsClaim = 0,

    ofBonusTook = "",

    ofRollAim = 0,
    ofHpGrabAt = 1,

    ofBankHeld = 0,

    ofRcState = "",

    ofDhState = "",

    ofBountyAt = "",

    ofBountyTo = -1,
    ofBountySeq = 0,
    ofCaughtBy = "",

    ofBalAt = "",
    ofBalFound = "",

    ofPhProp = 0,
    ofPhLift = 0,
    ofOitcKills = 0,
    ofRktBlast = "",
    ofRktGrab = 0,
    ofRktShot = "",
    ofRktDownBy = "",
    ofCrHeld = false,

    ofCrownTo = "",

    ofRope = "",
    ofBond = "",

    ofCrew = "",

    ofTicks = "",

    ofPhoto = false,

    ofMvPick = 0,

    ofTurfPaint = "",

    ofFzRow = "",

    ofSilverGot = 0,

    ofFsHits = 0,

    ofSbState = "",
    ofSbGrab = "",

    ofPermadead = false,

    ofFbKick = "",

    ofVbHit = "",

    ofBallRide = "",

    ofGlassRow = 0,
    ofGlassFell = 0,

    ofGdPos = "",

    ofDfParry = "0 0 0",
    ofDfHit = "0 0",
    ofDfLives = 0,

    ofUpside = 0,
}

function util.clear_player_row(localIndex)
    local row = gPlayerSyncTable[localIndex]
    if row == nil then return end

    util.forget_host_records(localIndex)

    for key, value in pairs(util.PLAYER_ROW_DEFAULTS) do
        util.publish_row(localIndex, key, value)
    end

    row.ofTier = nil
end

function util.forget_host_records(localIndex)
    if OF.util.asks(OF.ranks, "forget") then
        OF.ranks.forget(localIndex)
    end
    if OF.util.asks(OF.jail, "forget_sentence") then
        OF.jail.forget_sentence(localIndex)
    end
end

local function row_holds_somebody(localIndex)
    local row = gPlayerSyncTable ~= nil and gPlayerSyncTable[localIndex] or nil
    if row == nil then return false end

    if row.ofTier ~= nil then return true end
    for key, value in pairs(util.PLAYER_ROW_DEFAULTS) do
        local have = row[key]
        if have ~= nil and have ~= value then return true end
    end
    return false
end

util.sweptRows = util.sweptRows or false

function util.sweep_stale_rows()
    if util.sweptRows then return 0 end

    local me = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if me == nil or me.connected ~= true then return 0 end

    util.sweptRows = true
    if not util.is_host() then return 0 end

    local swept = 0
    for i = 1, (MAX_PLAYERS or 1) - 1 do
        local np = gNetworkPlayers[i]
        if (np == nil or np.connected ~= true) and row_holds_somebody(i) then
            util.clear_player_row(i)
            swept = swept + 1
        end
    end
    return swept
end

hook_event(HOOK_ON_PLAYER_DISCONNECTED, function(m)
    if m == nil then return end
    if not util.is_host() then return end
    if m.playerIndex == 0 then return end

    if OF.wireWatch then OF.wire_mark("a player left") end
    util.clear_player_row(m.playerIndex)
end)

local TICK_KEY = "ofTicks"
local TICK_FPS = 30

local TICK_NAME_MAX = 8
local TICK_SECONDS_MAX = 5999
local TICK_MOST = 6

util.TICK_WIDEST = TICK_MOST * (TICK_NAME_MAX + 1 + #tostring(TICK_SECONDS_MAX))
    + (TICK_MOST - 1)

local tickFrames = {}

local tickSeen = {}

local tickRaw = {}

local tickSaid = {}
local tickPublished = nil

local function tick_seconds(frames)
    return math.ceil(frames / TICK_FPS)
end

local function tick_name_ok(name)
    if type(name) ~= "string" then return false end
    if #name < 1 or #name > TICK_NAME_MAX then return false end
    return string.match(name, "^%w+$") ~= nil
end

local function tick_pack(byName, said)
    local names = {}
    for name in pairs(byName) do table.insert(names, name) end
    table.sort(names)
    local parts = {}
    for _, name in ipairs(names) do
        local seconds = tick_seconds(byName[name])
        said[name] = seconds
        table.insert(parts, name .. ":" .. seconds)
    end
    return table.concat(parts, ";")
end

local function tick_parse(text)
    local out = {}
    if type(text) ~= "string" or text == "" then return out end
    local kept = 0
    for piece in string.gmatch(text, "[^;]+") do
        local name, seconds = string.match(piece, "^(%w+):(%d+)$")
        local value = tonumber(seconds)
        if kept < TICK_MOST and name ~= nil and value ~= nil
            and tick_name_ok(name) and value <= TICK_SECONDS_MAX then
            out[name] = value
            kept = kept + 1
        end
    end
    return out
end

local function tick_publish()
    local mine = tickFrames[0]
    local said = {}
    local packed = (mine ~= nil) and tick_pack(mine, said) or ""
    tickSaid = said

    tickPublished = (packed ~= "") and packed or nil
    util.publish_row(0, TICK_KEY, packed)
end

function util.tick_row(name, seconds)
    if not tick_name_ok(name) then return false end

    local mine = tickFrames[0]
    if mine == nil then
        mine = {}
        tickFrames[0] = mine
    end

    if seconds == nil then
        if mine[name] == nil then return true end
        mine[name] = nil
        tick_publish()
        return true
    end

    if type(seconds) ~= "number" then return false end

    if seconds ~= seconds then return false end
    if seconds < 0 or seconds > TICK_SECONDS_MAX then return false end

    if mine[name] == nil then
        local live = 0
        for _ in pairs(mine) do live = live + 1 end
        if live >= TICK_MOST then return false end
    end

    mine[name] = math.floor(seconds * TICK_FPS)
    tick_publish()
    return true
end

function util.row_ticks(localIndex, name)
    local held = tickFrames[localIndex]
    if held == nil then return nil end
    return held[name]
end

function util.tick_frame()
    for localIndex = 0, MAX_PLAYERS - 1 do
        local row = gPlayerSyncTable[localIndex]

        if localIndex ~= 0 and row ~= nil then
            local raw = row[TICK_KEY]
            if raw ~= tickRaw[localIndex] then
                tickRaw[localIndex] = raw
                local said = tick_parse(raw)
                local seen = tickSeen[localIndex] or {}
                local held = tickFrames[localIndex] or {}
                for name, seconds in pairs(said) do
                    if seen[name] ~= seconds then
                        seen[name] = seconds
                        held[name] = seconds * TICK_FPS
                    end
                end

                for name in pairs(held) do
                    if said[name] == nil then
                        held[name] = nil
                        seen[name] = nil
                    end
                end
                tickSeen[localIndex] = seen
                tickFrames[localIndex] = held
            end
        end

        local held = tickFrames[localIndex]
        if held ~= nil then
            for name, frames in pairs(held) do
                if frames > 0 then held[name] = frames - 1 end
            end
        end
    end

    local mine = tickFrames[0]
    if mine == nil or tickPublished == nil then return end
    for name, frames in pairs(mine) do
        if tickSaid[name] ~= tick_seconds(frames) then
            tick_publish()
            return
        end
    end
end

util.missing = util.missing or {}

local FALLBACK_GOLD = { r = 255, g = 255, b = 0 }

function util.gold()
    local value = OF.GOLD
    if type(value) ~= "table" or value.r == nil then return FALLBACK_GOLD end
    return value
end

local function channel(value)
    value = tonumber(value)
    if value == nil then return 255 end
    value = math.floor(value + 0.5)
    if value < 0 then return 0 end
    if value > 255 then return 255 end
    return value
end

local ACCENT_FORMAT = "\\#%02x%02x%02x\\"
function util.colour_escape(r, g, b)
    return string.format(ACCENT_FORMAT, channel(r), channel(g), channel(b))
end

function util.accent()
    local gold = util.gold()
    return util.colour_escape(gold.r, gold.g, gold.b)
end

function util.binding(name)
    local fn = _G[name]
    if type(fn) == "function" then return fn end
    util.missing[name] = true
    return nil
end

function util.optional(name, fallback, ...)
    local fn = util.binding(name)
    if fn == nil then return fallback end
    local ok, result = pcall(fn, ...)
    if not ok then return fallback end
    return result
end

local LCG_A, LCG_C, LCG_M = 1103515245, 12345, 2147483648
local ownState = 1

function util.seed_own(value)
    local n = math.floor(math.abs(tonumber(value) or 1)) % LCG_M
    ownState = n > 0 and n or 1
    return true
end

function util.random()
    ownState = (LCG_A * ownState + LCG_C) % LCG_M
    return math.floor(ownState / 65536) / 32768
end

function util.random_int(low, high)
    if high == nil then low, high = 1, low end
    low, high = math.floor(low or 1), math.floor(high or 1)
    if high < low then low, high = high, low end
    return low + math.floor(util.random() * (high - low + 1)) % (high - low + 1)
end

util.WEIGHT_MOST = 8

local function bounded_weight(value, fallback)
    value = tonumber(value)
    if value == nil then return fallback end
    value = math.floor(value)
    if value < 1 then return 1 end
    if value > util.WEIGHT_MOST then return util.WEIGHT_MOST end
    return value
end

function util.draw_weight(entry, lag)
    if type(entry) ~= "table" then return 1 end
    local weight = bounded_weight(entry.weight, 1)
    local lift = bounded_weight(entry.lift, weight)
    lag = tonumber(lag) or 0
    if lag <= 0 or lift == weight then return weight end
    if lag > 1 then lag = 1 end
    local delta = (lift - weight) * lag
    delta = delta >= 0 and math.floor(delta) or math.ceil(delta)
    return bounded_weight(weight + delta, weight)
end

function util.pick_weighted(choices, lag, roll)
    if type(choices) ~= "table" or #choices == 0 then return nil end
    if type(roll) ~= "function" then return nil end

    local bag = {}
    for _, entry in ipairs(choices) do
        for _ = 1, util.draw_weight(entry, lag) do
            table.insert(bag, entry)
        end
    end

    local at = roll(#bag)
    if type(at) ~= "number" then return nil end
    at = math.floor(at)
    if at < 1 or at > #bag then return nil end
    return bag[at]
end

local seeded = false

function util.seed_random()
    if seeded then return false end
    seeded = true
    local fine = util.optional("clock_elapsed_f64", nil)
    if type(fine) ~= "number" then

        fine = (util.optional("get_global_timer", 0) or 0) / 30
    end
    local mixed = (util.optional("get_time", 0) or 0)
        + math.floor((fine % 1) * 1000000000)
        + network_global_index_from_local(0)

    ownState = math.floor(math.abs(mixed) % LCG_M)
    if ownState <= 0 then ownState = 1 end
    return true
end

function util.missing_bindings()
    local list = {}
    for name in pairs(util.missing) do table.insert(list, name) end
    table.sort(list)
    return list
end

local interpResolved = false
local printInterp = nil

local rectInterp = nil

local function resolve_interp()
    if interpResolved then return end
    interpResolved = true
    local p = _G["djui_hud_print_text_interpolated"]
    if type(p) == "function" then printInterp = p end
    local r = _G["djui_hud_render_rect_interpolated"]
    if type(r) == "function" then rectInterp = r end
end

function util.forget_interp()
    interpResolved = false
    printInterp = nil
    rectInterp = nil
end

function util.interpolates()
    resolve_interp()
    return printInterp ~= nil
end

local function font_handed_back(previous, ok, ...)
    djui_hud_set_font(previous)
    if not ok then error((...), 0) end
    return ...
end

function util.in_font(font, draw)
    if type(draw) ~= "function" then return end

    if font == nil or djui_hud_set_font == nil then return draw() end

    local previous = FONT_NORMAL
    if djui_hud_get_font ~= nil then previous = djui_hud_get_font() end

    djui_hud_set_font(font)
    return font_handed_back(previous, pcall(draw))
end

function util.in_font_call(font, fn, ...)
    if type(fn) ~= "function" then return end
    if font == nil or djui_hud_set_font == nil then return fn(...) end
    local previous = FONT_NORMAL
    if djui_hud_get_font ~= nil then previous = djui_hud_get_font() end
    djui_hud_set_font(font)
    return font_handed_back(previous, pcall(fn, ...))
end

function util.hud_face(text)
    local face = _G["FONT_MENU"]
    if face == nil then return nil end
    if type(text) ~= "string" then return face end

    if string.find(text, "[^\032-\126\t\n]") ~= nil then return nil end
    return face
end

local TITLE_OVER_NORMAL = 32 / 64

function util.hud_scale(face, scale)

    if face == nil or face ~= _G["FONT_MENU"] then return scale end
    return scale * TITLE_OVER_NORMAL
end

function util.round_faces_on()
    local lockdown = OF and OF.lockdown
    if not util.asks(lockdown, "round_or_run") then return false end
    return lockdown.round_or_run() == true
end

function util.round_screen()
    if not util.round_faces_on() then return false end
    local scope = OF and OF.roundscope
    if util.asks(scope, "inside") and scope.inside(0) then return true end

    local modes = OF and OF.gamemodes
    if util.asks(modes, "role") and modes.role(0) ~= nil and modes.role(0) ~= "" then
        return true
    end
    local spectate, act = OF and OF.spectate, OF and OF.roundact
    return util.asks(spectate, "is_spectating") and spectate.is_spectating(0) == true
        and util.asks(act, "watches") and act.watches(0) == true
end

function util.title_face(text)
    local face = util.hud_face(text)
    if face ~= nil then return face end
    if util.round_faces_on() then return _G["FONT_ALIASED"] end
    return nil
end

function util.round_title_face(text)
    if not util.round_faces_on() then return nil end
    return util.title_face(text)
end

function util.round_board_face()
    if not util.round_faces_on() then return nil end
    return _G["FONT_ALIASED"]
end

function util.board_heading_face(text)
    return util.round_title_face(text)
end

function util.board_title(text, x, y, scale, r, g, b, a)
    if type(text) ~= "string" then text = tostring(text or "") end
    local face = util.board_heading_face(text)
    local at = util.hud_scale(face, scale)
    return util.in_font(face, function()
        util.text(text, x, y, at, r, g, b, a)
        return util.text_size(text, at)
    end)
end

function util.board_title_size(text, scale)
    if type(text) ~= "string" then text = tostring(text or "") end
    local face = util.board_heading_face(text)
    local at = util.hud_scale(face, scale)
    return util.in_font(face, function()
        local w, h = util.text_size(text, at)
        return w, h, at
    end)
end

function util.round_title(text, x, y, scale, r, g, b, a, from)
    if type(text) ~= "string" then text = tostring(text or "") end
    local face = util.round_title_face(text)
    local at = util.hud_scale(face, scale)
    if from ~= nil and at ~= scale then
        from.scale = util.hud_scale(face, from.scale or scale)
    end
    return util.in_font(face, function()
        util.text(text, x, y, at, r, g, b, a, from)
        return util.text_size(text, at)
    end)
end

function util.round_title_size(text, scale)
    if type(text) ~= "string" then text = tostring(text or "") end
    local face = util.round_title_face(text)
    local at = util.hud_scale(face, scale)
    return util.in_font(face, function()
        local w, h = util.text_size(text, at)
        return w, h, at
    end)
end

function util.round_board(text, x, y, scale, r, g, b, a, raw)
    if type(text) ~= "string" then text = tostring(text or "") end
    return util.in_font(util.round_board_face(), function()
        if raw then
            util.text_raw(text, x, y, scale, r, g, b, a)
        else
            util.text(text, x, y, scale, r, g, b, a)
        end
        return util.text_size(util.plain(text), scale)
    end)
end

function util.round_board_size(text, scale)
    if type(text) ~= "string" then text = tostring(text or "") end
    return util.in_font(util.round_board_face(), function()
        return util.text_size(text, scale)
    end)
end

do

    util.ROUND_SIZE = { headline = 1.4, line = 1.0, under = 0.76, legend = 0.55 }

    local STEPS = { 1.4, 1.0, 0.76 }
    local EDGES = { 1.15, 0.92 }

    function util.round_scale(size)
        if size == nil then return nil end
        if type(size) == "string" then
            return util.ROUND_SIZE[size] or util.ROUND_SIZE.line
        end
        if type(size) ~= "number" then return util.ROUND_SIZE.line end
        for index, edge in ipairs(EDGES) do
            if size >= edge then return STEPS[index] end
        end
        return STEPS[#STEPS]
    end

    util.ROUND_TONE_NAME = {
        text = "ink", info = "ink2", dim = "mute", good = "good", bad = "bad",
        warn = "warn", cold = "cold", target = "target", objective = "target",
    }
    util.ROUND_TONE = setmetatable({}, { __index = function(_, name)
        local token = util.ROUND_TONE_NAME[name]
        local hud = OF.hud
        if token == nil or hud == nil or hud.C == nil then return nil end
        return hud.C[token]
    end })

    function util.round_tone(tone)
        if tone == "gold" or tone == "accent" then
            local gold = util.gold()
            return gold.r, gold.g, gold.b
        end
        local t = util.ROUND_TONE[tone or "text"] or util.ROUND_TONE.text
        if t == nil then return 255, 255, 255 end
        return t[1], t[2], t[3]
    end

    util.ROUND_ONE_LINE = true
    util.roundLineDrops = 0

    function util.round_line(text, size, tone, opts)
        if opts ~= nil and type(opts.state) == "table" and OF.hud ~= nil
            and type(OF.hud.state_line) == "function" then
            local st = opts.state
            OF.hud.state_line(st.id or st[1] or text, text, { prio = st.prio or st[2],
                tone = st.tone or (tone ~= nil and tone ~= "text" and util.round_tone_token(tone)) or nil,
                figure = st.figure, urgent = st.urgent, colour = st.colour })
            return false
        end
        local r, g, b = util.round_tone(tone)
        local alpha = opts ~= nil and opts.alpha or 255
        return util.banner(text, util.round_scale(size or "line"), r, g, b,
            alpha, opts)
    end

    function util.round_tone_token(tone)
        if tone == "gold" or tone == "accent" then return "accent" end
        return util.ROUND_TONE_NAME[tone or "text"] or "ink"
    end

    function util.round_line_low(text, size, tone, opts)
        local r, g, b = util.round_tone(tone)
        local alpha = opts ~= nil and opts.alpha or 255
        return util.banner_low(text, util.round_scale(size or "line"), r, g, b,
            alpha, opts)
    end

    function util.round_under(text, size, tone)
        local r, g, b = util.round_tone(tone or "info")
        return { text = text, scale = util.round_scale(size or "under"),
            r = r, g = g, b = b }
    end

    local LEGEND_PAD = 6
    local LEGEND_EDGE = 16

    local LEGEND_INSET = 4

    util.LEGEND_ON_SCREEN = false
    util.legendLines = nil
    util.legendDrawn = 0

    function util.legend_forget()
        util.legendLines = nil
    end

    function util.legend(lines, opts)
        if type(lines) ~= "table" or #lines == 0 then return false end
        if util.menu_has_screen() then return false end
        local replay = OF and OF.replay
        if util.asks(replay, "playing") and replay.playing() ~= nil then
            return false
        end
        local playing = OF and OF.gamemodes and OF.gamemodes.current and OF.gamemodes.current() or nil
        local kept = {}
        for index, line in ipairs(lines) do kept[index] = line end
        util.legendLines = { key = playing ~= nil and playing.key or nil, lines = kept }
        if util.LEGEND_ON_SCREEN ~= true then return false end
        util.legendDrawn = util.legendDrawn + 1

        if OF.input ~= nil and type(OF.input.button_text) == "function" then
            local said = {}
            for index, line in ipairs(lines) do said[index] = OF.input.button_text(line) end
            lines = said
        end
        local scale = util.ROUND_SIZE.legend
        djui_hud_set_resolution(RESOLUTION_DJUI)
        local lineH, width = 0, 0
        for _, line in ipairs(lines) do
            local w, h = util.round_title_size(line, scale)
            if w > width then width = w end
            if h > lineH then lineH = h end
        end
        local height = #lines * lineH
        local x = djui_hud_get_screen_width() - width - LEGEND_EDGE - LEGEND_INSET
        local y = math.floor((djui_hud_get_screen_height() - height) / 2)
        local gold = util.gold()
        util.plate(x - LEGEND_PAD, y - LEGEND_PAD, width + LEGEND_PAD * 2 + LEGEND_INSET,
            height + LEGEND_PAD * 2, { edge = gold, alpha = 200 })
        local dimLast = opts == nil or opts.dimLast ~= false
        for at, line in ipairs(lines) do
            local tone = (dimLast and at == #lines) and 180 or 235
            util.round_title(line, x + 4, y + (at - 1) * lineH, scale,
                tone, tone, tone, 255)
        end
        return true, x - LEGEND_PAD, y - LEGEND_PAD, width + LEGEND_PAD * 2 + LEGEND_INSET,
            height + LEGEND_PAD * 2
    end

    local behindOwed = 0
    util.cameraBehindResets = 0

    function util.camera_behind_soon()
        behindOwed = 2
        return true
    end

    function util.camera_behind_owed()
        return behindOwed
    end

    function util.camera_behind_update()
        if behindOwed <= 0 then return false end
        behindOwed = behindOwed - 1
        local m = gMarioStates[0]
        if m == nil or m.area == nil or m.area.camera == nil then return false end
        util.optional("reset_camera", nil, m.area.camera)
        util.cameraBehindResets = util.cameraBehindResets + 1
        return true
    end

end

local print_moving
do
local function print_moving_run(message, prevX, prevY, prevScale, x, y, scale)
    if prevX == nil or printInterp == nil then
        djui_hud_print_text(message, x, y, scale)
        return
    end

    printInterp(message, prevX, prevY, prevScale, prevScale, x, y, scale, scale)
end

local TITLE_TICK_PULL = 0.48

local function title_tick_pull(message)
    if type(message) ~= "string" or string.find(message, "'", 1, true) == nil then
        return 0, 0
    end
    local face = _G["FONT_MENU"]
    if face == nil or djui_hud_get_font == nil or djui_hud_get_font() ~= face then
        return 0, 0
    end
    local count = select(2, string.gsub(message, "'", "'"))
    return count * djui_hud_measure_text("'") * TITLE_TICK_PULL, count
end
util.title_tick_pull = title_tick_pull

print_moving = function(message, prevX, prevY, prevScale, x, y, scale)
    resolve_interp()
    if title_tick_pull(message) == 0 then
        print_moving_run(message, prevX, prevY, prevScale, x, y, scale)
        return
    end

    local pull = djui_hud_measure_text("'") * TITLE_TICK_PULL
    local start, back = 1, 0
    while start <= #message do
        local tick = string.find(message, "'", start, true)
        local stop = tick or #message
        local run = string.sub(message, start, stop)
        local lead = start > 1 and djui_hud_measure_text(string.sub(message, 1, start - 1)) or 0
        local dx = lead - back
        print_moving_run(run,
            prevX ~= nil and prevX + dx * (prevScale or scale) or nil, prevY, prevScale,
            x + dx * scale, y, scale)
        if tick == nil then break end
        back = back + pull
        start = tick + 1
    end
end
end

function util.rect(x, y, w, h, r, g, b, a, from)
    djui_hud_set_color(util.byte(r), util.byte(g), util.byte(b), util.byte(a))
    if from == nil or from.x == nil then
        djui_hud_render_rect(x, y, w, h)
        return
    end
    resolve_interp()
    if rectInterp == nil then
        djui_hud_render_rect(x, y, w, h)
        return
    end
    rectInterp(from.x, from.y, from.width or w, from.height or h, x, y, w, h)
end

function util.meter(x, y, width, height, share, first, second)
    share = util.clamp(share or 0.5, 0, 1)
    local left = math.floor(width * share + 0.5)

    first = first or { r = 255, g = 255, b = 255 }
    second = second or { r = 90, g = 90, b = 90 }

    if left > 0 then
        util.rect(x, y, left, height, first.r, first.g, first.b, 235)
    end
    if left < width then
        util.rect(x + left, y, width - left, height,
            second.r, second.g, second.b, 235)
    end
end

util.CHECKS_MOST = 24
local CHECK_SIZE = 7
local CHECK_GAP = 4

function util.checks(x, y, done, total, colour)
    total = math.floor(util.clamp(total or 0, 0, util.CHECKS_MOST))
    if total <= 0 then return 0 end
    done = math.floor(util.clamp(done or 0, 0, total))

    colour = colour or util.gold()
    local step = CHECK_SIZE + CHECK_GAP
    for index = 1, total do
        local at = x + (index - 1) * step
        if index <= done then
            util.rect(at, y, CHECK_SIZE, CHECK_SIZE,
                colour.r, colour.g, colour.b, 235)
        else

            util.rect(at, y, CHECK_SIZE, CHECK_SIZE, 255, 255, 255, 40)
        end
    end
    return total * step - CHECK_GAP
end

do

local NO_OPTS = {}
local PLAIN_BODY = { r = 10, g = 10, b = 14 }

local function fade(value, alpha) return math.floor(value * (alpha / 255)) end

function util.plate(x, y, width, height, opts)
    opts = opts or NO_OPTS
    local alpha = opts.alpha or 255
    if alpha <= 0 then return end

    local look = OF.util.asks(OF.theme, "active")
        and OF.theme.active() or nil
    local body = look ~= nil and look.panel or PLAIN_BODY

    for step = 2, 1, -1 do
        local spread = step * 2
        util.rect(x - spread, y - spread,
            width + spread * 2, height + spread * 2, 0, 0, 0, fade(22 - step * 6, alpha))
    end

    util.rect(x, y, width, height, body.r, body.g, body.b, fade(238, alpha))
    util.rect(x, y, width, 1, 255, 255, 255, fade(30, alpha))
    util.rect(x, y + height - 1, width, 1, 0, 0, 0, fade(60, alpha))

    if opts.edge ~= nil then
        util.rect(x, y, 4, height, opts.edge.r, opts.edge.g, opts.edge.b, alpha)
    end
    if opts.accent ~= nil then
        util.rect(x, y + height, width, 2,
            opts.accent.r, opts.accent.g, opts.accent.b, alpha)
    end
end
end

local ESCAPE = "\\" .. "#%x*" .. "\\"
function util.list_of(names)
    if names == nil or #names == 0 then return "" end
    if #names == 1 then return names[1] end
    local head = {}
    for i = 1, #names - 1 do table.insert(head, names[i]) end
    return table.concat(head, ", ") .. " and " .. names[#names]
end

do

local plainOf, plainCount = {}, 0

function util.plain(text)
    if type(text) ~= "string" then return text end
    local done = plainOf[text]
    if done ~= nil then return done end
    done = (string.gsub(text, ESCAPE, ""))
    if plainCount >= 512 then plainOf, plainCount = {}, 0 end
    plainOf[text] = done
    plainCount = plainCount + 1
    return done
end
end

do
local NAME_ESCAPE = "\\" .. "#(%x*)" .. "\\"
local function safe_run(hex)
    local n = #hex
    if n == 4 then return "\\" .. "#" .. string.sub(hex, 1, 3) .. "\\" end
    if n == 8 then return "\\" .. "#" .. string.sub(hex, 1, 6) .. "\\" end
    return nil
end
function util.name_safe(name)
    if type(name) ~= "string" then return name == nil and "" or tostring(name) end
    return (string.gsub(name, NAME_ESCAPE, safe_run))
end
end

function util.same_world(i)
    if i == nil or i == 0 then return false end
    local np, mine = gNetworkPlayers[i], gNetworkPlayers[0]
    if np == nil or mine == nil or not np.connected then return false end
    if np.currPositionValid == false then return false end
    local m = gMarioStates ~= nil and gMarioStates[i] or nil
    if m ~= nil then
        local answer = util.optional("is_player_in_local_area", nil, m)
        if answer ~= nil then return answer ~= 0 and answer ~= false end
    end
    return np.currLevelNum == mine.currLevelNum and np.currAreaIndex == mine.currAreaIndex
        and (np.currActNum or 0) == (mine.currActNum or 0)
        and (np.currCourseNum or 0) == (mine.currCourseNum or 0)
end

function util.seen_here(i)
    if i == 0 then return true end
    if not util.same_world(i) then return false end
    local scope = OF.roundscope
    return not (scope ~= nil and scope.hides_body ~= nil and scope.hides_body(i))
end

function util.presser(askerLocal)
    if askerLocal == nil then return nil end
    local np = gNetworkPlayers[askerLocal]
    if np == nil or np.name == nil or np.name == "" then return nil end
    return util.plain(np.name)
end

function util.row_key(text)
    text = util.plain(tostring(text or ""))

    local cut
    repeat
        text, cut = string.gsub(text, "^%[[xX%s%-]%]%s*", "")
    until cut == 0
    local head = string.match(text, "^(.-): ")
    if head ~= nil and head ~= "" then return head end
    return text
end

function util.cut_coloured(text, budget)
    if type(text) ~= "string" then return "" end
    budget = math.floor(tonumber(budget) or 0)
    if budget < 0 then budget = 0 end

    local pieces, at, seen = {}, 1, 0
    while at <= #text do
        local openAt, closeAt = string.find(text, ESCAPE, at)
        if openAt == at then
            pieces[#pieces + 1] = string.sub(text, openAt, closeAt)
            at = closeAt + 1
        else
            if seen >= budget then break end
            local runEnd = (openAt ~= nil) and (openAt - 1) or #text
            local room = budget - seen
            if runEnd - at + 1 > room then runEnd = at + room - 1 end
            pieces[#pieces + 1] = string.sub(text, at, runEnd)
            seen = seen + (runEnd - at + 1)
            at = runEnd + 1
        end
    end
    return table.concat(pieces)
end

function util.text(message, x, y, scale, r, g, b, a, from)

    message = util.plain(message)
    a = util.byte(a)

    local prevX, prevY, prevScale
    if from ~= nil then
        prevX, prevY, prevScale = from.x, from.y, from.scale or scale
    end

    djui_hud_set_color(0, 0, 0, math.floor(a * 0.65))
    print_moving(message,
        prevX ~= nil and prevX + 2 * prevScale or nil,
        prevY ~= nil and prevY + 2 * prevScale or nil, prevScale,
        x + 2 * scale, y + 2 * scale, scale)
    djui_hud_set_color(util.byte(r), util.byte(g), util.byte(b), a)
    print_moving(message, prevX, prevY, prevScale, x, y, scale)
end

function util.text_raw(message, x, y, scale, r, g, b, a)
    if type(message) ~= "string" then message = tostring(message) end
    a = util.byte(a)
    local tinted = util.colour_escape(r, g, b) .. message
    djui_hud_set_color(0, 0, 0, math.floor(a * 0.65))
    djui_hud_print_text(tinted, x + 2 * scale, y + 2 * scale, scale)
    djui_hud_set_color(255, 255, 255, a)
    djui_hud_print_text(tinted, x, y, scale)
end

function util.text_named(prefix, name, suffix, x, y, scale, r, g, b, a)
    local head = util.plain(prefix ~= nil and prefix or "")
    local tail = util.plain(suffix ~= nil and suffix or "")
    local own = name ~= nil and tostring(name) or ""
    local line = head .. own
    if tail ~= "" then

        if own:find(ESCAPE) ~= nil then
            line = line .. util.colour_escape(r, g, b)
        end
        line = line .. tail
    end
    if line == "" then return 0 end

    util.text_raw(line, x, y, scale, r, g, b, a)
    return util.drawn_width(line, scale)
end

function util.named_width(prefix, name, suffix, scale)
    return util.drawn_width(prefix or "", scale)
        + util.drawn_width(name or "", scale)
        + util.drawn_width(suffix or "", scale)
end

function util.mirror_x(x)
    if util.asks(OF.modifiers, "mirror_screen_x") then return OF.modifiers.mirror_screen_x(x) end
    return x
end

local RING_FAR = 20000

local function world_screen(world, out)
    if djui_hud_world_pos_to_screen_pos == nil then return false end

    local point = world

    if not djui_hud_world_pos_to_screen_pos(point, out) then return false end
    if math.abs(out.x) > RING_FAR or math.abs(out.y) > RING_FAR then
        return false
    end

    out.x = util.mirror_x(out.x)
    return true
end

util.world_screen = world_screen

local screenAt = { x = 0, y = 0, z = 0 }
local worldAt = { x = 0, y = 0, z = 0 }

local function project_point(x, y, z)
    worldAt.x, worldAt.y, worldAt.z = x, y, z
    if not world_screen(worldAt, screenAt) then return nil end
    return screenAt.x, screenAt.y
end

local function view_axis()
    local eye = gLakituState
    if eye == nil or eye.pos == nil or eye.focus == nil then return nil end
    if util.optional("is_game_paused", false) == true then return nil end
    local ex, ey, ez = eye.pos.x, eye.pos.y, eye.pos.z
    local fx, fy, fz = eye.focus.x, eye.focus.y, eye.focus.z

    if type(ex) ~= "number" or type(ey) ~= "number" or type(ez) ~= "number"
        or type(fx) ~= "number" or type(fy) ~= "number"
        or type(fz) ~= "number" then
        return nil
    end
    fx, fy, fz = fx - ex, fy - ey, fz - ez
    local length = math.sqrt(fx * fx + fy * fy + fz * fz)

    if not (length > 0.0001) then return nil end
    return ex, ey, ez, fx / length, fy / length, fz / length
end

local function view_depth(x, y, z)
    local ex, ey, ez, fx, fy, fz = view_axis()
    if ex == nil then return nil end
    return (x - ex) * fx + (y - ey) * fy + (z - ez) * fz
end

util.view_depth = view_depth

util.view_axis = view_axis

local function walk_to_plane(goodX, goodZ, badX, badZ, y)
    local nearX, nearZ = goodX, goodZ
    local farX, farZ = badX, badZ
    local edgeX, edgeY = nil, nil
    for _ = 1, 6 do
        local midX = (nearX + farX) * 0.5
        local midZ = (nearZ + farZ) * 0.5
        local px, py = project_point(midX, y, midZ)
        if px == nil then
            farX, farZ = midX, midZ
        else
            nearX, nearZ = midX, midZ
            edgeX, edgeY = px, py
        end
    end
    return edgeX, edgeY
end

local ringX, ringZ, atX, atY = {}, {}, {}, {}

local columnX, columnY = {}, {}

local function stroke_closed(count, y, width, first, span)
    local drawn = 0

    for k = 1, span or count do
        local index = first ~= nil and (((first - 1 + k - 1) % count) + 1) or k
        local step = index + 1
        if atX[index] ~= nil and atX[step] ~= nil then
            djui_hud_render_line(atX[index], atY[index], atX[step], atY[step],
                width)
            drawn = drawn + 1
        elseif atX[index] ~= nil then
            local edgeX, edgeY = walk_to_plane(ringX[index], ringZ[index],
                ringX[step], ringZ[step], y)
            if edgeX ~= nil then
                djui_hud_render_line(atX[index], atY[index], edgeX, edgeY, width)
                drawn = drawn + 1
            end
        elseif atX[step] ~= nil then
            local edgeX, edgeY = walk_to_plane(ringX[step], ringZ[step],
                ringX[index], ringZ[index], y)
            if edgeX ~= nil then
                djui_hud_render_line(edgeX, edgeY, atX[step], atY[step], width)
                drawn = drawn + 1
            end
        end
    end
    return drawn
end

util.EDGE_SHINE_PERIOD = 120

function util.ring_edge_passes(segments, y, width, r, g, b, a)
    a = a or 255
    djui_hud_set_color(util.byte(r), util.byte(g), util.byte(b), util.byte(a / 6))
    stroke_closed(segments, y, width + 8)
    djui_hud_set_color(util.byte(r * 0.22), util.byte(g * 0.22), util.byte(b * 0.22),
        util.byte(a * 0.55))
    stroke_closed(segments, y, width + 3)
    djui_hud_set_color(util.byte(r), util.byte(g), util.byte(b), util.byte(a))
    local drawn = stroke_closed(segments, y, width)
    local clock = util.optional("get_global_timer", 0) or 0
    local period = util.EDGE_SHINE_PERIOD
    local first = math.floor((clock % period) / period * segments) + 1
    djui_hud_set_color(util.byte(r + (255 - r) * 0.7), util.byte(g + (255 - g) * 0.7),
        util.byte(b + (255 - b) * 0.7), util.byte(a))
    stroke_closed(segments, y, math.max(1, width - 2), first, math.max(2, math.floor(segments / 6)))
    return drawn
end

function util.world_ring(at, radius, segments, size, r, g, b, a, style)
    if at == nil or type(radius) ~= "number" or radius <= 0 then return 0 end
    if djui_hud_render_line == nil or djui_hud_world_pos_to_screen_pos == nil then
        return 0
    end
    segments = math.max(8, math.floor(segments or 32))
    local width = size or 3

    djui_hud_set_color(util.byte(r), util.byte(g), util.byte(b), util.byte(a))
    local centreDepth = view_depth(at.x, at.y, at.z)
    if centreDepth ~= nil and centreDepth + radius <= 0 then
        djui_hud_set_rotation(0, 0, 0)
        return 0
    end

    for index = 1, segments + 1 do
        local angle = ((index - 1) / segments) * 2 * math.pi
        ringX[index] = at.x + math.cos(angle) * radius
        ringZ[index] = at.z + math.sin(angle) * radius
        atX[index], atY[index] = project_point(ringX[index], at.y, ringZ[index])
    end

    local drawn
    if style == "edge" then
        drawn = util.ring_edge_passes(segments, at.y, width, r, g, b, a)
    else
        drawn = stroke_closed(segments, at.y, width)
    end

    djui_hud_set_rotation(0, 0, 0)
    return drawn
end

util.ZONE_RING_SEGMENTS = 24

function util.zone_ring(at, radius, segments, size, r, g, b, a)
    segments = math.max(util.ZONE_RING_SEGMENTS, math.floor(tonumber(segments) or 0))

    local route = util.ring_route
    if type(route) == "function" then
        return route(nil, at, radius, { r = r or 255, g = g or 255, b = b or 255 },
            { alpha = a or 200, segments = segments, size = size or 4 })
    end
    return util.world_ring(at, radius, segments, size or 4, r, g, b, a or 200, "edge")
end

function util.world_wedge(at, radius, facing, half, segments, size, r, g, b, a)
    if at == nil or type(radius) ~= "number" or radius <= 0 then return 0 end
    if djui_hud_render_line == nil or djui_hud_world_pos_to_screen_pos == nil then
        return 0
    end
    local reach = math.abs(tonumber(half) or 0)
    if reach == 0 or reach >= 0x8000 then
        return util.world_ring(at, radius, segments, size, r, g, b, a)
    end
    segments = math.max(4, math.floor(segments or 20))
    local width = size or 2

    djui_hud_set_color(util.byte(r), util.byte(g), util.byte(b), util.byte(a))
    local centreDepth = view_depth(at.x, at.y, at.z)
    if centreDepth ~= nil and centreDepth + radius <= 0 then
        djui_hud_set_rotation(0, 0, 0)
        return 0
    end

    local from = ((tonumber(facing) or 0) - reach) * 2 * math.pi / 0x10000
    local span = reach * 2 * 2 * math.pi / 0x10000
    for index = 1, segments + 1 do
        local angle = from + span * (index - 1) / segments
        ringX[index] = at.x + math.sin(angle) * radius
        ringZ[index] = at.z + math.cos(angle) * radius
        atX[index], atY[index] = project_point(ringX[index], at.y, ringZ[index])
    end

    local drawn = stroke_closed(segments, at.y, width)

    local midX, midY = project_point(at.x, at.y, at.z)
    if midX ~= nil then
        for _, index in ipairs({ 1, segments + 1 }) do
            if atX[index] ~= nil then
                djui_hud_render_line(midX, midY, atX[index], atY[index], width)
                drawn = drawn + 1
            end
        end
    end

    djui_hud_set_rotation(0, 0, 0)
    return drawn
end

function util.world_column(at, radius, height, segments, size, uprights,
                           r, g, b, a)
    if at == nil or type(radius) ~= "number" or radius <= 0 then return 0 end
    if type(height) ~= "number" or height <= 0 then return 0 end
    if djui_hud_render_line == nil or djui_hud_world_pos_to_screen_pos == nil then
        return 0
    end
    segments = math.max(8, math.floor(segments or 20))
    local width = size or 2
    uprights = math.max(0, math.floor(uprights or 6))

    local drawn = util.world_ring(at, radius, segments, width, r, g, b, a)

    for index = 1, segments + 1 do
        columnX[index], columnY[index] = atX[index], atY[index]
    end

    local lid = { x = at.x, y = at.y + height, z = at.z }
    drawn = drawn + util.world_ring(lid, radius, segments, width, r, g, b, a)

    if uprights == 0 then return drawn end

    djui_hud_set_color(util.byte(r), util.byte(g), util.byte(b), util.byte(a))
    for post = 0, uprights - 1 do

        local index = math.floor(post * segments / uprights) + 1

        if columnX[index] ~= nil and atX[index] ~= nil then
            djui_hud_render_line(columnX[index], columnY[index],
                atX[index], atY[index], width)
            drawn = drawn + 1
        end
    end
    djui_hud_set_rotation(0, 0, 0)
    return drawn
end

function util.world_outline(at, corners, size, r, g, b, a)
    if at == nil or type(corners) ~= "table" then return 0 end
    local count = #corners
    if count < 3 then return 0 end
    if djui_hud_render_line == nil or djui_hud_world_pos_to_screen_pos == nil then
        return 0
    end
    local width = size or 3

    djui_hud_set_color(util.byte(r), util.byte(g), util.byte(b), util.byte(a))

    local reach = 0
    for index = 1, count do
        local corner = corners[index]
        local away = corner.x * corner.x + corner.z * corner.z
        if away > reach then reach = away end
    end
    reach = math.sqrt(reach)

    local centreDepth = view_depth(at.x, at.y, at.z)
    if centreDepth ~= nil and centreDepth + reach <= 0 then
        djui_hud_set_rotation(0, 0, 0)
        return 0
    end

    for index = 1, count do
        local corner = corners[index]
        ringX[index] = at.x + corner.x
        ringZ[index] = at.z + corner.z
        atX[index], atY[index] = project_point(ringX[index], at.y, ringZ[index])
    end

    ringX[count + 1], ringZ[count + 1] = ringX[1], ringZ[1]
    atX[count + 1], atY[count + 1] = atX[1], atY[1]

    local drawn = stroke_closed(count, at.y, width)
    djui_hud_set_rotation(0, 0, 0)
    return drawn
end

function util.world_arrow()
    return 0
end

local function stroke_between(ax, ay, az, bx, by, bz, size, r, g, b, a)
    if djui_hud_render_line == nil or djui_hud_world_pos_to_screen_pos == nil then
        return false
    end

    local ex, ey, ez, fx, fy, fz = view_axis()
    if ex ~= nil then
        local fromDepth = (ax - ex) * fx + (ay - ey) * fy + (az - ez) * fz
        local toDepth = (bx - ex) * fx + (by - ey) * fy + (bz - ez) * fz
        if fromDepth <= 0 and toDepth <= 0 then return false end
    end

    local fromX, fromY = project_point(ax, ay, az)
    local toX, toY = project_point(bx, by, bz)
    if fromX == nil or toX == nil then return false end

    djui_hud_set_color(util.byte(r), util.byte(g), util.byte(b), util.byte(a))
    djui_hud_render_line(fromX, fromY, toX, toY, size or 4)
    djui_hud_set_rotation(0, 0, 0)
    return true
end

function util.world_beam(at, height, size, r, g, b, a)
    if at == nil then return false end

    height = height or 1000
    if type(height) ~= "number" or height <= 0 then return false end
    if type(at.y) ~= "number" then return false end

    return stroke_between(at.x, at.y, at.z, at.x, at.y + height, at.z,
        size, r, g, b, a)
end

function util.world_line(from, to, size, r, g, b, a)
    if type(from) ~= "table" or type(to) ~= "table" then return false end
    if type(from.x) ~= "number" or type(from.y) ~= "number"
        or type(from.z) ~= "number" then
        return false
    end
    if type(to.x) ~= "number" or type(to.y) ~= "number"
        or type(to.z) ~= "number" then
        return false
    end
    return stroke_between(from.x, from.y, from.z, to.x, to.y, to.z,
        size, r, g, b, a)
end

function util.width(message, scale)
    return (djui_hud_measure_text(message) - util.title_tick_pull(message)) * scale
end

function util.drawn_width(message, scale)
    return util.width(util.plain(message), scale)
end

function util.shorten(text, most)
    if type(text) ~= "string" then return "" end
    most = most or 14
    if most < 4 then most = 4 end
    if #util.plain(text) <= most then return text end

    local budget = most - 3
    local kept, seen, index = {}, 0, 1
    while index <= #text and seen < budget do
        local from, to = string.find(text, ESCAPE, index)
        if from == index then

            table.insert(kept, string.sub(text, from, to))
            index = to + 1
        else
            table.insert(kept, string.sub(text, index, index))
            seen = seen + 1
            index = index + 1
        end
    end
    return table.concat(kept) .. "..."
end

function util.short_name(name, most)
    return util.shorten(util.plain(tostring(name or "")), most)
end

function util.fit(message, scale, room)
    if type(message) ~= "string" or room == nil or room <= 0 then return message end
    if util.width(message, scale) <= room then return message end

    local ellipsis = "..."
    local budget = room - util.width(ellipsis, scale)
    if budget <= 0 then return ellipsis end

    local kept = ""
    for index = 1, #message do
        local candidate = string.sub(message, 1, index)
        if util.width(candidate, scale) > budget then break end
        kept = candidate
    end

    kept = string.gsub(kept, "%s+$", "")
    return kept .. ellipsis
end

util.HUD_EDGE = 18
util.HUD_PAD_X, util.HUD_PAD_Y = 8, 5

util.HUD_GLYPH_GAP = 0.15

function util.corner_counter(glyph, text, r, g, b, fromRight, scale, tint)
    if text == nil or text == "" then return 0 end

    if util.game_hud_hidden() then return 0 end
    scale = scale or 1.0

    local face = util.title_face(text)
    local at = util.hud_scale(face, scale)
    local width, height = util.in_font(face, function()
        return util.text_size(text, at)
    end)

    local box, gap = height, math.floor(height * util.HUD_GLYPH_GAP)
    if glyph == nil then box, gap = 0, 0 end

    local total = box + gap + width

    local x = djui_hud_get_screen_width() - total - util.HUD_EDGE
        - (fromRight or 0)
    local y = util.HUD_EDGE

    util.plate(x - util.HUD_PAD_X, y - util.HUD_PAD_Y,
        total + util.HUD_PAD_X * 2, height + util.HUD_PAD_Y * 2)

    if glyph ~= nil then

        if type(tint) == "table" then
            djui_hud_set_color(tint[1] or 255, tint[2] or 255, tint[3] or 255, 255)
        else
            djui_hud_set_color(255, 255, 255, 255)
        end
        djui_hud_render_texture(glyph, x, y,
            box / (glyph.width or box), box / (glyph.height or box))
    end

    util.in_font(face, function()
        util.text(text, x + box + gap, y, at, r, g, b, 255)
    end)

    return total + util.HUD_PAD_X * 3
end

function util.text_size(message, scale)
    local w, h = djui_hud_measure_text(message)
    return (w - util.title_tick_pull(message)) * scale, h * scale
end

function util.fit_name(name, scale, room)
    local plain = util.plain(type(name) == "string" and name or tostring(name or ""))
    if room == nil or room <= 0 then return plain end
    if util.text_size(plain, scale) <= room then return plain end

    local ellipsis = "..."
    local budget = room - util.text_size(ellipsis, scale)

    local kept = ""
    for index = 1, #plain do
        local candidate = string.sub(plain, 1, index)
        if util.text_size(candidate, scale) > budget then break end
        kept = candidate
    end

    if kept == "" then kept = string.sub(plain, 1, 1) end

    kept = string.gsub(kept, "%s+$", "")
    return kept .. ellipsis
end

function util.line_height(scale)
    local _, h = djui_hud_measure_text("Ag")
    return h * scale
end

util.ROW_FIT_MARGIN = 24

function util.rows_that_fit(top, lineHeight, margin)
    if lineHeight == nil or lineHeight <= 0 then return 1 end
    local bottom = djui_hud_get_screen_height() - (margin or util.ROW_FIT_MARGIN)
    return math.max(1, math.floor((bottom - top) / lineHeight))
end

function util.scroll_list(panel, rows, first, last)
    if panel == nil or type(rows) ~= "table" then return false end
    if first == nil then first = 1 end
    if type(first) ~= "number" then return false end
    if last == nil then last = #rows end
    if last > #rows then last = #rows end
    if first < 1 then first = 1 end
    if last < first then return false end

    local fits = nil
    if util.asks(panel, "rows_that_fit") then fits = panel.rows_that_fit() end
    if type(fits) ~= "number" then fits = panel.visibleRows end
    if type(fits) ~= "number" or fits < 1 then fits = 1 end

    local function is_stop(r)
        if type(r) ~= "table" then return true end
        return r.action ~= nil or r.walk == true
    end

    local marked = false

    local runStart = nil
    for index = first, last + 1 do
        if index > last or is_stop(rows[index]) then
            if runStart ~= nil and index - runStart > fits then
                for at = runStart, index - 1 do
                    local r = rows[at]

                    if type(r) == "table" and r.heading ~= true
                        and r.slider == nil then
                        r.walk = true
                        marked = true
                    end
                end
            end
            runStart = nil
        elseif runStart == nil then
            runStart = index
        end
    end
    return marked
end

local STACK_TOP = 0.045
local STACK_GAP = 6

local STACK_BOTTOM = 0.045

util.hudStack = nil
util.hudStackLow = nil
local stackFrame = nil

local function frame_stamp()
    if get_global_timer ~= nil then return get_global_timer() end
    return nil
end

local COUNTER_ROW_BOTTOM = 34

function util.game_hud_hidden()
    if util.optional("hud_is_hidden", false) == true then return true end
    local mods = OF.modifiers
    return mods ~= nil and mods.hudHeld == true
end

function util.counters_bottom(height)
    local flags = util.optional("hud_get_value", nil, HUD_DISPLAY_FLAGS)
    if type(flags) ~= "number" then return 0 end
    if util.optional("hud_is_hidden", false) == true then return 0 end
    if util.has_flag(flags, HUD_DISPLAY_FLAG_LIVES)
        or util.has_flag(flags, HUD_DISPLAY_FLAG_COIN_COUNT)
        or util.has_flag(flags, HUD_DISPLAY_FLAG_STAR_COUNT) then
        return COUNTER_ROW_BOTTOM * height / 240
    end
    return 0
end

function util.camera_icon_top(height)
    if util.roundMeterCorner then
        local _, top = util.round_meter_box(0, height)
        return top - 2 * height / 240
    end
    return 203 * height / 240
end

function util.camera_icon_left(width, height)
    if util.roundMeterCorner then
        local left = util.round_meter_box(width, height)
        return left
    end
    return width - 56 * height / 240
end

local ROUND_METER_HOLD = "roundmeter"
local ROUND_COINS_HOLD = "roundcoins"
local ROUND_METER_SIZE = 64
local ROUND_METER_RIGHT = 22
local ROUND_METER_BOTTOM = 19
local ROUND_METER_SLIDE = 20
local ROUND_METER_LINGER = 45

util.ROUND_METER_HIDDEN = "hidden"
util.ROUND_METER_EMPHASIZED = "emphasized"
util.ROUND_METER_VISIBLE = "visible"
util.ROUND_METER_HIDING = "hiding"
util.roundMeterOwned = false
util.roundMeterCorner = false
util.roundMeter = { state = util.ROUND_METER_HIDDEN, stored = 8, timer = 0,
                    slide = 0 }

function util.round_meter_box(width, height)
    local f = height / 240
    local size = ROUND_METER_SIZE * f
    return width - (ROUND_METER_RIGHT + ROUND_METER_SIZE) * f,
        height - (ROUND_METER_BOTTOM + ROUND_METER_SIZE) * f, size
end

function util.in_round_corner(x, y, w, h)
    if not util.roundMeterCorner then return false end
    local height = djui_hud_get_screen_height()
    local left, top = util.round_meter_box(djui_hud_get_screen_width(), height)
    local air = 2 * height / 240
    return x + w > left - air and y + h > top - air
end

local function round_meter_wanted()
    local scope, act = OF and OF.roundscope, OF and OF.roundact
    if util.asks(scope, "inside") and scope.inside(0) then return true end

    local spectate = OF and OF.spectate
    if util.asks(spectate, "is_spectating") and spectate.is_spectating(0) == true
        and util.asks(act, "watches") and act.watches(0) then
        return true
    end
    return false
end

local function round_meter_allowed(flags)
    if type(flags) ~= "number" or flags == 0 then return false end
    if not util.has_flag(flags, HUD_DISPLAY_FLAG_CAMERA_AND_POWER or 0x0008) then
        return false
    end
    if util.hudBitWas[HUD_DISPLAY_FLAG_POWER or 0x0100] == false then
        return false
    end
    return true
end

local function on_the_podium()
    local modes = OF and OF.gamemodes
    if util.asks(modes, "state") and modes.RESULTS ~= nil
        and modes.state() == modes.RESULTS then
        return true
    end
    local run = OF and OF.speedrun
    return run ~= nil and run.RESULTS ~= nil and gGlobalSyncTable ~= nil
        and gGlobalSyncTable.ofRunState == run.RESULTS
end

local function round_meter_reset(meter)
    meter.state, meter.stored, meter.timer, meter.slide =
        util.ROUND_METER_HIDDEN, 8, 0, 0
end

function util.round_meter_step()
    local owned = round_meter_wanted()

    if owned or util.roundMeterOwned then
        util.hud_hide(HUD_DISPLAY_FLAG_POWER or 0x0100, ROUND_METER_HOLD, owned)
        util.hud_hide(HUD_DISPLAY_FLAG_CAMERA or 0x0080, ROUND_METER_HOLD, owned)

        local modes = OF and OF.gamemodes
        local counters = owned and modes ~= nil and modes.state ~= nil
            and modes.state() ~= modes.OFF
        util.hud_hide(HUD_DISPLAY_FLAG_COIN_COUNT or 0x0002, ROUND_COINS_HOLD, counters)
        util.hud_hide(HUD_DISPLAY_FLAG_LIVES or 0x0001, ROUND_COINS_HOLD, counters)
        util.hud_hide(HUD_DISPLAY_FLAG_STAR_COUNT or 0x0004, ROUND_COINS_HOLD, counters)
    end
    util.roundMeterOwned = owned
    util.roundMeterCorner = owned and not on_the_podium()
    local meter = util.roundMeter
    if not util.roundMeterCorner then
        if meter.state ~= util.ROUND_METER_HIDDEN then round_meter_reset(meter) end
        return
    end
    local m = gMarioStates and gMarioStates[0]
    if m == nil then return end
    if not round_meter_allowed(util.optional("hud_get_value", nil, HUD_DISPLAY_FLAGS)) then

        round_meter_reset(meter)
        return
    end

    local health = m.health or 0x880
    local wedges = health > 0 and math.floor(health / 0x100) or 0
    if wedges > 8 then wedges = 8 end

    if meter.state ~= util.ROUND_METER_HIDING then
        if wedges < 8 and meter.stored == 8 and meter.state == util.ROUND_METER_HIDDEN then
            meter.state, meter.slide = util.ROUND_METER_EMPHASIZED, 0
        end
        if wedges == 8 and meter.stored == 7 then meter.timer = 0 end
        if wedges == 8 and meter.timer > ROUND_METER_LINGER then
            meter.state = util.ROUND_METER_HIDING
        end
        meter.stored = wedges
        if util.has_flag(m.action or 0, ACT_FLAG_SWIMMING or 0x2000) then
            if meter.state == util.ROUND_METER_HIDDEN
                or meter.state == util.ROUND_METER_EMPHASIZED then
                meter.state, meter.slide = util.ROUND_METER_VISIBLE, 0
            end
            meter.timer = 0
        end
    end

    if meter.state == util.ROUND_METER_HIDDEN then return end
    if meter.state == util.ROUND_METER_EMPHASIZED then
        if (m.hurtCounter or 0) > 0 then
            meter.timer = 0
        elseif meter.timer == ROUND_METER_LINGER then
            meter.state = util.ROUND_METER_VISIBLE
        end
    elseif meter.state == util.ROUND_METER_HIDING then
        meter.slide = meter.slide + ROUND_METER_SLIDE
        if meter.slide >= ROUND_METER_SIZE + ROUND_METER_BOTTOM then
            round_meter_reset(meter)
            return
        end
    end
    meter.timer = meter.timer + 1
end

function util.round_meter_render()
    if not util.roundMeterOwned then return false end

    util.round_coins_render()
    if not util.roundMeterCorner then return true end
    local meter = util.roundMeter
    if meter.state == util.ROUND_METER_HIDDEN then return true end
    if util.optional("hud_is_hidden", false) == true then return true end
    local m = gMarioStates and gMarioStates[0]
    local draw = util.binding("hud_render_power_meter")
    if m == nil or draw == nil then return true end
    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_color(255, 255, 255, 255)
    local height = djui_hud_get_screen_height()
    local x, y, size = util.round_meter_box(djui_hud_get_screen_width(), height)
    draw(m.health or 0, x, y + meter.slide * height / 240, size, size)
    return true
end

local ROUND_TOP_FIT = 0.8

do
local ROUND_TOP_EDGE = 5
local COUNTER_ROW_TOP = 13
local LIVES_REACH = 94
local STARS_REACH = 80

function util.round_top_on()
    return util.roundMeterCorner == true
end

function util.round_coins_wanted() return false end
function util.round_coins_render() return false end

function util.round_top_room()
    local width = djui_hud_get_screen_width()
    local f = djui_hud_get_screen_height() / 240
    local flags = util.optional("hud_get_value", nil, HUD_DISPLAY_FLAGS)
    if type(flags) ~= "number" or util.optional("hud_is_hidden", false) == true then
        return width
    end
    local reach = 0
    if util.has_flag(flags, HUD_DISPLAY_FLAG_LIVES) then reach = LIVES_REACH * f end
    if util.has_flag(flags, HUD_DISPLAY_FLAG_STAR_COUNT)
        or util.round_coins_wanted() then
        reach = math.max(reach, STARS_REACH * f)
    end
    return width - reach * 2
end

local counterZones = {}
local function counter_zones(width, height)
    local f = height / 240
    local n = 0
    local function add(x0, x1, y0, y1)
        counterZones[n + 1], counterZones[n + 2] = x0, x1
        counterZones[n + 3], counterZones[n + 4] = y0, y1
        n = n + 4
    end
    local flags = util.optional("hud_get_value", nil, HUD_DISPLAY_FLAGS)
    if type(flags) == "number" and util.optional("hud_is_hidden", false) ~= true then
        local top, bottom = COUNTER_ROW_TOP * f, COUNTER_ROW_BOTTOM * f
        if util.has_flag(flags, HUD_DISPLAY_FLAG_LIVES) then
            add(0, LIVES_REACH * f, top, bottom)
        end
        if util.has_flag(flags, HUD_DISPLAY_FLAG_STAR_COUNT) then
            add(width - STARS_REACH * f, width, top, bottom)
        end

        if util.has_flag(flags, HUD_DISPLAY_FLAG_COIN_COUNT) then
            local centre = width * 0.5
            add(centre + 6 * f, centre + 74 * f, top, bottom)
        end
    end
    for index = #counterZones, n + 1, -1 do counterZones[index] = nil end
    return counterZones, n
end

local function clear_of_counters(y, height, padding, plateW)
    if not util.round_top_on() then return y end
    local width = djui_hud_get_screen_width()
    local zones, n = counter_zones(width, djui_hud_get_screen_height())
    local left = (width - math.min(plateW or width, width)) * 0.5
    local right = width - left

    for _ = 1, 4 do
        local moved = false
        for index = 1, n, 4 do
            local x0, x1 = zones[index], zones[index + 1]
            local y0, y1 = zones[index + 2], zones[index + 3]
            if left < x1 and right > x0 and y - padding < y1
                and y + height + padding > y0 then
                y = y1 + padding
                moved = true
            end
        end
        if not moved then break end
    end
    return y
end

function util.hud_reset()
    local height = djui_hud_get_screen_height()
    if util.round_top_on() then
        util.hudStack = ROUND_TOP_EDGE * height / 240
    else
        util.hudStack = math.max(height * STACK_TOP, util.counters_bottom(height))
    end

    util.hudStackLow = height - height * STACK_BOTTOM
    stackFrame = frame_stamp()

    util.hudClaims = {}
    util.hudClaimsLow = {}
end

function util.hud_push(height)
    if util.hudStack == nil then util.hud_reset() end
    util.hudStack = util.hudStack + height
end

function util.hud_claim(height, padding, plateW)
    padding = padding or 6
    local stamp = frame_stamp()
    if util.hudStack == nil or stamp == nil or stamp ~= stackFrame then
        util.hud_reset()
    end
    local y = clear_of_counters(util.hudStack + padding, height, padding, plateW)
    util.hudStack = y + height + padding + STACK_GAP
    table.insert(util.hudClaims, { y = y - padding, height = height + padding * 2 })
    return y
end
end

function util.hud_claim_low(height, padding)
    padding = padding or 6
    local stamp = frame_stamp()
    if util.hudStackLow == nil or stamp == nil or stamp ~= stackFrame then
        util.hud_reset()
    end
    local y = util.hudStackLow - padding - height
    util.hudStackLow = y - padding - STACK_GAP
    table.insert(util.hudClaimsLow, { y = y - padding, height = height + padding * 2 })
    return y
end

util.hudHeldBy = {}
util.hudBitWas = {}

function util.hud_hidden(flag)
    local holders = util.hudHeldBy[flag]
    if holders == nil then return false end
    return next(holders) ~= nil
end

function util.hud_holders(flag)
    local n = 0
    for _ in pairs(util.hudHeldBy[flag] or {}) do n = n + 1 end
    return n
end

function util.hud_hide(flag, who, wanted)
    if type(flag) ~= "number" or who == nil then return false end

    local holders = util.hudHeldBy[flag]
    if holders == nil then
        holders = {}
        util.hudHeldBy[flag] = holders
    end
    local hadAny = next(holders) ~= nil
    if wanted then holders[who] = true else holders[who] = nil end
    local anyNow = next(holders) ~= nil

    local flags = util.optional("hud_get_value", nil, HUD_DISPLAY_FLAGS)
    if type(flags) ~= "number" then return anyNow end
    local lit = util.has_flag(flags, flag)

    if anyNow and not hadAny then util.hudBitWas[flag] = lit end

    if anyNow then
        if lit then
            util.optional("hud_set_value", nil, HUD_DISPLAY_FLAGS, flags - flag)
        end
        return true
    end

    if hadAny then
        local was = util.hudBitWas[flag]
        util.hudBitWas[flag] = nil
        if was == true and not lit then
            util.optional("hud_set_value", nil, HUD_DISPLAY_FLAGS, flags + flag)
        end
    end
    return false
end

function util.reassert_hud_holds()
    local flags = util.optional("hud_get_value", nil, HUD_DISPLAY_FLAGS)
    if type(flags) ~= "number" then return 0 end
    local out, taken = flags, 0
    for flag, holders in pairs(util.hudHeldBy) do
        if next(holders) ~= nil and util.has_flag(out, flag) then
            out = out - flag
            taken = taken + 1
        end
    end
    if taken > 0 then util.optional("hud_set_value", nil, HUD_DISPLAY_FLAGS, out) end
    return taken
end

if HOOK_ON_HUD_RENDER_BEHIND ~= nil then
    hook_event(HOOK_ON_HUD_RENDER_BEHIND, util.reassert_hud_holds)
end

function util.hud_room_flags()
    local flags = util.optional("hud_get_value", nil, HUD_DISPLAY_FLAGS)
    if type(flags) ~= "number" then return nil end
    for flag, was in pairs(util.hudBitWas) do
        local lit = util.has_flag(flags, flag)
        if was == true and not lit then
            flags = flags + flag
        elseif was == false and lit then
            flags = flags - flag
        end
    end
    return flags
end

util.aboveMenu = {}
local aboveFrame = nil

function util.above_menu(paint)
    if type(paint) ~= "function" then return false end

    local stamp = frame_stamp()
    if stamp == nil or stamp ~= aboveFrame then
        util.aboveMenu = {}
        aboveFrame = stamp
    end
    table.insert(util.aboveMenu, paint)
    return true
end

function util.paint_above_menu()
    local queued = util.aboveMenu
    util.aboveMenu = {}
    aboveFrame = nil
    for _, paint in ipairs(queued) do

        pcall(djui_hud_set_resolution, RESOLUTION_DJUI)
        pcall(djui_hud_set_font, FONT_NORMAL)

        pcall(paint)
    end
    return #queued
end

local BANNER_PAD = 5
local UNDER_GAP = 6

local LIMP_PITCH = 0x0180
local LIMP_ROLL  = 0x00E0
local LIMP_LEAN  = 0x0110

local TORSO_SWING = 0x0E00
local HEAD_SWING  = 0x0700

util.limpTick = util.limpTick or 0

local function set_joint(joint, roll, pitch, yaw)
    if joint == nil then return end
    joint.x = roll
    joint.y = pitch
    joint.z = yaw
end

function util.limp(m, tick)
    m = m or gMarioStates[0]
    if m == nil or m.marioObj == nil then return false end

    util.limpTick = tick or (util.limpTick + 1)
    local t = util.limpTick

    local gfx = m.marioObj.header.gfx
    if gfx ~= nil and gfx.angle ~= nil then
        gfx.angle.x = math.floor(t * LIMP_PITCH) % 0x10000
        gfx.angle.z = math.floor(t * LIMP_ROLL) % 0x10000
    end

    local body = m.marioBodyState
    if body == nil then return false end

    body.allowPartRotation = true

    local swing = math.sin(t * LIMP_LEAN / 0x8000 * math.pi)
    set_joint(body.torsoAngle,
        math.floor(TORSO_SWING * swing),
        math.floor(TORSO_SWING * 0.6 * math.cos(t * 0.07)), 0)
    set_joint(body.headAngle,
        math.floor(HEAD_SWING * -swing),
        math.floor(HEAD_SWING * 0.5 * math.sin(t * 0.05)), 0)
    return true
end

function util.stand_up(m)
    m = m or gMarioStates[0]
    util.limpTick = 0
    if m == nil or m.marioObj == nil then return false end

    local gfx = m.marioObj.header.gfx
    if gfx ~= nil and gfx.angle ~= nil then
        gfx.angle.x = 0
        gfx.angle.z = 0
    end

    local body = m.marioBodyState
    if body == nil then return false end
    set_joint(body.torsoAngle, 0, 0, 0)
    set_joint(body.headAngle, 0, 0, 0)
    body.allowPartRotation = false
    return true
end

util.limping = util.limping or false

function util.limp_until_landed()
    util.limping = true
    util.limpTick = 0
end

function util.limp_update(m)
    if not util.limping then return false end
    m = m or gMarioStates[0]
    if m == nil then return false end

    if util.action_group(m.action) == util.action_group(ACT_GROUP_AIRBORNE) then
        util.limp(m)
        return true
    end

    util.limping = false
    util.stand_up(m)
    return false
end

function util.skip_interpolation(obj)
    if obj == nil then return false end
    local fn = util.binding("obj_skip_interpolation")
    if fn == nil then return false end

    local ok = pcall(fn, obj)
    return ok
end

function util.wall_in(m, cx, cz, limit)
    if m == nil or m.pos == nil or type(cx) ~= "number" or type(cz) ~= "number"
        or type(limit) ~= "number" then return false end
    local dx, dz = m.pos.x - cx, m.pos.z - cz
    local flat = math.sqrt(dx * dx + dz * dz)
    if flat <= limit or flat <= 0 then return false end
    local nx, nz = dx / flat, dz / flat
    m.pos.x, m.pos.z = cx + nx * limit, cz + nz * limit
    if m.vel ~= nil then
        local out = (m.vel.x or 0) * nx + (m.vel.z or 0) * nz
        if out > 0 then m.vel.x, m.vel.z = m.vel.x - out * nx, m.vel.z - out * nz end
    end
    if m.faceAngle ~= nil and (m.forwardVel or 0) > 0 then
        local yaw = m.faceAngle.y * math.pi / 32768
        local along = math.sin(yaw) * nx + math.cos(yaw) * nz
        if along > 0 then m.forwardVel = m.forwardVel * (1 - along) end
    end
    return true
end

function util.place_player(localIndex, x, y, z)
    local m = gMarioStates ~= nil and gMarioStates[localIndex] or nil
    if m == nil or m.pos == nil then return false end
    if type(x) ~= "number" or type(y) ~= "number"
        or type(z) ~= "number" then return false end
    local obj = m.marioObj
    if obj == nil then return false end

    local moved = m.pos.x ~= x or m.pos.y ~= y or m.pos.z ~= z

    m.pos.x, m.pos.y, m.pos.z = x, y, z
    if type(obj.oPosX) == "number" then
        obj.oPosX, obj.oPosY, obj.oPosZ = x, y, z
    end
    local header = obj.header
    local gfx = header ~= nil and header.gfx or nil
    local at = gfx ~= nil and gfx.pos or nil
    if at ~= nil and type(at.x) == "number" then
        at.x, at.y, at.z = x, y, z
    end

    if moved then util.skip_interpolation(obj) end
    return true
end

local function banner_measure(line)

    line.face = util.title_face(line.segments ~= nil
        and util.segments_text(line.segments) or line.text)
    line.at = util.hud_scale(line.face, line.want)
    line.w, line.h = util.in_font(line.face, function()
        if line.segments ~= nil then
            return util.segments_width(line.segments, line.at),
                util.line_height(line.at)
        end
        return util.text_size(line.text, line.at)
    end)
end

local function banner_draw(line, x, y, alpha)
    util.in_font(line.face, function()
        if line.segments ~= nil then
            util.draw_segments(line.segments, x, y, line.at, alpha)
        else
            util.text(line.text, x, y, line.at, line.r, line.g, line.b, alpha)
        end
    end)
end

local BANNER_EDGE = 24

local function banner_fit(lines, screen)
    local widest = 0
    for _, line in ipairs(lines) do
        if line.w > widest then widest = line.w end
    end
    local room = screen - BANNER_EDGE * 2 - BANNER_PAD * 4
    if widest <= room or room <= 0 or widest <= 0 then return end

    local fit = room / widest
    for _, line in ipairs(lines) do
        line.at = line.at * fit
        line.w = line.w * fit
        line.h = line.h * fit
    end
end

local function banner_at(claim, text, scale, r, g, b, alpha, opts)
    opts = opts or {}
    local screen = djui_hud_get_screen_width()
    alpha = alpha or 255

    local unders = opts.under

    if unders ~= nil and util.ROUND_ONE_LINE and claim == util.hud_claim
        and util.round_faces_on() and util.optional("is_game_paused", false) ~= true then
        local n = (unders.text ~= nil or unders.segments ~= nil) and 1 or #unders
        util.roundLineDrops = (util.roundLineDrops or 0) + n
        unders = nil
    end
    if unders ~= nil and unders.text == nil and unders.segments == nil then

    elseif unders ~= nil then
        unders = { unders }
    end

    local snap = util.round_faces_on() and not opts.exact
    local lines = { { text = text, want = snap and util.round_scale(scale) or scale,
                      segments = opts.segments, r = r, g = g, b = b } }
    if unders ~= nil then
        for _, line in ipairs(unders) do
            line.want = line.scale or 0.7
            if snap then line.want = util.round_scale(line.want) end
            line.r = line.r or 220
            line.g = line.g or 220
            line.b = line.b or 220
            lines[#lines + 1] = line
        end
    end

    for _, line in ipairs(lines) do banner_measure(line) end

    local corner = nil
    if util.roundMeterCorner then
        local stamp = frame_stamp()
        if util.hudStack == nil or util.hudStackLow == nil or stamp == nil
            or stamp ~= stackFrame then
            util.hud_reset()
        end
        local height = djui_hud_get_screen_height()
        local cornerLeft, cornerTop = util.round_meter_box(screen, height)
        local air = 2 * height / 240
        local reaches
        if claim == util.hud_claim_low then
            reaches = util.hudStackLow - BANNER_PAD > cornerTop - air
        else
            banner_fit(lines, screen)
            local tall = 0
            for index, line in ipairs(lines) do
                tall = tall + line.h + (index > 1 and UNDER_GAP or 0)
            end
            reaches = util.hudStack + BANNER_PAD * 2 + tall > cornerTop - air
        end
        if reaches then corner = cornerLeft - air end
    end
    banner_fit(lines, corner or screen)

    local widest, total = 0, 0
    for index, line in ipairs(lines) do
        if line.w > widest then widest = line.w end
        total = total + line.h
        if index > 1 then total = total + UNDER_GAP end
    end

    if claim == util.hud_claim and util.round_top_on() and widest > 0 then
        local room = util.round_top_room() - BANNER_PAD * 4
        if widest > room and room / widest >= ROUND_TOP_FIT then
            local fit = room / widest
            widest, total = 0, 0
            for index, line in ipairs(lines) do
                line.at, line.w, line.h = line.at * fit, line.w * fit, line.h * fit
                if line.w > widest then widest = line.w end
                total = total + line.h
                if index > 1 then total = total + UNDER_GAP end
            end
        end
    end

    local top = lines[1]
    local centre = screen * 0.5
    if corner ~= nil then
        local half = widest * 0.5 + BANNER_PAD * 2
        if centre + half > corner - BANNER_EDGE then
            centre = corner - BANNER_EDGE - half
        end
    end
    local x = centre - top.w * 0.5
    local y = claim(total, BANNER_PAD, widest + BANNER_PAD * 4)

    opts.alpha = opts.alpha or alpha
    if claim == util.hud_claim then

        local claims = util.hudClaims
        local last = claims ~= nil and claims[#claims] or nil
        if last ~= nil then last.left = (screen - widest) * 0.5 - BANNER_PAD * 2 end
    end
    util.round_plate(centre - widest * 0.5 - BANNER_PAD * 2, y - BANNER_PAD,
        widest + BANNER_PAD * 4, total + BANNER_PAD * 2, opts)

    local lineY = y
    for index, line in ipairs(lines) do
        if index > 1 then lineY = lineY + UNDER_GAP end
        banner_draw(line, util.ink_centred_x(line, centre), lineY, alpha)
        lineY = lineY + line.h
    end
    return y, x, top.w, top.h
end

util.ROUND_PLATE_NONE = {}
function util.round_plate(x, y, width, height, opts)
    local hud = OF.hud
    if hud == nil or type(hud.plate) ~= "function" then
        return util.plate(x, y, width, height, opts)
    end
    opts = opts or util.ROUND_PLATE_NONE
    local strip = opts.edge or opts.accent
    hud.plate(x, y, width, height, { alpha = (opts.alpha or 255) / 255,
        strip = strip ~= nil and { strip.r or 255, strip.g or 255, strip.b or 255 } or nil })
    return true
end

function util.ink_centred_x(line, centre)
    local hud = OF.hud
    if hud == nil or type(hud.ink_at) ~= "function" then return centre - line.w * 0.5 end
    local text = line.segments ~= nil and util.segments_text(line.segments) or line.text
    local l, r = hud.ink_at(text, line.face, line.at)
    if l == nil then return centre - line.w * 0.5 end
    return centre - (l + r) * 0.5
end

util.BOARD_PLATE = {}
function util.board_plate_opts(opts)
    local head = opts ~= nil and opts.titleColour or nil
    util.BOARD_PLATE.edge = head or util.gold()
    return util.BOARD_PLATE
end

function util.board_name_drawn(entry, place, x, y, scale, r, g, b, room)
    local hud = OF.hud
    if hud == nil or type(hud.name) ~= "function" then return false end
    if util.round_board_face() ~= _G["FONT_ALIASED"] then return false end
    local nameKey = "board" .. tostring(entry.localIndex or place) .. "@" .. math.floor(x)
    hud.name(entry.name or "", x, y, { face = "board", scale = scale }, { r, g, b }, 255,
        "left", room, { key = nameKey })
    return true
end

function util.banner(text, scale, r, g, b, alpha, opts)
    return banner_at(util.hud_claim, text, scale, r, g, b, alpha, opts)
end

function util.banner_low(text, scale, r, g, b, alpha, opts)
    return banner_at(util.hud_claim_low, text, scale, r, g, b, alpha, opts)
end

local LABEL_OPTS = {}
function util.world_label(screenX, screenY, text, scale, r, g, b, alpha)
    if type(text) ~= "string" or text == "" then return false end
    alpha = alpha or 255

    local face = util.title_face(text)
    local at = util.hud_scale(face, scale)

    util.in_font(face, function()
        local width, height = util.text_size(text, at)

        local left = screenX - width * 0.5 - BANNER_PAD * 2
        local top = screenY - height * 0.5 - BANNER_PAD
        local boxW, boxH = width + BANNER_PAD * 4, height + BANNER_PAD * 2
        local screenW = djui_hud_get_screen_width()
        local screenH = djui_hud_get_screen_height()
        if left < screenW and left + boxW > 0 then
            left = math.max(2, math.min(left, screenW - boxW - 2))
        end
        if top < screenH and top + boxH > 0 then
            top = math.max(2, math.min(top, screenH - boxH - 2))
        end

        if util.in_round_corner(left, top, boxW, boxH) then
            local cornerLeft, cornerTop = util.round_meter_box(screenW, screenH)
            local air = 2 * screenH / 240
            local byLeft = left + boxW - (cornerLeft - air)
            local byUp = top + boxH - (cornerTop - air)
            if byLeft <= byUp then left = left - byLeft else top = top - byUp end
        end
        LABEL_OPTS.alpha = alpha

        util.round_plate(left, top, boxW, boxH, LABEL_OPTS)
        local textX = left + BANNER_PAD * 2
        local hud = OF.hud
        if hud ~= nil and type(hud.ink_at) == "function" then
            local l, rr = hud.ink_at(text, face, at)
            if l ~= nil then textX = left + boxW * 0.5 - (l + rr) * 0.5 end
        end
        util.text(text, textX, top + BANNER_PAD, at, r, g, b, alpha)
    end)
    return true
end

local METER_LIFT = 6
local METER_HEIGHT = 4

function util.banner_meter(top, x, width, share, first, second, lift)
    if type(top) ~= "number" or type(x) ~= "number" then return false end
    if type(width) ~= "number" or width <= 0 then return false end
    util.meter(x, top - METER_LIFT - (lift or 0), width, METER_HEIGHT,
        share, first, second)
    return true
end

local CHECKS_LIFT = 11

function util.banner_checks(top, x, done, total, colour, lift)
    if type(top) ~= "number" or type(x) ~= "number" then return false end
    return util.checks(x, top - CHECKS_LIFT - (lift or 0),
        done, total, colour) > 0
end

function util.segments_width(segments, scale)
    local w = 0
    for _, seg in ipairs(segments) do
        w = w + util.drawn_width(seg.text, scale)
    end
    return w
end

function util.segments_text(segments)
    local pieces = {}
    for _, seg in ipairs(segments) do
        pieces[#pieces + 1] = tostring(seg.text or "")
    end
    return table.concat(pieces)
end

do
local COLOUR_RUN = "\\" .. "#(%x*)" .. "\\"
local RUN_FORMS = { [0] = true, [3] = true, [4] = true, [6] = true, [8] = true }

local function run_colour(hex, white)
    local n = #hex
    if not RUN_FORMS[n] then return nil end
    if n == 0 then return white.r, white.g, white.b end
    if n <= 4 then
        local function one(i) return tonumber(string.sub(hex, i, i), 16) * 17 end
        return one(1), one(2), one(3)
    end
    return tonumber(string.sub(hex, 1, 2), 16), tonumber(string.sub(hex, 3, 4), 16),
        tonumber(string.sub(hex, 5, 6), 16)
end

function util.colour_runs(text, fallback)
    local runs = {}
    if type(text) ~= "string" then return runs end
    local white = fallback or { r = 255, g = 255, b = 255 }
    local r, g, b = white.r, white.g, white.b

    local at, look = 1, 1
    while look <= #text do

        local from, to, hex = string.find(text, COLOUR_RUN, look)
        if from == nil then break end
        local nr, ng, nb = run_colour(hex, white)
        if nr == nil then

            look = to + 1
        else
            if from > at then
                table.insert(runs, { text = string.sub(text, at, from - 1),
                                     r = r, g = g, b = b })
            end
            r, g, b = nr, ng, nb
            at = to + 1
            look = at
        end
    end

    if at <= #text then
        table.insert(runs, { text = string.sub(text, at), r = r, g = g, b = b })
    end
    return runs
end
end

function util.runs_width(runs, scale)
    local total = 0
    for _, run in ipairs(runs) do
        total = total + util.drawn_width(run.text, scale)
    end
    return total
end

function util.draw_segments(segments, x, y, scale, alpha)
    for _, seg in ipairs(segments) do
        if seg.raw then
            util.text_raw(seg.text, x, y, scale, seg.r, seg.g, seg.b, alpha)
        else
            util.text(seg.text, x, y, scale, seg.r, seg.g, seg.b, alpha)
        end
        x = x + util.drawn_width(seg.text, scale)
    end
end

util.BOARD_NAME_LETTERS = 10

local BOARD_WANT = 0.85
local BOARD_FLOOR = 0.5
local BOARD_TWO_WANT = 0.7
local BOARD_PAD_X = 8
local BOARD_PAD_Y = 5
local BOARD_GAP = 12
local BOARD_COLUMN_GAP = 18
local BOARD_LINE_GAP = 4

util.BOARD_NAME_ROOM = 150

util.nameRoomRatios = {}
util.NAME_ROOM_SAMPLE = "abcdefghij..."
function util.name_room_ratio()
    if djui_hud_get_font == nil then return 1 end
    local face = djui_hud_get_font()
    if face == nil or face == FONT_NORMAL then return 1 end
    local known = util.nameRoomRatios[face]
    if known ~= nil then return known end
    local here = djui_hud_measure_text(util.NAME_ROOM_SAMPLE)
    local pixel = util.in_font(FONT_NORMAL, function()
        return djui_hud_measure_text(util.NAME_ROOM_SAMPLE)
    end)
    local ratio = 1
    if type(here) == "number" and type(pixel) == "number" and here > 0 and pixel > 0 then
        ratio = math.min(1, here / pixel)
    end
    util.nameRoomRatios[face] = ratio
    return ratio
end

local BOARD_LOW_RESERVE = 52

function util.board_bottom()
    local height = djui_hud_get_screen_height()
    return height - height * STACK_BOTTOM - BOARD_LOW_RESERVE
end

local function board_line(scale)
    return util.line_height(scale) + BOARD_LINE_GAP * scale / BOARD_WANT
end

function util.board_fit(count, headings, top, bottom, want)
    want = want or BOARD_WANT
    local room = bottom - top
    local scale = want
    while scale >= 0.6 - 1e-6 do
        local line = board_line(scale)
        if (count + headings) * line + BOARD_PAD_Y * 2 * headings <= room then
            return scale, 1, line, true
        end
        scale = scale - 0.05
    end
    scale = math.min(want, BOARD_TWO_WANT)
    local half = math.ceil(count / 2)
    while scale >= BOARD_FLOOR - 1e-6 do
        local line = board_line(scale)
        if (half + headings) * line + BOARD_PAD_Y * 2 * headings <= room then
            return scale, 2, line, true
        end
        scale = scale - 0.05
    end
    return BOARD_FLOOR, 2, board_line(BOARD_FLOOR), false
end

local fitted = {}
local fittedCount = 0
function util.board_name(name, scale, room)
    if type(name) ~= "string" then name = tostring(name or "") end

    local face = djui_hud_get_font ~= nil and djui_hud_get_font() or 0
    local key = (math.floor(room) * 1000 + math.floor(scale * 100 + 0.5)) * 8
        + ((tonumber(face) or 0) + 1)
    local byName = fitted[name]
    if byName ~= nil then
        local hit = byName[key]
        if hit ~= nil then return hit end
    else
        if fittedCount > 2048 then fitted = {} fittedCount = 0 end
        byName = {}
        fitted[name] = byName
    end
    local most = util.BOARD_NAME_LETTERS + 3
    local cut = util.shorten(name, most)
    while most > 4 and util.width(cut, scale) > room do
        most = most - 1
        cut = util.shorten(name, most)
    end
    byName[key] = cut
    fittedCount = fittedCount + 1
    return cut
end

local MARKS = {}
local function place_mark(place)
    local mark = MARKS[place]
    if mark == nil then
        mark = tostring(place) .. ".  "
        MARKS[place] = mark
    end
    return mark
end

local OWN_ROW_ALPHA = 40
local BOARD_NO_OPTS = {}

function util.board_measure(y, title, rows, opts)

    return util.in_font(util.round_board_face(), function()
        return util.board_measure_here(y, title, rows, opts)
    end)
end

function util.board_measure_here(y, title, rows, opts)
    opts = opts or BOARD_NO_OPTS

    local count = math.min(#rows, opts.max or #rows)
    local headings = (title ~= nil and title ~= "") and 1 or 0
    local scale, columns, line = opts.scale, opts.columns, nil
    if scale == nil or columns == nil then
        scale, columns, line = util.board_fit(count, headings, y - BOARD_PAD_Y,
            opts.bottom or util.board_bottom(), scale or BOARD_WANT)
    else
        line = board_line(scale)
    end

    local nameRoom = util.BOARD_NAME_ROOM * scale / BOARD_WANT
        * util.name_room_ratio() * (opts.wide or 1)

    local markW, nameW, valueW = 0, 0, 0
    local smooth = util.round_board_face() == _G["FONT_ALIASED"]
    for place = 1, count do
        local entry = rows[place]
        if entry.place ~= nil then
            local w = util.width(place_mark(entry.place), scale)
            if w > markW then markW = w end
        end
        local cut = util.board_name(entry.name, scale, nameRoom)
        local w = util.width(cut, scale)

        if smooth and cut ~= entry.name then
            w = math.max(w, math.min(util.width(entry.name, scale), nameRoom))
        end
        if w > nameW then nameW = w end
        if entry.right ~= nil then
            w = util.width(entry.right, scale)
            if w > valueW then valueW = w end
        end
    end
    local columnW = markW + nameW + (valueW > 0 and (BOARD_GAP + valueW) or 0)

    if opts.wide ~= nil and opts.wide > 1 then
        columnW = columnW + BOARD_GAP * (opts.wide - 1) * 2
    end
    local per = columns == 2 and math.ceil(count / 2) or count
    local innerW = columnW * columns + (columns == 2 and BOARD_COLUMN_GAP or 0)
    if headings > 0 then

        local titleW = util.board_title_size(title, scale)
        if titleW > innerW then innerW = titleW end
    end
    return scale, columns, line, per, markW, nameW, valueW, columnW, innerW,
        nameRoom, headings
end

function util.board_box(x, y, title, rows, opts)
    local _, _, line, per, _, _, _, _, innerW, _, headings =
        util.board_measure(y, title, rows, opts)
    return x - BOARD_PAD_X, y - BOARD_PAD_Y, innerW + BOARD_PAD_X * 2,
        line * (per + headings) + BOARD_PAD_Y * 2
end

function util.stack_bottom_over(left, right)
    local claims = util.hudClaims

    if claims == nil or frame_stamp() ~= stackFrame then return nil end
    local screen = djui_hud_get_screen_width()
    local bottom = nil
    for index = 1, #claims do
        local claim = claims[index]
        local from = claim.left
        if from ~= nil and from < right and screen - from > left then
            local under = claim.y + claim.height
            if bottom == nil or under > bottom then bottom = under end
        end
    end
    return bottom
end

local function below_stack(x, y, innerW)
    local bottom = util.stack_bottom_over(x - BOARD_PAD_X, x + innerW + BOARD_PAD_X)
    if bottom == nil then return y end
    return math.max(y, bottom + BOARD_PAD_Y + 2)
end

function util.board_top(x, y, width)
    return below_stack(x, y, width or 300)
end

util.boardBoxes = {}
util.boardBoxCount = 0
util.boardBoxFrame = nil
function util.note_board(x, y, w, h)
    local stamp = frame_stamp()
    local w0, h0 = djui_hud_get_screen_width(), djui_hud_get_screen_height()
    if stamp ~= util.boardBoxFrame or w0 ~= util.boardBoxW or h0 ~= util.boardBoxH then
        util.boardBoxCount = 0
        util.boardBoxFrame, util.boardBoxW, util.boardBoxH = stamp, w0, h0
    end
    local n = util.boardBoxCount
    local boxes = util.boardBoxes
    boxes[n + 1], boxes[n + 2], boxes[n + 3], boxes[n + 4] = x, y, x + w, y + h
    util.boardBoxCount = n + 4
end

function util.on_a_board(x0, y0, x1, y1)
    if util.boardBoxFrame ~= frame_stamp() or util.boardBoxW ~= djui_hud_get_screen_width()
        or util.boardBoxH ~= djui_hud_get_screen_height() then
        return false
    end
    local boxes = util.boardBoxes
    for index = 1, util.boardBoxCount, 4 do
        if x1 > boxes[index] and x0 < boxes[index + 2] and y1 > boxes[index + 1]
            and y0 < boxes[index + 3] then
            return true
        end
    end
    return false
end

function util.clear_of_boards(x, y, reach)
    local width = djui_hud_get_screen_width()
    if util.boardBoxFrame ~= frame_stamp() or util.boardBoxW ~= width
        or util.boardBoxH ~= djui_hud_get_screen_height() then
        return x, y
    end
    local boxes = util.boardBoxes
    local half = width * 0.5
    for index = 1, util.boardBoxCount, 4 do
        local x0, y0, x1, y1 = boxes[index], boxes[index + 1],
            boxes[index + 2], boxes[index + 3]
        if x + reach > x0 and x - reach < x1 and y + reach * 0.5 > y0
            and y - reach * 0.5 < y1 then
            if (x0 + x1) * 0.5 < half then x = x1 + reach else x = x0 - reach end
        end
    end
    return x, y
end

util.boardsDrawn = 0

function util.board(x, y, title, rows, opts)
    opts = opts or BOARD_NO_OPTS
    util.boardsDrawn = util.boardsDrawn + 1
    local count = math.min(#rows, opts.max or #rows)
    local scale, columns, line, per, markW, _, _, columnW, innerW, nameRoom,
        headings = util.board_measure(y, title, rows, opts)
    local moved = below_stack(x, y, innerW)
    if moved ~= y then
        y = moved
        scale, columns, line, per, markW, _, _, columnW, innerW, nameRoom,
            headings = util.board_measure(y, title, rows, opts)
    end

    local shown = per
    if util.asks(OF.hud, "band_area") then
        local bandTop, bandBottom = OF.hud.band_area()
        if bandTop ~= nil and y - BOARD_PAD_Y < bandBottom
            and y + line * (per + headings) + BOARD_PAD_Y > bandTop then
            shown = math.min(per, math.floor((bandTop - 2 - BOARD_PAD_Y - y) / line) - headings)
            if shown < 1 then
                util.boardClipped = per
                return y
            end
        end
    end
    util.boardClipped = per - shown
    local height = line * (shown + headings)

    util.round_plate(x - BOARD_PAD_X, y - BOARD_PAD_Y, innerW + BOARD_PAD_X * 2,
        height + BOARD_PAD_Y * 2, util.board_plate_opts(opts))
    util.note_board(x - BOARD_PAD_X, y - BOARD_PAD_Y, innerW + BOARD_PAD_X * 2,
        height + BOARD_PAD_Y * 2)
    if headings > 0 then

        local head = opts.titleColour or util.gold()

        util.board_title(title, x, y, scale, head.r, head.g, head.b, 255)
    end

    util.in_font(util.round_board_face(), function()
        util.board_rows(x, y, rows, opts, count, scale, columns, line, per, markW,
            columnW, innerW, nameRoom, headings, shown < per and shown or nil)
    end)
    return y + height + BOARD_PAD_Y
end

function util.board_rows(x, y, rows, opts, count, scale, columns, line, per,
        markW, columnW, innerW, nameRoom, headings, shown)
    local colour = opts.colour
    local r, g, b = util.name_colour()
    local plainR, plainG, plainB = r, g, b
    local sides = colour == nil and util.asks(OF and OF.teams, "in_play")
        and OF.teams.in_play()
    for place = 1, count do
        local entry = rows[place]
        local slot = place - 1
        local colX = x
        if columns == 2 and slot >= per then
            slot = slot - per
            colX = x + columnW + BOARD_COLUMN_GAP
        end

        if shown == nil or slot < shown then
        local rowY = y + line * (slot + headings)
        if entry.localIndex == 0 then

            local washL, washR = x - BOARD_PAD_X, x + innerW + BOARD_PAD_X
            if columns == 2 then
                local middle = x + columnW + BOARD_COLUMN_GAP * 0.5
                if colX > x then washL = middle else washR = middle end
            end
            util.rect(washL, rowY - 1, washR - washL, line - 1,
                255, 255, 255, OWN_ROW_ALPHA)
        end
        if colour ~= nil then
            r, g, b = colour(entry.place or place)
        elseif sides and entry.localIndex ~= nil then

            r, g, b = plainR, plainG, plainB
            local team = OF.teams.find(OF.teams.of(entry.localIndex))
            if team ~= nil then r, g, b = team.r, team.g, team.b end
        end
        if entry.place ~= nil then
            util.text(place_mark(entry.place), colX, rowY, scale, r, g, b, 255)
        end
        if not util.board_name_drawn(entry, place, colX + markW, rowY, scale, r, g, b, nameRoom) then
            util.text_raw(util.board_name(entry.name, scale, nameRoom),
                colX + markW, rowY, scale, r, g, b, 255)
        end
        if entry.right ~= nil then

            local after = (opts.wide ~= nil and opts.wide > 1)
                and BOARD_GAP * (opts.wide - 1) * 2 or 0
            util.text(entry.right, colX + columnW - after - util.width(entry.right, scale),
                rowY, scale, 255, 255, 255, 255)
        end
        end
    end
end

local HEADLINE_PAD_X, HEADLINE_PAD_Y = 18, 10

function util.fit_scale(text, want, room)
    if type(text) ~= "string" or room == nil or room <= 0 then return want end
    local width = util.text_size(text, want)
    if width <= room or width <= 0 then return want end
    return math.max(want * 0.45, want * room / width)
end

local HEADLINE_ACCENT = {}
function util.final_headline(text, y, scale, left, room)
    if type(text) ~= "string" or text == "" then return y end
    local screenWidth = djui_hud_get_screen_width()
    left = left or 0
    room = room or screenWidth

    local face = util.round_title_face(text)
    local want = util.hud_scale(face, scale or 1.8)
    local width, height
    util.in_font(face, function()
        scale = util.fit_scale(text, want, room - 48 - HEADLINE_PAD_X * 2)
        width, height = util.text_size(text, scale)
    end)
    local x = left + (room - width) * 0.5
    HEADLINE_ACCENT.accent = OF.GOLD
    util.round_plate(x - HEADLINE_PAD_X, y - HEADLINE_PAD_Y,
        width + HEADLINE_PAD_X * 2, height + HEADLINE_PAD_Y * 2, HEADLINE_ACCENT)
    util.in_font(face, function()
        util.text(text, x, y, scale,
            util.gold().r, util.gold().g, util.gold().b, 255)
    end)
    return y + height
end

OF.LEVELS = {

    { name = "Castle Grounds",            group = "Castle", level = LEVEL_CASTLE_GROUNDS,   area = 1, act = 0 },
    { name = "Castle Lobby",              group = "Castle", level = LEVEL_CASTLE,           area = 1, act = 0 },
    { name = "Castle Upstairs",           group = "Castle", level = LEVEL_CASTLE,           area = 2, act = 0 },
    { name = "Castle Basement",           group = "Castle", level = LEVEL_CASTLE,           area = 3, act = 0 },
    { name = "Castle Courtyard",          group = "Castle", level = LEVEL_CASTLE_COURTYARD, area = 1, act = 0 },

    { name = "Bob-omb Battlefield",       group = "Courses", level = LEVEL_BOB, area = 1, act = 1 },
    { name = "Whomp's Fortress",          group = "Courses", level = LEVEL_WF,  area = 1, act = 1 },
    { name = "Jolly Roger Bay",           group = "Courses", level = LEVEL_JRB, area = 1, act = 1 },
    { name = "Jolly Roger Bay - Inside the Ship", group = "Courses", level = LEVEL_JRB, area = 2, act = 1 },
    { name = "Cool, Cool Mountain",       group = "Courses", level = LEVEL_CCM, area = 1, act = 1 },
    { name = "Cool, Cool Mountain - Slide", group = "Courses", level = LEVEL_CCM, area = 2, act = 1 },
    { name = "Big Boo's Haunt",           group = "Courses", level = LEVEL_BBH, area = 1, act = 1 },
    { name = "Hazy Maze Cave",            group = "Courses", level = LEVEL_HMC, area = 1, act = 1 },
    { name = "Lethal Lava Land",          group = "Courses", level = LEVEL_LLL, area = 1, act = 1 },
    { name = "Lethal Lava Land - Volcano", group = "Courses", level = LEVEL_LLL, area = 2, act = 1 },
    { name = "Shifting Sand Land",        group = "Courses", level = LEVEL_SSL, area = 1, act = 1 },
    { name = "Shifting Sand Land - Pyramid", group = "Courses", level = LEVEL_SSL, area = 2, act = 1 },
    { name = "Dire, Dire Docks",          group = "Courses", level = LEVEL_DDD, area = 1, act = 1 },
    { name = "Snowman's Land",            group = "Courses", level = LEVEL_SL,  area = 1, act = 1 },
    { name = "Snowman's Land - Igloo",    group = "Courses", level = LEVEL_SL,  area = 2, act = 1 },
    { name = "Wet-Dry World",             group = "Courses", level = LEVEL_WDW, area = 1, act = 1 },
    { name = "Tall, Tall Mountain",       group = "Courses", level = LEVEL_TTM, area = 1, act = 1 },
    { name = "Tall, Tall Mountain - Slide", group = "Courses", level = LEVEL_TTM, area = 2, act = 1 },
    { name = "Tiny-Huge Island (huge)",   group = "Courses", level = LEVEL_THI, area = 1, act = 1 },
    { name = "Tiny-Huge Island (tiny)",   group = "Courses", level = LEVEL_THI, area = 2, act = 1 },
    { name = "Tiny-Huge Island - Red Coin Cave", group = "Courses", level = LEVEL_THI, area = 3, act = 1 },
    { name = "Tick Tock Clock",           group = "Courses", level = LEVEL_TTC, area = 1, act = 1 },
    { name = "Rainbow Ride",              group = "Courses", level = LEVEL_RR,  area = 1, act = 1 },

    { name = "Bowser in the Dark World",  group = "Bowser", level = LEVEL_BITDW,   area = 1, act = 0 },
    { name = "Bowser in the Fire Sea",    group = "Bowser", level = LEVEL_BITFS,   area = 1, act = 0 },
    { name = "Bowser in the Sky",         group = "Bowser", level = LEVEL_BITS,    area = 1, act = 0 },
    { name = "Bowser 1 Arena",            group = "Bowser", level = LEVEL_BOWSER_1, area = 1, act = 0 },
    { name = "Bowser 2 Arena",            group = "Bowser", level = LEVEL_BOWSER_2, area = 1, act = 0 },
    { name = "Bowser 3 Arena",            group = "Bowser", level = LEVEL_BOWSER_3, area = 1, act = 0 },

    { name = "Princess's Secret Slide",   group = "Secret", secret = true, level = LEVEL_PSS,   area = 1, act = 0 },
    { name = "Cavern of the Metal Cap",   group = "Secret", secret = true, level = LEVEL_COTMC, area = 1, act = 0 },
    { name = "Tower of the Wing Cap",     group = "Secret", secret = true, level = LEVEL_TOTWC, area = 1, act = 0 },
    { name = "Vanish Cap under the Moat", group = "Secret", secret = true, level = LEVEL_VCUTM, area = 1, act = 0 },
    { name = "Wing Mario over the Rainbow", group = "Secret", secret = true, level = LEVEL_WMOTR, area = 1, act = 0 },
    { name = "The Secret Aquarium",       group = "Secret", secret = true, level = LEVEL_SA,    area = 1, act = 0 },

}

OF.LEVEL_GROUPS = { "Castle", "Courses", "Bowser", "Secret" }

OF.WAYPOINT_GROUP = "Waypoints"
OF.BOWSER_GROUP = "Bowser"
function util.waypoint_destinations()
    if OF.waypoints == nil or OF.waypoints.list == nil then return {} end
    local list = {}
    for _, point in ipairs(OF.waypoints.list()) do
        table.insert(list, {
            name = point.name,
            group = OF.WAYPOINT_GROUP,
            level = point.level, area = point.area, act = point.act,
            point = point,
        })
    end
    return list
end

local HAZARDS = {
    { word = "lava", types = { "SURFACE_BURNING" } },
    { word = "quicksand", types = { "SURFACE_SHALLOW_QUICKSAND",
        "SURFACE_DEEP_QUICKSAND", "SURFACE_INSTANT_QUICKSAND",
        "SURFACE_DEEP_MOVING_QUICKSAND", "SURFACE_SHALLOW_MOVING_QUICKSAND",
        "SURFACE_QUICKSAND", "SURFACE_MOVING_QUICKSAND",
        "SURFACE_INSTANT_MOVING_QUICKSAND" } },
    { word = "pits", types = { "SURFACE_DEATH_PLANE" } },
    { word = "wind", types = { "SURFACE_HORIZONTAL_WIND", "SURFACE_VERTICAL_WIND" } },
    { word = "ice", types = { "SURFACE_ICE" } },
}
util.HAZARDS = HAZARDS

util.hazardsRead = {}

function util.level_hazards(level, area)
    if type(level) ~= "number" then return {} end
    area = area or 1
    local key = level * 16 + area
    if util.hazardsRead[key] ~= nil then return util.hazardsRead[key] end

    local words = {}
    local get = _G.smlua_collision_util_get_level_collision
    local find = _G.smlua_collision_util_find_surface_types
    if type(get) == "function" and type(find) == "function"
        and level >= 0 and level < (LEVEL_COUNT or 39) then
        local ok, collision = pcall(get, level, area)
        local types = nil
        if ok and collision ~= nil then
            local found
            ok, found = pcall(find, collision)
            if ok and type(found) == "table" then types = found end
        end
        if types ~= nil then
            local present = {}
            for _, t in pairs(types) do present[t] = true end
            for _, hazard in ipairs(HAZARDS) do
                for _, name in ipairs(hazard.types) do
                    local value = _G[name]
                    if value ~= nil and present[value] then
                        local word = hazard.word
                        if word == "lava" and level == LEVEL_SL then
                            word = "icy water"
                        end
                        table.insert(words, word)
                        break
                    end
                end
            end
        end
    end
    util.hazardsRead[key] = words
    return words
end

function util.level_hazard_line(level, area)
    local words = util.level_hazards(level, area)
    if #words == 0 then return nil end
    return table.concat(words, ", ")
end

OF.VENUE_GROUP = "Venues"
function util.venue_destinations()
    local list = {}
    if OF.arena == nil or type(OF.arena.PLACES) ~= "table" then return list end
    local registered = {}
    for _, entry in ipairs(util.custom_levels()) do registered[entry.level] = true end
    for _, place in ipairs(OF.arena.PLACES) do
        if place.venue == true and type(place.level) == "number" and registered[place.level] then
            table.insert(list, {
                name = place.name,
                group = OF.VENUE_GROUP,
                level = place.level,
                area = place.area or 1,
                act = place.act or 1,
                custom = true,
            })
        end
    end
    return list
end

function util.levels_in_group(group)
    if group == OF.VENUE_GROUP then return util.venue_destinations() end

    if group == "Mod levels" then
        local venue = {}
        for _, entry in ipairs(util.venue_destinations()) do venue[entry.level] = true end

        if OF.arena ~= nil and type(OF.arena.PLACES) == "table" then
            for _, place in ipairs(OF.arena.PLACES) do
                if place.noTravel == true then
                    if type(place.level) == "number" then venue[place.level] = true end
                    venue[place.name] = true
                end
            end
        end
        local list = {}
        for _, entry in ipairs(util.custom_levels()) do
            if not venue[entry.level] and not venue[entry.name] then table.insert(list, entry) end
        end
        return list
    end
    if group == OF.WAYPOINT_GROUP then return util.waypoint_destinations() end

    local list = {}
    for _, entry in ipairs(OF.LEVELS) do
        if entry.group == group then table.insert(list, entry) end
    end
    return list
end

function util.level_groups()
    local groups = {}
    for _, group in ipairs(OF.LEVEL_GROUPS) do

        if #util.levels_in_group(group) > 0 then table.insert(groups, group) end
    end
    if #util.venue_destinations() > 0 then table.insert(groups, OF.VENUE_GROUP) end
    if #util.levels_in_group("Mod levels") > 0 then table.insert(groups, "Mod levels") end

    if #util.waypoint_destinations() > 0 then
        table.insert(groups, OF.WAYPOINT_GROUP)
    end
    return groups
end

OF.COURSES = {
    { num = COURSE_BOB, name = "Bob-omb Battlefield",  level = LEVEL_BOB },
    { num = COURSE_WF,  name = "Whomp's Fortress",     level = LEVEL_WF },
    { num = COURSE_JRB, name = "Jolly Roger Bay",      level = LEVEL_JRB },
    { num = COURSE_CCM, name = "Cool, Cool Mountain",  level = LEVEL_CCM },
    { num = COURSE_BBH, name = "Big Boo's Haunt",      level = LEVEL_BBH },
    { num = COURSE_HMC, name = "Hazy Maze Cave",       level = LEVEL_HMC },
    { num = COURSE_LLL, name = "Lethal Lava Land",     level = LEVEL_LLL },
    { num = COURSE_SSL, name = "Shifting Sand Land",   level = LEVEL_SSL },
    { num = COURSE_DDD, name = "Dire, Dire Docks",     level = LEVEL_DDD },
    { num = COURSE_SL,  name = "Snowman's Land",       level = LEVEL_SL },
    { num = COURSE_WDW, name = "Wet-Dry World",        level = LEVEL_WDW },
    { num = COURSE_TTM, name = "Tall, Tall Mountain",  level = LEVEL_TTM },
    { num = COURSE_THI, name = "Tiny-Huge Island",     level = LEVEL_THI },
    { num = COURSE_TTC, name = "Tick Tock Clock",      level = LEVEL_TTC },
    { num = COURSE_RR,  name = "Rainbow Ride",         level = LEVEL_RR },
}

util.PAINTING_WIDTH = 64
util.PAINTING_HALF = 32

util.PAINTINGS = {
    [COURSE_BOB] = { bottom = "inside_castle_seg7_texture_0700B800",
                     top    = "inside_castle_seg7_texture_0700A800" },
    [COURSE_CCM] = { bottom = "inside_castle_seg7_texture_0700D800",
                     top    = "inside_castle_seg7_texture_0700C800" },
    [COURSE_WF]  = { bottom = "inside_castle_seg7_texture_0700F800",
                     top    = "inside_castle_seg7_texture_0700E800" },
    [COURSE_JRB] = { bottom = "inside_castle_seg7_texture_07011800",
                     top    = "inside_castle_seg7_texture_07010800" },
    [COURSE_LLL] = { bottom = "inside_castle_seg7_texture_07012800",
                     top    = "inside_castle_seg7_texture_07013800" },
    [COURSE_SSL] = { bottom = "inside_castle_seg7_texture_07015800",
                     top    = "inside_castle_seg7_texture_07014800" },
    [COURSE_WDW] = { bottom = "inside_castle_seg7_texture_07018800",
                     top    = "inside_castle_seg7_texture_07017800" },
    [COURSE_THI] = { bottom = "inside_castle_seg7_texture_0701A800",
                     top    = "inside_castle_seg7_texture_07019800" },
    [COURSE_TTM] = { bottom = "inside_castle_seg7_texture_0701C800",
                     top    = "inside_castle_seg7_texture_0701B800" },
    [COURSE_TTC] = { bottom = "inside_castle_seg7_texture_0701E800",
                     top    = "inside_castle_seg7_texture_0701D800" },
    [COURSE_SL]  = { bottom = "inside_castle_seg7_texture_07020800",
                     top    = "inside_castle_seg7_texture_0701F800" },
}

util.PAINTING_FACES = {}
for course, key in pairs({
    [COURSE_BOB] = "bob", [COURSE_CCM] = "ccm", [COURSE_WF] = "wf", [COURSE_JRB] = "jrb",
    [COURSE_LLL] = "lll", [COURSE_SSL] = "ssl", [COURSE_WDW] = "wdw", [COURSE_THI] = "thihuge",
    [COURSE_TTM] = "ttm", [COURSE_TTC] = "ttc", [COURSE_SL] = "sl",
}) do

    util.PAINTING_FACES[course] = { top = "of_pnt_" .. key .. "_top", bottom = "of_pnt_" .. key .. "_bottom" }
end

local function place_key(level, area)
    return tostring(level) .. "." .. tostring(area or 1)
end

util.PLACE_FACES = {

    [place_key(LEVEL_BITDW, 1)]    = { top = "of_pnt_bitdw_top",  bottom = "of_pnt_bitdw_bottom" },
    [place_key(LEVEL_BITFS, 1)]    = { top = "of_pnt_bitfs_top",  bottom = "of_pnt_bitfs_bottom" },
    [place_key(LEVEL_BITS, 1)]     = { top = "of_pnt_bits_top",   bottom = "of_pnt_bits_bottom" },
    [place_key(LEVEL_BOWSER_1, 1)] = { top = "of_pnt_b1_top",     bottom = "of_pnt_b1_bottom" },
    [place_key(LEVEL_BOWSER_2, 1)] = { top = "of_pnt_b2_top",     bottom = "of_pnt_b2_bottom" },
    [place_key(LEVEL_BOWSER_3, 1)] = { top = "of_pnt_b3_top",     bottom = "of_pnt_b3_bottom" },

    [place_key(LEVEL_PSS, 1)]      = { top = "of_pnt_pss_top",    bottom = "of_pnt_pss_bottom" },
    [place_key(LEVEL_SA, 1)]       = { top = "of_pnt_sa_top",     bottom = "of_pnt_sa_bottom" },
    [place_key(LEVEL_COTMC, 1)]    = { top = "of_pnt_cotmc_top",  bottom = "of_pnt_cotmc_bottom" },
    [place_key(LEVEL_TOTWC, 1)]    = { top = "of_pnt_wc_top",     bottom = "of_pnt_wc_bottom" },
    [place_key(LEVEL_VCUTM, 1)]    = { top = "of_pnt_vc_top",     bottom = "of_pnt_vc_bottom" },
    [place_key(LEVEL_WMOTR, 1)]    = { top = "of_pnt_wmotr_top",  bottom = "of_pnt_wmotr_bottom" },

    [place_key(LEVEL_BBH, 1)]      = { top = "of_pnt_bbh_top",    bottom = "of_pnt_bbh_bottom" },
    [place_key(LEVEL_RR, 1)]       = { top = "of_pnt_rr_top",     bottom = "of_pnt_rr_bottom" },
    [place_key(LEVEL_HMC, 1)]      = { top = "of_pnt_hmc_top",    bottom = "of_pnt_hmc_bottom" },
    [place_key(LEVEL_DDD, 1)]      = { top = "of_pnt_ddd_top",    bottom = "of_pnt_ddd_bottom" },

    [place_key(LEVEL_JRB, 2)]      = { top = "of_pnt_ship_top",       bottom = "of_pnt_ship_bottom" },
    [place_key(LEVEL_CCM, 2)]      = { top = "of_pnt_ccmslide_top",   bottom = "of_pnt_ccmslide_bottom" },
    [place_key(LEVEL_TTM, 2)]      = { top = "of_pnt_ttmslide_top",   bottom = "of_pnt_ttmslide_bottom" },
    [place_key(LEVEL_LLL, 2)]      = { top = "of_pnt_volcano_top",    bottom = "of_pnt_volcano_bottom" },
    [place_key(LEVEL_SSL, 2)]      = { top = "of_pnt_pyramid_top",    bottom = "of_pnt_pyramid_bottom" },
    [place_key(LEVEL_SL, 2)]       = { top = "of_pnt_igloo_top",      bottom = "of_pnt_igloo_bottom" },

    [place_key(LEVEL_THI, 1)]      = { top = "of_pnt_thihuge_top",     bottom = "of_pnt_thihuge_bottom" },
    [place_key(LEVEL_THI, 2)]      = { top = "of_pnt_thitiny_top",     bottom = "of_pnt_thitiny_bottom" },
    [place_key(LEVEL_THI, 3)]      = { top = "of_pnt_wigglercave_top", bottom = "of_pnt_wigglercave_bottom" },

    [place_key(LEVEL_CASTLE_GROUNDS, 1)] = { top = "of_pnt_grounds_top", bottom = "of_pnt_grounds_bottom" },

    [place_key(LEVEL_CASTLE, 1)]           = { top = "of_pnt_castle_lobby_top",     bottom = "of_pnt_castle_lobby_bottom" },
    [place_key(LEVEL_CASTLE, 2)]           = { top = "of_pnt_castle_upstairs_top",  bottom = "of_pnt_castle_upstairs_bottom" },
    [place_key(LEVEL_CASTLE, 3)]           = { top = "of_pnt_castle_basement_top",  bottom = "of_pnt_castle_basement_bottom" },
    [place_key(LEVEL_CASTLE_COURTYARD, 1)] = { top = "of_pnt_castle_courtyard_top", bottom = "of_pnt_castle_courtyard_bottom" },
}

util.ARENA_FACES = {
    desert_cage = { top = "of_pnt_desert_cage_top", bottom = "of_pnt_desert_cage_bottom" },
    ice_donut   = { top = "of_pnt_ice_donut_top",   bottom = "of_pnt_ice_donut_bottom" },
    the_plate   = { top = "of_pnt_the_plate_top",   bottom = "of_pnt_the_plate_bottom" },

    skykeep     = { top = "of_pnt_skykeep_top",     bottom = "of_pnt_skykeep_bottom" },
}

function util.register_place_face(level, area, key, own)

    if type(own) == "table" then return util.file_place_face(level, area, own) end
    local pair = util.ARENA_FACES[key]
    if pair == nil or level == nil then return false end
    util.PLACE_FACES[place_key(level, area or 1)] = pair
    return true
end

function util.file_place_face(level, area, pair)
    if type(level) ~= "number" or type(pair) ~= "table" then return false end
    if type(pair.top) ~= "string" or type(pair.bottom) ~= "string" then return false end
    util.PLACE_FACES[place_key(level, area or 1)] = { top = pair.top, bottom = pair.bottom }
    return true
end

local paintingCache = {}

local function painting_texture(name)
    local held = paintingCache[name]
    if held ~= nil then
        if held == false then return nil end
        return held
    end
    if get_texture_info == nil then
        paintingCache[name] = false
        return nil
    end
    local ok, info = pcall(get_texture_info, name)
    if not ok or info == nil then
        paintingCache[name] = false
        return nil
    end
    paintingCache[name] = info
    return info
end

function util.painting_texel(info)
    local width = info ~= nil and tonumber(info.width) or nil
    if width == nil or width <= 0 then return 1 end
    return util.PAINTING_WIDTH / width
end

local function draw_painting_pair(pair, x, y, scale, alpha)
    if pair == nil then return false end
    if djui_hud_render_texture == nil then return false end

    local top = painting_texture(pair.top)
    local bottom = painting_texture(pair.bottom)
    if top == nil or bottom == nil then return false end

    scale = scale or 1
    djui_hud_set_color(255, 255, 255, util.byte(alpha == nil and 255 or alpha))
    local topAt = scale * util.painting_texel(top)
    local bottomAt = scale * util.painting_texel(bottom)
    djui_hud_render_texture(top, x, y, topAt, topAt)
    djui_hud_render_texture(bottom, x, y + util.PAINTING_HALF * scale,
        bottomAt, bottomAt)
    return true
end

local function place_painting_pair(level, area)
    local pair = util.PLACE_FACES[place_key(level, area)]
    if pair ~= nil then return pair end
    if area ~= nil and area ~= 1 then return nil end
    local course = util.course_of_level(level)
    return util.PAINTING_FACES[course] or util.PAINTINGS[course]
end

function util.has_painting_for_place(level, area)
    return place_painting_pair(level, area) ~= nil
end

function util.painting_for_place(level, area, x, y, scale, alpha)
    return draw_painting_pair(place_painting_pair(level, area), x, y, scale, alpha)
end

function util.every_destination()
    local list = {}
    for _, entry in ipairs(OF.LEVELS) do table.insert(list, entry) end
    for _, entry in ipairs(util.custom_levels()) do table.insert(list, entry) end
    for _, entry in ipairs(util.waypoint_destinations()) do
        table.insert(list, entry)
    end
    return list
end

function util.find_destination(text)
    local needle = string.lower(text or "")
    if needle == "" then return nil end

    local all = util.every_destination()
    for _, entry in ipairs(all) do
        if string.lower(entry.name) == needle then return entry end
    end
    for _, entry in ipairs(all) do
        if string.sub(string.lower(entry.name), 1, #needle) == needle then
            return entry
        end
    end
    for _, entry in ipairs(all) do
        if string.find(string.lower(entry.name), needle, 1, true) ~= nil then
            return entry
        end
    end
    return nil
end

function util.destination_act(entry)
    if type(entry) ~= "table" then return 0 end
    local fallback = math.floor(tonumber(entry.act) or 0)
    local level = entry.level
    if level == nil then return fallback end
    local area = entry.area

    local inArea, inLevel = nil, nil
    for i = 0, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[i]
        if np ~= nil and np.connected and np.currLevelSyncValid
            and np.currLevelNum == level then
            local act = math.floor(tonumber(np.currActNum) or 0)
            if act ~= 99 then
                if np.currAreaSyncValid and np.currAreaIndex == area then
                    if inArea == nil then inArea = act end
                elseif inLevel == nil then
                    inLevel = act
                end
            end
        end
    end

    if inArea ~= nil then return inArea end
    if inLevel ~= nil then return inLevel end
    return fallback
end

util.SECRET_STAGE = "Secret stage"
function util.level_name(levelNum, areaIndex)
    if areaIndex ~= nil then
        for _, entry in ipairs(OF.LEVELS) do
            if entry.level == levelNum and entry.area == areaIndex then
                return entry.name
            end
        end
    end
    for _, entry in ipairs(OF.LEVELS) do
        if entry.level == levelNum then
            return entry.name
        end
    end

    if type(levelNum) ~= "number" then return "Unknown" end
    local ok, info = pcall(smlua_level_util_get_info, levelNum)
    if ok and info ~= nil then
        if info.fullName ~= nil and info.fullName ~= "" then return info.fullName end
        if info.shortName ~= nil and info.shortName ~= "" then return info.shortName end
    end
    return "Unknown"
end

function util.concealed_level_name(levelNum, areaIndex)
    if util.level_is_secret(levelNum, areaIndex) then return util.SECRET_STAGE end
    return util.level_name(levelNum, areaIndex)
end

function util.level_is_secret(levelNum, areaIndex)
    if type(levelNum) ~= "number" then return false end
    if areaIndex ~= nil then
        for _, entry in ipairs(OF.LEVELS) do
            if entry.level == levelNum and entry.area == areaIndex then
                return entry.secret == true
            end
        end
    end
    for _, entry in ipairs(OF.LEVELS) do
        if entry.level == levelNum then return entry.secret == true end
    end
    return false
end

function util.secret_order()
    for index, entry in ipairs(OF.LEVELS) do
        if entry.secret == true then return index end
    end
    return #OF.LEVELS + 1
end

function util.level_order(levelNum, areaIndex)
    if areaIndex ~= nil then
        for index, entry in ipairs(OF.LEVELS) do
            if entry.level == levelNum and entry.area == areaIndex then return index end
        end
    end
    for index, entry in ipairs(OF.LEVELS) do
        if entry.level == levelNum then return index end
    end
    return #OF.LEVELS + 1
end

local CUSTOM_LEVEL_NUM_START = 50
local CUSTOM_LEVEL_PROBE_END = 250

function util.custom_levels()
    local found = {}
    local list = {}

    local function take(info)
        while info ~= nil do
            local levelNum = info.levelNum
            if levelNum ~= nil and not found[levelNum] then
                found[levelNum] = true
                local name = info.fullName
                if name == nil or name == "" then name = info.shortName end
                if name ~= nil and name ~= "" then
                    table.insert(list, {
                        name = name,
                        group = "Mod levels",
                        level = levelNum,
                        area = 1,
                        act = 1,
                        custom = true,
                    })
                end
            end
            info = info.next
        end
    end

    for levelNum = CUSTOM_LEVEL_NUM_START, CUSTOM_LEVEL_PROBE_END do
        if not found[levelNum] then
            local ok, info = pcall(smlua_level_util_get_info, levelNum)
            if ok and info ~= nil then take(info) end
        end
    end

    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

function util.course_name(courseNum)
    for _, entry in ipairs(OF.COURSES) do
        if entry.num == courseNum then return entry.name end
    end
    return "Course " .. tostring(courseNum)
end

function util.star_act_index(obj)
    if obj == nil or obj.oBehParams == nil then return nil end
    local raw = math.floor(obj.oBehParams / 16777216)

    if gLevelValues ~= nil and OF.util.flag(gLevelValues.useGlobalStarIds) == 1 then
        return (raw % 256) % 7
    end
    return raw % 32
end

hook_event(HOOK_MARIO_UPDATE, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    util.limp_update(m)
end, OF.LOCAL_MARIO)

do

    local ledger = {}

    function util.lend_setting(name, holder, getter, setter, value)
        if name == nil or holder == nil then return false end
        if util.binding(setter) == nil then return false end
        local slot = ledger[name]
        if slot == nil then
            local was = util.optional(getter, nil)
            if was == nil then return false end
            slot = { was = was, holders = {}, count = 0, get = getter,
                set = setter, wants = {}, order = {} }
            ledger[name] = slot
        end
        if not slot.holders[holder] then
            slot.holders[holder] = true
            slot.count = slot.count + 1
            table.insert(slot.order, holder)
        end

        slot.wants[holder] = value
        slot.value = value
        util.optional(setter, nil, value)
        return true
    end

    function util.return_setting(name, holder)
        local slot = ledger[name]
        if slot == nil or holder == nil then return false end
        if not slot.holders[holder] then return false end
        slot.holders[holder] = nil
        slot.count = slot.count - 1
        slot.wants[holder] = nil
        for at = #slot.order, 1, -1 do
            if slot.order[at] == holder then table.remove(slot.order, at) end
        end
        if slot.count > 0 then

            local newest = slot.order[#slot.order]
            if newest ~= nil then
                slot.value = slot.wants[newest]
                util.optional(slot.set, nil, slot.value)
            end
            return true
        end
        ledger[name] = nil
        util.optional(slot.set, nil, slot.was)
        return true
    end

    function util.setting_was(name)
        local slot = ledger[name]
        if slot == nil then return nil end
        return slot.was
    end

    function util.setting_count(name)
        local slot = ledger[name]
        if slot == nil then return 0 end
        return slot.count
    end

    function util.setting_holders(name)
        local slot = ledger[name]
        local list = {}
        if slot == nil then return list end
        for holder in pairs(slot.holders) do table.insert(list, holder) end
        table.sort(list)
        return list
    end

    local NEWCAM = CAMERA_MODE_NEWCAM or 0x12

    local function settle_camera_mode()
        if gLakituState == nil or type(gLakituState.mode) ~= "number" then return false end

        if gLakituState.mode == NEWCAM then return false end
        local m = gMarioStates ~= nil and gMarioStates[0] or nil
        local camera = m ~= nil and m.area ~= nil and m.area.camera or nil
        if camera == nil or type(camera.mode) ~= "number" then return false end

        if camera.mode ~= NEWCAM then return false end
        camera.mode = gLakituState.mode
        return true
    end

    util.settle_camera_mode = settle_camera_mode

    function util.lend_free_cam(holder)
        local lent = util.lend_setting("freeCam", holder,
            "camera_config_is_free_cam_enabled",
            "camera_config_enable_free_cam", false)
        settle_camera_mode()
        return lent
    end

    function util.return_free_cam(holder)
        local given = util.return_setting("freeCam", holder)
        settle_camera_mode()
        return given
    end

    function util.lend_mouse_look(holder)
        local lent = util.lend_setting("cam.mouse", holder,
            "camera_config_is_mouse_look_enabled",
            "camera_config_enable_mouse_look", false)

        settle_camera_mode()
        return lent
    end

    function util.return_mouse_look(holder)
        local given = util.return_setting("cam.mouse", holder)
        settle_camera_mode()
        return given
    end

    function util.lend_hud_mouse(holder)
        return util.lend_setting("hudMouseLock", holder,
            "djui_hud_is_mouse_locked", "djui_hud_set_mouse_locked", false)
    end

    function util.return_hud_mouse(holder)
        return util.return_setting("hudMouseLock", holder)
    end

    function util.reset_camera_overrides()
        if util.binding("camera_reset_overrides") == nil then return false end
        util.optional("camera_reset_overrides", nil)
        for _, slot in pairs(ledger) do
            if slot.count > 0 and slot.value ~= nil then
                util.optional(slot.set, nil, slot.value)
            end
        end

        settle_camera_mode()
        return true
    end

    function util.forget_settings()
        ledger = {}
    end
end

do

    local MODES = {

        { key = "spectate", name = "spectating",
          at = function() return OF.spectate end, yields = false },
        { key = "photo", name = "photo mode",
          at = function() return OF.camera end, yields = true },
        { key = "forge", name = "the forge",
          at = function() return OF.forge end, yields = true },
        { key = "gun", name = "the doorway gun",
          at = function() return OF.doorways end, yields = true },
        { key = "noclip", name = "noclip",
          at = function() return OF.cheats end, yields = true },
    }

    local function ask(row, what)
        local owner = row.at()
        if not util.asks(owner, what) then return nil end
        if type(owner[what]) ~= "function" then return nil end
        return owner[what]()
    end

    local function row_live(row)
        return ask(row, "mode_live") == true
    end

    local function row_for(key)
        for _, row in ipairs(MODES) do
            if row.key == key then return row end
        end
        return nil
    end

    local stack = {}

    local busy = false

    local function say(text)
        if not util.asks(OF.notify, "show") then return end
        OF.notify.show(text, "info", 4)
    end

    local function settle()
        if busy then return false end
        busy = true
        local handed = nil
        while #stack > 0 do
            local entry = stack[#stack]

            if row_live(entry.by) then break end
            table.remove(stack)
            if ask(entry.row, "mode_resume") == true then
                handed = entry.row.name
                break
            end

        end
        busy = false
        if handed ~= nil then say(OF.lang.fill("@ is back", handed)) end
        return handed ~= nil
    end

    function util.hands_on()
        for _, row in ipairs(MODES) do
            if row_live(row) then return row.key, row.name end
        end
        return nil
    end

    function util.enter_mode(key)
        local row = row_for(key)
        if row == nil then return true end
        if busy then return true end

        for _, other in ipairs(MODES) do
            if other.key ~= key and not other.yields and row_live(other) then

                return false, OF.lang.fill("Stop @ first.", other.name)
            end
        end

        busy = true

        for i = #stack, 1, -1 do
            if stack[i].row.key == key then table.remove(stack, i) end
        end

        local took = nil
        for _, other in ipairs(MODES) do
            if other.key ~= key and row_live(other) then
                if ask(other, "mode_suspend") == true then
                    table.insert(stack, { row = other, by = row })
                    took = other.name
                end
            end
        end
        busy = false

        if took ~= nil then
            say(OF.lang.fill("@ is off until you are done", took))
        end
        return true
    end

    function util.leave_mode(key)
        local row = row_for(key)
        if row == nil then return false end
        return settle()
    end

    function util.mode_notice(key)
        local row = row_for(key)
        if row == nil then return nil end
        if row_live(row) then return nil end
        for _, other in ipairs(MODES) do
            if other.key ~= key and row_live(other) then
                if other.yields then
                    return OF.lang.fill(
                        "@ is on - this puts it away and gives it back after",
                        other.name)
                end
                return OF.lang.fill("@ is on - stop that first", other.name)
            end
        end
        return nil
    end

    function util.forget_modes()
        stack = {}
        busy = false
    end

    function util.suspended_modes()
        local list = {}
        for _, entry in ipairs(stack) do table.insert(list, entry.row.key) end
        return list
    end

    hook_event(HOOK_UPDATE, function()
        settle()
    end)
end

util.FLY_PACES = { 6, 20, 50, 110 }
util.FLY_PACE_NAMES = { "crawl", "walk", "sweep", "rush" }
util.FLY_SPRINT = 3
util.FLY_LIFT = 34

util.flyPace = 2

function util.fly_pace_name()
    return util.FLY_PACE_NAMES[util.flyPace] or util.FLY_PACE_NAMES[2]
end

function util.step_fly_pace(delta)
    local count = #util.FLY_PACES
    util.flyPace = ((util.flyPace - 1 + (delta or 1)) % count) + 1
    return true
end

function util.fly_speed(down)
    local base = util.FLY_PACES[util.flyPace] or util.FLY_PACES[2]
    if util.has_flag(down, A_BUTTON) then base = base * util.FLY_SPRINT end
    return base
end

function util.fly_lift(down)
    if util.has_flag(down, Z_TRIG) then return 0 end
    local lift = util.FLY_LIFT
    if util.has_flag(down, A_BUTTON) then lift = lift * util.FLY_SPRINT end
    if util.has_flag(down, R_TRIG) then return lift end
    if util.has_flag(down, L_TRIG) then return -lift end
    return 0
end

function util.fly_mag(stickX, stickY)
    local raw = math.sqrt((stickX or 0) * (stickX or 0) + (stickY or 0) * (stickY or 0))
    return math.min(raw, 64) / 64, math.max(raw, 1)
end

util.COIN_KINDS = {
    { model = E_MODEL_YELLOW_COIN, worth = 1, weight = 82 },
    { model = E_MODEL_RED_COIN,    worth = 2, weight = 14 },
    { model = E_MODEL_BLUE_COIN,   worth = 5, weight = 4 },
}

local KIND_WEIGHT_TOTAL = 0
for _, kind in ipairs(util.COIN_KINDS) do
    KIND_WEIGHT_TOTAL = KIND_WEIGHT_TOTAL + kind.weight
end

util.COIN_EVERY = 45
util.COIN_BURST = 5
util.COIN_SPREAD = 900
util.COIN_HEIGHT = 700
util.COIN_LIVE_MAX = 40

util.COIN_WORTH_MAX = 50

function util.coin_worth(obj)
    if obj == nil then return 1 end
    local value = obj.oDamageOrCoinValue
    if type(value) ~= "number" or value < 1 then return 1 end
    return math.floor(util.clamp(value, 1, util.COIN_WORTH_MAX))
end

function util.coin_kind()
    local roll = math.random(KIND_WEIGHT_TOTAL)
    for _, kind in ipairs(util.COIN_KINDS) do
        if roll <= kind.weight then return kind end
        roll = roll - kind.weight
    end
    return util.COIN_KINDS[1]
end

local function claim_worth(coin, kind)
    if coin == nil then return end
    coin.oInteractType = INTERACT_COIN
    coin.oDamageOrCoinValue = kind.worth
    coin.oHealth = 0
    coin.oNumLootCoins = 0
    local flags = coin.oFlags or 0
    if not util.has_flag(flags, OBJ_FLAG_30) then
        coin.oFlags = flags + OBJ_FLAG_30
    end
end

util.claim_worth = claim_worth

util.COIN_POUCH_MAX = 120

local function rained_coin_behaviour()
    if not util.asks(OF.gamemodes, "option_is") then
        return id_bhvSingleCoinGetsSpawned
    end
    if OF.gamemodes.option_is("drop", "float") then return id_bhvYellowCoin end
    return id_bhvSingleCoinGetsSpawned
end

function util.coin_put(pouch, x, y, z, kind)
    if pouch == nil then return false end
    if #pouch >= util.COIN_POUCH_MAX then util.coin_live(pouch) end
    kind = kind or util.COIN_KINDS[1]
    local coin = OF.slots.spawn_sync(
        rained_coin_behaviour(), kind.model, x, y, z,
        function(o) claim_worth(o, kind) end)
    if coin == nil then return false end
    table.insert(pouch, coin)
    return true
end

function util.coin_live(pouch)
    if pouch == nil then return 0 end
    local kept = 0
    for index = 1, #pouch do
        local coin = pouch[index]
        pouch[index] = nil
        if util.alive(coin) and coin.activeFlags ~= 0 then
            kept = kept + 1
            pouch[kept] = coin
        end
    end
    return kept
end

function util.coin_sweep(pouch)
    if pouch == nil then return end
    for _, coin in ipairs(pouch) do
        if util.alive(coin) then coin.activeFlags = 0 end
    end
end

util.PACKET_RAIN = "gmrain"
util.leadPouch = {}

local function same_room(a, b)
    return a ~= nil and b ~= nil and a.currLevelNum == b.currLevelNum
        and a.currAreaIndex == b.currAreaIndex and a.currActNum == b.currActNum
end

function util.coin_rain_by_lead(playing, options)
    if not util.is_host() then return nil end
    local me = gNetworkPlayers[0]
    for _, entry in ipairs(playing) do
        if entry.localIndex == 0 or same_room(gNetworkPlayers[entry.localIndex], me) then
            return nil
        end
    end
    local lead = util.asks(OF.net, "round_lead") and OF.net.round_lead() or nil
    if lead == nil or lead == 0 then return nil end
    local leadNp = gNetworkPlayers[lead]
    local who = {}
    for _, entry in ipairs(playing) do
        local np = gNetworkPlayers[entry.localIndex]
        if np ~= nil and same_room(np, leadNp) then who[#who + 1] = np.globalIndex end
    end
    if #who == 0 then return 0 end
    options = options or {}
    local coins = math.floor(tonumber(options.coins) or util.COIN_BURST)
    if not util.send_to_player(lead, {
        ofp = util.PACKET_RAIN, g = table.concat(who, ","), n = coins,
        sp = options.spread, h = options.height, mx = options.max,
        pl = options.plain == true and 1 or nil,
    }) then
        return 0
    end
    return coins
end

function util.receive_rain(data)
    if type(data) ~= "table" or data.ofp ~= util.PACKET_RAIN then return 0 end
    if util.is_host() or not util.from_host(data) then return 0 end
    if not (util.asks(OF.net, "is_round_lead") and OF.net.is_round_lead(0)) then return 0 end
    local me = gNetworkPlayers[0]
    local playing = {}
    for piece in string.gmatch(tostring(data.g or ""), "[^,]+") do
        local li = util.local_from_global(tonumber(piece) or -1)
        if li ~= nil and same_room(gNetworkPlayers[li], me) then
            playing[#playing + 1] = { localIndex = li }
        end
    end
    if #playing == 0 then return 0 end

    local coins = math.max(1, math.min(math.floor(tonumber(data.n) or util.COIN_BURST),
        util.COIN_LIVE_MAX))
    return util.coin_rain(util.leadPouch, playing, {
        coins = coins, spread = tonumber(data.sp), height = tonumber(data.h),
        max = tonumber(data.mx), plain = data.pl ~= nil,
    })
end

function util.coin_lead_sweep()
    util.coin_sweep(util.leadPouch)
    util.leadPouch = {}
end

function util.coin_rain(pouch, playing, options)
    if pouch == nil or playing == nil or #playing == 0 then return 0 end
    options = options or {}

    local byLead = util.coin_rain_by_lead(playing, options)
    if byLead ~= nil then return byLead end

    local room = (options.max or util.COIN_LIVE_MAX) - util.coin_live(pouch)
    if room <= 0 then return 0 end

    local spread = options.spread or util.COIN_SPREAD
    local height = options.height or util.COIN_HEIGHT
    local yellowOnly = options.plain == true

    local fell = 0
    for _ = 1, math.min(options.coins or util.COIN_BURST, room) do
        local entry = playing[math.random(#playing)]
        local m = gMarioStates[entry.localIndex]
        if m ~= nil and m.pos ~= nil then
            local kind = util.COIN_KINDS[1]
            if not yellowOnly then kind = util.coin_kind() end

            kind = util.coin_maybe_black(kind)
            if util.coin_put(pouch,
                m.pos.x + math.random(-spread, spread),
                m.pos.y + height,
                m.pos.z + math.random(-spread, spread), kind) then
                fell = fell + 1
            end
        end
    end
    return fell
end

util.COIN_BLACK = { model = E_MODEL_BURN_SMOKE, worth = 1, weight = 0, black = true }
util.COIN_BLACK_ONE_IN = 10
util.COIN_BLACK_TAKES = 3

function util.is_black_coin(obj)
    if obj == nil or util.COIN_BLACK.model == nil then return false end
    return util.optional("obj_has_model_extended", 0, obj, util.COIN_BLACK.model) ~= 0
end

function util.coin_black_wanted()
    return util.asks(OF.gamemodes, "option_is") and OF.gamemodes.option_is("black", "on")
end

function util.coin_maybe_black(kind)
    if util.COIN_BLACK.model == nil or not util.coin_black_wanted() then return kind end
    if math.random(util.COIN_BLACK_ONE_IN) == 1 then return util.COIN_BLACK end
    return kind
end

util.FEVER_KEY = "ofCoinFever"
util.FEVER_CALM = 20 * 30
util.FEVER_LENGTH = 15 * 30

util.FEVER_FULL = 0x880

local feverCalm, feverLeft = 0, 0

local feverHeard = nil

function util.coin_fever_wanted()
    return util.asks(OF.gamemodes, "option_is") and OF.gamemodes.option_is("fever", "on")
end

function util.coin_fever_on()
    return gGlobalSyncTable[util.FEVER_KEY] == "1" and util.coin_fever_wanted()
end

function util.coin_all_full(playing)
    if playing == nil then return false end
    local counted = 0
    for _, entry in ipairs(playing) do

        if util.can_play(entry.localIndex) then
            local m = gMarioStates[entry.localIndex]
            if m == nil or (m.health or 0) < util.FEVER_FULL then return false end
            counted = counted + 1
        end
    end
    return counted > 0
end

function util.coin_fever_host(playing)
    if not util.is_host() then return util.coin_fever_on() end
    if not util.coin_fever_wanted() then
        if gGlobalSyncTable[util.FEVER_KEY] ~= nil then util.publish(util.FEVER_KEY, nil) end
        feverCalm, feverLeft = 0, 0
        return false
    end
    local full = util.coin_all_full(playing)
    if feverLeft > 0 then
        feverLeft = feverLeft - 1
        if not full or feverLeft <= 0 then
            feverLeft, feverCalm = 0, 0
            util.publish(util.FEVER_KEY, nil)
            return false
        end
        return true
    end
    if full then feverCalm = feverCalm + 1 else feverCalm = 0 end
    if feverCalm >= util.FEVER_CALM then
        feverCalm, feverLeft = 0, util.FEVER_LENGTH
        util.publish(util.FEVER_KEY, "1")
        return true
    end
    return false
end

function util.coin_fever_reset()
    feverCalm, feverLeft = 0, 0
    feverHeard = nil
    if util.is_host() and gGlobalSyncTable[util.FEVER_KEY] ~= nil then
        util.publish(util.FEVER_KEY, nil)
    end
end

function util.coin_fever_watch()
    local on = util.coin_fever_on()
    if feverHeard == nil then feverHeard = on return end
    if on == feverHeard then return end
    feverHeard = on
    if not util.asks(OF.notify, "show") then return end
    if on then
        OF.notify.show("Coin Fever - every coin counts double", "good", 4)
    else
        OF.notify.show("The Fever is over", "info", 3)
    end
end

util.STREAK_CAP = 4

function util.coin_streak_wanted()
    return util.asks(OF.gamemodes, "option_is") and OF.gamemodes.option_is("streak", "on")
end

function util.coin_score(obj, streak)
    local fever = util.coin_fever_on()
    if util.is_black_coin(obj) then
        if streak ~= nil then streak.kind, streak.award = nil, 0 end
        if fever then return util.COIN_BLACK_TAKES end
        return -util.COIN_BLACK_TAKES
    end
    local worth = util.coin_worth(obj)
    local award = worth
    if streak ~= nil and util.coin_streak_wanted() then
        if streak.kind == worth and (streak.award or 0) > 0 then
            award = math.min(streak.award * 2, worth * util.STREAK_CAP)
        end
        streak.kind, streak.award = worth, award
    end
    if fever then award = award * 2 end
    return award
end
