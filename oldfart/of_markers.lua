OF = OF or {}
OF.markers = OF.markers or {}

local markers = OF.markers

local HEAD_HEIGHT = 210
local MAX_DISTANCE = 6000

local MARGIN = 30

local screen = { x = 0, y = 0, z = 0 }
local world = { x = 0, y = 0, z = 0 }

function markers.on()
    return OF.settings == nil or OF.settings.markers ~= false
end

function markers.set(value)
    if OF.settings == nil then return false end
    OF.settings.set_markers(value)
    return true
end

local LOOKS = {

    { key = "roles",  default = true,
      name = "What each player is in the round, over their head",
      blurb = "the bomb, the ball, the runner - off leaves the"
              .. " round's places and arrows alone" },
    { key = "leader", default = true,
      name = "Mark whoever is leading the round",
      blurb = "the one player everybody else has to stop" },

    { key = "sight",  default = true, drawn = true,
      name = "Hide marks behind walls",
      blurb = "a mark for somebody out of sight fades away instead of floating"
              .. " over the wall they are behind" },

    { key = "radar",  default = false,
      name = "A minimap of who is near",
      blurb = "a dot for everybody close by, in the corner - not while you"
              .. " play a round" },
}

local LOOK_BY_KEY = {}
for _, look in ipairs(LOOKS) do LOOK_BY_KEY[look.key] = look end

function markers.looks()
    local list = {}
    for index, look in ipairs(LOOKS) do
        list[index] = { key = look.key, name = look.name,
                        blurb = look.blurb, default = look.default,
                        drawn = look.drawn == true }
    end
    return list
end

function markers.look(key)
    local look = LOOK_BY_KEY[key]
    if look == nil then return false end
    if OF.settings == nil or OF.settings.markerLooks == nil then
        return look.default
    end
    local set = OF.settings.markerLooks[key]
    if set == nil then return look.default end
    return set == true
end

function markers.set_look(key, value)
    if LOOK_BY_KEY[key] == nil then
        return false, "There is no mark setting called that."
    end
    if OF.settings == nil or OF.settings.set_marker_look == nil then
        return false, "The settings file is not loaded."
    end
    OF.settings.set_marker_look(key, value == true)
    return true
end

local function border_position(dx, dz, screenWidth, screenHeight)

    local vx, vz, rx, rz
    if gLakituState ~= nil and gLakituState.pos ~= nil
        and gLakituState.focus ~= nil then
        local ax = (gLakituState.focus.x or 0) - (gLakituState.pos.x or 0)
        local az = (gLakituState.focus.z or 0) - (gLakituState.pos.z or 0)
        local flat = math.sqrt(ax * ax + az * az)
        if flat > 0.0001 then
            vx, vz = ax / flat, az / flat
            rx, rz = -vz, vx
        end
    end

    if vx == nil then
        local view = 0
        if gLakituState ~= nil and gLakituState.yaw ~= nil then
            view = gLakituState.yaw + 0x8000
        end
        vx, vz = sins(view), coss(view)
        rx, rz = -coss(view), sins(view)
    end

    local ahead = dx * vx + dz * vz
    local side  = dx * rx + dz * rz

    if OF.util.asks(OF.warp, "tilt") then
        local roll = OF.warp.tilt()
        if type(roll) == "number" and roll ~= 0 then
            local c, s = coss(roll), sins(roll)
            side, ahead = side * c - ahead * s, ahead * c + side * s
        end
    end

    local length = math.sqrt(side * side + ahead * ahead)
    if length <= 0 then return screenWidth * 0.5, screenHeight - MARGIN end

    local dirX, dirY = side / length, -ahead / length

    local halfWidth = screenWidth * 0.5 - MARGIN
    local halfHeight = screenHeight * 0.5 - MARGIN

    local reach = math.huge
    if math.abs(dirX) > 0.0001 then reach = halfWidth / math.abs(dirX) end
    if math.abs(dirY) > 0.0001 then
        reach = math.min(reach, halfHeight / math.abs(dirY))
    end

    return screenWidth * 0.5 + dirX * reach, screenHeight * 0.5 + dirY * reach
end

local function off_the_counters(x, y, screenWidth, screenHeight)

    if y < screenHeight * 0.5 then
        local top = OF.util.counters_bottom(screenHeight)

        local banners = OF.util.stack_bottom_over(x - MARGIN, x + MARGIN)
        if banners ~= nil and banners > top then top = banners end
        local floor = math.min(top + MARGIN * 0.5, screenHeight * 0.5)
        if top > 0 and y < floor then y = floor end

        if OF.util.asks(OF.hud, "cluster_clear") then
            local under = OF.hud.cluster_clear(x)
            if under ~= nil and y < under then y = math.min(under, screenHeight * 0.5) end
        end
    end
    if x > OF.util.camera_icon_left(screenWidth, screenHeight) - MARGIN then
        local camera = OF.util.camera_icon_top(screenHeight) - MARGIN * 0.5
        if y > camera then y = camera end
    end

    if OF.util.asks(OF.util, "clear_of_boards") then
        x, y = OF.util.clear_of_boards(x, y, MARGIN)
    end
    return x, y
end

markers.keep_clear = off_the_counters

function markers.place(x, y, z)
    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()

    local fromX, fromZ = x, z
    if gLakituState ~= nil and gLakituState.pos ~= nil then
        fromX = x - gLakituState.pos.x
        fromZ = z - gLakituState.pos.z
    end

    world.x, world.y, world.z = x, y, z
    if OF.util.world_screen(world, screen) then
        if screen.x >= MARGIN and screen.x <= screenWidth - MARGIN
            and screen.y >= MARGIN and screen.y <= screenHeight - MARGIN then
            return screen.x, screen.y, false
        end

        local edgeX, edgeY = off_the_counters(
            math.max(MARGIN, math.min(screenWidth - MARGIN, screen.x)),
            math.max(MARGIN, math.min(screenHeight - MARGIN, screen.y)),
            screenWidth, screenHeight)
        return edgeX, edgeY, true
    end

    local borderX, borderY = border_position(fromX, fromZ, screenWidth, screenHeight)
    borderX, borderY = off_the_counters(borderX, borderY, screenWidth, screenHeight)
    return borderX, borderY, true
end

local SIGHT_TORSO = 90
local SIGHT_HEAD = 160

local SIGHT_RISE = 0.34
local SIGHT_FALL = 0.08

local SIGHT_GONE = 0.02

local SIGHT_BUDGET = 6

local SIGHT_NEAR = 260

local SIGHT_LIMITED = { team = true, prey = true }

function markers.occluded(kind)
    if kind == nil then return false end
    if not markers.look("sight") then return false end
    if OF.util.asks(OF.gamemodes, "marker_occluded") then
        local said = OF.gamemodes.marker_occluded(kind)
        if said ~= nil then return said == true end
    end
    return SIGHT_LIMITED[kind] == true
end

local sightValue = {}
local sightTarget = {}

local sightBlocked = {}
markers.SIGHT_LATCH = 2

local sightOrder = 0

function markers.clear_line(sx, sy, sz, tx, ty, tz)
    local dx, dy, dz = tx - sx, ty - sy, tz - sz
    if dx * dx + dy * dy + dz * dz <= SIGHT_NEAR * SIGHT_NEAR then
        return true, 0
    end

    local hit = OF.util.optional("collision_find_surface_on_ray", nil,
        sx, sy, sz, dx, dy, dz)
    if hit == nil then return true, 0 end
    return hit.surface == nil, 1
