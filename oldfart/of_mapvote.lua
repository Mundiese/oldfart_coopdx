OF = OF or {}
OF.mapvote = OF.mapvote or {}

local mapvote = OF.mapvote

local CARD_KEY = "ofMvCard"
local LEFT_KEY = "ofMvLeft"
local WON_KEY = "ofMvWon"
local ROW_KEY = "ofMvPick"
mapvote.CARD_KEY = CARD_KEY
mapvote.LEFT_KEY = LEFT_KEY
mapvote.WON_KEY = WON_KEY
mapvote.ROW_KEY = ROW_KEY

local VOTE_SECONDS = 10

local SHOW_FRAMES = 135
local MOST = 3

local ROOM_Y = 15000
local FLOOR_Z = -600
local ALCOVE_Z = 500
local SILL = 220
local PAD_HALF_X = 255.5
local PAD_HALF_Z = 153.5
local PAD_TOP = 26
local FLOOR_SX = 5
local FLOOR_SZ = 6
local ALCOVE_SX = 1.5
local ALCOVE_SZ = 2
local POST_SX = 0.25
local POST_SY = 14
local POST_SZ = 0.5
local LINTEL_SX = 2

local VOTE_HALF_X = PAD_HALF_X * ALCOVE_SX
local VOTE_HALF_Z = PAD_HALF_Z * ALCOVE_SZ

local VOTE_UNDER = 60
local VOTE_OVER = 700

local CATCH_DROP = 400

local SLOTS = {
    [2] = { -700, 700 },
    [3] = { -1000, 0, 1000 },
}

local COLOURS = {
    { 255, 214, 102 },
    { 120, 214, 255 },
    { 255, 150, 190 },
}

local FRAME_SILL_Y = ROOM_Y + SILL
local PLATE_Y = ROOM_Y + SILL + 25 * POST_SY + 120

local PICTURE_MID_Y = (FRAME_SILL_Y + PLATE_Y) * 0.5

local PICTURE_HALF_WIDTH = VOTE_HALF_X * 0.85

mapvote.wantVote = mapvote.wantVote or {}

function mapvote.wanted(modeKey)
    if modeKey == nil then return false end
    return mapvote.wantVote[modeKey] == true
end

function mapvote.set_wanted(modeKey, on)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    if modeKey == nil then return false, "No such game mode." end
    if on == true then
        mapvote.wantVote[modeKey] = true
    else
        mapvote.wantVote[modeKey] = nil
    end
    return true
end

function mapvote.reset_options()
    local moved = next(mapvote.wantVote) ~= nil
    for key in pairs(mapvote.wantVote) do mapvote.wantVote[key] = nil end
    return moved
end

local function code_of(entry)
    if type(entry) ~= "table" then return nil end
    if entry.what == "arena" then
        if type(entry.value) ~= "string" or entry.value == "" then return nil end
        return "a" .. entry.value
    end
    local place = entry.value
    if type(place) ~= "table" or place.level == nil then return nil end

    local track = tonumber(place.track or entry.track)
    return "l" .. tostring(place.level) .. "."
        .. tostring(place.area or entry.area or 1)
        .. (track ~= nil and ("." .. tostring(track)) or "")
end

mapvote.code_of = code_of

function mapvote.places_of(modeKey)
    local mode = modeKey ~= nil and OF.gamemodes ~= nil and OF.gamemodes.BY_KEY ~= nil
        and OF.gamemodes.BY_KEY[modeKey] or nil
    if mode ~= nil and type(mode.votePlaces) == "function" then
        local ok, list = pcall(mode.votePlaces)
        return (ok and type(list) == "table") and list or {}
    end
    if not OF.util.asks(OF.gamemodes, "offered_places") then return {} end
    return OF.gamemodes.offered_places(modeKey)
end

function mapvote.entry_of(modeKey, code)
    if modeKey == nil or type(code) ~= "string" then return nil end
    for _, entry in ipairs(mapvote.places_of(modeKey)) do
        if code_of(entry) == code then return entry end
    end

    local level, area = code:match("^l(%-?%d+)%.(%d+)$")
    level, area = tonumber(level), tonumber(area)
    if level ~= nil and area ~= nil and OF.util.asks(OF.util, "level_name") then
        local name = OF.util.level_name(level, area)
        return { what = "level", level = level, area = area,
                 value = { level = level, area = area, act = 1, name = name } }
    end
    return nil
