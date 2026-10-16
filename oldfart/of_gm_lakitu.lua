OF = OF or {}

local ROLE_LAKITU = "lakitu"
local ROLE_RUNNING = "running"
local DEFAULT_TARGET = 10

local PLACES = {
    empty = { x = 0, y = 0, z = 0 },
}

local PLACE_ORDER = { "empty" }

local ROOM_RADIUS = 1700

local CLOUD_HIGH = 420
local CLOUD_TOP = 34
local CLOUD_ACCEL = 2.4
local CLOUD_KEEP = 0.92

local BUMP_REACH = 140
local BUMP_SLACK = 500

local GRACE = 5.0
local REVENGE = 6.0

local EGG_GRAVITY = 1.6
local SPINY_SPEED = 12
local SPINY_LIFE = 8.0
local SPINY_REACH = 90
local THROW_AHEAD = 12

local AIM_CONE = math.pi * 0.4
local AIM_REACH = 1300
local THROW_MOST = 50

local HURT_GAP = 3.0
local HIT_SLACK = 600

local THROW_ACTION = "lkthrow"
local HIT_ACTION = "lkhit"
local BUMP_ACTION = "lkbump"
local ASK_AGAIN = 0.4

local AT_KEY = "ofLkAt"
local KEYS = { "ofLkSpin", "ofLkSpin2" }
local GOT_KEY = "ofLkGot"
local TARGET_KEY = "ofLkTo"
local ROUND_KEYS = { "ofLkAt", "ofLkGot", "ofLkTo" }
local CHUNK = 160
local ENTRY = 18
local OFFSET = 23000
local MOST_SPINIES = 16

local EGG_ANIMS = "spiny_egg_seg5_anims_050157E4"
local SPINY_ANIMS = "spiny_seg5_anims_05016EAC"
local hostSpinies = {}
local hostNextId = 1
local hostGot = {}
local hostGrace = {}
local hostRevenge = {}
local hostNoRoom = false
local spinies = {}
local wireSeen = nil
local placed = false
local askedAt = {}
local hurtAt = -99
local seenGot = -1
local cloudVX, cloudVZ = 0, 0
local drawnSpiny = {}
local heardSpinies = 0

local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"
local function to36(n, width)
    n = math.floor(n)
    if n < 0 then n = 0 end
    local out = ""
    for _ = 1, width do
        local d = n % 36
        out = string.sub(DIGITS, d + 1, d + 1) .. out
        n = math.floor(n / 36)
    end
    return out
end

local function from36(text)
    return tonumber(text, 36) or 0
end

local function lakitus_for(players)
    return math.max(1, math.floor(((players or 0) - 1) / 8) + 1)
end

local function spinies_for(players, stop)
    if stop == nil or stop == "endless" then return MOST_SPINIES end
    if stop == "three" then return 3 end
    if stop == "six" then return 6 end
    return 2 + math.floor((players or 0) / 4)
end

local function target_points()
    local value = gGlobalSyncTable[TARGET_KEY]
    if type(value) ~= "number" or value <= 0 then return DEFAULT_TARGET end
    return value
end

local function points_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    return math.floor((row ~= nil and tonumber(row.ofScore)) or 0)
end

local function field()
    local at = gGlobalSyncTable[AT_KEY]
    if type(at) ~= "string" then return nil end
    local key = string.match(at, "^(%S+) ")
    local place = key ~= nil and PLACES[key] or nil
    if place == nil then return nil end
    return { x = place.x, y = place.y, z = place.z, r = ROOM_RADIUS }
end

local function here_ok(localIndex)
    local at = gGlobalSyncTable[AT_KEY]
    local np = gNetworkPlayers[localIndex or 0]
    if type(at) ~= "string" or np == nil then return false end
    local _, level, area = string.match(at, "^(%S+) (%-?%d+) (%-?%d+)")
    return level ~= nil and np.currLevelNum == tonumber(level)
        and np.currAreaIndex == tonumber(area)
end

local function arena_ring()
    local f = field()
    if f == nil then return nil end
    local _, level, area = string.match(gGlobalSyncTable[AT_KEY], "^(%S+) (%-?%d+) (%-?%d+)")
    return { x = f.x, z = f.z, r = f.r, level = tonumber(level), area = tonumber(area) }
end

