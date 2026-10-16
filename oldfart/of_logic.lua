OF = OF or {}
OF.logic = OF.logic or {}

local logic = OF.logic

logic.TARGET, logic.BUTTON, logic.ZONE = 1, 2, 3
logic.KIND_NAMES = { [1] = "target", [2] = "button", [3] = "zone" }

logic.KEYS = { lgtarget = 1, lgbutton = 2, lgzone = 3 }
logic.MAX_LINK = 31
logic.MAX_WIRES = 24
logic.STATE_KEY = "ofLogic"
logic.WIRES_KEY = "ofWires"
logic.WIRES_KEYS = { "ofWires", "ofWires2", "ofWires3", "ofWires4",
                     "ofWires5", "ofWires6", "ofWires7", "ofWires8" }
logic.ACTION = "logic"
logic.ZONE_RADIUS = 300
logic.ZONE_HEIGHT = 400

logic.HIT_REACH = 170
logic.SHOT_WIDTH = 90

logic.TARGET_MIDDLE = 120

logic.RESET_FRAMES = 90

logic.PENDING_FRAMES = 45

logic.RESULT_FRAMES = 30 * 12
logic.FPS = 30

logic.MAX_DOWN = 28

logic.EVENTS = { "pressed", "entered", "left", "hit", "alldown", "timer" }
logic.ACTIONS = { "raise", "start", "flip", "timer_start", "timer_stop", "message", "finish" }

local EVENT_CODE = { pressed = "p", entered = "e", left = "l", hit = "h", alldown = "a", timer = "t" }
local ACTION_CODE = { raise = "r", start = "s", flip = "o", timer_start = "b", timer_stop = "x",
    message = "m", finish = "f" }
local CODE_EVENT, CODE_ACTION = {}, {}
for k, v in pairs(EVENT_CODE) do CODE_EVENT[v] = k end
for k, v in pairs(ACTION_CODE) do CODE_ACTION[v] = k end

logic.ACTION_NUMBERED = { raise = true, start = true }

logic.MESSAGES = { "Go!", "The door is open", "Halfway there", "Well done", "Time is up" }

function logic.kind(o)
    if o == nil then return 0 end
    local kind = math.floor(tonumber(o.oBehParams2ndByte) or 0)
    if logic.KIND_NAMES[kind] == nil then return 0 end
    return kind
end

function logic.link(o)
    if o == nil then return 0 end
    local params = math.floor(tonumber(o.oBehParams) or 0)
    return (params >> 24) & 0xFF
end

function logic.params(kind, link)
    link = math.max(0, math.min(logic.MAX_LINK, math.floor(tonumber(link) or 1)))
    return ((link & 0xFF) << 24) + ((math.floor(kind) & 0xFF) << 16)
end

function logic.find(key)
    local kind = logic.KEYS[key]
    if kind == nil or OF.spawner == nil or OF.spawner.LOGIC == nil then return nil end
    local models = { [1] = E_MODEL_WOODEN_SIGNPOST, [2] = E_MODEL_PURPLE_SWITCH, [3] = E_MODEL_NONE }
    return { key = key, name = "Logic", bhv = OF.spawner.LOGIC, model = models[kind],
             reach = 20000, params = logic.params(kind, 1), logic = true }
end

logic.forgeLink = 1

function logic.setup(o)
    if o == nil then return end
    local params = math.floor(tonumber(o.oBehParams) or 0) & 0xFFFFFF
    o.oBehParams = params + ((logic.forgeLink & 0xFF) << 24)
end

local function index_of(list, word)
    for i, w in ipairs(list) do if w == word then return i end end
    return nil
end

function logic.wire(on, src, act, dst, arg)
    if type(on) == "table" then
        on, src, act, dst, arg = on.on or on[1], on.src or on[2], on.act or on[3],
            on.dst or on[4], on.arg or on[5]
    end
    if index_of(logic.EVENTS, on) == nil or index_of(logic.ACTIONS, act) == nil then return nil end
    local limit = on == "timer" and 3600 or logic.MAX_LINK
    src = math.floor(tonumber(src) or 0)
    dst = math.floor(tonumber(dst) or 0)
    if src < 0 or src > limit or dst < 0 or dst > logic.MAX_LINK then return nil end
    if type(arg) == "string" then
        arg = arg:gsub("[;|]", " "):sub(1, 60)
        if arg == "" then arg = nil end
    elseif arg ~= nil then
        arg = tostring(math.floor(tonumber(arg) or 0))
    end
    return { on = on, src = src, act = act, dst = dst, arg = arg }
end

function logic.message_text(arg)
    local n = tonumber(arg)
    if n ~= nil and logic.MESSAGES[n] ~= nil then return logic.MESSAGES[n] end
    if type(arg) == "string" and arg ~= "" then return arg end
    return logic.MESSAGES[1]
end