end

local labelFor = {}
local labelCard = nil

function mapvote.label_of(modeKey, code)
    if labelCard ~= cardRaw then
        labelCard = cardRaw
        labelFor = {}
    end
    local memo = labelFor[code]
    if memo ~= nil then return memo end
    local answer = mapvote.read_label(modeKey, code)
    labelFor[code] = answer
    return answer
end

function mapvote.read_label(modeKey, code)
    local entry = mapvote.entry_of(modeKey, code)
    if entry ~= nil then
        if entry.what == "arena" then
            if OF.util.asks(OF.arena, "name_of") then
                local name = OF.arena.name_of(entry.value)
                if type(name) == "string" and name ~= "" then return name end
            end
            return tostring(entry.value)
        end
        local place = entry.value
        if type(place) == "table" and type(place.name) == "string"
            and place.name ~= "" then
            return place.name
        end
    end

    return OF.lang.t("A level this machine has not got")
end

function mapvote.read_card(text)
    if type(text) ~= "string" or text == "" then return nil end
    local parts = {}
    for piece in string.gmatch(text, "[^;]+") do
        table.insert(parts, piece)
    end
    if #parts < 4 then return nil end
    local card = { stamp = parts[1], mode = parts[2], codes = {} }
    for index = 3, #parts do table.insert(card.codes, parts[index]) end
    if #card.codes < 2 or #card.codes > MOST then return nil end
    return card
end

local cardRaw = nil
local cardParsed = nil

function mapvote.card()
    local text = gGlobalSyncTable[CARD_KEY]
    if type(text) ~= "string" then text = "" end
    if text ~= cardRaw then
        cardRaw = text
        cardParsed = mapvote.read_card(text)
    end
    return cardParsed
end

function mapvote.running()
    return mapvote.card() ~= nil
end

local askingAside = false
function mapvote.owns_pad()
    return not askingAside and not mapvote.ROOM and mapvote.card() ~= nil
end

local function aside(fn, ...)
    askingAside = true
    local ok, a, b = pcall(fn, ...)
    askingAside = false
    if not ok then error(a, 0) end
    return a, b
end

function mapvote.covered()
    return aside(function() return OF.util.menu_has_screen() end) == true
end

function mapvote.reads_pad()
    return mapvote.owns_pad() and not mapvote.covered()
end