local function spiny_at(s, t, f)
    local spent = (t - s.born) * 30
    if spent < 0 then spent = 0 end
    if t - s.born > SPINY_LIFE then return nil end
    local fallFrames = math.sqrt(2 * CLOUD_HIGH / EGG_GRAVITY)
    local x, z
    if spent < fallFrames then
        x, z = s.x + s.vx * spent, s.z + s.vz * spent
        local y = f.y + CLOUD_HIGH - 0.5 * EGG_GRAVITY * spent * spent
        return x, y, z, false
    end
    local lx, lz = s.x + s.vx * fallFrames, s.z + s.vz * fallFrames
    local walked = (spent - fallFrames) * SPINY_SPEED
    local a = s.yaw / 1296 * 2 * math.pi
    x, z = lx + math.sin(a) * walked, lz + math.cos(a) * walked
    local dx, dz = x - f.x, z - f.z
    local d = math.sqrt(dx * dx + dz * dz)
    if d > f.r then x, z = f.x + dx / d * f.r, f.z + dz / d * f.r end
    return x, f.y, z, true
end

local function pack_spiny(s, f)
    return to36(s.id % 1296, 2) .. to36(s.by % 36, 1) .. to36(s.born * 10, 3)
        .. to36(s.x - f.x + OFFSET, 3) .. to36(s.z - f.z + OFFSET, 3)
        .. to36(s.vx * 10 + 600, 2) .. to36(s.vz * 10 + 600, 2) .. to36(s.yaw % 1296, 2)
end

local function unpack_spiny(e, f)
    if #e ~= ENTRY then return nil end
    return { id = from36(string.sub(e, 1, 2)), by = from36(string.sub(e, 3, 3)),
             born = from36(string.sub(e, 4, 6)) / 10,
             x = from36(string.sub(e, 7, 9)) - OFFSET + f.x,
             z = from36(string.sub(e, 10, 12)) - OFFSET + f.z,
             vx = (from36(string.sub(e, 13, 14)) - 600) / 10,
             vz = (from36(string.sub(e, 15, 16)) - 600) / 10,
             yaw = from36(string.sub(e, 17, 18)) }
end

local function sorted_ids(set)
    local ids = {}
    for id in pairs(set) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end

local function publish_spinies()
    local f = field()
    if f == nil then return end
    local parts = {}
    for _, id in ipairs(sorted_ids(hostSpinies)) do parts[#parts + 1] = pack_spiny(hostSpinies[id], f) end
    local chunks = OF.util.chunk_parts(parts, CHUNK) or {}
    for index, key in ipairs(KEYS) do OF.util.publish(key, chunks[index]) end
end

local function publish_got()
    local out = {}
    for g = 0, 15 do out[#out + 1] = to36(math.min(hostGot[g] or 0, 1295), 2) end
    OF.util.publish(GOT_KEY, table.concat(out))
end

local function got_of(globalIndex)
    local text = gGlobalSyncTable[GOT_KEY]
    if type(text) ~= "string" or globalIndex == nil then return 0 end
    local at = globalIndex * 2 + 1
    if #text < at + 1 then return 0 end
    return from36(string.sub(text, at, at + 1))
end

local function listen()
    local f = field()
    if f == nil then return end
    local text = OF.util.joined(KEYS)
    if text == wireSeen then return end
    wireSeen = text
    local seen = {}
    for i = 1, #text - ENTRY + 1, ENTRY do
        local s = unpack_spiny(string.sub(text, i, i + ENTRY - 1), f)
        if s ~= nil then spinies[s.id] = s seen[s.id] = true end
    end
    for id in pairs(spinies) do if not seen[id] then spinies[id] = nil end end
end

local function round_is_mine()
    local current = OF.gamemodes.current()
    return current ~= nil and current.key == "lakitu"
        and OF.gamemodes.state() == OF.gamemodes.ACTIVE
end

local function out_by(globalIndex, t)
    local count = 0
    for _, s in pairs(hostSpinies) do
        if s.by == globalIndex and t - s.born <= SPINY_LIFE then count = count + 1 end
    end
    return count
end

local function aim_at(li, m, a)
    local fall = math.sqrt(2 * CLOUD_HIGH / EGG_GRAVITY)
    local best, bestScore = nil, nil
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_RUNNING)) do
        local rm = gMarioStates[entry.localIndex]
        if entry.localIndex ~= li and rm ~= nil and rm.pos ~= nil and OF.util.can_play(entry.localIndex) then
            local dx, dz = rm.pos.x - m.pos.x, rm.pos.z - m.pos.z
            local d = math.sqrt(dx * dx + dz * dz)
            if d <= AIM_REACH then
                local off = math.abs((math.atan(dx, dz) - a + math.pi) % (2 * math.pi) - math.pi)
                if d < 1 then off = 0 end
                if off <= AIM_CONE then
                    local score = off * 600 + d
                    if bestScore == nil or score < bestScore then best, bestScore = rm, score end
                end
            end
        end
    end
    if best == nil then return nil end
    local lead = math.min(fall, 30)
    return best.pos.x + (best.vel ~= nil and best.vel.x or 0) * lead,
        best.pos.z + (best.vel ~= nil and best.vel.z or 0) * lead
