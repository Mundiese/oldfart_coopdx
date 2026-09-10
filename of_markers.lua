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
      blurb = "the bomb, the ball, the runner, your side - off leaves the"
              .. " round's places and arrows alone" },
    { key = "arrow",  default = true,
      name = "Point an arrow at what is off your screen",
      blurb = "the game's own radar arrow, on the mark against the border" },
    { key = "near",   default = true,
      name = "Show how near an off-screen mark is",
      blurb = "a bar under it - the fuller, the closer" },
    { key = "health", default = true,
      name = "Show when your side is hurt",
      blurb = "the power meter's eight wedges, over a team-mate who has lost one" },
    { key = "leader", default = true,
      name = "Mark whoever is leading the round",
      blurb = "the one player everybody else has to stop" },
    { key = "fade",   default = true,
      name = "Fade marks into the distance",
      blurb = "so a lobby of sixteen is not a wall of marks" },
    { key = "shrink", default = true,
      name = "Shrink marks into the distance",
      blurb = "near reads as near, without a number" },
    { key = "crowd",  default = true,
      name = "Mark everybody on your side",
      blurb = "off leaves only what the round itself is about" },

    { key = "sight",  default = true,
      name = "Hide marks behind walls",
      blurb = "a mark for somebody out of sight fades away instead of floating"
              .. " over the wall they are behind" },
}

local LOOK_BY_KEY = {}
for _, look in ipairs(LOOKS) do LOOK_BY_KEY[look.key] = look end

function markers.looks()
    local list = {}
    for index, look in ipairs(LOOKS) do
        list[index] = { key = look.key, name = look.name,
                        blurb = look.blurb, default = look.default }
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

        return math.max(MARGIN, math.min(screenWidth - MARGIN, screen.x)),
               math.max(MARGIN, math.min(screenHeight - MARGIN, screen.y)),
               true
    end

    local borderX, borderY = border_position(fromX, fromZ, screenWidth, screenHeight)
    return borderX, borderY, true
end

local FAN_STEP = 24
local FAN_LIMIT = 5

local fanTaken = {}

function markers.forget_fan()
    fanTaken = {}
end

function markers.fan(x, y, width)
    if x == nil or y == nil then return y end
    width = width or 0

    local step = -FAN_STEP
    if y + step * FAN_LIMIT < MARGIN then step = FAN_STEP end

    for _ = 1, FAN_LIMIT do
        local clash = false
        for _, box in ipairs(fanTaken) do
            if math.abs(x - box.x) < (width + box.width) * 0.5
                and math.abs(y - box.y) < FAN_STEP then
                clash = true
                break
            end
        end
        if not clash then break end
        y = y + step
    end

    table.insert(fanTaken, { x = x, y = y, width = width })
    return y
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

    if #wanted > 0 then
        local was = OF.util.optional("camera_get_checking_surfaces", false) == true
        OF.util.optional("camera_set_checking_surfaces", nil, true)

        local spent, asked = 0, 0
        while spent < SIGHT_BUDGET and asked < #wanted do
            sightOrder = sightOrder + 1
            if sightOrder > #wanted then sightOrder = 1 end
            local index = wanted[sightOrder]
            local seen, casts = body_seen(index)
            sightTarget[index] = seen and 1 or 0
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

    if markers.look("crowd")
        and OF.util.asks(OF.teams, "in_play") and OF.teams.in_play()
        and OF.teams.of(localIndex) ~= OF.teams.NONE
        and OF.teams.same(0, localIndex) then
        local team = OF.teams.find(OF.teams.of(localIndex))
        if team ~= nil then return "team", team.r, team.g, team.b end
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

local RING_LABEL_LIFT = 200

local RING_ARROW_CLEAR = 60
local RING_ARROW_LENGTH = 180
local RING_ARROW_WIDTH = 4

