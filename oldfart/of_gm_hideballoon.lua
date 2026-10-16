OF = OF or {}

local ROLE_PLAY = "playing"
local HIDE_STOPS = { thirty = 30, fifteen = 15, fortyfive = 45 }
local HIDE_DEFAULT = "thirty"
local ROUND_SECONDS = 30 + 180

local FIND_RANGE = 250

local HIDDEN_SCALE = 1.25

local GROUND_TOLERANCE = 40

local EARN_EVERY = 15
local FIND_POINTS = 3

local WALL_REACH = 150
local WALL_GAP = 2
local CHEST = 80
local PROBE_TURNS = 16

local HINT_BANDS = {
    { far = 800, word = "Hot", tone = "good" },
    { far = 1800, word = "Warm", tone = "warn" },
    { far = 3200, word = "Cold", tone = "info" },
}
local HINT_DEFAULT = "warmcold"
local roundPlace = nil
local myBalloon = nil
local locked = false
local lastScore = nil

local function hide_seconds()
    return HIDE_STOPS[OF.gamemodes.option_now("hide") or HIDE_DEFAULT]
        or HIDE_STOPS[HIDE_DEFAULT]
end

local function hide_seconds_showing()
    return HIDE_STOPS[OF.gamemodes.option_showing("hideballoon", "hide")
        or HIDE_DEFAULT] or HIDE_STOPS[HIDE_DEFAULT]
end

local function hiding()
    return OF.gamemodes.since_start() < hide_seconds()
end

local PLACE_BUTTONS = { L_TRIG, U_JPAD }

local function place_pressed()
    if not OF.util.asks(OF.input, "pressed") then return false end
    for _, button in ipairs(PLACE_BUTTONS) do
        if OF.input.pressed(button) then return true end
    end
    return false
end

local function pack_spot(x, y, z, yaw)
    if yaw ~= nil then
        return string.format("%.0f %.0f %.0f %.0f", x, y, z, math.floor(yaw) % 0x10000)
    end
    return string.format("%.0f %.0f %.0f", x, y, z)
end

local function unpack_spot(text)
    if type(text) ~= "string" then return nil end
    local x, y, z, yaw = text:match("^(%-?%d+)%s+(%-?%d+)%s+(%-?%d+)%s*(%d*)$")
    if x == nil then return nil end
    return { x = tonumber(x), y = tonumber(y), z = tonumber(z),
             yaw = (yaw ~= nil and yaw ~= "") and tonumber(yaw) or nil }
end

local function grounded_spot(m)
    if m == nil or m.pos == nil then return nil end
    local found = OF.util.optional("find_floor_height", nil,
        m.pos.x, m.pos.y + 100, m.pos.z)
    if type(found) ~= "number" or found <= gLevelValues.floorLowerLimit then
        return nil
    end
    if math.abs(found - m.pos.y) > GROUND_TOLERANCE then return nil end
    return { x = m.pos.x, y = found, z = m.pos.z }
end

local function wall_ahead(m)
    local yaw = m.faceAngle.y
    local dx, dz = sins(yaw), coss(yaw)
    local cy = m.pos.y + CHEST
    local hit = OF.util.optional("collision_find_surface_on_ray", nil,
        m.pos.x, cy, m.pos.z, dx * WALL_REACH, 0, dz * WALL_REACH)
    if hit == nil or hit.surface == nil or hit.hitPos == nil then return nil end
    local n = hit.surface.normal
    if n == nil or math.abs(n.y or 0) > 0.3 then return nil end
    local hx, hz = hit.hitPos.x, hit.hitPos.z
    if (hx - m.pos.x) ^ 2 + (hz - m.pos.z) ^ 2 > WALL_REACH * WALL_REACH + 1 then return nil end
    local flat = math.sqrt(n.x * n.x + n.z * n.z)
    if flat < 0.01 then return nil end
    return { x = hx, y = hit.hitPos.y, z = hz, nx = n.x / flat, nz = n.z / flat }