function logic.encode(wires)
    local rows = {}
    for i, w in ipairs(wires or {}) do
        if i > logic.MAX_WIRES then break end
        local row = EVENT_CODE[w.on] .. w.src .. ACTION_CODE[w.act] .. w.dst
        if w.arg ~= nil then row = row .. ":" .. w.arg end
        rows[#rows + 1] = row
    end
    return table.concat(rows, ";")
end

function logic.decode(text)
    local out = {}
    if type(text) ~= "string" then return out end
    for row in text:gmatch("[^;]+") do
        local e, src, a, dst, rest = row:match("^(%a)(%d+)(%a)(%d+)(.*)$")
        if e ~= nil then
            local arg = rest:match("^:(.*)$")
            local w = logic.wire(CODE_EVENT[e], src, CODE_ACTION[a], dst, arg)
            if w ~= nil then out[#out + 1] = w end
        end
    end
    return out
end

function logic.room_key(level, area)
    if type(level) ~= "number" then return "" end
    if OF.forge ~= nil and type(OF.forge.keep_key_for) == "function" then
        local key = OF.forge.keep_key_for(level, area)
        if type(key) == "string" then return key end
    end
    return tostring(level) .. "a" .. tostring(math.floor(tonumber(area) or 1))
end

function logic.room_here()
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if np == nil then return "" end
    return logic.room_key(np.currLevelNum, np.currAreaIndex)
end

function logic.decode_rooms(text)
    local out = {}
    if type(text) ~= "string" then return out end
    for group in text:gmatch("[^|]+") do
        local room, code = group:match("^([%w]+)=(.*)$")
        if room ~= nil then
            local list = logic.decode(code)
            if #list > 0 then out[room] = list end
        end
    end
    return out
end

function logic.encode_rooms(rooms)
    local keys = {}
    for room, list in pairs(rooms or {}) do
        if type(room) == "string" and room:match("^[%w]+$") and #list > 0 then
            keys[#keys + 1] = room
        end
    end
    table.sort(keys)
    local groups = {}
    for _, room in ipairs(keys) do groups[#groups + 1] = room .. "=" .. logic.encode(rooms[room]) end
    return table.concat(groups, "|")
end

local wiresCache = { parts = {}, rooms = {} }

function logic.wires_text()
    if gGlobalSyncTable == nil then return nil end
    local parts = {}
    for _, key in ipairs(logic.WIRES_KEYS) do
        local part = gGlobalSyncTable[key]
        if type(part) == "string" and part ~= "" then parts[#parts + 1] = part end
    end
    return table.concat(parts, "|")
end

function logic.forge_rooms()
    local moved = false
    for k, key in ipairs(logic.WIRES_KEYS) do
        local part = gGlobalSyncTable ~= nil and gGlobalSyncTable[key] or nil
        if part ~= wiresCache.parts[k] then
            wiresCache.parts[k] = part
            moved = true
        end
    end
    if moved then wiresCache.rooms = logic.decode_rooms(logic.wires_text()) end
    return wiresCache.rooms
end

logic.hostRooms = nil

function logic.forge_wires(room)
    room = room or logic.room_here()
    if logic.hostRooms ~= nil and OF.util.is_host() then
        return logic.hostRooms[room] or {}
    end
    return logic.forge_rooms()[room] or {}
end

function logic.venue_wires(key)
    local out = {}
    local layout = key ~= nil and OF.venues ~= nil and OF.venues.LAYOUTS ~= nil
        and OF.venues.LAYOUTS[key] or nil
    if layout == nil or type(layout.wires) ~= "table" then return out end
    for _, row in ipairs(layout.wires) do
        local w = logic.wire(row)
        if w ~= nil then out[#out + 1] = w end
    end
    return out
end

function logic.place_here()
    local key = OF.venues ~= nil and OF.venues.built or nil
    return type(key) == "string" and key or ""
end

function logic.wires_for(place, room)
    local out = {}
    for _, w in ipairs(logic.venue_wires(place)) do out[#out + 1] = w end
    for _, w in ipairs(logic.forge_wires(room)) do out[#out + 1] = w end
    return out
end

function logic.group_wired(g, wires)
    for _, w in ipairs(wires or logic.wires_for(logic.place_here())) do
        if w.act == "raise" and w.dst == g then return true end
    end
    return false
end

function logic.empty_state()
    return { running = false, start = 0, elapsed = 0, raised = {}, down = {}, hits = {},
             result = nil, seq = 0, starts = {}, levelNum = 0, areaNum = 0 }
end

local function sorted_keys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end

function logic.pack(st)
    local parts = {}
    parts[#parts + 1] = string.format("c%.0f.%.0f.%.0f", st.running and 1 or 0,
        math.floor(st.start or 0), math.floor(st.elapsed or 0))
    local g = {}
    for _, k in ipairs(sorted_keys(st.raised)) do if st.raised[k] then g[#g + 1] = tostring(k) end end
    parts[#parts + 1] = "g" .. table.concat(g, ",")
    local d = {}
    for _, id in ipairs(sorted_keys(st.down)) do
        if #d >= logic.MAX_DOWN then break end
        d[#d + 1] = id .. "." .. st.down[id]
    end
    parts[#parts + 1] = "d" .. table.concat(d, ",")
    local h = {}
    for _, gi in ipairs(sorted_keys(st.hits)) do h[#h + 1] = gi .. "." .. st.hits[gi] end
    parts[#parts + 1] = "h" .. table.concat(h, ",")
    if st.result ~= nil then
        parts[#parts + 1] = string.format("r%.0f.%.0f.%.0f", st.result.frames, st.result.hits, st.seq)
    else
        parts[#parts + 1] = "r..." .. st.seq
    end
    local m = {}
    for _, link in ipairs(sorted_keys(st.starts)) do
        local s = st.starts[link]
        m[#m + 1] = link .. "." .. s.count .. "." .. s.t0
    end
    parts[#parts + 1] = "m" .. table.concat(m, ",")
    parts[#parts + 1] = string.format("a%.0f.%.0f", st.levelNum or 0, st.areaNum or 0)
    return table.concat(parts, "|")
end

local function numbers(text)
    local out = {}
    for n in (text or ""):gmatch("-?%d+") do out[#out + 1] = tonumber(n) end
    return out
end

function logic.unpack(text)
    local st = logic.empty_state()
    if type(text) ~= "string" or text == "" then return st end
    for part in text:gmatch("[^|]+") do
        local tag, body = part:sub(1, 1), part:sub(2)
        if tag == "c" then
            local v = numbers(body)
            st.running, st.start, st.elapsed = v[1] == 1, v[2] or 0, v[3] or 0
        elseif tag == "g" then
            for _, n in ipairs(numbers(body)) do st.raised[n] = true end
        elseif tag == "d" then
            for id, grp in body:gmatch("(%d+)%.(%d+)") do st.down[tonumber(id)] = tonumber(grp) end
        elseif tag == "h" then
            for gi, n in body:gmatch("(%d+)%.(%d+)") do st.hits[tonumber(gi)] = tonumber(n) end
        elseif tag == "r" then
            local f, hits, seq = body:match("^(%d*)%.(%d*)%.(%d+)$")
            st.seq = tonumber(seq) or 0
            if f ~= nil and f ~= "" then st.result = { frames = tonumber(f), hits = tonumber(hits) or 0 } end
        elseif tag == "m" then
            for link, count, t0 in body:gmatch("(%d+)%.(%d+)%.(-?%d+)") do
                st.starts[tonumber(link)] = { count = tonumber(count), t0 = tonumber(t0) }
            end
        elseif tag == "a" then
            local v = numbers(body)
            st.levelNum, st.areaNum = v[1] or 0, v[2] or 0
        end
    end
    return st
end

local stateCache = { text = false, st = nil }

function logic.state()
    local text = gGlobalSyncTable ~= nil and gGlobalSyncTable[logic.STATE_KEY] or nil
    if text ~= stateCache.text or stateCache.st == nil then
        stateCache.text = text
        stateCache.st = logic.unpack(text)
    end
    return stateCache.st
end

local function area_now()
    if type(get_network_area_timer) ~= "function" then return 0 end
    return math.floor(tonumber(get_network_area_timer()) or 0)
end
logic.area_now = area_now

local function frame_now()
    return type(get_global_timer) == "function" and math.floor(tonumber(get_global_timer()) or 0) or 0
end

logic.pending = {}

function logic.standing(o, st, wires)
    if o == nil then return false end
    st = st or logic.state()
    local id = math.floor(tonumber(o.oSyncID) or 0)
    if st.down[id] ~= nil then return false end
    local p = logic.pending[id]
    if p ~= nil and frame_now() - p < logic.PENDING_FRAMES then return false end
    local g = logic.link(o)
    return st.raised[g] == true or not logic.group_wired(g, wires)
end

local host = nil

local hostBook = { fellAt = {}, fellIn = {}, fellRoom = {}, startedAt = nil, fired = {}, place = "" }

local function host_state()
    if host == nil then host = logic.unpack(gGlobalSyncTable ~= nil and gGlobalSyncTable[logic.STATE_KEY] or nil) end
    return host
end

local function host_publish()
    host.seq = (host.seq or 0) + 1
    if OF.util.publish ~= nil then
        OF.util.publish(logic.STATE_KEY, logic.pack(host))
    elseif gGlobalSyncTable ~= nil then
        gGlobalSyncTable[logic.STATE_KEY] = logic.pack(host)
    end
end

local function total_hits(st)
    local n = 0
    for _, v in pairs(st.hits) do n = n + v end
    return n
end
logic.total_hits = total_hits

local function say_all(text, kind, value)
    if OF.util.asks(OF.notify, "send_all") then
        OF.notify.send_all(text, kind or "info", 4, value)
    end
end

local run_wires

local function do_action(w, t, place)
    local st = host
    if w.act == "raise" then
        st.raised[w.dst] = true
        for id, g in pairs(st.down) do
            if g == w.dst then st.down[id] = nil hostBook.fellAt[id] = nil end
        end
    elseif w.act == "start" then
        local s = st.starts[w.dst] or { count = 0, t0 = 0 }
        st.starts[w.dst] = { count = (s.count + 1) % 1000, t0 = t }
    elseif w.act == "flip" then
        if OF.util.asks(OF.spawner, "host_onoff") then OF.spawner.host_onoff(0) end
    elseif w.act == "timer_start" then
        st.running, st.start, st.elapsed, st.result = true, t, 0, nil
        st.hits, st.down, st.raised = {}, {}, {}
        hostBook.fellAt, hostBook.fellIn, hostBook.fired = {}, {}, {}
        hostBook.fellRoom = {}
        hostBook.startedAt = frame_now()
        hostBook.place = place
        hostBook.room = hostBook.roomNow
        say_all("Course started")
    elseif w.act == "timer_stop" then
        if st.running then st.elapsed = math.max(0, t - st.start) end
        st.running = false
    elseif w.act == "message" then
        say_all(logic.message_text(w.arg))
    elseif w.act == "finish" then
        if st.running then st.elapsed = math.max(0, t - st.start) end
        st.running = false
        st.result = { frames = st.elapsed, hits = total_hits(st) }
        local text = OF.util.asks(OF.speedrun, "format_time")
            and OF.speedrun.format_time(st.elapsed) or tostring(st.elapsed)
        say_all("Course done: @", "good", text .. "  " .. st.result.hits .. " hits")
    end
end

run_wires = function(event, n, t, place, depth)
    depth = depth or 0
    if depth > 4 then return 0 end
    local wires = logic.wires_for(place, hostBook.roomNow)
    local ran = 0
    for pass = 1, 2 do
        for _, w in ipairs(wires) do
            local first = w.act == "timer_start"
            if w.on == event and w.src == n and ((pass == 1) == first) then
                do_action(w, t, place)
                ran = ran + 1
            end
        end
    end
    return ran
end

function logic.host_report(asker, text, place)
    if not OF.util.is_host() then
        return false, "Only the host."
    end
    if type(text) ~= "string" then return false end
    local v = {}
    for word in text:gmatch("[^:]+") do v[#v + 1] = word end
    local event, n, t = v[1], tonumber(v[2]), tonumber(v[3])
    if index_of(logic.EVENTS, event) == nil or n == nil or t == nil then return false end
    if event == "timer" or event == "alldown" then return false end
    n, t = math.floor(n), math.floor(t)
    if n < 0 or n > logic.MAX_LINK then return false end
    asker = math.floor(tonumber(asker) or 0)
    if OF.util.asks(OF.roundscope, "inside") and OF.roundscope.inside(asker) then
        return false, "Not inside a round"
    end
    place = type(place) == "string" and place or ""
    local st = host_state()
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[asker] or nil
    if np ~= nil then st.levelNum, st.areaNum = np.currLevelNum or 0, np.currAreaIndex or 0 end

    hostBook.roomNow = np ~= nil and logic.room_key(np.currLevelNum, np.currAreaIndex) or nil
    if event == "hit" then
        local id, left = math.floor(tonumber(v[4]) or 0), math.floor(tonumber(v[5]) or 1)
        if id <= 0 or st.down[id] ~= nil then return false end
        st.down[id] = n
        hostBook.fellAt[id] = frame_now()
        hostBook.fellIn[id] = place
        hostBook.fellRoom[id] = hostBook.roomNow
        local gi = np ~= nil and np.globalIndex or asker
        st.hits[gi] = (st.hits[gi] or 0) + 1
        run_wires("hit", n, t, place)
        if left <= 0 then run_wires("alldown", n, t, place) end
    else
        run_wires(event, n, t, place)
    end
    host_publish()
    return true
end

function logic.course_attended(st)
    if st == nil or (st.levelNum or 0) == 0 then return true end
    for i = 0, (MAX_PLAYERS or 16) - 1 do
        local np = gNetworkPlayers ~= nil and gNetworkPlayers[i] or nil
        if np ~= nil and (i == 0 or np.connected) and np.currLevelNum == st.levelNum
            and np.currAreaIndex == st.areaNum then
            return true
        end
    end
    return false
end

function logic.host_update()
    if host == nil then return false end
    local now = frame_now()

    if now % 30 == 0 and (host.running or next(host.raised) ~= nil or next(host.down) ~= nil)
        and not logic.course_attended(host) then
        return logic.host_reset()
    end
    local changed = false
    for id, at in pairs(hostBook.fellAt) do
        local g = host.down[id]
        if g == nil then
            hostBook.fellAt[id] = nil
        elseif now - at >= logic.RESET_FRAMES
            and not logic.group_wired(g, logic.wires_for(hostBook.fellIn[id],
                hostBook.fellRoom[id])) then
            host.down[id] = nil
            hostBook.fellAt[id] = nil
            changed = true
        end
    end
    if host.running and hostBook.startedAt ~= nil then
        local seconds = (now - hostBook.startedAt) / logic.FPS
        hostBook.roomNow = hostBook.room
        for i, w in ipairs(logic.wires_for(hostBook.place, hostBook.room)) do
            if w.on == "timer" and seconds >= w.src and not hostBook.fired[i] then
                hostBook.fired[i] = true
                do_action(w, host.start + math.floor(seconds * logic.FPS), hostBook.place)
                changed = true
            end
        end
    end
    if changed then host_publish() end
    return changed
end

function logic.host_reset()
    host = logic.empty_state()
    hostBook = { fellAt = {}, fellIn = {}, fellRoom = {}, startedAt = nil, fired = {}, place = "" }
    host_publish()
    return true
end

function logic.report(event, n, extra)
    local text = event .. ":" .. math.floor(n) .. ":" .. area_now()
    if extra ~= nil then text = text .. ":" .. extra end
    local place = logic.place_here()
    if OF.util.is_host() then
        return logic.host_report(0, text, place)
    end
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does(logic.ACTION, text, nil, place)
    end
    return false
end

logic.KEEP_PREFIX = "lw"
logic.KEEP_INDEX = "lwrooms"
local function keeps_wires()
    return OF.forge ~= nil
        and type(OF.forge.keep_on) == "function" and OF.forge.keep_on()
end

local function keep_room_wires(room, list)
    if not keeps_wires() or room == "" then return false end
    local index, seen = {}, false
    for r in tostring(OF.util.stored(logic.KEEP_INDEX, "") or ""):gmatch("[%w]+") do
        if r == room then seen = true end
        if r ~= room or #list > 0 then index[#index + 1] = r end
    end
    if #list > 0 and not seen then index[#index + 1] = room end
    OF.util.store_soon(logic.KEEP_PREFIX .. room, logic.encode(list))
    OF.util.store_soon(logic.KEEP_INDEX, table.concat(index, ","))
    return true
end

logic.PUBLISH_MOST = 250

local function host_rooms()
    if logic.hostRooms == nil then
        logic.hostRooms = {}
        for room, list in pairs(logic.forge_rooms()) do logic.hostRooms[room] = list end
    end
    return logic.hostRooms
end

local function rooms_stood_in()
    local out = {}
    for i = 0, (MAX_PLAYERS or 16) - 1 do
        local np = gNetworkPlayers ~= nil and gNetworkPlayers[i] or nil
        if np ~= nil and (i == 0 or np.connected) then
            out[logic.room_key(np.currLevelNum, np.currAreaIndex)] = true
        end
    end
    return out
end

local function publish_rooms()
    local rooms = host_rooms()
    local stood = rooms_stood_in()
    local here = logic.room_here()
    local keys = {}
    for room in pairs(stood) do
        if rooms[room] ~= nil and #rooms[room] > 0 then keys[#keys + 1] = room end
    end
    table.sort(keys, function(a, b)
        if (a == here) ~= (b == here) then return a == here end
        return a < b
    end)

    local slots = {}
    for k = 1, #logic.WIRES_KEYS do slots[k] = {} end
    for _, room in ipairs(keys) do
        for k = 1, #slots do
            slots[k][room] = rooms[room]
            if #logic.encode_rooms(slots[k]) <= logic.PUBLISH_MOST then break end
            slots[k][room] = nil
        end
    end
    local texts = {}
    for k, key in ipairs(logic.WIRES_KEYS) do
        local text = logic.encode_rooms(slots[k])
        texts[k] = text
        local now = gGlobalSyncTable ~= nil and gGlobalSyncTable[key] or nil
        if (now or "") ~= text then
            if OF.util.publish ~= nil then OF.util.publish(key, text)
            elseif gGlobalSyncTable ~= nil then gGlobalSyncTable[key] = text end
        end
    end
    return table.concat(texts, "|")
end
logic.publish_rooms = publish_rooms

function logic.keep_restore()
    if not keeps_wires() then return 0 end
    local rooms, put = host_rooms(), 0
    for room in tostring(OF.util.stored(logic.KEEP_INDEX, "") or ""):gmatch("[%w]+") do
        if rooms[room] == nil then
            local list = logic.decode(OF.util.stored(logic.KEEP_PREFIX .. room, "") or "")
            if #list > 0 then rooms[room], put = list, put + 1 end
        end
    end
    if put > 0 then publish_rooms() end
    return put
end

local function publish_wires(list, room)
    host_rooms()[room] = #list > 0 and list or nil
    publish_rooms()
    keep_room_wires(room, list)
end

function logic.forget_room_wires(room)
    if not OF.util.is_host() then return false end
    if type(room) ~= "string" or room == "" then return false end
    local rooms = host_rooms()
    local had = rooms[room] ~= nil
    rooms[room] = nil
    publish_rooms()
    local index = {}
    for r in tostring(OF.util.stored(logic.KEEP_INDEX, "") or ""):gmatch("[%w]+") do
        if r ~= room then index[#index + 1] = r else had = true end
    end
    if OF.util.stored(logic.KEEP_PREFIX .. room) ~= nil then
        OF.util.clear(logic.KEEP_PREFIX .. room)
        had = true
    end
    if #index > 0 then
        OF.util.store_soon(logic.KEEP_INDEX, table.concat(index, ","))
    elseif OF.util.stored(logic.KEEP_INDEX) ~= nil then
        OF.util.clear(logic.KEEP_INDEX)
    end
    return had
end

function logic.forget_all_wires()
    if not OF.util.is_host() then return 0 end
    local gone, seen = 0, {}
    for room in pairs(host_rooms()) do seen[room] = true end
    for r in tostring(OF.util.stored(logic.KEEP_INDEX, "") or ""):gmatch("[%w]+") do seen[r] = true end
    for room in pairs(seen) do
        if logic.forget_room_wires(room) then gone = gone + 1 end
    end
    logic.hostRooms = {}
    publish_rooms()
    return gone
end

function logic.host_wires(op, arg, room)
    if not OF.util.is_host() then
        return false, "Only the host."
    end
    room = type(room) == "string" and room ~= "" and room or logic.room_here()
    if room == "" then return false, "Not in a level yet." end
    local list = {}
    for _, w in ipairs(logic.forge_wires(room)) do list[#list + 1] = w end
    if op == "add" then
        local adding = logic.decode(arg)
        if #adding == 0 then return false, "That wire is not one I know." end
        for _, w in ipairs(adding) do
            if #list >= logic.MAX_WIRES then return false, "That is as many wires as a level holds." end
            list[#list + 1] = w
        end

        if #logic.encode_rooms({ [room] = list }) > logic.PUBLISH_MOST then
            return false, "That is as many wires as a level holds."
        end
    elseif op == "del" then
        local i = math.floor(tonumber(arg) or 0)
        if list[i] == nil then return false end
        table.remove(list, i)
    elseif op == "clear" then
        list = {}
    else
        return false
    end
    publish_wires(list, room)
    return true
end

function logic.ask_wires(op, arg)
    if OF.util.is_host() then
        return logic.host_wires(op, arg)
    end
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does(logic.ACTION, "wire", op, arg)
    end
    return false, "No host to ask yet - try again in a second."
end

local stoodOn = nil
local inZone = setmetatable({}, { __mode = "k" })

local startsSeen = {}

function logic.standing_in(group, except)
    local n = 0
    if OF.spawner == nil or OF.spawner.LOGIC == nil or obj_get_first_with_behavior_id == nil then
        return 0
    end
    local st, wires = logic.state(), logic.wires_for(logic.place_here())
    local o = obj_get_first_with_behavior_id(OF.spawner.LOGIC)
    while o ~= nil do
        if o ~= except and o.activeFlags ~= 0 and logic.kind(o) == logic.TARGET
            and logic.link(o) == group and logic.standing(o, st, wires) then
            n = n + 1
        end
        o = obj_get_next_with_same_behavior_id(o)
    end
    return n
end

function logic.hit(o)
    if o == nil or logic.kind(o) ~= logic.TARGET or not logic.standing(o) then return false end
    local id = math.floor(tonumber(o.oSyncID) or 0)
    if id <= 0 then return false end
    local left = logic.standing_in(logic.link(o), o)
    logic.pending[id] = frame_now()
    if OF.util.asks(OF.sounds, "play") and SOUND_ACTION_HIT ~= nil then
        OF.sounds.play(SOUND_ACTION_HIT)
    end
    return logic.report("hit", logic.link(o), id .. ":" .. left)
end

local function attacking(m)
    local flag = ACT_FLAG_ATTACKING or 0x00800000
    return m ~= nil and ((m.action or 0) & flag) ~= 0
end

function logic.punch_reaches(m, o)
    if not attacking(m) then return false end
    local dx, dz = m.pos.x - o.oPosX, m.pos.z - o.oPosZ
    local dy = (m.pos.y + 60) - (o.oPosY + logic.TARGET_MIDDLE)
    return dx * dx + dz * dz <= logic.HIT_REACH * logic.HIT_REACH and math.abs(dy) <= 200
end

function logic.shot(ex, ey, ez, dx, dy, dz, reach)
    if OF.spawner == nil or OF.spawner.LOGIC == nil or obj_get_first_with_behavior_id == nil then
        return nil
    end
    reach = tonumber(reach) or 6000
    local best, bestAlong = nil, reach
    local o = obj_get_first_with_behavior_id(OF.spawner.LOGIC)
    while o ~= nil do
        if o.activeFlags ~= 0 and logic.kind(o) == logic.TARGET and logic.standing(o) then
            local px, py, pz = o.oPosX - ex, o.oPosY + logic.TARGET_MIDDLE - ey, o.oPosZ - ez
            local along = px * dx + py * dy + pz * dz
            if along > 0 and along < bestAlong then
                local cx, cy, cz = px - dx * along, py - dy * along, pz - dz * along
                if cx * cx + cy * cy + cz * cz <= logic.SHOT_WIDTH * logic.SHOT_WIDTH then
                    best, bestAlong = o, along
                end
            end
        end
        o = obj_get_next_with_same_behavior_id(o)
    end
    if best ~= nil then logic.hit(best) end
    return best
end

local DOWN_PITCH = 0x4000
local TURN_STEP = 0x0C00

function logic.init(o)
    if o == nil then return end
    o.oCollisionDistance = 20000
    if logic.kind(o) == logic.TARGET then
        o.oFaceAnglePitch = logic.standing(o) and 0 or DOWN_PITCH
    end
end

function logic.loop(o)
    if o == nil then return end
    local kind = logic.kind(o)
    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    if kind == logic.TARGET then
        local up = logic.standing(o)
        local goal = up and 0 or DOWN_PITCH
        local pitch = math.floor(tonumber(o.oFaceAnglePitch) or 0)
        if pitch < goal then pitch = math.min(goal, pitch + TURN_STEP)
        elseif pitch > goal then pitch = math.max(goal, pitch - TURN_STEP) end
        o.oFaceAnglePitch = pitch
        if up and m ~= nil and logic.punch_reaches(m, o) then logic.hit(o) end
    elseif kind == logic.BUTTON then
        if type(load_object_collision_model) == "function" then load_object_collision_model() end
        local air = ACT_FLAG_AIR or 0x800
        local standing = m ~= nil and m.floor ~= nil and m.floor.object == o
            and ((m.action or 0) & air) == 0
        if standing and stoodOn ~= o then logic.report("pressed", logic.link(o)) end
        if standing then stoodOn = o elseif stoodOn == o then stoodOn = nil end
    elseif kind == logic.ZONE then
        if m == nil then return end
        local dx, dz = m.pos.x - o.oPosX, m.pos.z - o.oPosZ
        local dy = m.pos.y - o.oPosY
        local inside = dx * dx + dz * dz <= logic.ZONE_RADIUS * logic.ZONE_RADIUS
            and dy >= -50 and dy <= logic.ZONE_HEIGHT
        local was = inZone[o]
        if was ~= nil and inside ~= was then
            logic.report(inside and "entered" or "left", logic.link(o))
        end
        inZone[o] = inside
    end
end

function logic.movers_update(st)
    st = st or logic.state()
    if not OF.util.asks(OF.spawner, "movers_here") then return 0 end
    local started = 0
    for link, s in pairs(st.starts) do
        if startsSeen[link] ~= s.count then
            startsSeen[link] = s.count
            for _, o in ipairs(OF.spawner.movers_here()) do
                local spec = OF.spawner.mover_read(o)
                if spec ~= nil and spec.trigger == "wired" and spec.link == link then
                    if OF.spawner.mover_go(o, s.t0) then started = started + 1 end
                end
            end
        end
    end
    return started
end

local function time_text(frames)
    if OF.util.asks(OF.speedrun, "format_time") then
        return OF.speedrun.format_time(frames)
    end
    return tostring(frames)
end

local function here(st)
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if np == nil then return false end
    return st.levelNum == 0 or (np.currLevelNum == st.levelNum and np.currAreaIndex == st.areaNum)
end

local resultSeen = { seq = nil, at = 0 }

function logic.readout(st, now)
    st = st or logic.state()
    if not here(st) then return nil end
    if st.running then
        return { title = OF.util.asks(OF.lang, "t") and OF.lang.t("Course") or "Course",
                 lines = { time_text(math.max(1, area_now() - st.start)),
                           OF.util.asks(OF.lang, "fill") and OF.lang.fill("Hits: @", tostring(total_hits(st)))
                               or ("Hits: " .. total_hits(st)) } }
    end
    if st.result == nil then return nil end
    now = now or frame_now()
    if resultSeen.seq ~= st.seq then resultSeen.seq, resultSeen.at = st.seq, now end
    if now - resultSeen.at > logic.RESULT_FRAMES then return nil end
    local lines = { time_text(st.result.frames),
        OF.util.asks(OF.lang, "fill") and OF.lang.fill("Hits: @", tostring(st.result.hits)) or ("Hits: " .. st.result.hits) }
    for _, gi in ipairs(sorted_keys(st.hits)) do
        local li = network_local_index_from_global ~= nil and network_local_index_from_global(gi) or nil
        local np = li ~= nil and gNetworkPlayers ~= nil and gNetworkPlayers[li] or nil
        local name = np ~= nil and np.name or ("#" .. gi)
        lines[#lines + 1] = name .. "  " .. st.hits[gi]
    end
    return { title = OF.util.asks(OF.lang, "t") and OF.lang.t("Course done") or "Course done", lines = lines }
end

function logic.draw_readout()
    local card = logic.readout()
    if card == nil or not OF.util.world_label ~= nil then return false end
    local w = djui_hud_get_screen_width()
    local y = 70
    OF.util.world_label(w * 0.5, y, card.title, 0.8, 255, 220, 120, 240)
    for i, line in ipairs(card.lines) do
        OF.util.world_label(w * 0.5, y + 30 + (i - 1) * 26, line, i == 1 and 0.9 or 0.6, 255, 255, 255, 230)
    end
    return true
end

local markAt, markOut = { x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 0 }
function logic.draw_marks()
    if OF.spawner == nil or OF.spawner.LOGIC == nil or obj_get_first_with_behavior_id == nil then
        return 0
    end
    if not OF.util.world_ring ~= nil then return 0 end
    local forgeOpen = OF.forge ~= nil and OF.forge.open == true
    local drawn = 0
    local o = obj_get_first_with_behavior_id(OF.spawner.LOGIC)
    while o ~= nil do
        local kind = logic.kind(o)
        markAt.x, markAt.y, markAt.z = o.oPosX, o.oPosY, o.oPosZ
        if kind == logic.ZONE then
            OF.util.world_ring(markAt, logic.ZONE_RADIUS, 24, 2, 120, 220, 255, forgeOpen and 220 or 120)
            drawn = drawn + 1
        end
        if forgeOpen and OF.util.world_screen ~= nil then
            markAt.y = o.oPosY + 260
            if OF.util.world_screen(markAt, markOut) then
                OF.util.world_label(markOut.x, markOut.y,
                    (logic.KIND_NAMES[kind] or "?") .. " " .. logic.link(o), 0.5, 255, 230, 140, 220)
                drawn = drawn + 1
            end
        end
        o = obj_get_next_with_same_behavior_id(o)
    end
    return drawn
end

function logic.renumber(olds)
    local used = {}
    if OF.spawner ~= nil and OF.spawner.LOGIC ~= nil and obj_get_first_with_behavior_id ~= nil then
        local o = obj_get_first_with_behavior_id(OF.spawner.LOGIC)
        while o ~= nil do
            if o.activeFlags ~= 0 then used[logic.link(o)] = true end
            o = obj_get_next_with_same_behavior_id(o)
        end
    end

    if OF.spawner ~= nil and type(OF.spawner.movers_here) == "function" then
        for _, o in ipairs(OF.spawner.movers_here()) do
            local spec = OF.spawner.mover_read(o)
            if spec ~= nil and spec.trigger == "wired" then used[spec.link] = true end
        end
    end
    for _, w in ipairs(logic.forge_wires()) do
        if w.on ~= "timer" then used[w.src] = true end
        used[w.dst] = true
    end
    local map, next = {}, 1
    local sorted = {}
    for _, n in ipairs(olds or {}) do
        n = math.floor(tonumber(n) or 0)
        if n > 0 and map[n] == nil then map[n] = false sorted[#sorted + 1] = n end
    end
    table.sort(sorted)
    for _, n in ipairs(sorted) do
        while next <= logic.MAX_LINK and used[next] do next = next + 1 end
        if next > logic.MAX_LINK then return nil end
        map[n] = next
        used[next] = true
    end
    return map
end

function logic.wire_mapped(w, map)
    w = logic.wire(w)
    if w == nil then return nil end
    local src, dst = w.src, w.dst
    if w.on ~= "timer" then
        src = map[src]
        if not src then return nil end
    end
    if logic.ACTION_NUMBERED[w.act] then
        dst = map[dst]
        if not dst then return nil end
    end
    return logic.wire(w.on, src, w.act, dst, w.arg)
end

function logic.wire_inside(w, links)
    local named = 0
    if w.on ~= "timer" then
        if not links[w.src] then return false end
        named = named + 1
    end
    if logic.ACTION_NUMBERED[w.act] then
        if not links[w.dst] then return false end
        named = named + 1
    end
    return named > 0
end

local registered = false
function logic.register()
    if registered then return true end
    if OF.util.asks(OF.net, "register_action") then
        registered = true
        OF.net.register_action(logic.ACTION, "round_move", function(fromLocal, x, y, z)
            if OF.util ~= nil and not OF.util.is_host() then return false, "Only the host." end
            if x == "wire" then
                if y == "reset" then return logic.host_reset() end

                local np = gNetworkPlayers ~= nil and gNetworkPlayers[fromLocal] or nil
                if np == nil then return false end
                return logic.host_wires(y, z, logic.room_key(np.currLevelNum, np.currAreaIndex))
            end
            return logic.host_report(fromLocal, x, z)
        end)
    end
    return registered
end

hook_event(HOOK_ON_MODS_LOADED, logic.register)

hook_event(HOOK_UPDATE, function()
    if not registered then logic.register() end
    if OF.util.is_host() then

        if not logic.keptRestored then
            logic.keptRestored = true
            logic.keep_restore()
        end

        logic.roomTick = (logic.roomTick or 0) + 1
        if logic.hostRooms ~= nil and logic.roomTick % 30 == 0 then logic.publish_rooms() end
        logic.host_update()
    end
    logic.movers_update()
end)

hook_event(HOOK_ON_LEVEL_INIT, function()
    stoodOn = nil
    logic.pending = {}
    startsSeen = {}
end)

hook_event(HOOK_ON_HUD_RENDER, function()
    if OF.util.menu_has_screen() then return end
    if djui_hud_set_resolution ~= nil then djui_hud_set_resolution(RESOLUTION_DJUI) end
    logic.draw_marks()
    logic.draw_readout()
end)