function markers.place_ring(spot, radius, look)
    if type(spot) ~= "table" or spot.x == nil then return 0 end
    if type(radius) ~= "number" or radius <= 0 then return 0 end
    if not OF.util.asks(OF.util, "world_ring") then return 0 end
    look = look or {}

    local r = look.r or 255
    local g = look.g or 255
    local b = look.b or 255
    local alpha = look.alpha or 200

    local drawn = OF.util.world_ring(spot, radius, look.segments or 40,
        look.size or 3, r, g, b, alpha) or 0

    local distance = look.distance
    local close = distance ~= nil and distance <= radius

    if look.arrow == true and not close
        and OF.util.asks(OF.util, "world_arrow") then
        OF.util.world_arrow(
            { x = spot.x, y = spot.y + RING_LABEL_LIFT + RING_ARROW_CLEAR,
              z = spot.z },
            RING_ARROW_LENGTH, RING_ARROW_WIDTH, r, g, b, alpha)
    end

    local label = look.label
    if type(label) ~= "string" or label == "" then return drawn end
    if close then return drawn end
    if not OF.util.asks(OF.util, "world_screen") then return drawn end

    local at = { x = spot.x, y = spot.y + RING_LABEL_LIFT, z = spot.z }
    if not OF.util.world_screen(at, screen) then return drawn end

    OF.util.world_label(screen.x, screen.y, label, 1.0, r, g, b, 255)
    return drawn
end

local markWas = {}
local markNow = {}

local JUMP_SHARE = 0.2

function markers.forget_marks()
    markWas, markNow = {}, {}
end

function markers.remembered(id)
    if id == nil then return nil end
    return markWas[id]
end

function markers.marks_drawn()
    markWas, markNow = markNow, {}
end

function markers.moves()
    if not (OF.util.asks(OF.util, "interpolates") and OF.util.interpolates()) then
        return false
    end
    return OF.util.asks(OF.util, "box_interpolates")
        and OF.util.box_interpolates() == true
end

local function mark_step(id, now, pinned)

    if id == nil or pinned then return nil end

    local here = gNetworkPlayers[0]
    now.level = here ~= nil and here.currLevelNum or nil
    now.area = here ~= nil and here.currAreaIndex or nil

    local was = markWas[id]

    markNow[id] = now

    if was == nil then return nil end
    if was.level ~= now.level or was.area ~= now.area then return nil end
    if not markers.moves() then return nil end

    if was.x == now.x and was.y == now.y and was.scale == now.scale then
        return nil
    end

    local cap = djui_hud_get_screen_height() * JUMP_SHARE
    if math.abs(now.x - was.x) > cap or math.abs(now.y - was.y) > cap then
        return nil
    end

    return was
end

local function render_places()
    local me = gMarioStates[0]
    if me == nil then return end

    for at, spot in ipairs(markers.places()) do
        local dx, dy, dz = spot.x - me.pos.x, spot.y - me.pos.y, spot.z - me.pos.z
        local distance = math.sqrt(dx * dx + dy * dy + dz * dz)

        local x, y, offscreen = markers.place(spot.x, spot.y + HEAD_HEIGHT, spot.z)

        local label = spot.label or "the hill"
        local follow = spot.follow == true or FOLLOWED[label] == true
        if not offscreen or follow then

            markers.draw(label, x, y,
                spot.r or OF.util.gold().r, spot.g or OF.util.gold().g,
                spot.b or OF.util.gold().b, distance, offscreen,
                { bearing = markers.bearing(me, spot.x, spot.z),
                  id = "place:" .. tostring(spot.id or at) .. ":" .. label })
        end
    end
end