end

local function host_throw(fromLocal)
    if not OF.util.is_host() then return false, "Only the host." end
    if not round_is_mine() then return false, "No round." end
    local f = field()
    local li = tonumber(fromLocal) or -1
    local np, m = gNetworkPlayers[li], gMarioStates[li]
    if f == nil or np == nil or m == nil or m.pos == nil then return false, "Nobody." end
    if OF.gamemodes.role(li) ~= ROLE_LAKITU then return false, "Not the Lakitu." end
    local t = OF.gamemodes.since_start()
    local players = #OF.gamemodes.with_role(ROLE_LAKITU) + #OF.gamemodes.with_role(ROLE_RUNNING)
    if out_by(np.globalIndex, t) >= spinies_for(players, OF.gamemodes.option_now("spinies")) then
        return false, "Your Spinies are all out."
    end
    local count = 0
    for _ in pairs(hostSpinies) do count = count + 1 end
    if count >= MOST_SPINIES then return false, "There are Spinies enough out already." end
    local yaw = m.faceAngle ~= nil and m.faceAngle.y or 0
    local a = (yaw % 65536) / 65536 * 2 * math.pi
    local vx = (m.vel ~= nil and m.vel.x or 0) * 0.5 + math.sin(a) * THROW_AHEAD
    local vz = (m.vel ~= nil and m.vel.z or 0) * 0.5 + math.cos(a) * THROW_AHEAD
    local walk = a
    local tx, tz = aim_at(li, m, a)
    if tx ~= nil then
        local fall = math.sqrt(2 * CLOUD_HIGH / EGG_GRAVITY)
        vx, vz = (tx - m.pos.x) / fall, (tz - m.pos.z) / fall
        local speed = math.sqrt(vx * vx + vz * vz)
        if speed > THROW_MOST then vx, vz = vx * THROW_MOST / speed, vz * THROW_MOST / speed end
        if speed > 0.01 then walk = math.atan(vx, vz) end
    end
    local s = { id = hostNextId, by = np.globalIndex, born = t, x = m.pos.x, z = m.pos.z,
        vx = math.max(-THROW_MOST, math.min(THROW_MOST, vx)),
        vz = math.max(-THROW_MOST, math.min(THROW_MOST, vz)),
        yaw = math.floor((walk % (2 * math.pi)) / (2 * math.pi) * 1296) % 1296 }
    hostSpinies[s.id] = s
    hostNextId = hostNextId % 1295 + 1
    publish_spinies()
    return true
end

local function host_hit(fromLocal, idText)
    if not OF.util.is_host() then return false, "Only the host." end
    if not round_is_mine() then return false, "No round." end
    local f = field()
    local li = tonumber(fromLocal) or -1
    local np, m = gNetworkPlayers[li], gMarioStates[li]
    if f == nil or np == nil or m == nil or m.pos == nil then return false, "Nobody." end
    if OF.gamemodes.role(li) ~= ROLE_RUNNING then return false, "Not running." end
    local s = hostSpinies[tonumber(idText) or -1]
    if s == nil then return false, "Already gone." end
    local x, y, z = spiny_at(s, OF.gamemodes.since_start(), f)
    if x == nil then return false, "Already gone." end
    if (m.pos.x - x) ^ 2 + (m.pos.z - z) ^ 2 + (m.pos.y - y) ^ 2 > HIT_SLACK * HIT_SLACK then
        return false, "Not near it."
    end
    hostSpinies[s.id] = nil
    if s.by ~= np.globalIndex then hostGot[s.by] = (hostGot[s.by] or 0) + 1 end
    publish_spinies()
    publish_got()
    return true
end