end

local function body_seen(localIndex)
    local m = gMarioStates[localIndex]
    if m == nil or m.pos == nil then return true, 0 end
    if gLakituState == nil or gLakituState.pos == nil then return true, 0 end

    local sx, sy, sz = gLakituState.pos.x, gLakituState.pos.y, gLakituState.pos.z

    local clear, spent = markers.clear_line(sx, sy, sz,
        m.pos.x, m.pos.y + SIGHT_TORSO, m.pos.z)
    if clear then return true, spent end

    local head, more = markers.clear_line(sx, sy, sz,
        m.pos.x, m.pos.y + SIGHT_HEAD, m.pos.z)
    return head, spent + more
end

function markers.sight(localIndex)
    local value = sightValue[localIndex]
    if value == nil then return 1 end
    return value
end

function markers.forget_sight()
    sightValue = {}
    sightTarget = {}
    sightBlocked = {}
    sightOrder = 0
end

function markers.tick_sight(wanted)
    wanted = wanted or {}

    local live = {}
    for _, index in ipairs(wanted) do live[index] = true end
    for index in pairs(sightValue) do
        if not live[index] then sightValue[index] = nil end
    end
    for index in pairs(sightTarget) do
        if not live[index] then sightTarget[index] = nil end
    end
    for index in pairs(sightBlocked) do
        if not live[index] then sightBlocked[index] = nil end
    end

    if #wanted > 0 then
        local was = OF.util.optional("camera_get_checking_surfaces", false) == true
        OF.util.optional("camera_set_checking_surfaces", nil, true)

        local spent, asked = 0, 0
        while spent < SIGHT_BUDGET and asked < #wanted do
            sightOrder = sightOrder + 1
            if sightOrder > #wanted then sightOrder = 1 end
            local index = wanted[sightOrder]
            local seen, casts = body_seen(index)

            if seen then
                sightBlocked[index] = 0
                sightTarget[index] = 1
            else
                sightBlocked[index] = (sightBlocked[index] or 0) + 1
                if sightBlocked[index] >= markers.SIGHT_LATCH then sightTarget[index] = 0 end
            end
            spent = spent + casts
            asked = asked + 1
        end

        OF.util.optional("camera_set_checking_surfaces", nil, was)
    end

    for _, index in ipairs(wanted) do
        local target = sightTarget[index]
        if target == nil then target = 1 end
        local value = sightValue[index]
        if value == nil then value = 1 end
        if value < target then
            value = math.min(target, value + SIGHT_RISE)
        elseif value > target then
            value = math.max(target, value - SIGHT_FALL)
        end
        sightValue[index] = value
    end
end

local FOLLOWED = { bomb = true, ["the hill"] = true, ["the line"] = true,

                   ["the flag"] = true,

                   leading = true }

local passLeader = nil
local passLeaderKnown = false

function markers.leader()
    if OF.gamemodes == nil or OF.gamemodes.is_running == nil then return nil end
    if not OF.gamemodes.is_running() then return nil end

    local mode = OF.gamemodes.current()
    if mode ~= nil and mode.resultsBy == "survival" then return nil end

    if mode ~= nil and mode.noNametags then return nil end

    if mode ~= nil and mode.noLeaderMark then return nil end

    local best, who, tied = 0, nil, false
    for _, entry in ipairs(OF.util.connected_players()) do
        local row = gPlayerSyncTable[entry.localIndex]
        local score = row ~= nil and row.ofScore or 0
        if score > best then
            best, who, tied = score, entry.localIndex, false
        elseif score == best and score > 0 then
            tied = true
        end
    end

    if best <= 0 or tied then return nil end
    return who
end

function markers.for_player(localIndex)
    if localIndex == 0 then return nil end
    if OF.gamemodes == nil or not OF.gamemodes.is_running() then return nil end

    if not markers.look("roles") then return nil end

    if OF.util.asks(OF.spectate, "is_spectating")
        and OF.spectate.is_spectating(localIndex) then
        return nil
    end

    if OF.util.asks(OF.gamemodes, "marked_player") then
        local kind, r, g, b = OF.gamemodes.marked_player(localIndex)
        if kind ~= nil then return kind, r, g, b end
    end

    if markers.look("leader") then
        local ahead = passLeader
        if not passLeaderKnown then ahead = markers.leader() end
        if ahead == localIndex then
            local gold = OF.util.gold()
            return "leading", gold.r, gold.g, gold.b
        end
    end

    if OF.util.asks(OF.zombies, "can_see")
        and OF.zombies.can_see(localIndex) then
        return "prey", 255, 90, 90
    end

    return nil
end

function markers.places()
    local list = {}
    if OF.gamemodes == nil or OF.gamemodes.is_running == nil then return list end
    if not OF.gamemodes.is_running() then return list end

    if OF.util.asks(OF.gamemodes, "marked_place") then
        local one = OF.gamemodes.marked_place()
        if type(one) == "table" and one.x ~= nil then table.insert(list, one) end
    end

    local mode = OF.util.asks(OF.gamemodes, "current") and OF.gamemodes.current() or nil
    if mode ~= nil and type(mode.places) == "function" then
        local ok, more = pcall(mode.places)
        if ok and type(more) == "table" then
            for _, spot in ipairs(more) do
                if type(spot) == "table" and spot.x ~= nil then
                    table.insert(list, spot)
                end
            end
        end
    end

    return list
end

local RING_SLOTS = 16
local RING_SEGMENTS = 56
local RING_CHUNK = 4

local RING_ROWS = { { -1.0, 0, 40 }, { -0.55, 150, 40 }, { -0.22, 255, 255 }, { 0.22, 255, 255 }, { 0.55, 150, 40 }, { 1.0, 0, 40 } }

markers.RING_SLOTS = RING_SLOTS
markers.RING_SEGMENTS = RING_SEGMENTS

markers.RING_WIDTH = 48

markers.RING_LIFT = 12

markers.RING_FLOOR_REACH = 500

markers.RING_FLOOR_HIGH = 1500

markers.RING_FADE_IN = 6
markers.RING_FADE_OUT = 10

markers.RING_PULSE_PERIOD = 90
markers.RING_PULSE_DEPTH = 0.3

markers.RING_MOVE = 8
markers.RING_RESIZE = 0.01

local ringAsked = false
local ringModels = nil
local ringSlots = {}
markers.ringSlots = ringSlots

local RING_PREFIX = "of_ring_slot_"
local function ring_geo(slot) return string.format(RING_PREFIX .. "%02.0f_geo", slot) end

function markers.ring_models()
    if ringAsked then return ringModels end
    ringAsked = true
    local found = {}
    for slot = 1, RING_SLOTS do
        local geo = ring_geo(slot)
        if not OF.util.optional("mod_file_exists", false, "actors/" .. geo .. ".bin") then return nil end
        local id = OF.util.optional("smlua_model_util_get_id", nil, geo)
        if type(id) ~= "number" or id == E_MODEL_ERROR_MODEL then return nil end
        found[slot] = id
    end
    ringModels = found
    return ringModels
end