local function render()

    if not markers.on() then markers.forget_marks() return end
    if OF.gamemodes == nil or OF.gamemodes.is_running == nil then
        markers.forget_marks()
        return
    end
    if not OF.gamemodes.is_running() then markers.forget_marks() return end

    local me = gMarioStates[0]
    if me == nil then markers.forget_marks() return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    markers.forget_fan()

    if OF.util.menu_has_screen() then markers.forget_marks() return end

    render_places()

    local wanted = {}

    passLeader = markers.leader()
    passLeaderKnown = true

    for _, entry in ipairs(OF.util.connected_players()) do
        local localIndex = entry.localIndex
        local kind, r, g, b = markers.for_player(localIndex)

        if kind ~= nil then
            local m = gMarioStates[localIndex]
            local np = entry.np

            if m ~= nil and np ~= nil
                and np.currLevelNum == gNetworkPlayers[0].currLevelNum
                and np.currAreaIndex == gNetworkPlayers[0].currAreaIndex then

                local dx = m.pos.x - me.pos.x
                local dy = m.pos.y - me.pos.y
                local dz = m.pos.z - me.pos.z
                local distance = math.sqrt(dx * dx + dy * dy + dz * dz)

                if distance < MAX_DISTANCE or FOLLOWED[kind] then
                    local x, y, offscreen = markers.place(
                        m.pos.x, m.pos.y + HEAD_HEIGHT, m.pos.z)
                    if not offscreen or FOLLOWED[kind] then

                        local wedges = nil
                        if kind == "team" then
                            wedges = markers.wedges(localIndex)
                        end

                        local seen = nil
                        if markers.occluded(kind) then
                            table.insert(wanted, localIndex)
                            seen = markers.sight(localIndex)
                        end

                        local named = nil
                        if kind == "team" then
                            local np = gNetworkPlayers[localIndex]
                            if np ~= nil then
                                named = OF.util.short_name(np.name,
                                    TEAM_NAME_CUT)
                            end
                        end
                        markers.draw(kind, x, y, r, g, b, distance, offscreen, {
                            bearing = markers.bearing(me, m.pos.x, m.pos.z),
                            wedges = wedges,
                            sight = seen,
                            name = named,
                            id = "player:" .. kind .. ":" .. localIndex,
                        })
                    end
                end
            end
        end
    end

    passLeaderKnown = false

    markers.tick_sight(wanted)

    markers.marks_drawn()
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

local ARROW_TEXTURE = "texture_hud_char_arrow_up"
local CLOSENESS_HEIGHT = 2

local MARK_SCALE = 0.6
local SHRINK_FLOOR = 0.75

local TEAM_SCALE = 0.9

local TEAM_NAME_CUT = 12

local ARROW_BOX = 8
local ARROW_GAP = 4

local WEDGE_FULL = 0x880
local WEDGE_STEP = 0x100
local WEDGES = 8
local PIP_WIDTH = 3
local PIP_GAP = 1
local PIP_HEIGHT = 3

function markers.wedges(localIndex)
    local m = gMarioStates[localIndex]
    if m == nil or m.health == nil then return nil end
    if m.health <= 0 then return 0 end
    return math.min(math.floor(m.health / WEDGE_STEP), WEDGES)
end

local function wedge_colour(wedges)
    if wedges <= 2 then return 255, 96, 96 end
    if wedges <= 4 then return 255, 200, 90 end
    return 120, 220, 120
end

function markers.bearing(m, x, z)
    if m == nil or m.pos == nil or x == nil or z == nil then return nil end
    if gLakituState == nil or gLakituState.pos == nil then return nil end
    local toTarget = atan2s(z - m.pos.z, x - m.pos.x)
    local toCamera = atan2s(m.pos.z - gLakituState.pos.z,
                            m.pos.x - gLakituState.pos.x)
    return toTarget - toCamera
end

local pipWas = { width = PIP_WIDTH, height = PIP_HEIGHT }