end

local function balloon_clips(kx, ky, kz, scale)
    local out = {}
    local B = OF.ball.BALLOON
    for _, band in ipairs(B.bands) do
        local r = band.r * scale
        local ay = ky + (band.y + B.knot) * scale
        for k = 0, PROBE_TURNS - 1 do
            local a = k * 0x10000 / PROBE_TURNS
            local dx, dz = sins(a), coss(a)
            local reach = r + WALL_GAP + 1
            local hit = OF.util.optional("collision_find_surface_on_ray", nil,
                kx, ay, kz, dx * reach, 0, dz * reach)
            if hit ~= nil and hit.surface ~= nil and hit.hitPos ~= nil then
                local n = hit.surface.normal
                if n ~= nil and math.abs(n.y or 0) <= 0.3 then
                    local flat = math.sqrt(n.x * n.x + n.z * n.z)
                    local nx, nz = n.x / flat, n.z / flat
                    local square = (kx - hit.hitPos.x) * nx + (kz - hit.hitPos.z) * nz
                    if square < r then
                        table.insert(out, { nx = nx, nz = nz, depth = r - square })
                    end
                end
            end
        end
    end
    return out
end

local function wall_spot(m)
    if m == nil or m.pos == nil then return nil end
    local w = wall_ahead(m)
    if w == nil then return nil end
    local B = OF.ball.BALLOON
    local s = HIDDEN_SCALE
    local off = B.radius * s + WALL_GAP
    local kx, kz = w.x + w.nx * off, w.z + w.nz * off
    local ky = m.pos.y + CHEST - B.knot * s

    for _, y in ipairs({ ky, ky + (B.knot + 38) * s }) do
        local hit = OF.util.optional("collision_find_surface_on_ray", nil,
            kx, y, kz, -w.nx * (off + 20), 0, -w.nz * (off + 20))
        if hit == nil or hit.surface == nil then return nil end
    end

    for _ = 1, 4 do
        local clips = balloon_clips(kx, ky, kz, s)
        if #clips == 0 then
            local yaw = OF.util.optional("atan2s", 0, w.nz, w.nx) or 0
            return { x = kx, y = ky, z = kz, yaw = yaw }
        end
        local worst = clips[1]
        for _, c in ipairs(clips) do if c.depth > worst.depth then worst = c end end
        kx = kx + worst.nx * (worst.depth + WALL_GAP)
        kz = kz + worst.nz * (worst.depth + WALL_GAP)
    end
    return nil
end

local function find_entries(text)
    local out = {}
    if type(text) ~= "string" then return out end
    for gi, sec in text:gmatch("(%-?%d+):(%d+)") do
        table.insert(out, { gi = tonumber(gi), at = tonumber(sec) })
    end
    return out
end

local function already_found(text, gi)
    for _, e in ipairs(find_entries(text)) do
        if e.gi == gi then return true end
    end
    return false
end

local function record_find(text, gi, at)
    local entry = tostring(gi) .. ":" .. tostring(math.max(0, math.floor(at or 0)))
    if type(text) ~= "string" or text == "" then return entry end
    return text .. "," .. entry
end

local function found_count(localIndex)
    local row = gPlayerSyncTable[localIndex]
    return #find_entries(row ~= nil and row.ofBalFound or nil)
end

local function hunt_length()
    local limit = tonumber(gGlobalSyncTable.ofGmLimit) or ROUND_SECONDS
    if limit <= 0 then limit = ROUND_SECONDS end
    return math.max(0, limit - hide_seconds())
end

local function hunt_seconds()
    local t = OF.gamemodes.since_start() - hide_seconds()
    return math.max(0, math.min(t, hunt_length()))
end

local function found_at(gi)
    local first = nil
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_PLAY)) do
        local row = gPlayerSyncTable[entry.localIndex]
        for _, e in ipairs(find_entries(row ~= nil and row.ofBalFound or nil)) do
            if e.gi == gi and (first == nil or e.at < first) then first = e.at end
        end
    end
    return first
