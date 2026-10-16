local SPEED = 29
OF.gm_greendemon_speed = function() return SPEED end

local FALLBACK_REACH = 90
local FALLBACK_START = 700

local MAX_DEMONS = 16

local WAKE_AFTER = 3

local HOVER = 40

local AIM_LIFT = 60

local STEP_UP = 160
local STUCK_FRAMES = 60
local CLIMB_FRAMES = 45

local LOOK_AHEAD = 40

local PUBLISH_EVERY = 4

local SNAP_OVER = 300

local RETARGET_EVERY = 6
local RETARGET_MARGIN = 50

local COORD_HALF = 23328

local ROLE_ALIVE = "alive"
local ROLE_OUT = "out"
local PLAN_KEY = "ofGdPlan"
local POS_KEY = "ofGdPos"
local planText = nil
local plan = {}
local planOrder = {}
local copies = {}
local rowSeen = {}
local published = nil
local publishTick = 0
local woke = false
local seated = false

local burstSaid = false

local wasChasing = false
local wasClose = false
local CLOSE_CUE = 600
local trailTick = 0

local hostDemons = {}
local hostNextId = 0
local hostPlanned = false
local mode_lunged = false
local hostRetargetTick = 0

local function reach()
    return (OF.modifiers ~= nil and OF.modifiers.DEMON_REACH) or FALLBACK_REACH
end

local function start_distance()
    return (OF.modifiers ~= nil and OF.modifiers.DEMON_START) or FALLBACK_START
end

local BURST_EVERY = 5
local BURST_FOR = 1
local BURST_SPEED = 48

local function burst_at(t)
    local awake = (tonumber(t) or 0) - WAKE_AFTER
    if awake < 0 then return false, nil end
    local phase = awake % BURST_EVERY
    if awake >= BURST_EVERY and phase < BURST_FOR then return true, nil end
    return false, math.max(1, math.ceil(BURST_EVERY - phase))
end
OF.gm_greendemon_burst = function(t) return burst_at(t) end
OF.gm_greendemon_burst_speed = function() return BURST_SPEED end

local function step_at(t)
    if burst_at(t) then return BURST_SPEED end
    return SPEED
end
OF.gm_greendemon_step_at = function(t) return step_at(t) end

local function on_ground()
    return OF.gamemodes.option_now("path") == "ground"
end

local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"
local function digit(n)
    return DIGITS:sub(n + 1, n + 1)
end

local function undigit(c)
    local at = DIGITS:find(c, 1, true)
    return at ~= nil and (at - 1) or nil
end

local function pack_coord(v)
    local n = math.floor((tonumber(v) or 0) / 2 + 0.5) + COORD_HALF
    n = math.max(0, math.min(36 * 36 * 36 - 1, n))
    local a = math.floor(n / 1296)
    local b = math.floor((n - a * 1296) / 36)
    return digit(a) .. digit(b) .. digit(n - a * 1296 - b * 36)
end

local function unpack_coord(s)
    local a, b, c = undigit(s:sub(1, 1)), undigit(s:sub(2, 2)), undigit(s:sub(3, 3))
    if a == nil or b == nil or c == nil then return nil end
    return (a * 1296 + b * 36 + c - COORD_HALF) * 2
end

local function pack_spot(x, y, z)
    return pack_coord(x) .. pack_coord(y) .. pack_coord(z)
end

local function unpack_spot(s)
    local x = unpack_coord(s:sub(1, 3))
    local y = unpack_coord(s:sub(4, 6))
    local z = unpack_coord(s:sub(7, 9))
    if x == nil or y == nil or z == nil then return nil end
    return x, y, z
end

local function read_plan()
    local text = gGlobalSyncTable[PLAN_KEY]
    if type(text) ~= "string" then text = "" end
    if text == planText then return end
    planText = text
    plan, planOrder = {}, {}
    for at = 1, #text - 10, 11 do
        local id = undigit(text:sub(at, at))
        local t = text:sub(at + 1, at + 1)
        local x, y, z = unpack_spot(text:sub(at + 2, at + 10))
        if id ~= nil and x ~= nil and plan[id] == nil then
            plan[id] = { target = undigit(t), x = x, y = y, z = z }
            table.insert(planOrder, id)
        end
    end