function markers.draw(kind, x, y, r, g, b, distance, pinned, extra)
    extra = extra or {}

    local text = kind

    if kind == "team" then
        text = "*"
        if extra.name ~= nil and extra.name ~= "" then text = extra.name end
    end
    if kind == "prey" then text = "!" end

    local close = 1 - math.max(0, math.min(1, (distance or 0) / MAX_DISTANCE))

    local alpha = 255
    if markers.look("fade") then
        alpha = math.floor(120 + 135 * close)
    end

    if extra.sight ~= nil then
        if extra.sight <= SIGHT_GONE then return end
        alpha = math.floor(alpha * extra.sight)
    end

    local base = MARK_SCALE
    if kind == "team" then base = TEAM_SCALE end
    local scale = base
    if markers.look("shrink") then
        scale = base * (SHRINK_FLOOR + (1 - SHRINK_FLOOR) * close)
    end

    local width, height = OF.util.text_size(text, scale)

    local arrow = nil
    if pinned and extra.bearing ~= nil and markers.look("arrow") then
        arrow = texture(ARROW_TEXTURE)
    end

    local lead = 0
    if arrow ~= nil then lead = ARROW_BOX + ARROW_GAP end

    local boxWidth = width + lead

    y = markers.fan(x, y, boxWidth + 10)

    local left = x - boxWidth * 0.5

    local was = mark_step(extra.id, {
        x = x, y = y, scale = scale, box = boxWidth, height = height,
        lead = lead,
        pips = extra.wedges ~= nil and extra.wedges < WEDGES
            and markers.look("health"),
    }, pinned)
    local wasLeft = nil
    if was ~= nil then wasLeft = was.x - was.box * 0.5 end

    OF.util.plate(left - 5, y - height - 4, boxWidth + 10, height + 6,
        { alpha = alpha,
          from = was ~= nil
              and { x = wasLeft - 5, y = was.y - was.height - 4,
                    width = was.box + 10, height = was.height + 6 }
              or nil })

    if arrow ~= nil then

        djui_hud_set_color(r, g, b, alpha)
        djui_hud_set_rotation(extra.bearing + 0x4000, 0.5, 0.5)
        djui_hud_render_texture(arrow, left,
            y - height - 4 + (height + 6 - ARROW_BOX) * 0.5,
            ARROW_BOX / (arrow.width or ARROW_BOX),
            ARROW_BOX / (arrow.height or ARROW_BOX))

        djui_hud_set_rotation(0, 0, 0)
    end

    OF.util.text(text, left + lead, y - height - 2, scale, r, g, b, alpha,
        was ~= nil
            and { x = wasLeft + was.lead, y = was.y - was.height - 2,
                  scale = was.scale }
            or nil)

    local look = OF.util.asks(OF.theme, "active") and OF.theme.active() or nil
    local empty = look ~= nil and look.title or { r = 28, g = 28, b = 38 }

    local function dimmed(value) return math.floor(value * (alpha / 255)) end

    if extra.wedges ~= nil and extra.wedges < WEDGES
        and markers.look("health") then
        local pipsWidth = WEDGES * PIP_WIDTH + (WEDGES - 1) * PIP_GAP
        local pipsLeft = x - pipsWidth * 0.5
        local pipsTop = y - height - 4 - PIP_HEIGHT - 3
        local hr, hg, hb = wedge_colour(extra.wedges)

        local pipsMoved = was ~= nil and was.pips == true
        if pipsMoved then
            pipWas.y = was.y - was.height - 4 - PIP_HEIGHT - 3
        end
        for pip = 1, WEDGES do
            local step = (pip - 1) * (PIP_WIDTH + PIP_GAP)
            local pipX = pipsLeft + step
            local from = nil
            if pipsMoved then
                pipWas.x = was.x - pipsWidth * 0.5 + step
                from = pipWas
            end
            if pip <= extra.wedges then
                OF.util.rect(pipX, pipsTop, PIP_WIDTH, PIP_HEIGHT,
                    dimmed(hr), dimmed(hg), dimmed(hb), alpha, from)
            else
                OF.util.rect(pipX, pipsTop, PIP_WIDTH, PIP_HEIGHT,
                    dimmed(empty.r), dimmed(empty.g), dimmed(empty.b), alpha,
                    from)
            end
        end
    end

    if not pinned then return end
    if not markers.look("near") then return end

    OF.util.meter(left - 5, y + 3, boxWidth + 10, CLOSENESS_HEIGHT, close,
        { r = dimmed(r), g = dimmed(g), b = dimmed(b) },
        { r = dimmed(empty.r), g = dimmed(empty.g), b = dimmed(empty.b) })
end

local RADAR_COIN_FRAMES = {
    "coin_seg3_texture_03005780",
    "coin_seg3_texture_03005F80",
    "coin_seg3_texture_03006780",
    "coin_seg3_texture_03006F80",
}

local RADAR_S = "texture_hud_char_S"
local S_BOX_W, S_BOX_H = 14, 16

local COIN_BOX = 12

local RADAR_X = 24
local RADAR_BOTTOM = 31
local N64_HEIGHT = 240

function markers.radar_angle(m, target)
    if m == nil or target == nil then return nil end
    return markers.bearing(m, target.oPosX, target.oPosZ)
end

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

local RADAR_STEP = 30

function markers.radar_slot(coinShowing, which)
    if which == "coin" then return RADAR_BOTTOM end
    return coinShowing and (RADAR_BOTTOM + RADAR_STEP) or RADAR_BOTTOM
end