end

local function finders()
    local list = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_PLAY)) do
        if found_count(entry.localIndex) >= 1 then table.insert(list, entry) end
    end
    return list
end

local function nearest_unfound()
    if roundPlace == nil then return nil, nil end
    local mineRow = gPlayerSyncTable[0]
    local foundText = mineRow ~= nil and mineRow.ofBalFound or ""
    local bestSpot, bestDist = nil, nil
    for _, entry in ipairs(OF.util.connected_players()) do
        if entry.localIndex ~= 0 then
            local row = gPlayerSyncTable[entry.localIndex]
            local spot = row ~= nil and unpack_spot(row.ofBalAt) or nil
            if spot ~= nil and not already_found(foundText, entry.np.globalIndex) then
                spot.level, spot.area = roundPlace.level, roundPlace.area
                local d = OF.gamemodes.distance_to_place(spot)
                if d ~= nil and (bestDist == nil or d < bestDist) then
                    bestSpot, bestDist = spot, d
                end
            end
        end
    end
    return bestSpot, bestDist
end

local function scan_for_finds()
    if roundPlace == nil then return end
    local mine = gPlayerSyncTable[0]
    local foundText = mine ~= nil and mine.ofBalFound or ""
    for _, entry in ipairs(OF.util.connected_players()) do
        local i = entry.localIndex
        if i ~= 0 then
            local row = gPlayerSyncTable[i]
            local spot = row ~= nil and unpack_spot(row.ofBalAt) or nil
            if spot ~= nil then
                local gi = entry.np.globalIndex
                if not already_found(foundText, gi) then
                    spot.level, spot.area = roundPlace.level, roundPlace.area
                    if OF.gamemodes.at_place(spot, FIND_RANGE) then
                        foundText = record_find(foundText, gi, hunt_seconds())
                        OF.util.publish_row(0, "ofBalFound", foundText)

                        if OF.util.asks(OF.hud, "banner") then
                            OF.hud.banner("medal", OF.lang.fill("FOUND +@",
                                tostring(FIND_POINTS)), nil, { quiet = true })
                        end

                        OF.gamemodes.cue("good")
                        return
                    end
                end
            end
        end
    end
end

local mode = {
    key = "hideballoon",

    allActs = true,

    boardWide = 1.5,
    name = "Hide the Balloon",
    blurb = "hide a balloon on the course, then hunt everybody else's",
    how = "L hides your balloon - on the ground or a wall ahead.\n"
        .. "Then hunt - one word says hot, warm, cold or freezing.\n"
        .. "Your balloon earns a point every 15 s it stays hidden.\n"
        .. "Each balloon you find is +3, and its owner stops earning.\n"
        .. "Most points wins; every balloon found ends it early.",
    aims = { [ROLE_PLAY] = "Hide yours well, then find as many as you can." },
    minPlayers = 2,

    maps = "surveyed",
    surveyKeys = { "points" },
    openCourses = true,

    roomsOut = {
        { level = LEVEL_SL, area = 2 }, { level = LEVEL_THI, area = 3 },
        { level = LEVEL_RR, area = 1 }, { level = LEVEL_BITDW, area = 1 },
        { level = LEVEL_BITFS, area = 1 },

        { level = LEVEL_LLL, area = 1 }, { level = LEVEL_LLL, area = 2 },
        { level = LEVEL_TTC, area = 1 }, { level = LEVEL_COTMC, area = 1 },

        { level = LEVEL_JRB, area = 1 }, { level = LEVEL_WDW, area = 1 },
        { level = LEVEL_SSL, area = 2 }, { level = LEVEL_THI, area = 2 },
        { level = LEVEL_CCM, area = 1 },

        { level = LEVEL_CASTLE_GROUNDS, area = 1 },
    },

    room = { rules = { interactions = 0 } },

    noDozing = true,

    cheatsGiven = OF.gamemodes.water_rule("hide"),

    defaultLimit = ROUND_SECONDS,
    music = nil,

    teams = false,

    keepsScore = true,

    options = {
        { key = "hide", name = "Hide time",
          help = "how long everybody gets to place their balloon",
          choices = {
              { key = "thirty", name = "thirty seconds",
                help = "the usual hide" },
              { key = "fifteen", name = "fifteen seconds",
                help = "a quick scatter for a course everybody knows" },
              { key = "fortyfive", name = "forty-five seconds",
                help = "time to really explore before locking it in" },
          } },

        { key = "hint", name = "Hot and cold hint",
          help = "a word on how close the nearest balloon is",
          choices = {
              { key = "warmcold", name = "on",
                help = "one word on the hunt line, never a direction" },
              { key = "off", name = "off",
                help = "find them by looking - they are hidden" },
          } },
    },
}

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_PLAY)
    end
    if options == nil or tonumber(options.limit) == nil then
        OF.util.publish("ofGmLimit", hide_seconds() + 180)
    end