end

local function read_row(localIndex)
    local row = gPlayerSyncTable[localIndex]
    local text = row ~= nil and row[POS_KEY] or nil
    local out = {}
    if type(text) ~= "string" then return out, "" end
    for at = 1, #text - 9, 10 do
        local id = undigit(text:sub(at, at))
        local x, y, z = unpack_spot(text:sub(at + 1, at + 9))
        if id ~= nil and x ~= nil then out[id] = { x = x, y = y, z = z } end
    end
    return out, text
end

local function am_out()
    return OF.gamemodes.role(0) == ROLE_OUT
end

local function contenders()
    local list = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_ALIVE)) do
        if OF.gamemodes.in_contention(entry.localIndex) then
            table.insert(list, entry)
        end
    end
    return list
end

local function local_of(global)
    if global == nil then return nil end
    local i = network_local_index_from_global(global)
    if i == nil or i >= MAX_PLAYERS then return nil end
    return i
end

local function global_of(localIndex)
    return network_global_index_from_local(localIndex)
end

local function seen_here(localIndex)
    if localIndex == nil then return false end
    local np, me = gNetworkPlayers[localIndex], gNetworkPlayers[0]
    if np == nil or me == nil or not np.connected then return false end
    if localIndex == 0 then return true end
    if np.currLevelNum ~= me.currLevelNum then return false end
    if np.currAreaIndex ~= me.currAreaIndex then return false end
    return np.currPositionValid ~= false
end

local function floor_at(x, y, z)
    local f = OF.util.optional("find_floor_height", nil, x, y, z)
    if f == nil or f <= -10000 then return nil end
    return f
end

local function fly(d, tx, ty, tz, step)
    local dx, dy, dz = tx - d.x, ty - d.y, tz - d.z
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
    if distance < 0.001 then return end
    local s = math.min(step, distance)
    d.x, d.y, d.z = d.x + dx / distance * s, d.y + dy / distance * s,
        d.z + dz / distance * s
    local ground = floor_at(d.x, d.y + 200, d.z)
    if ground ~= nil and d.y < ground + HOVER then d.y = ground + HOVER end
end

local function walk(d, cx, cz, s)
    local nx, nz = d.x + cx * s, d.z + cz * s
    local hit = OF.util.optional("collision_find_surface_on_ray", nil,
        d.x, d.y - HOVER + 60, d.z, cx * (s + LOOK_AHEAD), 0, cz * (s + LOOK_AHEAD))
    if hit ~= nil and hit.surface ~= nil then return false end
    local ground = floor_at(nx, d.y - HOVER + STEP_UP, nz)
    if ground == nil then return false end
    d.x, d.z, d.y = nx, nz, ground + HOVER
    return true
end

local function crawl(d, tx, ty, tz, step)
    if (d.climb or 0) > 0 then
        d.climb = d.climb - 1
        fly(d, tx, ty, tz, step)
        return
    end
    local dx, dz = tx - d.x, tz - d.z
    local flat = math.sqrt(dx * dx + dz * dz)
    if flat < 1 then
        local ground = floor_at(d.x, d.y + STEP_UP, d.z)
        if ground ~= nil then d.y = ground + HOVER end
        return
    end
    local s = math.min(step, flat)
    local ux, uz = dx / flat, dz / flat
    if walk(d, ux, uz, s)
        or walk(d, ux >= 0 and 1 or -1, 0, s * math.abs(ux))
        or walk(d, 0, uz >= 0 and 1 or -1, s * math.abs(uz)) then
        d.stuck = 0
        return
    end
    d.stuck = (d.stuck or 0) + 1
    if d.stuck >= STUCK_FRAMES then
        d.stuck = 0
        d.climb = CLIMB_FRAMES
    end
end

local function advance(d, m, step)
    if m == nil or m.pos == nil then return end
    if on_ground() then
        crawl(d, m.pos.x, m.pos.y + AIM_LIFT, m.pos.z, step)
    else
        fly(d, m.pos.x, m.pos.y + AIM_LIFT, m.pos.z, step)
    end
end