function mapvote.draw_candidates(modeKey)
    local pool = {}
    local seen = {}
    for _, entry in ipairs(mapvote.places_of(modeKey)) do
        local code = code_of(entry)
        if code ~= nil and not seen[code] then
            seen[code] = true
            table.insert(pool, code)
        end
    end
    if #pool < 2 then return nil end

    local fresh = {}
    for _, code in ipairs(pool) do
        if not mapvote.played_lately(code) then table.insert(fresh, code) end
    end
    if #fresh >= 2 then pool = fresh end
    for index = #pool, 2, -1 do
        local other = math.random(index)
        pool[index], pool[other] = pool[other], pool[index]
    end
    local out = {}
    for index = 1, math.min(MOST, #pool) do
        table.insert(out, pool[index])
    end
    return out
end

function mapvote.slot_x(count, index)
    local row = SLOTS[count]
    if row == nil then return nil end
    return row[index]
end

function mapvote.slot_of(x, y, z, count)
    if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
        return 0
    end
    for index = 1, count do
        local at = mapvote.slot_x(count, index)
        if at ~= nil
            and math.abs(x - at) <= VOTE_HALF_X
            and math.abs(z - ALCOVE_Z) <= VOTE_HALF_Z
            and y >= mapvote.floor_top() + mapvote.sill() - VOTE_UNDER
            and y <= mapvote.floor_top() + mapvote.sill() + VOTE_OVER then
            return index
        end
    end
    return 0
end

function mapvote.seat_at(globalIndex)
    local g = globalIndex
    if type(g) ~= "number" or g < 0 or g > 15 then g = 0 end
    local x = -900 + (g % 8) * 257
    local z = -900 + math.floor(g / 8) * 260
    return x, ROOM_Y + 30, z
end

local myRoom = nil
local myStamp = nil

local function tear_down()
    if myRoom ~= nil then
        for index, obj in pairs(myRoom) do
            if OF.util.alive(obj) then
                OF.util.optional("obj_mark_for_deletion", nil, obj)
            end
            myRoom[index] = nil
        end
    end
    myRoom = nil
    myStamp = nil
end

mapvote.tear_down = tear_down

local function slab(x, y, z, sx, sy, sz)
    return OF.util.optional("spawn_non_sync_object", nil,
        id_bhvStaticCheckeredPlatform, E_MODEL_CHECKERBOARD_PLATFORM,
        x, y, z, function(o)
            OF.util.optional("obj_scale_xyz", nil, o, sx, sy, sz)
            o.oFaceAngleYaw = 0
            o.oFaceAnglePitch = 0
            o.oFaceAngleRoll = 0
        end)
end

function mapvote.room_plan(count)
    local plan = {}

    table.insert(plan, { what = "floor",
        x = 0, y = ROOM_Y - PAD_TOP, z = FLOOR_Z,
        sx = FLOOR_SX, sy = 1, sz = FLOOR_SZ })
    local frontZ = ALCOVE_Z - VOTE_HALF_Z
    local postOut = VOTE_HALF_X + PAD_HALF_X * POST_SX
    local postMid = ROOM_Y + SILL + 25 * POST_SY
    for index = 1, count do
        local at = mapvote.slot_x(count, index)
        if at ~= nil then
            table.insert(plan, { what = "alcove",
                x = at, y = ROOM_Y + SILL - PAD_TOP, z = ALCOVE_Z,
                sx = ALCOVE_SX, sy = 1, sz = ALCOVE_SZ })
            table.insert(plan, { what = "post",
                x = at - postOut, y = postMid, z = frontZ,
                sx = POST_SX, sy = POST_SY, sz = POST_SZ })
            table.insert(plan, { what = "post",
                x = at + postOut, y = postMid, z = frontZ,
                sx = POST_SX, sy = POST_SY, sz = POST_SZ })
            table.insert(plan, { what = "lintel",
                x = at, y = postMid + 26 * POST_SY + 25, z = frontZ,
                sx = LINTEL_SX, sy = 1, sz = POST_SZ })
        end
    end
    return plan
end

function mapvote.top_of(piece)
    if type(piece) ~= "table" then return nil end
    return piece.y + PAD_TOP * (piece.sy or 1)
end

function mapvote.floor_top() return ROOM_Y end
function mapvote.sill() return SILL end
function mapvote.ceiling_lid() return 20000 end

function mapvote.plan_fits(plan)
    for _, piece in ipairs(plan) do
        local top = mapvote.top_of(piece)
        if top == nil or top >= mapvote.ceiling_lid() then return false end
    end
    return true
end

local function build_room(card)
    myStamp = card.stamp
    myRoom = {}
    local plan = mapvote.room_plan(#card.codes)
    if not mapvote.plan_fits(plan) then return false end
    for _, piece in ipairs(plan) do
        table.insert(myRoom,
            slab(piece.x, piece.y, piece.z, piece.sx, piece.sy, piece.sz))
    end
    return true
end

local held = false
local wasX, wasY, wasZ = nil, nil, nil
local wasLevel, wasArea = nil, nil
local myPick = 0

local function my_global()
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if np == nil then return 0 end
    local g = np.globalIndex
    if type(g) ~= "number" or g < 0 or g > 15 then return 0 end
    return g
end

local function lift_me()
    local x, y, z = mapvote.seat_at(my_global())
    if OF.util.asks(OF.net, "snap_to") then

        OF.net.snap_to(x, y, z, 0)
    else
        OF.util.place_player(0, x, y, z)
    end
end

local function remember_where()
    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if m == nil or m.pos == nil then return false end
    wasX, wasY, wasZ = m.pos.x, m.pos.y, m.pos.z
    wasLevel = np ~= nil and np.currLevelNum or nil
    wasArea = np ~= nil and np.currAreaIndex or nil
    return true
end

local function put_me_back()
    if wasX == nil then return false end
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if np ~= nil and wasLevel ~= nil
        and (np.currLevelNum ~= wasLevel or np.currAreaIndex ~= wasArea) then
        return false
    end
    if OF.util.asks(OF.net, "snap_to") then
        OF.net.snap_to(wasX, wasY, wasZ, nil)
    else
        OF.util.place_player(0, wasX, wasY, wasZ)
    end
    return true
end

local function say_my_pick(value)
    if value == myPick then return false end
    myPick = value
    return OF.util.publish_row(0, ROW_KEY, value)
end

function mapvote.my_pick()
    return myPick
end

function mapvote.tally(card)
    local counts = {}
    for index = 1, #card.codes do counts[index] = 0 end
    if not OF.util.asks(OF.gamemodes, "participants") then return counts end
    for _, entry in ipairs(OF.gamemodes.participants()) do
        local row = gPlayerSyncTable ~= nil
            and gPlayerSyncTable[entry.localIndex] or nil
        local pick = row ~= nil and row[ROW_KEY] or 0
        if type(pick) == "number" and counts[pick] ~= nil then
            counts[pick] = counts[pick] + 1
        end
    end
    return counts
end

function mapvote.winner(card, counts)
    local best = -1
    for index = 1, #card.codes do
        local at = counts[index] or 0
        if at > best then best = at end
    end
    local tied = {}
    for index = 1, #card.codes do
        if (counts[index] or 0) == best then table.insert(tied, index) end
    end
    return tied[math.random(#tied)], tied
end

mapvote.LATELY = 2
mapvote.lately = {}

function mapvote.played_lately(code)
    for _, seen in ipairs(mapvote.lately) do
        if seen == code then return true end
    end
    return false
end

function mapvote.remember(code)
    if code == nil then return end
    local kept = { code }
    for _, seen in ipairs(mapvote.lately) do
        if seen ~= code and #kept < mapvote.LATELY then table.insert(kept, seen) end
    end
    mapvote.lately = kept
end

function mapvote.apply(modeKey, code)
    local entry = mapvote.entry_of(modeKey, code)
    if entry == nil then return false end
    mapvote.remember(code)

    if type(entry.option) == "string" and entry.choice ~= nil then
        if not OF.util.asks(OF.gamemodes, "set_option") then return false end
        return OF.gamemodes.set_option(modeKey, entry.option, entry.choice) == true
    end
    if not OF.util.asks(OF.gamemodes, "set_level") then return false end
    if entry.what == "arena" then
        OF.gamemodes.set_level(nil)
        OF.gamemodes.arenaChoice = entry.value
        return true
    end
    local place = entry.value
    return OF.gamemodes.set_level({
        level = place.level,
        area = place.area or entry.area or 1,
        act = place.act or 1,
        name = place.name,
        track = place.track or entry.track,
    }) == true
end

local deadline = nil
local showUntil = nil
local waitingKey = nil
local waitingOptions = nil

local function now_frames()
    return OF.util.optional("get_global_timer", 0) or 0
end

function mapvote.close()
    OF.util.publish(CARD_KEY, nil)
    OF.util.publish(LEFT_KEY, nil)
    OF.util.publish(WON_KEY, nil)
    deadline = nil
    showUntil = nil
    waitingKey = nil
    waitingOptions = nil
end

function mapvote.takes_over(modeKey, options)
    if not OF.util.is_host() then return false end
    if type(options) == "table" and options.voted == true then return false end
    if not mapvote.wanted(modeKey) then return false end
    if mapvote.running() then return false end

    local codes = mapvote.draw_candidates(modeKey)
    if codes == nil or #codes < 2 then return false end

    local stamp = math.floor(now_frames() % 100000000)
    local parts = { tostring(stamp), tostring(modeKey) }
    for _, code in ipairs(codes) do table.insert(parts, code) end

    OF.util.publish(WON_KEY, nil)
    OF.util.publish(LEFT_KEY, VOTE_SECONDS)
    OF.util.publish(CARD_KEY, table.concat(parts, ";"))
    deadline = now_frames() + VOTE_SECONDS * 30
    showUntil = nil
    waitingKey = modeKey
    waitingOptions = options
    return true
end

function mapvote.host_step()
    if not OF.util.is_host() then return end
    local card = mapvote.card()
    if card == nil then return end

    local roundOn = OF.util.asks(OF.gamemodes, "state")
        and OF.gamemodes.state() ~= OF.gamemodes.OFF

    if deadline == nil or roundOn then
        mapvote.close()
        return
    end

    local at = now_frames()

    local left = math.ceil((deadline - at) / 30)
    if left < 0 then left = 0 end
    OF.util.publish(LEFT_KEY, left)
    if left > 0 then return end

    local won = gGlobalSyncTable[WON_KEY]
    if type(won) ~= "string" or won == "" then
        local index = mapvote.winner(card, mapvote.tally(card))
        OF.util.publish(WON_KEY, card.codes[index])
        showUntil = at + SHOW_FRAMES
        return
    end

    if showUntil == nil or at < showUntil then return end

    local modeKey = waitingKey
    local options = waitingOptions or {}
    mapvote.close()
    if modeKey == nil then return end
    mapvote.apply(modeKey, won)
    options.voted = true
    if OF.util.asks(OF.gamemodes, "start") then
        OF.gamemodes.start(modeKey, options)
    end
end

function mapvote.local_step()

    if not mapvote.ROOM then
        if mapvote.card() == nil then
            if held then
                held = false
                say_my_pick(0)
                if OF.input ~= nil and type(OF.input.hold_mouse) == "function" then
                    OF.input.hold_mouse(mapvote.HOLDER, false)
                end
            end
        else
            held = true
        end
        return
    end
    local card = mapvote.card()
    if card == nil then
        if myRoom ~= nil then tear_down() end
        if held then
            held = false

            local off = not OF.util.asks(OF.gamemodes, "state")
                or OF.gamemodes.state() == OF.gamemodes.OFF
            if off then put_me_back() end
            wasX, wasY, wasZ = nil, nil, nil
            wasLevel, wasArea = nil, nil
            say_my_pick(0)
        end
        return
    end

    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if held and wasLevel ~= nil and np ~= nil
        and (np.currLevelNum ~= wasLevel or np.currAreaIndex ~= wasArea) then
        if myRoom ~= nil then tear_down() end
        say_my_pick(0)
        return
    end

    if myStamp ~= card.stamp then
        tear_down()
        build_room(card)
    end

    if myRoom == nil or #myRoom == 0 then return end

    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    if m == nil or m.pos == nil then return end

    if not held then

        held = true
        remember_where()
        lift_me()
        return
    end
    if m.pos.y < ROOM_Y - CATCH_DROP then

        lift_me()
        return
    end

    say_my_pick(mapvote.slot_of(m.pos.x, m.pos.y, m.pos.z, #card.codes))
end

mapvote.ROOM = false
mapvote.TIE_FRAMES = 60
mapvote.REVEAL_FRAMES = 75
mapvote.HOLDER = "mapvote"
mapvote.STICK_LEAN = 40
mapvote.STICK_FIRST = 10
mapvote.STICK_REPEAT = 6

local cursor = 1
local stickHeld = 0

local upSeen = { stamp = nil, a = false, click = false }
function mapvote.armed_for(card, aDown, clickDown)
    if card == nil then return false, false end
    if upSeen.stamp ~= card.stamp then
        upSeen = { stamp = card.stamp, a = false, click = false }
    end
    if not aDown then upSeen.a = true end
    if not clickDown then upSeen.click = true end
    return upSeen.a, upSeen.click
end
local shown = { stamp = nil, since = 0, wonAt = nil, tied = nil, winner = nil }
local cardRects = nil

function mapvote.cursor() return cursor end

function mapvote.move(step)
    local card = mapvote.card()
    if card == nil then return cursor end
    local count = #card.codes
    cursor = ((cursor - 1 + step) % count) + 1

    OF.sounds.ui("move", OF.hud.sound_of("move"))
    return cursor
end

function mapvote.choose(index)
    local card = mapvote.card()
    if card == nil then return false end
    local won = gGlobalSyncTable[WON_KEY]
    if type(won) == "string" and won ~= "" then return false end
    if type(index) ~= "number" or index < 0 or index > #card.codes then return false end
    if index > 0 then cursor = index end
    if say_my_pick(index) ~= false and index > 0 then OF.sounds.ui("select", OF.hud.sound_of("vote")) end
    return true
end

function mapvote.before_mario(m)
    if m == nil or m.playerIndex ~= 0 or mapvote.ROOM then return false end
    local card = mapvote.card()
    if card == nil then
        stickHeld = 0
        return false
    end
    if mapvote.covered() then return false end
    local c = m.controller
    if c == nil then return false end

    local x = c.stickX or 0
    if OF.util.asks(OF.input, "menu_stick") then x = OF.input.menu_stick(m) end
    local down = c.buttonDown or 0
    if R_JPAD ~= nil and OF.util.has_flag(down, R_JPAD) then x = 127
    elseif L_JPAD ~= nil and OF.util.has_flag(down, L_JPAD) then x = -127 end
    if math.abs(x) >= mapvote.STICK_LEAN then
        stickHeld = stickHeld + 1
        if stickHeld == 1 or (stickHeld > mapvote.STICK_FIRST
            and (stickHeld - mapvote.STICK_FIRST) % mapvote.STICK_REPEAT == 0) then
            mapvote.move(x > 0 and 1 or -1)
        end
    else
        stickHeld = 0
    end
    local pressed = c.buttonPressed or 0
    local input0 = OF.input
    local clickDown = input0 ~= nil and type(input0.mouse_held) == "function"
        and input0.mouse_held(L_MOUSE_BUTTON) == true
    local aArmed, clickArmed = mapvote.armed_for(card,
        OF.util.has_flag(c.buttonDown or 0, A_BUTTON), clickDown)
    if aArmed and OF.util.has_flag(pressed, A_BUTTON) then mapvote.choose(cursor) end

    local input = OF.input
    if input ~= nil and type(input.device) == "function" and input.device() == "mouse"
        and cardRects ~= nil and djui_hud_get_mouse_x ~= nil then
        if type(input.hold_mouse) == "function" then input.hold_mouse(mapvote.HOLDER, true) end
        local mx, my = djui_hud_get_mouse_x(), djui_hud_get_mouse_y()
        for i, r in ipairs(cardRects) do
            if mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then
                cursor = i
                if clickArmed and type(input.mouse_pressed) == "function"
                    and input.mouse_pressed(L_MOUSE_BUTTON) then
                    mapvote.choose(i)
                end
            end
        end
    end

    local start = OF.util.has_flag(c.buttonDown or 0, START_BUTTON) and START_BUTTON or 0
    local startPressed = OF.util.has_flag(pressed, START_BUTTON) and START_BUTTON or 0
    c.buttonDown, c.buttonPressed = start, startPressed
    c.stickX, c.stickY, c.stickMag = 0, 0, 0
    return true
end

function mapvote.phase(card, counts, now)
    now = now or OF.hud.now()
    if shown.stamp ~= card.stamp then
        shown = { stamp = card.stamp, since = now, wonAt = nil, tied = nil, winner = nil }
        cursor = 1
    end
    local won = gGlobalSyncTable[WON_KEY]
    if type(won) ~= "string" or won == "" then return "vote", nil, 0 end
    if shown.wonAt == nil then
        shown.wonAt = now
        local winner = nil
        for i, code in ipairs(card.codes) do if code == won then winner = i end end
        local best = -1
        for i = 1, #card.codes do best = math.max(best, counts[i] or 0) end
        local tied = {}
        for i = 1, #card.codes do
            if (counts[i] or 0) == best then table.insert(tied, i) end
        end
        local inside = false
        for _, i in ipairs(tied) do if i == winner then inside = true end end
        if not inside then tied = { winner } end
        shown.winner, shown.tied = winner, tied
    end
    local age = now - shown.wonAt
    if #shown.tied > 1 and age < mapvote.TIE_FRAMES then
        local light = OF.hud.roulette(shown.tied, shown.winner, age, mapvote.TIE_FRAMES)

        if light ~= shown.light then
            shown.light = light
            OF.hud.cue("roulette")
        end
        return "tie", light, age
    end
    OF.hud.cue_once("vote-reveal" .. tostring(card.stamp), "reveal")
    local start = #shown.tied > 1 and mapvote.TIE_FRAMES or 0
    return "reveal", shown.winner, age - start
end

function mapvote.cards_for(card, counts)
    local cards = {}
    local tones = {}
    local sides = OF.util.asks(OF.teams, "in_play") and OF.teams.in_play()
    for i = 1, #card.codes do cards[i] = { voters = {} } end
    if OF.util.asks(OF.gamemodes, "participants") then
        for _, entry in ipairs(OF.gamemodes.participants()) do
            local row = gPlayerSyncTable ~= nil and gPlayerSyncTable[entry.localIndex] or nil
            local pick = row ~= nil and row[ROW_KEY] or 0
            if type(pick) == "number" and cards[pick] ~= nil then
                local tone = OF.hud.C.ink2
                if entry.localIndex == 0 then tone = "gold"
                elseif sides then
                    local team = OF.teams.find(OF.teams.of(entry.localIndex))
                    if team ~= nil then tone = { team.r, team.g, team.b } end
                end
                table.insert(cards[pick].voters, tone)
            end
        end
    end
    for i, code in ipairs(card.codes) do
        local colour = COLOURS[i] or COLOURS[1]
        local level, area = mapvote.place_of(code)
        cards[i].name = mapvote.label_of(card.mode, code)
        cards[i].tags = mapvote.hazards_of(code) or ""
        cards[i].tone = { colour[1], colour[2], colour[3] }
        cards[i].level, cards[i].area = level, area
        tones[i] = cards[i].tone
    end
    return cards
end

local function render_cards(card)
    local H = OF.hud
    local counts = mapvote.tally(card)
    local now = H.now()
    local phase, light, phaseAge = mapvote.phase(card, counts, now)
    local cards = mapvote.cards_for(card, counts)
    local tied = shown.tied or {}
    for _, i in ipairs(tied) do if cards[i] ~= nil then cards[i].tied = true end end
    local mode = OF.gamemodes ~= nil and OF.gamemodes.BY_KEY ~= nil
        and OF.gamemodes.BY_KEY[card.mode] or nil
    local title = OF.lang.t("Vote for the map")
    if mode ~= nil then title = title .. " - " .. OF.lang.t(mode.name) end
    local secs = gGlobalSyncTable[LEFT_KEY]
    local mine = mapvote.my_pick()
    cardRects = H.map_cards(cards, {
        selected = cursor, mine = (mine ~= nil and mine > 0) and mine or nil,
        secs = type(secs) == "number" and secs or nil,
        title = string.upper(title), phase = phase,
        highlight = phase == "tie" and light or nil,
        winner = phase == "reveal" and light or shown.winner,
        phaseAge = phaseAge,
    }, now - shown.since)
    if phase == "vote" then
        H.hints({ { "move", OF.lang.t("choose") }, { "jump", OF.lang.t("vote") } })
    end
    return cardRects
end
mapvote.render_cards = render_cards

local function update()
    mapvote.local_step()
    mapvote.host_step()
end

local worldAt = { x = 0, y = 0, z = 0 }
local screenAt = { x = 0, y = 0, z = 0 }

local function project(x, y, z)
    if not OF.util.asks(OF.util, "world_screen") then return nil end
    worldAt.x, worldAt.y, worldAt.z = x, y, z
    if not OF.util.world_screen(worldAt, screenAt) then return nil end
    return screenAt.x, screenAt.y
end

local function strip_for(card, counts)
    local segments = {}
    local plain = ""
    for index = 1, #card.codes do
        if index > 1 then
            table.insert(segments, { text = "   ", r = 255, g = 255, b = 255 })
            plain = plain .. "   "
        end
        local colour = COLOURS[index] or COLOURS[1]
        local text = OF.lang.fill("@ @",
            mapvote.label_of(card.mode, card.codes[index]),
            tostring(counts[index] or 0))
        table.insert(segments,
            { text = text, r = colour[1], g = colour[2], b = colour[3] })
        plain = plain .. text
    end
    return plain, segments
end

local function under_for(card)
    local won = gGlobalSyncTable[WON_KEY]
    if type(won) == "string" and won ~= "" then
        return OF.lang.fill("The lobby picked @",
            mapvote.label_of(card.mode, won))
    end
    local seconds = gGlobalSyncTable[LEFT_KEY]
    if type(seconds) ~= "number" then seconds = 0 end
    local mine = mapvote.my_pick()
    if mine >= 1 and mine <= #card.codes then
        return OF.lang.fill("@ seconds - you are inside @", tostring(seconds),
            mapvote.label_of(card.mode, card.codes[mine]))
    end
    return OF.lang.fill("@ seconds - jump into a painting to choose",
        tostring(seconds))
end

function mapvote.hazards_of(code)
    if type(code) ~= "string" then return nil end
    local level, area = code:match("^l(%-?%d+)%.(%d+)$")
    level, area = tonumber(level), tonumber(area)
    if level == nil or not OF.util.asks(OF.util, "level_hazard_line") then
        return nil
    end
    return OF.util.level_hazard_line(level, area)
end

function mapvote.place_of(code)
    if type(code) ~= "string" then return nil, nil end
    local level, area = code:match("^l(%-?%d+)%.(%d+)$")
    if level == nil then level, area = code:match("^l(%-?%d+)%.(%d+)%.%d+$") end
    if level ~= nil then
        level, area = tonumber(level), tonumber(area)
    else
        local key = code:match("^a(.+)$")
        if key == nil or not OF.util.asks(OF.arena, "find") then
            return nil, nil
        end
        local place = OF.arena.find(key)
        if place == nil or place.level == nil then return nil, nil end
        level, area = place.level, place.area or 1
    end
    if not OF.util.asks(OF.util, "has_painting_for_place")
        or not OF.util.has_painting_for_place(level, area) then
        return nil, nil
    end
    return level, area
end

local function draw_frame_picture(at, level, area)
    local leftX, leftY = project(at - PICTURE_HALF_WIDTH, PICTURE_MID_Y,
        ALCOVE_Z - VOTE_HALF_Z)
    local rightX, rightY = project(at + PICTURE_HALF_WIDTH, PICTURE_MID_Y,
        ALCOVE_Z - VOTE_HALF_Z)
    if leftX == nil or rightX == nil then return end
    local scale = math.abs(rightX - leftX) / OF.util.PAINTING_WIDTH
    if scale <= 0 then return end
    local pixels = OF.util.PAINTING_WIDTH * scale
    OF.util.painting_for_place(level, area, (leftX + rightX) * 0.5 - pixels * 0.5,
        (leftY + rightY) * 0.5 - pixels * 0.5, scale, 255)
end

local STRIP_ICON_GAP = 4

local function draw_strip_pictures(card, plain, segments, x, topW, topH, y)
    if type(topW) ~= "number" or topW <= 0 then return end
    local face = OF.util.hud_face(plain)
    local wantAt = OF.util.hud_scale(face, 0.9)
    local unfitted = OF.util.in_font(face, function()
        return OF.util.segments_width(segments, wantAt)
    end)
    if type(unfitted) ~= "number" or unfitted <= 0 then return end
    local ratio = topW / unfitted
    local size = topH
    OF.util.in_font(face, function()
        local cursor = x
        for segIndex, seg in ipairs(segments) do
            local width = OF.util.drawn_width(seg.text, wantAt) * ratio
            if segIndex % 2 == 1 then
                local candidate = (segIndex + 1) / 2
                local level, area = mapvote.place_of(card.codes[candidate])
                if level ~= nil and type(size) == "number" and size > 0 then
                    OF.util.painting_for_place(level, area,
                        cursor - size - STRIP_ICON_GAP, y,
                        size / OF.util.PAINTING_WIDTH, 255)
                end
            end
            cursor = cursor + width
        end
    end)
end

local function render()

    if mapvote.covered() then return end
    local card = mapvote.card()
    if card == nil then return end
    if not mapvote.ROOM then
        aside(render_cards, card)
        return
    end
    local counts = mapvote.tally(card)
    local count = #card.codes

    for index = 1, count do
        local at = mapvote.slot_x(count, index)
        if at ~= nil then

            local level, area = mapvote.place_of(card.codes[index])
            if level ~= nil then
                draw_frame_picture(at, level, area)
            end
            local sx, sy = project(at, ROOM_Y + SILL + 25 * POST_SY + 120,
                ALCOVE_Z - VOTE_HALF_Z)
            if sx ~= nil then
                local colour = COLOURS[index] or COLOURS[1]
                OF.util.world_label(sx, sy,
                    mapvote.label_of(card.mode, card.codes[index]), 0.7,
                    colour[1], colour[2], colour[3], 255)
                local hazards = mapvote.hazards_of(card.codes[index])
                if hazards ~= nil then
                    OF.util.world_label(sx, sy + 24, hazards, 0.5,
                        200, 200, 200, 230)
                end
            end
        end
    end

    local plain, segments = strip_for(card, counts)
    local stripY, stripX, stripW, stripH = OF.util.banner_low(plain, 0.9,
        255, 255, 255, 255, {
            segments = segments,
            under = { { text = under_for(card), scale = 0.7 } },
        })
    draw_strip_pictures(card, plain, segments, stripX, stripW, stripH, stripY)
end

hook_event(HOOK_UPDATE, update)
hook_event(HOOK_ON_HUD_RENDER, render)
hook_event(HOOK_BEFORE_MARIO_UPDATE, mapvote.before_mario, OF.LOCAL_MARIO)