end

function mode.late_join(localIndex)
    OF.gamemodes.set_role(localIndex, ROLE_PLAY)
    return ROLE_PLAY
end

function mode.pin()
    OF.shooter.publish_ffa_points(ROLE_PLAY)
end

mode.leadPin = { keys = function() return { OF.shooter.SPAWN_KEY } end }

function mode.death_place()
    return OF.shooter.ffa_respawn_point()
end

function mode.port_to_spawn(m)
    if m == nil or m.pos == nil then return false end
    local ok, to = pcall(mode.death_place)
    if not ok or type(to) ~= "table" or to.x == nil then return false end
    m.pos.x, m.pos.y, m.pos.z = to.x, to.y or m.pos.y, to.z
    if m.vel ~= nil then m.vel.x, m.vel.y, m.vel.z = 0, 0, 0 end
    m.forwardVel = 0
    m.peakHeight = m.pos.y
    if m.faceAngle ~= nil and to.yaw ~= nil then m.faceAngle.y = to.yaw end
    if m.marioObj ~= nil then OF.util.skip_interpolation(m.marioObj) end
    return true
end

function mode.on_start()
    myBalloon = nil
    locked = false
    lastScore = nil
    roundPlace = OF.gamemodes.here_place(0)
    if OF.gamemodes.role(0) == ROLE_PLAY then
        OF.util.publish_row(0, "ofBalAt", nil)
        OF.util.publish_row(0, "ofBalFound", "")
        OF.util.publish_row(0, "ofScore", 0)
    end

end