local function drop_object(d)
    if d ~= nil and d.obj ~= nil then
        if OF.util.asks(OF.modifiers, "is_demon_object")
            and OF.modifiers.is_demon_object(d.obj) then
            OF.util.optional("obj_mark_for_deletion", nil, d.obj)
        end
        d.obj = nil
    end
end

local function show(d)
    local mine = d.obj ~= nil and OF.util.asks(OF.modifiers, "is_demon_object")
        and OF.modifiers.is_demon_object(d.obj)
    if not mine then
        d.obj = nil
        if not OF.util.asks(OF.modifiers, "spawn_demon_object") then return end
        d.obj = OF.modifiers.spawn_demon_object(d.x, d.y, d.z)
        if d.obj == nil then return end
    end
    d.obj.oPosX, d.obj.oPosY, d.obj.oPosZ = d.x, d.y, d.z
end

local function clear_all()
    for id, d in pairs(copies) do
        drop_object(d)
        copies[id] = nil
    end
end

local function my_report()
    local me = global_of(0)
    local parts = {}
    for _, id in ipairs(planOrder) do
        local p, d = plan[id], copies[id]
        if p ~= nil and d ~= nil and p.target == me then
            table.insert(parts, digit(id) .. pack_spot(d.x, d.y, d.z))
        end
    end
    return table.concat(parts)
end

local function ease(d, pub)
    local dx, dy, dz = pub.x - d.x, pub.y - d.y, pub.z - d.z
    if dx * dx + dy * dy + dz * dz > SNAP_OVER * SNAP_OVER then
        d.x, d.y, d.z = pub.x, pub.y, pub.z
    else
        d.x, d.y, d.z = d.x + dx * 0.5, d.y + dy * 0.5, d.z + dz * 0.5
    end
end

local function tick_demons()
    read_plan()
    local t = OF.gamemodes.since_start()
    local awake = OF.gamemodes.state() == OF.gamemodes.ACTIVE and t >= WAKE_AFTER
    local step = step_at(t)
    local driving = not am_out() and OF.gamemodes.role(0) == ROLE_ALIVE

    local lunging = awake and step == BURST_SPEED
    if lunging and not mode_lunged and driving then
        for _, id in ipairs(planOrder) do
            if plan[id] ~= nil and local_of(plan[id].target) == 0 then
                OF.gamemodes.cue("hazard", nil, "gdlunge")
                break
            end
        end
    end
    mode_lunged = lunging

    for id, d in pairs(copies) do
        if plan[id] == nil then
            drop_object(d)
            copies[id] = nil
        end
    end

    local rows = {}
    for _, id in ipairs(planOrder) do
        local p = plan[id]
        local d = copies[id]
        if d == nil then
            d = { x = p.x, y = p.y, z = p.z, stuck = 0, climb = 0 }
            copies[id] = d
        end
        local target = local_of(p.target)
        local visible = seen_here(target)

        if target == 0 then
            if driving and awake then advance(d, gMarioStates[0], step) end
        elseif target ~= nil then
            if rows[target] == nil then
                local parsed, text = read_row(target)
                rows[target] = { parsed = parsed, fresh = text ~= rowSeen[target] }
                rowSeen[target] = text
            end
            local pub = rows[target].parsed[id]
            if awake and visible then advance(d, gMarioStates[target], step) end
            if pub ~= nil and rows[target].fresh then ease(d, pub) end
        end

        if visible then show(d) else drop_object(d) end
    end

    trailTick = trailTick + 1
    local count = #planOrder
    local stride = math.max(1, math.ceil(count / 5))
    local held = OF.util.optional("count_unimportant_objects", false)
    if awake and not (type(held) == "number" and held > 600) then
        for n, id in ipairs(planOrder) do
            local d = copies[id]
            if d ~= nil and d.obj ~= nil and (trailTick + n) % stride == 0
                and OF.util.asks(OF.modifiers, "demon_sparkle") then
                OF.modifiers.demon_sparkle(d.obj)
            end
        end
    end

    publishTick = publishTick + 1
    if publishTick >= PUBLISH_EVERY then
        publishTick = 0
        local report = driving and my_report() or ""
        if report ~= published then
            published = report
            OF.util.publish_row(0, POS_KEY, report)
        end
    end

    if awake and not woke then
        woke = true

    end
end