function markers.forget_rings()
    for _, s in pairs(ringSlots) do
        if markers.slot_alive(s) then s.obj.activeFlags = 0 end
    end
    for k in pairs(ringSlots) do ringSlots[k] = nil end
    ringAsked, ringModels = false, nil
end

local function slot_vertices(slot)
    if vtx_get_from_name == nil or vtx_get_next_vertex == nil then return nil end
    local list = {}
    for c = 0, RING_SEGMENTS / RING_CHUNK - 1 do
        local name = string.format(RING_PREFIX .. "%02.0f_vtx_%.0f", slot, c)
        local ok, v, count = pcall(vtx_get_from_name, name)
        if not ok or v == nil then return nil end
        local want = (RING_CHUNK + 1) * #RING_ROWS
        count = type(count) == "number" and count or want
        for _ = 1, math.min(count, want) do
            if v == nil then return nil end
            list[#list + 1] = v
            v = vtx_get_next_vertex(v)
        end
    end
    return list
end

local function slot_place(s, x, y, z, radius, width)
    if s.vtx == nil then s.vtx = slot_vertices(s.slot) end
    if s.vtx == nil then return false end
    local rows = #RING_ROWS
    local half = width / 2
    local reach = markers.RING_FLOOR_REACH
    local column = 0
    for c = 0, RING_SEGMENTS / RING_CHUNK - 1 do
        for j = 0, RING_CHUNK do
            local seg = (c * RING_CHUNK + j) % RING_SEGMENTS
            local angle = seg / RING_SEGMENTS * 2 * math.pi
            local cs, sn = math.cos(angle), math.sin(angle)

            local px, pz = x + cs * radius, z + sn * radius
            local floorY = OF.util.optional("find_floor_height", nil, px, y + 300, pz)
            local dy = 0
            if type(floorY) == "number" and math.abs(floorY - y) <= reach then
                dy = floorY - y
            else
                floorY = OF.util.optional("find_floor_height", nil, px, y + markers.RING_FLOOR_HIGH, pz)
                if type(floorY) == "number" and math.abs(floorY - y) <= markers.RING_FLOOR_HIGH then
                    dy = floorY - y
                end
            end
            dy = dy + markers.RING_LIFT
            for r = 1, rows do
                local v = s.vtx[column * rows + r]
                if v == nil then return false end
                local at = radius + RING_ROWS[r][1] * half
                v.x, v.y, v.z = cs * at, dy, sn * at
            end
            column = column + 1
        end
    end
    s.x, s.y, s.z, s.radius, s.width = x, y, z, radius, width
    return true
end

local function slot_colour(s, r, g, b, a)
    if gfx_get_from_name == nil or gfx_get_command == nil or gfx_set_command == nil then return end
    if s.mat == nil then
        local ok, dl = pcall(gfx_get_from_name, string.format(RING_PREFIX .. "%02.0f_mat", s.slot))
        if not ok or dl == nil then return end
        s.mat = gfx_get_command(dl, 3)
    end
    if s.mat == nil then return end
    r, g, b, a = math.floor(r), math.floor(g), math.floor(b), math.floor(a)
    if s.cr == r and s.cg == g and s.cb == b and s.ca == a then return end
    s.cr, s.cg, s.cb, s.ca = r, g, b, a
    pcall(gfx_set_command, s.mat, "gsDPSetEnvColor(%i, %i, %i, %i)", r, g, b, a)
end

local function slot_room()
    local np = gNetworkPlayers[0]
    if np == nil then return "" end
    return tostring(np.currLevelNum) .. ":" .. tostring(np.currAreaIndex) .. ":" .. tostring(np.currActNum)
end

local function slot_alive(s)
    local o = s.obj
    if o == nil or o.activeFlags == nil or o.activeFlags == 0 then return false end
    if s.room ~= slot_room() then return false end
    local model = OF.util.optional("obj_get_model_id_extended", nil, o)
    if model ~= nil and ringModels ~= nil and model ~= ringModels[s.slot] then return false end
    return true
end
markers.slot_alive = slot_alive

local function slot_object(s, x, y, z)
    if slot_alive(s) then return s.obj end
    s.vtx, s.mat, s.cr = nil, nil, nil
    s.radius = nil
    local o = OF.slots.spawn_non_sync(id_bhvStaticObject, ringModels[s.slot], x, y, z, nil)
    s.obj = o
    s.room = slot_room()
    if o == nil then return nil end
    o.oFaceAnglePitch, o.oFaceAngleYaw, o.oFaceAngleRoll = 0, 0, 0
    o.oRoom = -1
    if o.header ~= nil and o.header.gfx ~= nil then o.header.gfx.skipInViewCheck = true end
    return o
end

local function slot_move(s, x, y, z)
    local o = s.obj
    if o == nil then return end
    o.oPosX, o.oPosY, o.oPosZ = x, y, z
    if o.header ~= nil and o.header.gfx ~= nil and o.header.gfx.pos ~= nil then
        o.header.gfx.pos.x, o.header.gfx.pos.y, o.header.gfx.pos.z = x, y, z
    end
end

local function slot_for(id, x, z, radius, r, g, b, now)
    if id ~= nil then
        for _, s in pairs(ringSlots) do
            if s.id == id then return s end
        end
    else
        local best, bestAway = nil, nil
        for _, s in pairs(ringSlots) do
            if s.id == nil and s.claimed ~= now and s.touched ~= nil and now - s.touched <= 2
                and s.wr == r and s.wg == g and s.wb == b and s.radius ~= nil
                and math.abs(s.radius - radius) <= radius * 0.05 then
                local away = (s.x - x) ^ 2 + (s.z - z) ^ 2
                if away <= (math.max(300, radius * 0.5)) ^ 2 and (bestAway == nil or away < bestAway) then
                    best, bestAway = s, away
                end
            end
        end
        if best ~= nil then return best end
    end
    for slot = 1, RING_SLOTS do
        local s = ringSlots[slot]
        if s == nil then
            s = { slot = slot, alpha = 0 }
            ringSlots[slot] = s
        end
        if (s.touched == nil or now - s.touched > 2) and (s.alpha or 0) <= 0 then
            s.id = id
            s.radius = nil
            s.alpha = 0
            return s
        end
    end
    return nil
end

local fallbackSight = {}
local function fallback_seen(key, at, radius)
    local now = OF.util.asks(OF.hud, "now") and OF.hud.now() or 0
    local st = fallbackSight[key]
    if st == nil then st = { clear = { true, true, true, true, true }, turn = 0, value = 1 }; fallbackSight[key] = st end
    if st.at ~= now and gLakituState ~= nil and gLakituState.pos ~= nil then
        st.at = now
        st.turn = st.turn % 5 + 1
        local px, pz = at.x, at.z
        if st.turn == 2 then px = px + radius elseif st.turn == 3 then px = px - radius
        elseif st.turn == 4 then pz = pz + radius elseif st.turn == 5 then pz = pz - radius end
        local was = OF.util.optional("camera_get_checking_surfaces", false) == true
        OF.util.optional("camera_set_checking_surfaces", nil, true)
        local clear = markers.clear_line(gLakituState.pos.x, gLakituState.pos.y, gLakituState.pos.z,
            px, at.y + 30, pz)
        OF.util.optional("camera_set_checking_surfaces", nil, was)
        st.clear[st.turn] = clear
        local any = false
        for i = 1, 5 do if st.clear[i] then any = true end end
        local target = any and 1 or 0
        if st.value < target then st.value = math.min(1, st.value + 1 / markers.RING_FADE_IN)
        elseif st.value > target then st.value = math.max(0, st.value - 1 / markers.RING_FADE_OUT) end
    end
    return st.value
end
markers.fallback_seen = fallback_seen

function markers.forget_fallback_sight() fallbackSight = {} end

function markers.target_tone(tone)
    if tone == nil or tone == "gold" or tone == "accent" then return "target" end
    return tone
end

local function tone_rgb(tone)
    if type(tone) == "table" and tone.r ~= nil then return tone.r, tone.g, tone.b end
    tone = markers.target_tone(tone)
    if OF.util.asks(OF.hud, "colour") then return OF.hud.colour(tone or "target") end
    return 255, 210, 60
end

markers.COUNT_LIFT = 140
markers.COUNT_PIP = 10
local countWants = {}
local countScreen, countWorld = { x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 0 }
function markers.ring_count(key, pos, radius, count, tone)
    local hud = OF.hud
    if hud == nil or type(count) ~= "table" or count[2] == nil or count[2] < 1 then return 0 end
    local me = gMarioStates[0]
    if me ~= nil and me.pos ~= nil then
        local dx, dz = me.pos.x - pos.x, me.pos.z - pos.z
        if dx * dx + dz * dz <= radius * radius then return 0 end
    end
    local id = "count:" .. tostring(key)
    if type(tone) == "table" and tone.r ~= nil then tone = { tone.r, tone.g, tone.b } end
    if #countWants > 32 then countWants = {} end
    countWants[#countWants + 1] = { id = id, x = pos.x, y = (pos.y or 0) + 60, z = pos.z }
    local seen = markers.point_sight(id)
    if seen <= 0.05 then return 0 end
    countWorld.x, countWorld.y, countWorld.z = pos.x, (pos.y or 0) + markers.COUNT_LIFT, pos.z
    if not OF.util.world_screen(countWorld, countScreen) then return 0 end

    local word = tostring(count[1] or 0) .. "/" .. tostring(count[2])
    hud.text_centred(word, countScreen.x, countScreen.y, "heading", tone, 255 * seen)
    return 1
end

function markers.take_count_wants()
    local list = countWants
    countWants = {}
    return list
end

function markers.ring(id, pos, radius, tone, opts)
    local drawn = markers.ring_body(id, pos, radius, tone, opts)
    if opts ~= nil and opts.count ~= nil and type(pos) == "table" and pos.x ~= nil then
        local key = id or string.format("%.0f:%.0f", math.floor(pos.x / 100), math.floor(pos.z / 100))
        markers.ring_count(key, pos, radius, opts.count, tone)
    end
    return drawn
end

function markers.ring_body(id, pos, radius, tone, opts)
    if type(pos) ~= "table" or pos.x == nil then return 0 end
    if type(radius) ~= "number" or radius <= 0 then return 0 end
    opts = opts or {}
    local r, g, b = tone_rgb(tone)
    local a = opts.alpha or 200
    local now = OF.util.asks(OF.hud, "now") and OF.hud.now() or 0
    local y = pos.y or 0

    if markers.ring_models() ~= nil and OF.slots ~= nil then
        local s = slot_for(id, pos.x, pos.z, radius, r, g, b, now)
        if s ~= nil and slot_object(s, pos.x, y, pos.z) ~= nil then
            local width = opts.width or markers.RING_WIDTH
            if s.radius == nil or math.abs(s.radius - radius) > radius * markers.RING_RESIZE
                or s.width ~= width
                or (s.x - pos.x) ^ 2 + (s.y - y) ^ 2 + (s.z - pos.z) ^ 2 > markers.RING_MOVE ^ 2 then
                slot_place(s, pos.x, y, pos.z, radius, width)
                slot_move(s, pos.x, y, pos.z)
            end
            s.touched, s.claimed = now, now
            s.wr, s.wg, s.wb, s.wa = r, g, b, a
            s.contested = opts.contested == true
            return s.alpha > 0 and RING_SEGMENTS or 1
        end
    end

    local key = id or string.format("%.0f:%.0f:%.0f", math.floor(pos.x / 100), math.floor(pos.z / 100),
        math.floor(radius))
    local seen = fallback_seen(key, pos, radius)
    if seen <= 0.02 then return 0 end
    return OF.util.world_ring({ x = pos.x, y = y, z = pos.z }, radius, opts.segments or 40,
        opts.size or 4, r, g, b, a * seen, "edge") or 0
end

OF.util = OF.util or {}
OF.util.ring_route = function(...) return markers.ring(...) end

function markers.tick_rings()
    local now = OF.util.asks(OF.hud, "now") and OF.hud.now() or 0
    for _, s in pairs(ringSlots) do
        local want = 0
        if s.touched ~= nil and now - s.touched <= 1 then want = 1 end
        if want > s.alpha then
            s.alpha = math.min(want, s.alpha + 1 / markers.RING_FADE_IN)
        elseif want < s.alpha then
            s.alpha = math.max(want, s.alpha - 1 / markers.RING_FADE_OUT)
        end
        local o = s.obj
        if o ~= nil and not slot_alive(s) then

            s.obj, s.vtx, s.mat, s.cr, s.radius = nil, nil, nil, nil, nil
            o = nil
        end
        if o ~= nil then
            local k = s.alpha
            if s.contested and want > 0 then
                local breath = 0.5 + 0.5 * math.sin(now * 2 * math.pi / markers.RING_PULSE_PERIOD)
                k = k * (1 - markers.RING_PULSE_DEPTH * breath)
            end
            slot_colour(s, s.wr or 255, s.wg or 255, s.wb or 255, (s.wa or 200) * k)
            local flags = o.header ~= nil and o.header.gfx ~= nil and o.header.gfx.node ~= nil
                and o.header.gfx.node.flags or nil
            local hidden = GRAPH_RENDER_INVISIBLE or 16
            if flags ~= nil then
                if s.alpha <= 0 then
                    o.header.gfx.node.flags = flags | hidden
                elseif flags & hidden ~= 0 then
                    o.header.gfx.node.flags = flags & ~hidden
                end
            end
        end
        if s.alpha <= 0 and (s.touched == nil or now - s.touched > 2) then s.id = nil end
    end
end

function markers.place_ring(spot, radius, look)
    if type(spot) ~= "table" or spot.x == nil then return 0 end
    if type(radius) ~= "number" or radius <= 0 then return 0 end
    look = look or {}
    local id = spot.id ~= nil and ("place:" .. tostring(spot.id)) or nil

    local count = nil
    if type(look.label) == "string" then
        local have, of = string.match(look.label, "^(%d+)/(%d+)$")
        if have ~= nil then count = { tonumber(have), tonumber(of) } end
    end
    return markers.ring(id, spot, radius,
        { r = look.r or 255, g = look.g or 255, b = look.b or 255 },
        { alpha = look.alpha or 200, segments = look.segments, size = look.size or 3, count = count })
end

markers.NEAR_IN = 2500
markers.NEAR_OUT = 2800

markers.COMPASS_FLOOR = 600
markers.EDGE_CAP = 4
markers.ON_CAP = 6
markers.MERGE_PX = 44
markers.LABEL_FRAMES = 90
markers.MOVED = 600
markers.OCCLUDED_SHARE = 0.6
markers.FADE_IN = 6
markers.FADE_OUT = 10
markers.CROSSFADE = 6
markers.PLAYER_LIFT = HEAD_HEIGHT
markers.PLACE_LIFT = 160
markers.CUE_PULSES = 40

markers.HIDE_MODES = { hideseek = true, sardines = true, prophunt = true, zombies = true }

function markers.players_marked(mode)
    if mode == nil and OF.util.asks(OF.gamemodes, "current") then
        mode = OF.gamemodes.current()
    end
    if mode == nil then return true end
    if type(mode.marking) == "table" and mode.marking.players ~= nil then
        return mode.marking.players ~= false
    end
    return not markers.HIDE_MODES[mode.key]
end

local function tone_of(tone, r, g, b)
    if r ~= nil then return { r, g, b } end
    if type(tone) == "table" and tone.r ~= nil then return { tone.r, tone.g, tone.b } end
    return tone or "target"
end

local function legacy_targets(list)
    for at, spot in ipairs(markers.places()) do
        local label = spot.label or "the hill"
        local follow = spot.follow == true or FOLLOWED[label] == true
        list[#list + 1] = {
            id = "place:" .. tostring(spot.id or label) .. ":" .. at,
            pos = spot, label = label, lift = HEAD_HEIGHT,
            tone = tone_of(nil, spot.r, spot.g, spot.b),
            priority = 90, compass = follow and "offscreen" or "never",
            ring = type(spot.ring) == "number" and { radius = spot.ring } or nil,
            occlude = true,
        }
    end
    passLeader = markers.leader()
    passLeaderKnown = true
    for _, entry in ipairs(OF.util.connected_players()) do
        local index = entry.localIndex
        local kind, r, g, b = markers.for_player(index)

        if kind ~= nil and kind ~= "team" and kind ~= "prey" and kind ~= "leading" then
            list[#list + 1] = {
                id = "player:" .. kind .. ":" .. index, player = index, label = kind,
                tone = tone_of(nil, r, g, b),
                priority = kind == "leading" and 60 or 70,
                compass = FOLLOWED[kind] and "offscreen" or "never",
                occlude = markers.occluded(kind),
                legacyKind = kind,
            }
        end
    end
    passLeaderKnown = false
    return list
end

function markers.targets(viewer)
    local list = {}
    if OF.gamemodes == nil or not OF.gamemodes.is_running() then return list end
    local mode = OF.gamemodes.current()
    if mode ~= nil and type(mode.targets) == "function" then
        local ok, said = pcall(mode.targets, viewer or 0)
        if ok and type(said) == "table" then
            for _, t in ipairs(said) do
                if type(t) == "table" and t.id ~= nil and (t.pos ~= nil or t.player ~= nil) then
                    list[#list + 1] = t
                end
            end
        end
        return list
    end
    return legacy_targets(list)
end

local tstate = {}
markers.tstate = tstate

markers.lastPass = {}

function markers.forget_pass()
    for k in pairs(tstate) do tstate[k] = nil end
    markers.lastPass = {}

    if markers.forget_points ~= nil then markers.forget_points() end
end

local pointValue, pointTarget, pointBlocked = {}, {}, {}
local pointOrder = 0

function markers.point_sight(id)
    local v = pointValue[id]
    if v == nil then return 1 end
    return v
end

function markers.tick_points(wanted, budget)
    local live = {}
    for _, w in ipairs(wanted) do live[w.id] = true end
    for id in pairs(pointValue) do if not live[id] then pointValue[id] = nil end end
    for id in pairs(pointTarget) do if not live[id] then pointTarget[id] = nil end end
    for id in pairs(pointBlocked) do if not live[id] then pointBlocked[id] = nil end end
    if #wanted > 0 and budget > 0 and gLakituState ~= nil and gLakituState.pos ~= nil then
        local was = OF.util.optional("camera_get_checking_surfaces", false) == true
        OF.util.optional("camera_set_checking_surfaces", nil, true)
        local spent, asked = 0, 0
        while spent < budget and asked < #wanted do
            pointOrder = pointOrder % #wanted + 1
            local w = wanted[pointOrder]
            local clear, casts = markers.clear_line(gLakituState.pos.x, gLakituState.pos.y,
                gLakituState.pos.z, w.x, w.y, w.z)
            if clear then
                pointBlocked[w.id] = 0
                pointTarget[w.id] = 1
            else
                pointBlocked[w.id] = (pointBlocked[w.id] or 0) + 1
                if pointBlocked[w.id] >= markers.SIGHT_LATCH then pointTarget[w.id] = 0 end
            end
            spent, asked = spent + math.max(casts, 1), asked + 1
        end
        OF.util.optional("camera_set_checking_surfaces", nil, was)
    end
    for _, w in ipairs(wanted) do
        local target = pointTarget[w.id] or 1
        local value = pointValue[w.id] or 1
        if value < target then value = math.min(target, value + SIGHT_RISE)
        elseif value > target then value = math.max(target, value - SIGHT_FALL) end
        pointValue[w.id] = value
    end
end

function markers.forget_points()
    for id in pairs(pointValue) do pointValue[id] = nil end
    for id in pairs(pointTarget) do pointTarget[id] = nil end
    for id in pairs(pointBlocked) do pointBlocked[id] = nil end
    pointOrder = 0
end

local sightWantedAt = {}
function markers.want_sight(localIndex)
    sightWantedAt[localIndex] = OF.util.asks(OF.hud, "now") and OF.hud.now() or 0
end

local function same_room(index)
    return OF.util.same_world(index)
end

local function approach(value, target, up, down)
    if value < target then return math.min(target, value + up) end
    if value > target then return math.max(target, value - down) end
    return value
end

local onePos = {}

local function resolve(t, playersOk)
    if t.player ~= nil then
        if not playersOk then return nil end
        local index = t.player
        if index == 0 then return nil end
        local m = gMarioStates[index]
        if m == nil or m.pos == nil or not same_room(index) then return nil end
        if markers.hidden(index) then return nil end
        if OF.util.asks(OF.spectate, "is_spectating") and OF.spectate.is_spectating(index) then
            return nil
        end
        return m.pos.x, m.pos.y, m.pos.z, t.lift or markers.PLAYER_LIFT
    end
    local p = t.pos
    if type(p) ~= "table" or p.x == nil then return nil end
    return p.x, p.y or 0, p.z, t.lift or markers.PLACE_LIFT
end

markers.resolve = resolve

function markers.BY_PRIORITY(a, b)
    if a.priority ~= b.priority then return a.priority > b.priority end
    if a.dist ~= b.dist then return a.dist < b.dist end
    return a.id < b.id
end

function markers.render_targets()
    local hud = OF.hud
    local me = gMarioStates[0]
    if hud == nil or me == nil or me.pos == nil then return {} end
    local now = hud.now()
    local mode = OF.gamemodes.current()
    local playersOk = markers.players_marked(mode)
    local list = markers.targets(0)
    local sw, sh = hud.screen()
    local drawn = {}
    local cued = false

    local rows = {}
    for _, t in ipairs(list) do
        local x, y, z, lift = resolve(t, playersOk)
        if x ~= nil then
            local id = tostring(t.id)
            local st = tstate[id]
            local dx, dy, dz = x - me.pos.x, y - me.pos.y, z - me.pos.z
            local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
            if st == nil or now - (st.seen or -100) > 2 then
                st = { born = now, labelAt = now, alpha = 0, form = nil, near = dist < markers.NEAR_IN,
                       label = t.label, x = x, y = y, z = z, fresh = true }
                tstate[id] = st
            else
                st.fresh = false
                local jx, jz = x - st.x, z - st.z
                if t.label ~= st.label or (t.player == nil and jx * jx + jz * jz > markers.MOVED ^ 2) then
                    st.labelAt = now
                    st.moved = true
                end
            end
            st.seen, st.label, st.x, st.y, st.z = now, t.label, x, y, z
            if st.near then st.near = dist <= markers.NEAR_OUT else st.near = dist < markers.NEAR_IN end
            onePos.x, onePos.y, onePos.z = x, y, z
            local where, px, py, angle = hud.marker_locate(onePos, { lift = lift, id = "t:" .. id })
            local form
            local compass = t.compass or "offscreen"
            local floor = markers.COMPASS_FLOOR
            if t.ring ~= nil and t.ring.radius ~= nil then floor = math.max(floor, t.ring.radius) end
            if where == "edge" then
                if compass == "always" or (compass == "offscreen" and dist > floor) then form = "edge" end
            elseif where == "on" then
                if st.near and t.overhead ~= true then
                    if t.ring ~= nil then form = "ring" end
                else
                    form = "far"
                end
            end
            rows[#rows + 1] = { t = t, id = id, st = st, form = form, dist = dist, x = x, y = y, z = z,
                                lift = lift, px = px, py = py, angle = angle,
                                priority = tonumber(t.priority) or 50 }
        end
    end

    table.sort(rows, markers.BY_PRIORITY)
    local edges, ons, kept = 0, 0, {}
    for _, row in ipairs(rows) do
        if row.form == "edge" then
            local merged = false
            for _, k in ipairs(kept) do
                if math.abs(k.px - row.px) < markers.MERGE_PX and math.abs(k.py - row.py) < markers.MERGE_PX then
                    merged = true
                end
            end
            if merged or edges >= markers.EDGE_CAP then
                row.form = nil
            else
                edges = edges + 1
                kept[#kept + 1] = row
            end
        elseif row.form == "far" then
            if ons >= markers.ON_CAP then row.form = nil else ons = ons + 1 end
        end
    end

    local sight = markers.look("sight")
    local wantedPlayers, wantedPoints = {}, {}
    for _, row in ipairs(rows) do
        if sight and row.form == "far" and row.t.occlude ~= false then
            if row.t.player ~= nil then
                wantedPlayers[#wantedPlayers + 1] = row.t.player
            else
                wantedPoints[#wantedPoints + 1] = { id = row.id, x = row.x, y = row.y + 60, z = row.z }
            end
        end
    end
    for index, at in pairs(sightWantedAt) do
        if sight and now - at <= 2 then
            local dup = false
            for _, w in ipairs(wantedPlayers) do if w == index then dup = true end end
            if not dup then wantedPlayers[#wantedPlayers + 1] = index end
        else
            sightWantedAt[index] = nil
        end
    end
    for _, w in ipairs(markers.take_count_wants()) do wantedPoints[#wantedPoints + 1] = w end
    markers.tick_sight(wantedPlayers)
    markers.tick_points(wantedPoints, math.max(1, SIGHT_BUDGET - #wantedPlayers))

    local avoid = {}
    for _, row in ipairs(rows) do
        local st, t = row.st, row.t
        if row.form ~= st.form then
            if st.form ~= nil and st.alpha > 0 then
                st.fading = { form = st.form, alpha = st.alpha, px = st.px, py = st.py, angle = st.rimAngle }
            end
            st.form = row.form
            st.alpha = 0
        end
        st.px, st.py, st.rimAngle = row.px, row.py, row.angle
        local target = row.form ~= nil and 1 or 0
        st.alpha = approach(st.alpha, target, 1 / markers.FADE_IN, 1 / markers.FADE_OUT)

        if (st.fresh or st.moved) and row.priority >= 80 and st.cuedAt ~= st.labelAt then
            st.cuedAt = st.labelAt
            st.pulseUntil = now + markers.CUE_PULSES
            if not cued and type(hud.cue) == "function" then
                hud.cue("objective")
                cued = true
            end
        end
        st.moved = false
        if t.urgent and not st.urgent and type(hud.cue) == "function" then hud.cue("alarm") end
        st.urgent = t.urgent == true

        local tone = markers.target_tone(t.tone)
        local label = nil
        if now - (st.labelAt or now) < markers.LABEL_FRAMES then label = t.label end
        local pulse = st.urgent or (st.pulseUntil ~= nil and now < st.pulseUntil)

        if st.fading ~= nil then
            st.fading.alpha = st.fading.alpha - 1 / markers.CROSSFADE
            if st.fading.alpha <= 0 or st.fading.form == "ring" then st.fading = nil end
        end
        if st.fading ~= nil and (st.fading.form == "edge" or st.fading.form == "far") then
            hud.marker(row, nil, tone, nil, { lift = row.lift, alpha = 255 * st.fading.alpha, icon = t.icon,
                placed = { st.fading.form == "edge" and "edge" or "on", st.fading.px, st.fading.py, st.fading.angle } })
        end

        local a = st.alpha
        if sight and row.form == "far" and t.occlude ~= false then
            local seen = t.player ~= nil and markers.sight(t.player) or markers.point_sight(row.id)
            a = a * (markers.OCCLUDED_SHARE + (1 - markers.OCCLUDED_SHARE) * seen)
        end
        if row.form == "edge" or row.form == "far" then
            if a > 0.01 then
                hud.marker(row, nil, tone, label, {
                    lift = row.lift, alpha = 255 * a, pulse = pulse, avoid = avoid,

                    icon = type(t.icon) == "table" and t.icon or nil,
                    placed = { row.form == "edge" and "edge" or "on", row.px, row.py, row.angle },
                })
            end
        end

        if t.ring ~= nil and t.ring.radius ~= nil and st.near then
            markers.ring("target:" .. row.id, row, t.ring.radius, tone,
                { alpha = t.ring.alpha or 200, width = t.ring.width, contested = t.contested })
        end
        drawn[#drawn + 1] = { id = row.id, form = row.form, alpha = a, x = row.px, y = row.py,
                              label = label, pulse = pulse }
    end
    markers.lastPass = drawn
    return drawn
end

local hideVeto = nil

function markers.set_hide_veto(fn)
    hideVeto = fn
end

function markers.hidden(localIndex)

    local scope = OF.roundscope
    if scope ~= nil and scope.hides_body ~= nil and scope.hides_body(localIndex) then
        return true
    end
    if hideVeto == nil then return false end
    local ok, hidden = pcall(hideVeto, localIndex)
    return ok and hidden == true
end

local function render()

    if not markers.on() or OF.gamemodes == nil or OF.gamemodes.is_running == nil
        or not OF.gamemodes.is_running() then
        markers.forget_pass()
        return
    end
    local me = gMarioStates[0]
    if me == nil then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)
    if OF.util.menu_has_screen() then return end

    if OF.util.asks(OF.hud, "card_up") and OF.hud.card_up() then
        markers.forget_pass()
        return
    end

    if OF.util.asks(OF.roundscope, "outside_the_round") and OF.roundscope.outside_the_round() then
        markers.forget_pass()
        return
    end

    markers.render_targets()
end

local textures = {}

local function texture(name)
    if textures[name] ~= nil then return textures[name] end
    if get_texture_info == nil then return nil end
    local ok, info = pcall(get_texture_info, name)
    if not ok or info == nil then

        textures[name] = false
        return nil
    end
    textures[name] = info
    return info
end

local WEDGE_STEP = 0x100
local WEDGES = 8

function markers.wedges(localIndex)
    local m = gMarioStates[localIndex]
    if m == nil or m.health == nil then return nil end
    if m.health <= 0 then return 0 end
    return math.min(math.floor(m.health / WEDGE_STEP), WEDGES)
end

local RADAR_COIN_FRAMES = {
    "coin_seg3_texture_03005780",
    "coin_seg3_texture_03005F80",
    "coin_seg3_texture_03006780",
    "coin_seg3_texture_03006F80",
}

local RADAR_S = "texture_hud_char_S"
function markers.radar_frame(timer)
    return (math.floor((timer or 0) / 4) % 4) + 1
end

function markers.radar_wanted()
    if OF.rules == nil or OF.rules.value == nil then return false end
    return OF.rules.value("redradar") == 1
end

function markers.secret_radar_wanted()
    if OF.rules == nil or OF.rules.value == nil then return false end
    return OF.rules.value("secretradar") == 1
end

function markers.area_count(behaviourId, field)
    local m = gMarioStates[0]
    local area = m ~= nil and m.area or nil
    local total = area ~= nil and area[field] or nil
    if type(total) ~= "number" or total <= 0 then return nil end
    if count_objects_with_behavior == nil or get_behavior_from_id == nil then return nil end
    local ok, left = pcall(count_objects_with_behavior, get_behavior_from_id(behaviourId))
    if not ok or type(left) ~= "number" or left < 0 then return nil end
    local taken = math.max(0, math.min(total, total - left))
    return taken, total
end

function markers.red_coin_count()
    return markers.area_count(id_bhvRedCoin, "numRedCoins")
end

function markers.secret_count()
    return markers.area_count(id_bhvHiddenStarTrigger, "numSecrets")
end

function markers.trackers()
    local list = {}
    if markers.radar_wanted() then
        local taken, total = markers.red_coin_count()
        if total ~= nil then list[#list + 1] = { kind = "coin", taken = taken, total = total } end
    end
    if markers.secret_radar_wanted() then
        local taken, total = markers.secret_count()
        if total ~= nil then list[#list + 1] = { kind = "secret", taken = taken, total = total } end
    end
    return list
end

markers.TRACKER_MARKS = {
    coin = { behaviour = id_bhvRedCoin, label = "Red coin", tone = "bad" },
    secret = { behaviour = id_bhvHiddenStarTrigger, label = "Secret", tone = "info" },
}

function markers.tracker_target(kind)
    local mark = markers.TRACKER_MARKS[kind]
    local me = gMarioStates[0]
    if mark == nil or mark.behaviour == nil or me == nil or me.marioObj == nil then return nil end
    if obj_get_nearest_object_with_behavior_id == nil then return nil end
    local ok, o = pcall(obj_get_nearest_object_with_behavior_id, me.marioObj, mark.behaviour)
    if not ok or o == nil or type(o.oPosX) ~= "number" or type(o.oPosZ) ~= "number" then return nil end
    return o
end

local trackerSpot = {}
local function render_tracker_marks(list)
    local H = OF.hud
    if H == nil or type(H.marker) ~= "function" then return end
    local avoid = {}
    for _, t in ipairs(list) do
        if t.taken < t.total then
            local o = markers.tracker_target(t.kind)
            local mark = markers.TRACKER_MARKS[t.kind]
            if o ~= nil then
                trackerSpot.x, trackerSpot.y, trackerSpot.z = o.oPosX, o.oPosY or 0, o.oPosZ
                H.marker(trackerSpot, nil, mark.tone, mark.label, { lift = 60, avoid = avoid })
            end
        end
    end
end

markers.TRACKER_CHIP = 26
markers.TRACKER_GAP = 6
function markers.tracker_place(count, width)
    local H = OF.hud
    local sw, sh = H.screen()
    local x = H.MARGIN
    local y = math.max(H.MARGIN, OF.util.counters_bottom(sh) + 10)
    local h = count * (markers.TRACKER_CHIP + markers.TRACKER_GAP)
    if OF.util.asks(OF.gamemodes, "is_open") and OF.gamemodes.is_open() and type(H.round_zones) == "function" then
        for _, z in ipairs(H.round_zones()) do
            if x < z.x + z.w and x + (width or 160) > z.x and y < z.y + z.h and y + h > z.y then
                y = z.y + z.h + 6
            end
        end
    end
    return x, y
end

local function render_trackers()
    if OF.util.menu_has_screen() then return end

    if OF.util.game_hud_hidden() then return end
    local list = markers.trackers()
    if #list == 0 then return end
    local H = OF.hud
    if H == nil then return end
    djui_hud_set_resolution(RESOLUTION_DJUI)
    render_tracker_marks(list)
    djui_hud_set_resolution(RESOLUTION_DJUI)
    local size = markers.TRACKER_CHIP
    local icon = size - 10
    local widths, widest = {}, 0
    for i, t in ipairs(list) do
        t.text = tostring(t.taken) .. " / " .. tostring(t.total)
        widths[i] = 8 + icon + 8 + H.ink_width(t.text, "body") + 10
        widest = math.max(widest, widths[i])
    end
    local x, y = markers.tracker_place(#list, widest)
    for i, t in ipairs(list) do
        local cy = y + size / 2
        H.plate(x, y, widths[i], size, { alpha = 1, lit = true })
        if t.kind == "coin" then
            local info = texture(RADAR_COIN_FRAMES[markers.radar_frame(get_global_timer())])
            if info ~= nil then
                djui_hud_set_color(255, 40, 40, 255)
                djui_hud_render_texture(info, x + 8, cy - icon / 2, icon / (info.width or icon),
                    icon / (info.height or icon))
            end
        else
            local info = texture(RADAR_S)
            if info ~= nil then
                djui_hud_set_color(255, 255, 255, 255)
                djui_hud_render_texture(info, x + 8, cy - icon / 2, icon / (info.width or icon),
                    icon / (info.height or icon))
            end
        end
        local done = t.taken >= t.total
        H.text_mid(t.text, x + 8 + icon + 8, cy, "body", done and "good" or "ink", 255, "left")
        y = y + size + markers.TRACKER_GAP
    end
    djui_hud_set_resolution(RESOLUTION_DJUI)
end

local DOOR_BAR_REACH = 600
local DOOR_BAR_RISE = 200

local DOOR_BAR_LIFT = HEAD_HEIGHT * 2

local DOOR_BAR_WIDTH = 64
local DOOR_BAR_HEIGHT = 5

function markers.door_crowd_fill(object)
    if object == nil then return nil end
    if not OF.util.asks(OF.rules, "door_crowd_bar") then return nil end
    local fill = OF.rules.door_crowd_bar(object)
    if type(fill) ~= "number" then return nil end
    return OF.util.clamp(fill, 0, 1)
end

function markers.door_at_hand()
    local me = gMarioStates[0]
    if me == nil or me.pos == nil then return nil end
    if obj_get_first_with_behavior_id == nil then return nil end

    local best, bestDist = nil, nil
    for _, behaviourId in ipairs({ id_bhvStarDoor, id_bhvDoor }) do
        if behaviourId ~= nil then
            local object = obj_get_first_with_behavior_id(behaviourId)
            while object ~= nil do
                local x, y, z = object.oPosX, object.oPosY, object.oPosZ
                if type(x) == "number" and type(y) == "number"
                    and type(z) == "number" then
                    local rise = me.pos.y - y
                    if rise < 0 then rise = -rise end
                    if rise <= DOOR_BAR_RISE then
                        local dx, dz = me.pos.x - x, me.pos.z - z
                        local flat = dx * dx + dz * dz
                        if flat <= DOOR_BAR_REACH * DOOR_BAR_REACH
                            and (bestDist == nil or flat < bestDist) then
                            best, bestDist = object, flat
                        end
                    end
                end
                object = obj_get_next_with_same_behavior_id(object)
            end
        end
    end
    return best
end

local function render_door_crowd()

    if not markers.on() then return end
    if not OF.util.asks(OF.rules, "crowd_wanted") then return end
    if OF.rules.crowd_wanted() == nil then return end
    if OF.util.menu_has_screen() then return end

    local object = markers.door_at_hand()
    if object == nil then return end

    local fill = markers.door_crowd_fill(object)
    if fill == nil then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    local x, y, offscreen = markers.place(object.oPosX,
        (object.oPosY or 0) + DOOR_BAR_LIFT, object.oPosZ)

    if offscreen then return end

    local gold = OF.util.gold()
    OF.util.meter(x - DOOR_BAR_WIDTH / 2, y, DOOR_BAR_WIDTH, DOOR_BAR_HEIGHT,
        fill, gold, { r = 40, g = 40, b = 40 })
end

local RADAR_SIZE = 150
local RADAR_SCALE = 40
local RADAR_MARGIN = 16
local RADAR_DOT = 6

function markers.radar_shown()
    if not markers.on() or not markers.look("radar") then return false end
    if OF.util.menu_has_screen() then return false end

    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() == true then
        return false
    end
    if OF.util.asks(OF.camera, "is_photographing")
        and OF.camera.is_photographing(0) then
        return false
    end
    return gMarioStates[0] ~= nil and gMarioStates[0].pos ~= nil
end

function markers.radar_dots()
    local dots = {}
    local me = gMarioStates[0]
    local np0 = gNetworkPlayers[0]
    if me == nil or me.pos == nil or np0 == nil then return dots end

    local vx, vz = 0, 1
    if gLakituState ~= nil and gLakituState.pos ~= nil
        and gLakituState.focus ~= nil then
        local ax = (gLakituState.focus.x or 0) - (gLakituState.pos.x or 0)
        local az = (gLakituState.focus.z or 0) - (gLakituState.pos.z or 0)
        local flat = math.sqrt(ax * ax + az * az)
        if flat > 0.0001 then vx, vz = ax / flat, az / flat end
    end
    local rx, rz = -vz, vx

    local half = RADAR_SIZE / 2 - RADAR_DOT
    for _, entry in ipairs(OF.util.connected_players()) do
        local i = entry.localIndex
        local np = entry.np
        local m = gMarioStates[i]

        if i ~= 0 and np ~= nil and m ~= nil and m.pos ~= nil
            and OF.util.same_world(i) and not markers.hidden(i) then
            local dx, dz = m.pos.x - me.pos.x, m.pos.z - me.pos.z
            local ahead = (dx * vx + dz * vz) / RADAR_SCALE
            local side = (dx * rx + dz * rz) / RADAR_SCALE
            if math.abs(ahead) <= half and math.abs(side) <= half then

                table.insert(dots, { localIndex = i, x = -side, y = -ahead })
            end
        end
    end
    return dots
end

function markers.radar_colour(localIndex)
    if OF.util.asks(OF.teams, "of") and OF.util.asks(OF.teams, "color_of")
        and OF.teams.of(localIndex) ~= OF.teams.NONE then
        return OF.teams.color_of(localIndex)
    end
    return OF.util.player_color(localIndex)
end

local function render_minimap()
    if not markers.radar_shown() then return end
    djui_hud_set_resolution(RESOLUTION_DJUI)
    local w = djui_hud_get_screen_width()
    local h = djui_hud_get_screen_height()
    local left = w - RADAR_MARGIN - RADAR_SIZE
    local top = h - RADAR_MARGIN - RADAR_SIZE
    local cx, cy = left + RADAR_SIZE / 2, top + RADAR_SIZE / 2

    djui_hud_set_color(0, 0, 0, 140)
    djui_hud_render_rect(left, top, RADAR_SIZE, RADAR_SIZE)

    for _, dot in ipairs(markers.radar_dots()) do

        local r, g, b = markers.radar_colour(dot.localIndex)
        djui_hud_set_color(r, g, b, 255)
        djui_hud_render_rect(cx + dot.x - RADAR_DOT / 2, cy + dot.y - RADAR_DOT / 2,
            RADAR_DOT, RADAR_DOT)
    end

    djui_hud_set_color(255, 255, 255, 255)
    djui_hud_render_rect(cx - RADAR_DOT / 2, cy - RADAR_DOT / 2, RADAR_DOT, RADAR_DOT)
    djui_hud_set_color(255, 255, 255, 255)
end
markers.render_minimap = render_minimap

hook_event(HOOK_ON_HUD_RENDER, render_minimap)
hook_event(HOOK_ON_HUD_RENDER, render_trackers)

function markers.render_hud()
    render()
    if OF.tags ~= nil and type(OF.tags.draw_round_tags) == "function" then OF.tags.draw_round_tags() end
    if OF.hud ~= nil and type(OF.hud.render_prompt) == "function" then OF.hud.render_prompt() end
    markers.tick_rings()
end
hook_event(HOOK_ON_HUD_RENDER, markers.render_hud)
hook_event(HOOK_ON_HUD_RENDER, render_door_crowd)

function markers.build_rows(panel)
    local rows = {}
    if panel == nil or panel.row == nil or panel.header_row == nil then
        return rows
    end

    local ordered = {}
    for _, look in ipairs(markers.looks()) do
        if not look.drawn then table.insert(ordered, look) end
    end
    for _, look in ipairs(markers.looks()) do
        if look.drawn then table.insert(ordered, look) end
    end
    local half = nil
    for _, look in ipairs(ordered) do
        if look.drawn ~= half then
            half = look.drawn
            if half then
                local heading = panel.header_row("How a mark is drawn")
                if panel.with_help ~= nil then
                    heading = panel.with_help(heading,
                        "not through a wall")
                end
                table.insert(rows, heading)
            else
                table.insert(rows, panel.header_row("What a mark over a player shows"))
            end
        end
        local key = look.key
        local on = markers.look(key)

        local text = panel.tick(on, OF.lang.t(look.name))

        local r, g, b = 255, 255, 255
        if not on then r, g, b = 150, 150, 150 end

        table.insert(rows, panel.with_help(
            panel.row(text, r, g, b, function()
                OF.util.report(markers.set_look(key, not markers.look(key)))
            end),
            look.blurb ~= nil and OF.lang.t(look.blurb) or nil))
    end
    return rows
end