function mode.before_mario_update(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if locked then return end
    if not hiding() then return end

    OF.input.poll(m)
    if not place_pressed() then return end

    local spot = wall_spot(m)
    local onWall = spot ~= nil
    if spot == nil then spot = grounded_spot(m) end
    if spot == nil then

        if OF.util.asks(OF.hud, "banner") then
            OF.hud.banner("medal", OF.lang.t("NOT HERE"), nil, { tone = "bad", quiet = true })
        end
        return
    end
    myBalloon = spot
    OF.util.publish_row(0, "ofBalAt", pack_spot(spot.x, spot.y, spot.z, spot.yaw))
    OF.gamemodes.cue("chime")

    if OF.util.asks(OF.hud, "banner") then
        OF.hud.banner("medal", OF.lang.t(onWall and "PINNED" or "HIDDEN"), nil, { quiet = true })
    end
end

function mode.update()
    if hiding() then

        OF.gamemodes.tick_down(math.ceil(hide_seconds()
            - OF.gamemodes.since_start()))
        return
    end

    if not locked then
        locked = true
        if myBalloon == nil then
            local m = gMarioStates[0]
            local spot = grounded_spot(m)
            if spot == nil and m ~= nil and m.pos ~= nil then
                spot = { x = m.pos.x, y = m.pos.y, z = m.pos.z }
            end
            if spot ~= nil then
                myBalloon = spot
                OF.util.publish_row(0, "ofBalAt",
                    pack_spot(spot.x, spot.y, spot.z))
            end
        end

        mode.port_to_spawn(gMarioStates[0])

        if OF.util.asks(OF.hud, "banner") then
            OF.hud.banner("roundstate", OF.lang.t("HUNT"), nil, { quiet = true })
        end

        OF.gamemodes.release()
    end

    scan_for_finds()

    local total = mode.score_of(0)
    if total ~= lastScore then
        lastScore = total
        OF.util.publish_row(0, "ofScore", total)
    end
end

function mode.scenery()
    if not OF.gamemodes.is_running() then return end
    if roundPlace == nil then return end
    local seeking = not hiding()
    local mineRow = gPlayerSyncTable[0]
    local foundText = mineRow ~= nil and mineRow.ofBalFound or ""
    for _, entry in ipairs(OF.util.connected_players()) do
        local i = entry.localIndex
        local name = "balloon" .. tostring(entry.np.globalIndex)
        local row = gPlayerSyncTable[i]
        local spot = row ~= nil and unpack_spot(row.ofBalAt) or nil

        local show
        if i == 0 then
            show = not seeking and spot ~= nil
        else
            show = seeking and spot ~= nil
                and not already_found(foundText, entry.np.globalIndex)
        end
        if show then
            spot.level, spot.area = roundPlace.level, roundPlace.area

            OF.ball.balloon_draw(name, spot, OF.ball.balloon_colour(i),
                { scale = HIDDEN_SCALE, spin = spot.yaw == nil and 0x200 or nil,
                  yaw = spot.yaw, room = spot })
        else
            OF.ball.balloon_hide(name)
        end
    end
end

function mode.controls_lines()
    if not hiding() then return {} end
    return {
        OF.lang.t("L - hide your balloon here"),
        OF.lang.t("D-pad up - the same"),
        OF.lang.t("Press again to move it"),
    }
end

function mode.hint_word(dist)
    if (OF.gamemodes.option_now("hint") or HINT_DEFAULT) ~= "warmcold" then return nil end
    if type(dist) ~= "number" then return nil end
    for _, band in ipairs(HINT_BANDS) do
        if dist <= band.far then return band end
    end
    return { word = "Freezing", tone = "cold" }
end

function mode.hud()
    if OF.gamemodes.role(0) ~= ROLE_PLAY then return end
    local elapsed = OF.gamemodes.since_start()

    local state = OF.util.asks(OF.hud, "state_line") and OF.hud.state_line or function() end
    if hiding() then
        local left = math.max(0, math.ceil(hide_seconds() - elapsed))
        state("hide", OF.lang.t("Hide"), { prio = 50, tone = "warn", figure = left })
        if OF.util.asks(OF.hud, "prompt") then
            OF.hud.prompt("aim", OF.lang.t(myBalloon == nil and "Hide it" or "Move it"), nil,
                { id = "balhide" })
        end

        OF.util.legend(mode.controls_lines())
        return
    end

    local spot, dist = nearest_unfound()
    local word = spot ~= nil and mode.hint_word(dist) or nil
    if word ~= nil then
        state("hint", OF.lang.t(word.word), { prio = 50, tone = word.tone, colour = true })
        return
    end
    state("hunt", OF.lang.t("Hunt"), { prio = 20 })
end

function mode.points(hiddenSeconds, finds)
    local hidden = math.floor(math.max(0, hiddenSeconds or 0) / EARN_EVERY)
    local found = math.max(0, finds or 0) * FIND_POINTS
    return hidden + found, hidden, found
end
mode.EARN_EVERY, mode.FIND_POINTS = EARN_EVERY, FIND_POINTS

function mode.score_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    local np = gNetworkPlayers[localIndex]
    local hiddenFor = 0
    if row ~= nil and np ~= nil and unpack_spot(row.ofBalAt) ~= nil and not hiding() then
        local at = found_at(np.globalIndex)
        hiddenFor = at ~= nil and math.min(at, hunt_seconds()) or hunt_seconds()
    end
    return mode.points(hiddenFor, found_count(localIndex))
end

local function leaders()
    local best, list = nil, {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_PLAY)) do
        local total = mode.score_of(entry.localIndex)
        if best == nil or total > best then
            best, list = total, { entry }
        elseif total == best then
            table.insert(list, entry)
        end
    end
    return list, best or 0