function markers.coin_radar_showing()
    if not markers.radar_wanted() then return false end
    local m = gMarioStates[0]
    if m == nil or m.marioObj == nil then return false end
    if obj_get_nearest_object_with_behavior_id == nil then return false end
    return obj_get_nearest_object_with_behavior_id(m.marioObj, id_bhvRedCoin) ~= nil
end

local function render_coin_radar()
    if not markers.radar_wanted() then return end
    if OF.util.menu_has_screen() then return end

    local m = gMarioStates[0]
    if m == nil or m.marioObj == nil then return end
    if obj_get_nearest_object_with_behavior_id == nil then return end

    local coin = obj_get_nearest_object_with_behavior_id(m.marioObj, id_bhvRedCoin)
    if coin == nil then return end

    local angle = markers.radar_angle(m, coin)
    if angle == nil then return end

    djui_hud_set_resolution(RESOLUTION_N64)
    djui_hud_set_font(FONT_NORMAL)

    local coinInfo = texture(RADAR_COIN_FRAMES[markers.radar_frame(get_global_timer())])
    local arrowInfo = texture(ARROW_TEXTURE)
    local y = N64_HEIGHT - markers.radar_slot(true, "coin")

    if coinInfo ~= nil then
        djui_hud_set_color(255, 0, 0, 255)
        djui_hud_render_texture(coinInfo, RADAR_X, y,
            COIN_BOX / (coinInfo.width or COIN_BOX),
            COIN_BOX / (coinInfo.height or COIN_BOX))
    end

    if arrowInfo ~= nil then

        djui_hud_set_color(255, 255, 255, 255)
        djui_hud_set_rotation(angle + 0x4000, 0.5, 0.5)
        djui_hud_render_texture(arrowInfo, RADAR_X + COIN_BOX + 4, y,
            ARROW_BOX / (arrowInfo.width or ARROW_BOX),
            ARROW_BOX / (arrowInfo.height or ARROW_BOX))
        djui_hud_set_rotation(0, 0, 0)
    end

    djui_hud_set_resolution(RESOLUTION_DJUI)
end

local function render_secret_radar()
    if not markers.secret_radar_wanted() then return end
    if OF.util.menu_has_screen() then return end

    local m = gMarioStates[0]
    if m == nil or m.marioObj == nil then return end
    if obj_get_nearest_object_with_behavior_id == nil then return end

    local secret = obj_get_nearest_object_with_behavior_id(m.marioObj,
        id_bhvHiddenStarTrigger)
    if secret == nil then return end

    local angle = markers.radar_angle(m, secret)
    if angle == nil then return end

    djui_hud_set_resolution(RESOLUTION_N64)
    djui_hud_set_font(FONT_NORMAL)

    local sInfo = texture(RADAR_S)
    local arrowInfo = texture(ARROW_TEXTURE)
    local y = N64_HEIGHT - markers.radar_slot(markers.coin_radar_showing(), "secret")

    if sInfo ~= nil then
        djui_hud_set_color(255, 255, 255, 255)
        djui_hud_render_texture(sInfo, RADAR_X, y,
            S_BOX_W / (sInfo.width or S_BOX_W),
            S_BOX_H / (sInfo.height or S_BOX_H))
    end

    if arrowInfo ~= nil then
        djui_hud_set_color(255, 255, 255, 255)
        djui_hud_set_rotation(angle + 0x4000, 0.5, 0.5)
        djui_hud_render_texture(arrowInfo, RADAR_X + S_BOX_W + 4, y,
            ARROW_BOX / (arrowInfo.width or ARROW_BOX),
            ARROW_BOX / (arrowInfo.height or ARROW_BOX))
        djui_hud_set_rotation(0, 0, 0)
    end

    djui_hud_set_resolution(RESOLUTION_DJUI)
end

hook_event(HOOK_ON_HUD_RENDER, render_coin_radar)
hook_event(HOOK_ON_HUD_RENDER, render_secret_radar)
hook_event(HOOK_ON_HUD_RENDER, render)

function markers.build_rows(panel)
    local rows = {}
    if panel == nil or panel.row == nil or panel.header_row == nil then
        return rows
    end

    table.insert(rows, panel.header_row("What a mark over a player shows"))
    for _, look in ipairs(markers.looks()) do
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