local function nearest_demon()
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return nil end
    local best = nil
    for _, id in ipairs(planOrder) do
        local d = copies[id]
        if d ~= nil and d.obj ~= nil then
            local dx, dy, dz = m.pos.x - d.x, m.pos.y + AIM_LIFT - d.y, m.pos.z - d.z
            local far = math.sqrt(dx * dx + dy * dy + dz * dz)
            if best == nil or far < best then best = far end
        end
    end
    return best
end

local function best_seat()
    local best, bestNear = nil, nil
    for _, entry in ipairs(contenders()) do
        if entry.localIndex ~= 0 then
            local near = OF.gamemodes.distance(0, entry.localIndex) or math.huge
            if best == nil or near < bestNear then
                best, bestNear = entry, near
            end
        end
    end
    if best == nil then return nil end
    return global_of(best.localIndex)
end

local function watch_toggle(m)
    if not OF.util.asks(OF.spectate, "start") then return end
    if OF.util.menu_has_screen() then return end
    OF.input.poll(m)
    if not OF.input.pressed(L_JPAD) then return end
    if OF.spectate.is_active() then
        OF.spectate.stop()
        seated = false
        return
    end
    local seat = best_seat()
    if seat == nil then
        OF.util.report(false, "There is nobody left to watch.")
        return
    end
    seated = OF.spectate.start(seat) == true
end

local function put_out()
    OF.gamemodes.set_role(0, ROLE_OUT)
    OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
    published = ""
    OF.util.publish_row(0, POS_KEY, "")

end

local function next_id()
    local used = {}
    for _, h in ipairs(hostDemons) do used[h.id] = true end
    for _ = 1, 36 do
        local id = hostNextId
        hostNextId = (hostNextId + 1) % 36
        if not used[id] then return id end
    end
    return nil
end

local function add_demon(targetLocal, x, y, z)
    if #hostDemons >= MAX_DEMONS then return false end
    local id = next_id()
    if id == nil then return false end
    if x == nil then
        local m = gMarioStates[targetLocal]
        if m == nil or m.pos == nil then return false end
        local back = start_distance()
        x = m.pos.x - sins(m.faceAngle.y) * back
        y = m.pos.y + AIM_LIFT
        z = m.pos.z - coss(m.faceAngle.y) * back
    end
    table.insert(hostDemons, { id = id, target = global_of(targetLocal),
        x = x, y = y, z = z })
    return true
end

local function host_seen(localIndex)
    local np = gNetworkPlayers[localIndex]
    if np == nil or not np.connected then return false end
    if localIndex == 0 then return true end
    local me = gNetworkPlayers[0]
    return np.currLevelNum == me.currLevelNum
        and np.currAreaIndex == me.currAreaIndex
        and np.currPositionValid ~= false
end

local function nearest_to(h, pool)
    local best, bestFar = nil, nil
    for _, entry in ipairs(pool) do
        local m = gMarioStates[entry.localIndex]
        if host_seen(entry.localIndex) and m ~= nil and m.pos ~= nil then
            local dx, dy, dz = m.pos.x - h.x, m.pos.y - h.y, m.pos.z - h.z
            local far = math.sqrt(dx * dx + dy * dy + dz * dz)
            if best == nil or far < bestFar then best, bestFar = entry, far end
        end
    end
    return best, bestFar
end

local function publish_plan()
    local parts = {}
    for _, h in ipairs(hostDemons) do
        local t = h.target ~= nil and h.target < 36 and digit(h.target) or "-"
        table.insert(parts, digit(h.id) .. t .. pack_spot(h.x, h.y, h.z))
    end
    local text = table.concat(parts)
    if text ~= (gGlobalSyncTable[PLAN_KEY] or "") then
        OF.util.publish(PLAN_KEY, text)
    end
end

function OF.gm_greendemon_wanted(players, seconds)
    local start = math.max(1, math.ceil((players or 1) / 8))
    return math.min(MAX_DEMONS, start + math.max(0, math.floor((seconds or 0) / 40)))
end