end

local function all_found()
    local hidden = 0
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_PLAY)) do
        local row = gPlayerSyncTable[entry.localIndex]
        if row ~= nil and unpack_spot(row.ofBalAt) ~= nil then
            hidden = hidden + 1
            if found_at(entry.np.globalIndex) == nil then return false end
        end
    end
    return hidden > 0
end
mode.all_found = all_found

local function finish_by_points(early)
    local top, best = leaders()
    local lead = early and "Every balloon found - " or "Time - "
    if best <= 0 or #top == 0 then
        OF.gamemodes.finish(lead .. "nobody scored a point.")
        return
    end
    if #top == 1 then
        local name = top[1].np.name
        OF.gamemodes.finish(lead .. "@ won with @ points.", name, name, tostring(best))
        return
    end
    local names = {}
    for _, entry in ipairs(top) do table.insert(names, entry.np.name) end
    OF.gamemodes.finish(lead .. "@ tied on @ points.", { names = names },
        tostring(#names) .. " players", tostring(best))
end

function mode.host_update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if hiding() then return end
    if all_found() then finish_by_points(true) end
end

function mode.replayDecider()
    local top = leaders()
    return top[1] ~= nil and top[1].localIndex or nil
end

local function unfound_hiders()
    local list = {}
    local players = OF.gamemodes.with_role(ROLE_PLAY)
    for _, entry in ipairs(players) do
        local row = gPlayerSyncTable[entry.localIndex]
        local gi = entry.np ~= nil and entry.np.globalIndex or nil
        if row ~= nil and unpack_spot(row.ofBalAt) ~= nil and gi ~= nil then
            local found = false
            for _, other in ipairs(players) do
                local orow = gPlayerSyncTable[other.localIndex]
                if orow ~= nil and already_found(orow.ofBalFound, gi) then found = true end
            end
            if not found then table.insert(list, entry) end
        end
    end
    return list
end
mode.unfound_hiders = unfound_hiders
mode.wall_spot, mode.balloon_clips, mode.unpack_spot = wall_spot, balloon_clips, unpack_spot
mode.HIDDEN_SCALE, mode.WALL_GAP = HIDDEN_SCALE, WALL_GAP

function mode.on_timeout()
    finish_by_points(false)
end

function mode.standing(localIndex)
    if localIndex == nil then
        local list = {}
        for _, entry in ipairs(OF.gamemodes.with_role(ROLE_PLAY)) do
            table.insert(list, { key = entry.localIndex, score = (mode.score_of(entry.localIndex)) })
        end
        return list
    end
    if not OF.util.can_play(localIndex) then return "AWAY" end
    if hiding() then return nil end
    local _, hidden, found = mode.score_of(localIndex)
    return OF.lang.fill("@h @f", tostring(hidden), tostring(found))
end

function mode.terms()
    return OF.lang.fill("hide a balloon in @s, then hunt the rest",
        tostring(hide_seconds_showing()))
end

function mode.cleanup()
    myBalloon = nil
    locked = false
    lastScore = nil
    roundPlace = nil
    OF.util.publish_row(0, "ofBalAt", nil)
    OF.util.publish_row(0, "ofBalFound", nil)

    if OF.util.is_host() then
        OF.util.publish("ofShootAt", nil)
    end
    return true
end

OF.gamemodes.register(mode)