local function host_bump(fromLocal, whoText)
    if not OF.util.is_host() then return false, "Only the host." end
    if not round_is_mine() then return false, "No round." end
    local li = tonumber(fromLocal) or -1
    local np, m = gNetworkPlayers[li], gMarioStates[li]
    if np == nil or m == nil or m.pos == nil then return false, "Nobody." end
    if OF.gamemodes.role(li) ~= ROLE_RUNNING then return false, "Not running." end
    local target = OF.util.local_from_global(tonumber(whoText) or -1)
    local tm = target ~= nil and gMarioStates[target] or nil
    local tnp = target ~= nil and gNetworkPlayers[target] or nil
    if tm == nil or tm.pos == nil or tnp == nil then return false, "Nobody up there." end
    if OF.gamemodes.role(target) ~= ROLE_LAKITU then return false, "Not the Lakitu." end
    local t = OF.gamemodes.since_start()
    if t < (hostGrace[tnp.globalIndex] or -1) then return false, "Too soon." end
    if t < (hostRevenge[np.globalIndex] or -1) then return false, "Too soon - you just fell off." end
    if (m.pos.x - tm.pos.x) ^ 2 + (m.pos.z - tm.pos.z) ^ 2 > BUMP_SLACK * BUMP_SLACK then
        return false, "Not near it."
    end
    OF.gamemodes.set_role(target, ROLE_RUNNING)
    OF.gamemodes.set_role(li, ROLE_LAKITU)
    hostGrace[np.globalIndex] = t + GRACE
    hostRevenge[tnp.globalIndex] = t + REVENGE
    return true
end