local function host_plan()
    local pool = contenders()
    local inPool = {}
    for _, entry in ipairs(pool) do inPool[global_of(entry.localIndex)] = entry end
    local changed = false

    for _, h in ipairs(hostDemons) do
        local d = copies[h.id]
        if d ~= nil then h.x, h.y, h.z = d.x, d.y, d.z end
    end

    if not hostPlanned and #pool > 0 then
        hostPlanned = true
        if add_demon(pool[math.random(#pool)].localIndex) then changed = true end
    end

    if hostPlanned and #pool > 0 then
        local wanted = OF.gm_greendemon_wanted(#OF.gamemodes.participants(),
            OF.gamemodes.since_start())
        if #hostDemons < wanted then
            if add_demon(pool[math.random(#pool)].localIndex) then changed = true end
        end
    end

    hostRetargetTick = hostRetargetTick + 1
    local look = hostRetargetTick >= RETARGET_EVERY
    if look then hostRetargetTick = 0 end
    for _, h in ipairs(hostDemons) do
        local holding = h.target ~= nil and inPool[h.target] ~= nil
        if look or not holding then
            local best, bestFar = nearest_to(h, pool)
            if best ~= nil then
                local g = global_of(best.localIndex)
                local keep = false
                if holding and g ~= h.target then
                    local cur = inPool[h.target]
                    local m = gMarioStates[cur.localIndex]
                    if host_seen(cur.localIndex) and m ~= nil and m.pos ~= nil then
                        local dx, dy, dz = m.pos.x - h.x, m.pos.y - h.y, m.pos.z - h.z
                        keep = math.sqrt(dx * dx + dy * dy + dz * dz)
                            <= bestFar + RETARGET_MARGIN
                    else

                        keep = true
                    end
                end
                if not keep and g ~= h.target then
                    h.target = g
                    changed = true
                end
            elseif not holding and h.target ~= nil then
                h.target = nil
                changed = true
            end
        end
    end

    if changed then publish_plan() end
end

local mode = {
    key = "greendemon",
    name = "Green Demon",
    blurb = "a 1-UP comes after you - one touch and you are out",
    aims = { [ROLE_ALIVE] = "keep moving - a 1-UP is coming, and one touch is out." },
    how = "A 1-UP is loose, and it goes after whoever is nearest.\n"
        .. "Another joins it every forty seconds.\n"
        .. "Whoever it reaches is out.\n"
        .. "It is only a little slower than a run, so keep running.\n"
        .. "Whether it flies or keeps to the floor is set below.\n"
        .. "Last one uncaught wins, or everybody left at the buzzer.",
    minPlayers = 2,

    maps = { "bowser1", "bowser2", "bowser3", "desert_cage", "ice_donut", "the_plate", "aquarium" },

    room = { sweep = { "cannons" },
             rules = { interactions = PLAYER_INTERACTIONS_NONE } },

    defaultLimit = 150,

    target = { name = "round length", asks = "Round length", clock = true,
               help = "the round ends here if anybody is still running",
               default = 150, min = 60, max = 600, step = 30 },
    out_cause = function() return OF.lang.t("Caught by the Green Demon") end,
    teams = false,
    resultsBy = "survival",
    saysOut = true,
    lensRole = ROLE_OUT,
    music = SEQ_LEVEL_SPOOKY,
    options = {
        { key = "path", name = "1-UP path",
          help = "flying is the original; the floor makes walls count",
          choices = {
              { key = "fly", name = "through walls",
                help = "flies at you through anything, like the original" },
              { key = "ground", name = "along the floor",
                help = "walls hold it up for a moment - then it climbs" },
          } },
    },
}

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_ALIVE)
    end
    if options == nil or tonumber(options.limit) == nil then
        OF.util.publish("ofGmLimit", OF.util.clamp(
            math.floor(tonumber(options ~= nil and options.target)
                or OF.gamemodes.target_for(mode.key) or mode.target.default),
            mode.target.min, mode.target.max))
    end
end

local function reset_locals()
    clear_all()
    planText = nil
    plan, planOrder = {}, {}
    rowSeen = {}
    published = nil
    publishTick = 0
    woke = false
    wasChasing = false
    wasClose = false
    trailTick = 0
    hostDemons = {}
    hostNextId = 0
    hostPlanned = false
    hostRetargetTick = 0
end

function mode.on_start()
    reset_locals()
    seated = false
    burstSaid = false

end

function mode.scenery()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    if not OF.util.round_screen() then
        clear_all()
        return
    end
    tick_demons()
end

function mode.update()
    if OF.gamemodes.role(0) ~= ROLE_ALIVE then return end
    local t = OF.gamemodes.since_start()
    if t < WAKE_AFTER then

        OF.gamemodes.tick_down(math.ceil(WAKE_AFTER - t))
        return
    end
    local m = gMarioStates[0]
    if m ~= nil then

        if (m.health or 0) < 0x880 then m.health = 0x880 end
        m.hurtCounter = 0
    end
    local near = nearest_demon()
    if near ~= nil and near < reach() then
        put_out()
        return
    end
    local chasing = mode.chasing_me()
    local close = near ~= nil and near < CLOSE_CUE
    if (chasing and not wasChasing) or (close and not wasClose) then
        OF.gamemodes.cue("hazard")
    end
    wasChasing, wasClose = chasing, close
end

function mode.before_mario_update(m)
    if am_out() then
        OF.gamemodes.set_ghost(true)
        watch_toggle(m)
    end
end

function mode.host_update()
    host_plan()
    local alive = contenders()
    if #alive == 1 and #OF.gamemodes.still_here() > 1 then
        OF.gamemodes.finish("@ won.",
            alive[1].np.name, alive[1].np.name)
    elseif #alive == 0 then
        OF.gamemodes.finish("The Green Demon caught everybody.")
    end
end

function mode.on_timeout()
    local standing = contenders()
    if #standing == 0 then
        OF.gamemodes.finish("The Green Demon caught everybody.")
        return
    end
    if #standing == 1 then
        OF.gamemodes.finish("@ won.", standing[1].np.name,
            standing[1].np.name)
        return
    end
    local names = {}
    for _, entry in ipairs(standing) do
        if entry.np ~= nil and entry.np.name ~= nil then
            table.insert(names, entry.np.name)
        end
    end
    OF.gamemodes.finish(#standing == 1 and "Time - 1 player won." or "Time - @ players won.", { names = names },
        tostring(#standing))
end

function mode.cleanup()
    if seated and OF.util.asks(OF.spectate, "stop") then OF.spectate.stop() end
    seated = false
    OF.util.publish_row(0, POS_KEY, "")
    if OF.util.is_host() then OF.util.publish(PLAN_KEY, "") end
    reset_locals()
end

function mode.terms()
    return OF.lang.t("last uncaught wins - one 1-UP, nearest first")
end

function mode.standing(localIndex)
    if OF.gamemodes.role(localIndex) == ROLE_OUT then return "OUT" end
    if not OF.util.can_play(localIndex) then return "AWAY" end
    return nil
end

local function burst_chip(t)
    local bursting, left = burst_at(t)
    if not bursting then burstSaid = false end
    if not bursting and left == nil then return nil end
    local text = bursting and OF.lang.t("SPEED BURST")
        or OF.lang.fill("Burst in @s", tostring(left))
    if bursting and not burstSaid then
        burstSaid = true
        if OF.util.asks(OF.hud, "banner") then
            OF.hud.banner("roundstate", OF.lang.t("SPEED BURST"), nil)
        end
    end
    return text
end
mode.burst_chip = burst_chip

function mode.hud()
    if am_out() then

        OF.gamemodes.out_banner()
        return
    end

    local t = OF.gamemodes.since_start()
    local state = OF.util.asks(OF.hud, "state_line") and OF.hud.state_line or function() end
    if t < WAKE_AFTER then
        state("wake", OF.lang.t("Wakes in"), { prio = 50, tone = "warn",
            figure = math.ceil(WAKE_AFTER - t) })
        return
    end
    burst_chip(t)
    if mode.chasing_me() then
        state("after", OF.lang.t("It's after you"), { prio = 85, tone = "bad", urgent = true })
    end
end

function mode.chasing_me()
    local me = global_of(0)
    if me == nil then return false end
    for _, id in ipairs(planOrder) do
        local p = plan[id]
        if p ~= nil and p.target == me then return true end
    end
    return false
end

function mode.demon_copies()
    return copies
end

function mode.host_demons()
    return hostDemons
end

mode.pack_spot = pack_spot
mode.unpack_spot = unpack_spot

OF.gamemodes.register(mode)