local function host_tick(t)
    for id, s in pairs(hostSpinies) do
        if t - s.born > SPINY_LIFE then hostSpinies[id] = nil end
    end
    local runners = OF.gamemodes.with_role(ROLE_RUNNING)
    local riders = #OF.gamemodes.with_role(ROLE_LAKITU)
    local want = lakitus_for(riders + #runners)
    if riders < want and #runners > 1 then

        for li in pairs(OF.gamemodes.deal_fair(runners, 1, "lakitu")) do
            OF.gamemodes.set_role(li, ROLE_LAKITU)
            local np = gNetworkPlayers[li]
            if np ~= nil then hostGrace[np.globalIndex] = t + GRACE end
        end
    end
end

local function host_reset()
    if not OF.util.is_host() then return end
    hostSpinies, hostNextId, hostGot, hostGrace = {}, 1, {}, {}
    hostRevenge = {}
end

local registered = false
local function register_actions()
    if registered then return end
    if not OF.util.asks(OF.net, "register_action") then return end
    registered = true
    OF.net.register_action(THROW_ACTION, "round_move", host_throw)
    OF.net.register_action(HIT_ACTION, "round_move", host_hit)
    OF.net.register_action(BUMP_ACTION, "round_move", host_bump)
end

local function ask(name, x, key, t)
    if askedAt[key] ~= nil and t - askedAt[key] < ASK_AGAIN then return false end
    askedAt[key] = t
    register_actions()
    if OF.util.asks(OF.net, "host_does") then

        local ok, why = OF.net.host_does(name, x)
        if ok == false and why ~= nil and name ~= HIT_ACTION then
            OF.notify.show(why, "info", 2)
        end
        return ok ~= false
    end
    return false
end

local function at_load(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if not ok then return nil end
    return result
end

local CLOUD = at_load("allocate_mario_action",
    (ACT_GROUP_AIRBORNE or 0x080) | (ACT_FLAG_AIR or 0x800))

local function on_cloud(m)
    return m ~= nil and CLOUD ~= nil and m.action == CLOUD
end

local function act_cloud(m)
    if m == nil then return false end
    local f = field()
    local c = m.controller
    if m.playerIndex == 0 and c ~= nil then
        local sx, sy = tonumber(c.stickX) or 0, tonumber(c.stickY) or 0
        local mag = math.min(64, math.sqrt(sx * sx + sy * sy)) / 64
        local ax, az = 0, 0
        if mag > 0.05 then
            local cam = m.area ~= nil and m.area.camera ~= nil and m.area.camera.yaw or 0
            local yaw = math.floor(math.atan(sx, -sy) * 0x8000 / math.pi) + cam
            local turn = yaw * 2 * math.pi / 0x10000
            ax, az = math.sin(turn) * mag, math.cos(turn) * mag
            m.faceAngle.y = yaw
        end
        cloudVX = (cloudVX + ax * CLOUD_ACCEL) * CLOUD_KEEP
        cloudVZ = (cloudVZ + az * CLOUD_ACCEL) * CLOUD_KEEP
        local speed = math.sqrt(cloudVX * cloudVX + cloudVZ * cloudVZ)
        if speed > CLOUD_TOP then
            cloudVX, cloudVZ = cloudVX * CLOUD_TOP / speed, cloudVZ * CLOUD_TOP / speed
        end
        m.vel.x, m.vel.z = cloudVX, cloudVZ
    end
    m.vel.y = 0
    m.forwardVel = math.sqrt((m.vel.x or 0) ^ 2 + (m.vel.z or 0) ^ 2)
    if set_character_animation ~= nil then set_character_animation(m, CHAR_ANIM_IDLE_HEAD_CENTER) end
    if perform_air_step ~= nil then perform_air_step(m, 0) end
    if f ~= nil then
        m.pos.y = f.y + CLOUD_HIGH
        m.vel.y = 0
        local dx, dz = m.pos.x - f.x, m.pos.z - f.z
        local d = math.sqrt(dx * dx + dz * dz)
        if d > f.r then
            m.pos.x, m.pos.z = f.x + dx / d * f.r, f.z + dz / d * f.r
            cloudVX, cloudVZ = 0, 0
        end
    end
    return false
end

if CLOUD ~= nil then
    at_load("hook_mario_action", CLOUD, { every_frame = act_cloud })
end

local function ride_by_role(m, f)
    local lakitu = OF.gamemodes.role(0) == ROLE_LAKITU and round_is_mine()
    if lakitu and not on_cloud(m) and CLOUD ~= nil then
        m.pos.y = f.y + CLOUD_HIGH
        cloudVX, cloudVZ = 0, 0
        set_mario_action(m, CLOUD, 0)
        OF.gamemodes.cue("good")

        if OF.util.asks(OF.hud, "banner") then
            OF.hud.banner("role", OF.lang.t("YOU RIDE"), nil, { quiet = true })
        end
    elseif not lakitu and on_cloud(m) then
        set_mario_action(m, ACT_FREEFALL, 0)
        if round_is_mine() then
            OF.gamemodes.cue("bad")

            if OF.util.asks(OF.hud, "banner") then
                OF.hud.banner("role", OF.lang.t("KNOCKED OFF"), nil, { tone = "bad", quiet = true })
            end
        end
    end
end

local spot = { x = 0, y = 0, z = 0 }

local function anims(name)
    return gObjectAnimations ~= nil and gObjectAnimations[name] or nil
end

local CLOUD_PARTS = 5
local CLOUD_PART_HEIGHTS = { 11, 8, 12, 8, 9 }
local CLOUD_SIZE = 2.5
local CLOUD_OPACITY = 240
local CLOUD_UNDER = 50
local function cloud_part_name(i, k)
    return "lkcloud" .. i .. "p" .. k
end

local function draw_cloud(i, m, t)
    local sway = 2 * math.cos(t * 30 * 0x800 / 0x8000 * math.pi) * CLOUD_SIZE
    local yaw = (m.faceAngle ~= nil and m.faceAngle.y or 0) / 0x8000 * math.pi
    local shown = 0
    for k = 0, CLOUD_PARTS - 1 do
        local a = yaw + 2 * math.pi / CLOUD_PARTS * k
        local r = 25 * CLOUD_SIZE
        spot.x = m.pos.x + math.sin(a) * r + sway
        spot.y = m.pos.y - CLOUD_UNDER + CLOUD_PART_HEIGHTS[k + 1] * CLOUD_SIZE + sway
        spot.z = m.pos.z + math.cos(a) * r + sway
        local part = OF.gamemodes.show_token(cloud_part_name(i, k), E_MODEL_MIST, spot, nil)
        if part ~= nil then
            OF.util.optional("obj_set_billboard", nil, part)
            OF.util.optional("obj_scale", nil, part, CLOUD_SIZE)
            part.oOpacity = CLOUD_OPACITY
            shown = shown + 1
        end
    end
    return shown
end

local function hide_cloud(i)
    for k = 0, CLOUD_PARTS - 1 do OF.gamemodes.hide_token(cloud_part_name(i, k)) end
end

local SPINY_LIFT = -17
local function dress_spiny(o, hatched)
    o.oOpacity = 255
    local want = anims(hatched and SPINY_ANIMS or EGG_ANIMS)
    if want ~= nil then
        if o.oAnimations ~= want then o.oAnimations = want end
        OF.util.optional("obj_init_animation_with_accel_and_sound", nil, o, 0, 1.0)
    end
    o.oGraphYOffset = hatched and SPINY_LIFT or 0
end

local function draw(t, f)

    for i = 0, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[i]
        local m = gMarioStates[i]
        if np ~= nil and np.connected and OF.gamemodes.role(i) == ROLE_LAKITU
            and m ~= nil and m.pos ~= nil then
            draw_cloud(i, m, t)
        else
            hide_cloud(i)
        end
    end

    local shown = {}
    for _, id in ipairs(sorted_ids(spinies)) do
        local s = spinies[id]
        local x, y, z, hatched = spiny_at(s, t, f)
        local name = (hatched and "lkspiny" or "lkegg") .. id
        local fresh = x ~= nil and drawnSpiny[name] == nil
        if x ~= nil then
            spot.x, spot.y, spot.z = x, y, z
            local o = OF.gamemodes.show_token(name, hatched and E_MODEL_SPINY or E_MODEL_SPINY_BALL, spot, nil)
            if o ~= nil then
                dress_spiny(o, hatched)
                o.oFaceAngleYaw = math.floor(s.yaw / 1296 * 65536) % 65536
                if fresh then
                    heardSpinies = heardSpinies + 1
                    OF.gamemodes.round_sound_throttled("lk" .. (hatched and "hatch" or "throw"), 4,
                        hatched and SOUND_OBJ_SPINY_UNK59 or SOUND_OBJ_EVIL_LAKITU_THROW, o)
                end
            end
            shown[name] = true
        end
    end
    for name in pairs(drawnSpiny) do
        if not shown[name] then OF.gamemodes.hide_token(name) end
    end
    drawnSpiny = shown
end

local function clear_all()
    for i = 0, MAX_PLAYERS - 1 do hide_cloud(i) end
    for name in pairs(drawnSpiny) do OF.gamemodes.hide_token(name) end
    drawnSpiny = {}
end

local function judge_spinies(t, f)
    if OF.gamemodes.role(0) ~= ROLE_RUNNING or not round_is_mine() then return nil end
    if t - hurtAt < HURT_GAP then return nil end
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return nil end
    for _, id in ipairs(sorted_ids(spinies)) do
        local x, y, z = spiny_at(spinies[id], t, f)
        if x ~= nil and (m.pos.x - x) ^ 2 + (m.pos.z - z) ^ 2 < SPINY_REACH * SPINY_REACH
            and m.pos.y < y + 120 and m.pos.y + 160 > y then
            hurtAt = t
            if (m.invincTimer or 0) < HURT_GAP * 30 then m.invincTimer = math.floor(HURT_GAP * 30) end
            if atan2s ~= nil then m.faceAngle.y = atan2s(m.pos.z - z, m.pos.x - x) end
            m.forwardVel = -24
            m.vel.y = 24
            if ACT_BACKWARD_AIR_KB ~= nil then set_mario_action(m, ACT_BACKWARD_AIR_KB, 0) end
            OF.gamemodes.round_sound(SOUND_ACTION_BOUNCE_OFF_OBJECT)
            ask(HIT_ACTION, id, "hit" .. id, t)
            return id
        end
    end
    return nil
end

local function judge_bump(t)
    if OF.gamemodes.role(0) ~= ROLE_RUNNING or not round_is_mine() then return nil end
    local m = gMarioStates[0]
    if m == nil or m.pos == nil or (m.vel ~= nil and (m.vel.y or 0) <= 0) then return nil end
    for i = 1, MAX_PLAYERS - 1 do
        local np, tm = gNetworkPlayers[i], gMarioStates[i]
        if np ~= nil and np.connected and OF.gamemodes.role(i) == ROLE_LAKITU
            and tm ~= nil and tm.pos ~= nil then
            local flat = (m.pos.x - tm.pos.x) ^ 2 + (m.pos.z - tm.pos.z) ^ 2
            if flat < BUMP_REACH * BUMP_REACH and m.pos.y + 160 >= tm.pos.y - 60
                and m.pos.y < tm.pos.y then
                ask(BUMP_ACTION, np.globalIndex, "bump" .. np.globalIndex, t)
                return np.globalIndex
            end
        end
    end
    return nil
end

local mode = {
    key = "lakitu",
    name = "Lakitu's Cloud",
    blurb = "one rides the cloud and throws Spinies - knock him off and it is yours",
    how = "One player in every eight rides a cloud above the floor.\n"
        .. "The Lakitu throws Spinies with B: each hit is a point.\n"
        .. "Runners: jump up into the cloud to knock the Lakitu off.\n"
        .. "Whoever knocks him off takes the cloud and the throws.\n"
        .. "First to the target wins, or the most points at the clock.",
    aims = { [ROLE_LAKITU] = "Throw Spinies at the runners - and keep your cloud.",
             [ROLE_RUNNING] = "Dodge the Spinies and jump up into the cloud." },
    minPlayers = 2,

    maps = { "empty" },
    room = { rules = { interactions = PLAYER_INTERACTIONS_NONE } },
    target = { name = "points to win",
               asks = "Points to win",
               default = DEFAULT_TARGET, min = 5, max = 30, step = 5 },
    defaultLimit = 180,
    music = SEQ_LEVEL_WATER,
    teams = false,

    roleBanner = false,
    studio = { tint = { 170, 200, 230 } },
    options = {
        { key = "spinies", name = "Spinies out",
          help = "how many may be out at once, per cloud",
          choices = {
              { key = "endless", name = "no limit",
                help = "the throw's own pace is the only limit" },
              { key = "crowd", name = "for the lobby",
                help = "two and one more per four players: six at sixteen" },
              { key = "three", name = "three", help = "a few, whatever the lobby" },
              { key = "six", name = "six", help = "the floor crawls with them" },
          } },
    },
}

function mode.cluster()
    if not OF.util.asks(OF.gamemodes, "ffa_cluster") then return nil end
    return OF.gamemodes.ffa_cluster(mode)
end
mode.lakitus_for = lakitus_for
mode.arenaRing = arena_ring
mode.spinies_for = spinies_for
function mode.heard_spinies() return heardSpinies end
mode.spiny_at = spiny_at
mode.pack_spiny = pack_spiny
mode.unpack_spiny = unpack_spiny
mode.got_of = got_of
mode.host_throw = host_throw
mode.host_hit = host_hit
mode.host_bump = host_bump
mode.host_tick = host_tick
mode.judge_spinies = judge_spinies
mode.judge_bump = judge_bump
mode.act_cloud = act_cloud
mode.listen = listen
mode.ride_by_role = ride_by_role
mode.field = field
mode.CLOUD = CLOUD
mode.CLOUD_HIGH = CLOUD_HIGH
mode.GRACE = GRACE
mode.REVENGE = REVENGE
mode.HURT_GAP = HURT_GAP
mode.PLACES = PLACES
mode.draw = draw
mode.ROOM_RADIUS = ROOM_RADIUS

function mode.host_spinies()
    return hostSpinies
end

function mode.setup(players, options)
    local count = math.min(lakitus_for(#players), #players - 1)
    local riders = count > 0 and OF.gamemodes.deal_fair(players, count, "lakitu") or {}
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, riders[entry.localIndex] and ROLE_LAKITU or ROLE_RUNNING)
    end
    OF.util.publish(TARGET_KEY, options.target or DEFAULT_TARGET)
end

local function place_here()
    if not OF.util.asks(OF.arena, "find") then return nil end
    local np = gNetworkPlayers[0]
    if np == nil then return nil end
    for _, placeKey in ipairs(PLACE_ORDER) do
        local place = OF.arena.find(placeKey)
        if place ~= nil and place.level ~= nil and place.level == np.currLevelNum
            and (place.area or 1) == (np.currAreaIndex or 1) then
            return placeKey
        end
    end
    return nil
end

function mode.pin()
    host_reset()
    local key = place_here()
    if key == nil then
        hostNoRoom = true
        return
    end
    hostNoRoom = false
    local np = gNetworkPlayers[0]
    OF.util.publish(AT_KEY, string.format("%s %.0f %.0f", key, np.currLevelNum, np.currAreaIndex))
    publish_got()
    publish_spinies()
end

local function place_me(f)
    if placed then return end
    local np = gNetworkPlayers[0]
    if np == nil then return end
    placed = true
    local a = (np.globalIndex or 0) / 16 * 2 * math.pi
    local x, z = f.x + math.sin(a) * f.r * 0.6, f.z + math.cos(a) * f.r * 0.6
    local yaw = math.atan(f.x - x, f.z - z)
    OF.net.snap_to(x, f.y + 10, z, math.floor(yaw / math.pi * 32768) % 65536)
    OF.util.camera_behind_soon()
end

function mode.on_start()
    spinies, wireSeen, placed, askedAt = {}, nil, false, {}
    hurtAt, seenGot, cloudVX, cloudVZ = -99, -1, 0, 0
    clear_all()
    register_actions()
end

function mode.late_join(localIndex)
    OF.gamemodes.set_role(localIndex, ROLE_RUNNING)
    return ROLE_RUNNING
end

function mode.before_mario_update(m)
    if m == nil or m.playerIndex ~= 0 then return end
    local f = field()
    if f == nil or not here_ok(0) then return end
    ride_by_role(m, f)

    if on_cloud(m) and m.controller ~= nil
        and OF.util.has_flag(m.controller.buttonPressed or 0, B_BUTTON or 0x4000) then
        ask(THROW_ACTION, 0, "throw", OF.gamemodes.since_start())
    end
end

function mode.scenery()
    local f = field()
    if OF.gamemodes.state() == OF.gamemodes.OFF or f == nil
        or not here_ok(0) or not OF.util.round_screen() then
        clear_all()
        return
    end
    local t = OF.gamemodes.since_start()
    if OF.gamemodes.state() == OF.gamemodes.ACTIVE then place_me(f) end
    listen()
    draw(t, f)
    judge_spinies(t, f)
    judge_bump(t)
end

function mode.update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    local np = gNetworkPlayers[0]
    if np == nil then return end
    local got = got_of(np.globalIndex)
    if got ~= points_of(0) then
        if got > points_of(0) and seenGot >= 0 then OF.gamemodes.cue("good") end
        OF.util.publish_row(0, "ofScore", got)
    end
    seenGot = got
end

local function everybody()
    local out = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_LAKITU)) do out[#out + 1] = entry end
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_RUNNING)) do out[#out + 1] = entry end
    return out
end

function mode.host_update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if hostNoRoom then
        OF.gamemodes.abandon("Lakitu's Cloud is played in The Tiles.")
        return
    end
    local t = OF.gamemodes.since_start()
    local before = 0
    for _ in pairs(hostSpinies) do before = before + 1 end
    host_tick(t)
    local after = 0
    for _ in pairs(hostSpinies) do after = after + 1 end
    if after ~= before then publish_spinies() end
    local target = target_points()
    for _, entry in ipairs(everybody()) do
        local got = entry.np ~= nil and got_of(entry.np.globalIndex) or 0
        if got >= target then
            OF.gamemodes.finish("@ won with @ points from the cloud.", entry.np.name,
                entry.np.name, tostring(got))
            return
        end
    end
end

function mode.still_winnable()
    return #everybody() >= 2
end

function mode.terms()
    return OF.lang.fill("first to @ points, or most at the clock", tostring(target_points()))
end

function mode.on_timeout()
    local best, names = OF.gamemodes.best_of(everybody(),
        function(entry) return entry.np ~= nil and got_of(entry.np.globalIndex) or 0 end)
    if best == nil or best <= 0 then
        OF.gamemodes.finish("No Spiny reached anybody.")
    elseif #names > 1 then
        OF.gamemodes.finish(OF.lang.fill("Time - a draw at @ points.", tostring(best)))
    else
        OF.gamemodes.finish("@ won - the most points from the cloud.", names[1], names[1])
    end
end

function mode.hud()
    local f = field()
    if f == nil then return end
    if not here_ok(0) then
        OF.gamemodes.away_banner("The cloud is somewhere else")
        return
    end

    local role = OF.gamemodes.role(0)
    if role == ROLE_LAKITU then
        if OF.util.asks(OF.hud, "state_line") then
            OF.hud.state_line("riding", OF.lang.t("Riding"), { prio = 50, tone = "target" })
        end
        OF.util.legend({ OF.lang.t("Stick - steer the cloud"), OF.lang.t("B - throw a Spiny") })
    else
        OF.util.legend({ OF.lang.t("Double jump under the cloud - knock the Lakitu off"),
            OF.lang.t("Dodge the Spinies - they cannot be stomped") })
    end
    local r, g, b = OF.util.round_tone("cold")
    OF.util.zone_ring(f, f.r, 48, 4, r, g, b, 220, "edge")

    local board = {}
    for _, entry in ipairs(everybody()) do
        board[#board + 1] = { name = entry.np ~= nil and entry.np.name or "?",
            score = points_of(entry.localIndex), localIndex = entry.localIndex }
    end
    table.sort(board, function(a, b) return a.score > b.score end)
    for _, entry in ipairs(board) do entry.right = tostring(entry.score) end
    if OF.util.asks(OF.gamemodes, "board_cap") then
        board = OF.gamemodes.board_cap(board, OF.gamemodes.SIDE_BOARD_ROWS or 4)
    end
    OF.util.board(djui_hud_get_screen_width() * 0.03,
        djui_hud_get_screen_height() * 0.24, OF.lang.t("Points"), board,
        { width = 180, column = 120 })
end

function mode.cleanup()
    clear_all()
    local m = gMarioStates[0]
    if on_cloud(m) then set_mario_action(m, ACT_FREEFALL, 0) end
    if OF.util.is_host() then
        for _, key in ipairs(KEYS) do OF.util.publish(key, nil) end
        for _, key in ipairs(ROUND_KEYS) do OF.util.publish(key, nil) end
    end
    host_reset()
    hostNoRoom = false
    spinies, wireSeen, placed, askedAt = {}, nil, false, {}
    hurtAt, seenGot, cloudVX, cloudVZ = -99, -1, 0, 0
    return true
end

OF.gamemodes.register(mode)
