OF = OF or {}
OF.zelda = OF.zelda or {}
local zelda = OF.zelda

zelda.HOOK = "hook"
zelda.CHU = "chu"
zelda.NUT = "nut"
zelda.BOOM = "boom"
zelda.KIND_CHU = 1
zelda.KIND_BOOM = 2
zelda.KIND_TIP = 3

zelda.HOOK_REACH = { 7020, 16380 }

zelda.HOOK_SPEED = 60
zelda.HOOK_SPEED_MAX = 240
zelda.HOOK_FLIGHT = 60

zelda.HOOK_ARRIVE = 90

zelda.HOOK_ARRIVE_PLAYER = 150

zelda.HOOK_SPARE = 30
zelda.HOOK_MAX_FRAMES = 100

zelda.HOOK_STUCK = 6

zelda.HOOK_WALL_NEAR = 150
zelda.HOOK_LEDGE_NEAR = 400

zelda.HOOK_SKIM = 10

zelda.HOOK_SLACK = 50

zelda.HOOK_LIFT = 0.27

zelda.HOOK_CHEST = 80

zelda.HOOK_HOP = 20

zelda.HOOK_CATCH = 100

zelda.PULL_IMMUNE = 90

zelda.HOOK_POLE_MARGIN = 50
zelda.HOOK_ARRIVE_POLE = 20
zelda.HOOK_HEAD = 160
zelda.HOOK_ARRIVE_CEIL = 40

zelda.HOOK_ITEM_CATCH = 90
zelda.HOOK_REEL_NEAR = 50
zelda.ITEM_KINDS = {
    "id_bhvYellowCoin", "id_bhvSingleCoinGetsSpawned", "id_bhvRedCoin",
    "id_bhvMovingYellowCoin", "id_bhvMovingBlueCoin", "id_bhvBlueCoinJumping",
    "id_bhvBlueCoinSliding", "id_bhv1Up", "id_bhv1upWalking",
}

zelda.LINK_GAP = 300
zelda.LINKS = 16
zelda.LINKS_CROWDED = 4
zelda.CROWD = 8

zelda.CHU_LIFE = 180
zelda.CHU_SPEED = 24

zelda.CHU_REACH = 120

zelda.CHU_AHEAD = 80
zelda.CHU_DROP = 400

zelda.NUT_AHEAD = 300
zelda.NUT_RADIUS = 600

zelda.NUT_STUN = 60
zelda.NUT_IMMUNE = 90

zelda.NUT_WHITE = 45
zelda.NUT_FADE = 15
zelda.NUT_FLASH_RADIUS = 1200

zelda.NUT_POP = 9
zelda.NUT_POP_RADIUS = 1200
zelda.NUT_POP_PEAK = 0.85
zelda.NUT_POP_AWAY = 0.35

zelda.NUT_FUSE = 24

zelda.NUT_FUSES_MOST = 16
zelda.NUT_FUSE_MODEL = "E_MODEL_YELLOW_SPHERE"
zelda.NUT_FUSE_SCALE = 0.3
zelda.NUT_FUSE_PULSE = 0.45

zelda.NUT_FUSE_BEAT = 6

zelda.NUT_COOLDOWN = 150
zelda.NUT_COOLDOWN_ROUND = 90

zelda.BOOM_SPEED = 54
zelda.BOOM_OUT = 60
zelda.BOOM_CATCH = 120
zelda.BOOM_HIT = 120

zelda.BOOM_LIFE = 180

zelda.BOOM_CARRY = 1

zelda.BOOM_TURN_FAR = 600
zelda.BOOM_TURN_RATE = 0.0017
zelda.BOOM_TURN_MIN = 0.12

zelda.BOOM_CONE = 0x1C00

zelda.BOOM_KNOCK = -24
zelda.BOOM_KNOCK_UP = 20

zelda.MODEL_CHU = "E_MODEL_BLACK_BOBOMB"
zelda.MODEL_BOOM = "E_MODEL_KOOPA_SHELL"
zelda.MODEL_TIP = "E_MODEL_METALLIC_BALL"
zelda.MODEL_LINK = "E_MODEL_METALLIC_BALL"
zelda.MODEL_FLASH = "E_MODEL_SPARKLES"
zelda.PACKET = "zel"
local function mine()
    return OF.util.optional("network_global_index_from_local", 0, 0) or 0
end

local function normalise(x, y, z)
    local l = math.sqrt(x * x + y * y + z * z)
    if l < 0.0001 then return 0, 0, 0, 0 end
    return x / l, y / l, z / l, l
end

local function dist3(ax, ay, az, bx, by, bz)
    local dx, dy, dz = bx - ax, by - ay, bz - az
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function same_room(li)
    if li == nil or gNetworkPlayers == nil then return false end
    local np, me = gNetworkPlayers[li], gNetworkPlayers[0]
    if np == nil or me == nil or not np.connected then return false end
    return np.currLevelNum == me.currLevelNum
        and np.currAreaIndex == me.currAreaIndex
end

zelda.RAY_PRECISION = 3
zelda.RAY_CELL = 1024
function zelda.cast(sx, sy, sz, dx, dy, dz)
    local length = math.sqrt(dx * dx + dy * dy + dz * dz)
    if length < 0.001 then return nil end
    local stretch = (length + zelda.RAY_CELL / zelda.RAY_PRECISION + 1) / length
    local hit = OF.util.optional("collision_find_surface_on_ray", nil,
        sx, sy, sz, dx * stretch, dy * stretch, dz * stretch, zelda.RAY_PRECISION)
    if hit == nil or hit.surface == nil or hit.hitPos == nil then return nil end
    local hx, hy, hz = hit.hitPos.x, hit.hitPos.y, hit.hitPos.z
    if (hx - sx) * dx + (hy - sy) * dy + (hz - sz) * dz > length * length + 0.5 then
        return nil
    end
    local s = hit.surface
    local n = s.normal or { x = 0, y = 1, z = 0 }
    return {
        x = hx, y = hy, z = hz,
        nx = n.x or 0, ny = n.y or 0, nz = n.z or 0,
        type = s.type or 0,

        obj = s.object,
    }
end

local DEADLY = {
    "SURFACE_DEATH_PLANE", "SURFACE_BURNING", "SURFACE_INSTANT_QUICKSAND",
    "SURFACE_INSTANT_MOVING_QUICKSAND", "SURFACE_DEEP_QUICKSAND",
    "SURFACE_DEEP_MOVING_QUICKSAND", "SURFACE_VERTICAL_WIND",
}
function zelda.deadly(surfaceType)
    for _, name in ipairs(DEADLY) do
        local v = _G[name]
        if type(v) == "number" and v == surfaceType then return true end
    end
    return false
end

zelda.HOOK_WALL_LOW = -0.2
zelda.HOOK_WALL_HIGH = 0.7

function zelda.hook_kind(hit)
    if hit == nil or zelda.deadly(hit.type) then return nil end
    if hit.ny > zelda.HOOK_WALL_HIGH then
        if hit.obj ~= nil then return "top" end
        return nil
    end
    if hit.ny >= zelda.HOOK_WALL_LOW then return "wall" end
    if type(SURFACE_HANGABLE) == "number" and hit.type == SURFACE_HANGABLE then
        return "hang"
    end
    return "ceiling"
end

zelda.CAM_REST_PITCH = 0x05B0
zelda.AIM_FAN_STEP = 0x80
zelda.AIM_FAN_TOP = 0x0700

function zelda.true_aim(m)
    if m == nil or m.controller == nil or not OF.util.asks(OF.shooter, "weapon_of") then
        return false
    end
    local ok, shape = pcall(OF.shooter.weapon_of, 0)
    return ok and shape ~= nil
        and OF.util.has_flag(m.controller.buttonDown or 0, L_TRIG)
end

local function fan_line(ex, ey, ez, hx, hz, pitch, cx, cy, cz, reach)
    local c = math.cos(pitch)
    local dx, dy, dz = hx * c, math.sin(pitch), hz * c
    local own = (cx - ex) * dx + (cy - ey) * dy + (cz - ez) * dz
    if own < 0 then own = 0 end
    local sx, sy, sz = ex + dx * own, ey + dy * own, ez + dz * own
    return dx, dy, dz, sx, sy, sz, zelda.cast(sx, sy, sz, dx * reach, dy * reach, dz * reach)
end

function zelda.aim(m, reach)
    local cx, cy, cz = m.pos.x, m.pos.y + zelda.HOOK_CHEST, m.pos.z
    reach = (type(reach) == "number" and reach > 0) and reach or zelda.HOOK_REACH[1]
    if zelda.true_aim(m) and OF.util.asks(OF.shooter, "throw_aim") then
        local tx, ty, tz = OF.shooter.throw_aim(m, reach)
        if tx ~= nil then
            local ax, ay, az, l = normalise(tx - cx, ty - cy, tz - cz)
            if l > 1 then return cx, cy, cz, ax, ay, az, l end
        end
    end
    local ex, ey, ez, dx, dy, dz = nil, nil, nil, nil, nil, nil
    if OF.util.asks(OF.util, "view_axis") then
        ex, ey, ez, dx, dy, dz = OF.util.view_axis()
    end
    local flat = dx ~= nil and math.sqrt(dx * dx + dz * dz) or 0
    if ex == nil or flat < 0.01 then
        local yaw = m.faceAngle.y
        return cx, cy, cz, sins(yaw), 0, coss(yaw), reach
    end
    local hx, hz = dx / flat, dz / flat
    local pitch0 = math.atan(dy, flat)
    local first = nil
    local lift = 0
    while lift <= zelda.AIM_FAN_TOP do
        local pitch = math.max(-1.4, math.min(1.4, pitch0 + lift * math.pi / 0x8000))
        local ldx, ldy, ldz, sx, sy, sz, hit = fan_line(ex, ey, ez, hx, hz, pitch,
            cx, cy, cz, reach)
        local px, py, pz
        if hit ~= nil then
            px, py, pz = hit.x, hit.y, hit.z
        else
            px, py, pz = sx + ldx * reach, sy + ldy * reach, sz + ldz * reach
        end
        local ax, ay, az, l = normalise(px - cx, py - cy, pz - cz)
        if l < 1 then ax, ay, az, l = ldx, ldy, ldz, reach end
        if first == nil then first = { ax, ay, az, l } end
        if hit == nil or hit.ny <= zelda.HOOK_WALL_HIGH then
            return cx, cy, cz, ax, ay, az, l
        end
        lift = lift + zelda.AIM_FAN_STEP
    end
    return cx, cy, cz, first[1], first[2], first[3], first[4]
end

function zelda.stands_down(li, tool)
    if not OF.util.asks(OF.lockdown, "menu_stands_down") then return false end
    if not OF.lockdown.menu_stands_down(li) then return false end
    if OF.util.asks(OF.rules, "rounds_keep_handouts")
        and OF.rules.rounds_keep_handouts() then
        return false
    end
    local np = li ~= nil and gNetworkPlayers ~= nil and gNetworkPlayers[li] or nil
    if tool ~= nil and np ~= nil and zelda.mode_hands(np.globalIndex, tool) then
        return false
    end
    return true
end

function zelda.pvp_allowed()
    if OF.util.asks(OF.powerups, "room_is_fighting") then
        return OF.powerups.room_is_fighting() == true
    end
    if gServerSettings == nil or PLAYER_INTERACTIONS_NONE == nil then return true end
    return gServerSettings.playerInteractions ~= PLAYER_INTERACTIONS_NONE
end

zelda.modeHands = zelda.modeHands or {}
function zelda.hand_out(tool, fn)
    if type(tool) ~= "string" then return false end
    if fn ~= nil and type(fn) ~= "function" then return false end
    zelda.modeHands[tool] = fn
    return true
end

function zelda.mode_hands(globalIndex, tool)
    local fn = zelda.modeHands[tool or ""]
    if fn == nil or globalIndex == nil then return false end
    local ok, said = pcall(fn, globalIndex)
    return ok and said == true
end

zelda.ROW_OF = { hook = "hookshot", chu = "chu", nut = "flashnut", boom = "boomerang" }

function zelda.may_use(globalIndex, tool)
    if zelda.mode_hands(globalIndex, tool) then return true end
    local row = zelda.ROW_OF[tool or ""]
    if row == nil or not OF.util.asks(OF.powerups, "carried_by") then return false end
    for _, key in ipairs(OF.powerups.carried_by(globalIndex)) do
        if key == row then return true end
    end
    return false
end

zelda.live = zelda.live or {}
zelda.links = zelda.links or {}

local function owner_of(o)
    local gi = (o.oBehParams or 0) - 1
    if gi < 0 then return nil, nil end
    return gi, OF.util.local_from_global(gi)
end

local function forget(o)
    local chain = zelda.links[o]
    if chain ~= nil then
        for _, link in ipairs(chain) do
            OF.util.optional("obj_mark_for_deletion", nil, link)
        end
    end
    zelda.links[o] = nil
    zelda.live[o] = nil
end

function zelda.remove(o)
    if o == nil then return end
    forget(o)
    OF.util.optional("obj_mark_for_deletion", nil, o)
end

function zelda.blast(x, y, z, li)
    if zelda.stands_down(li, zelda.CHU) then
        OF.util.optional("spawn_mist_particles", nil)
        return false
    end
    local bhv, model = id_bhvExplosion, E_MODEL_EXPLOSION
    if type(bhv) ~= "number" then return false end
    local o = OF.slots.spawn_non_sync(bhv, model, x, y + 60, z, nil)
    return o ~= nil
end

function zelda.crawl(st)
    local speed = zelda.CHU_SPEED
    local ux, uy, uz = st.ux, st.uy, st.uz

    local ground = zelda.cast(st.x + ux * 6, st.y + uy * 6, st.z + uz * 6,
        -ux * 18, -uy * 18, -uz * 18)
    if ground ~= nil then
        st.ux, st.uy, st.uz = normalise(ground.nx, ground.ny, ground.nz)
        if st.ux == 0 and st.uy == 0 and st.uz == 0 then
            st.ux, st.uy, st.uz = ux, uy, uz
        end
        if zelda.deadly(ground.type) then return false end
        st.x, st.y, st.z = ground.x + st.ux, ground.y + st.uy, ground.z + st.uz

        local d = st.fx * st.ux + st.fy * st.uy + st.fz * st.uz
        local fx, fy, fz, l = normalise(st.fx - st.ux * d, st.fy - st.uy * d,
            st.fz - st.uz * d)
        if l > 0 then st.fx, st.fy, st.fz = fx, fy, fz end

        local wall = zelda.cast(st.x + st.ux * 6, st.y + st.uy * 6, st.z + st.uz * 6,
            st.fx * speed * 2, st.fy * speed * 2, st.fz * speed * 2)
        if wall ~= nil then
            if zelda.deadly(wall.type) then return false end
            local nx, ny, nz = normalise(wall.nx, wall.ny, wall.nz)

            local oux, ouy, ouz = st.ux, st.uy, st.uz
            local k = oux * nx + ouy * ny + ouz * nz
            local gx, gy, gz, gl = normalise(oux - nx * k, ouy - ny * k, ouz - nz * k)
            if gl == 0 then return false end
            st.ux, st.uy, st.uz = nx, ny, nz
            st.fx, st.fy, st.fz = gx, gy, gz
            st.x, st.y, st.z = wall.x + nx * 2, wall.y + ny * 2, wall.z + nz * 2
        else
            st.x = st.x + st.fx * speed
            st.y = st.y + st.fy * speed
            st.z = st.z + st.fz * speed
        end
        return true
    end

    local back = zelda.cast(st.x - ux * 12, st.y - uy * 12, st.z - uz * 12,
        -st.fx * speed * 3, -st.fy * speed * 3, -st.fz * speed * 3)
    if back == nil or zelda.deadly(back.type) then return false end
    local nx, ny, nz = normalise(back.nx, back.ny, back.nz)
    st.fx, st.fy, st.fz = -ux, -uy, -uz
    st.ux, st.uy, st.uz = nx, ny, nz
    st.x, st.y, st.z = back.x + nx * 2, back.y + ny * 2, back.z + nz * 2
    return true
end

local function player_within(x, y, z, reach, notGlobal, skip)
    if gMarioStates == nil then return nil end
    for li = 0, (MAX_PLAYERS or 16) - 1 do
        local m = gMarioStates[li]
        local np = gNetworkPlayers ~= nil and gNetworkPlayers[li] or nil
        if m ~= nil and m.pos ~= nil and np ~= nil and np.connected
            and np.globalIndex ~= notGlobal and (skip == nil or not skip[li])
            and same_room(li)
            and dist3(x, y, z, m.pos.x, m.pos.y + 80, m.pos.z) < reach then
            return li, m
        end
    end
    return nil
end
zelda.player_within = player_within

local function chu_frame(o, st)
    local ownerGi = owner_of(o)
    local age = st.age
    if age > zelda.CHU_LIFE then return false end
    local li = player_within(st.x, st.y, st.z, zelda.CHU_REACH, ownerGi)
    if li ~= nil and (ownerGi == mine() or li == 0) then
        st.touched = true
        return false
    end
    if not zelda.crawl(st) then return false end
    o.oPosX, o.oPosY, o.oPosZ = st.x, st.y, st.z

    local flat = math.sqrt(st.fx * st.fx + st.fz * st.fz)
    if flat > 0.01 then
        o.oFaceAngleYaw = OF.util.optional("atan2s", 0, st.fz, st.fx) or 0
    else
        o.oFaceAngleYaw = OF.util.optional("atan2s", 0, -st.uz, -st.ux) or 0
    end
    o.oFaceAnglePitch = OF.util.optional("atan2s", 0, flat, -st.fy) or 0
    o.oFaceAngleRoll = 0
    o.oMoveAngleYaw = o.oFaceAngleYaw
    return true
end

local function turn_toward(yaw, wantYaw, fraction)
    local gap = ((wantYaw - yaw + 0x8000) % 0x10000) - 0x8000
    return math.floor(yaw + gap * fraction) % 0x10000
end

local function boom_frame(o, st)
    local ownerGi, ownerLi = owner_of(o)
    if st.age > zelda.BOOM_LIFE or ownerLi == nil then return false end
    if st.age >= zelda.BOOM_OUT then st.back = true end

    local owner = gMarioStates[ownerLi]
    local tx, ty, tz
    if st.back then
        if owner == nil or owner.pos == nil then return false end
        tx, ty, tz = owner.pos.x, owner.pos.y + zelda.HOOK_CHEST, owner.pos.z
    elseif st.target ~= nil then
        local tli = OF.util.local_from_global(st.target)
        local tm = tli ~= nil and gMarioStates[tli] or nil
        if tm ~= nil and tm.pos ~= nil then
            tx, ty, tz = tm.pos.x, tm.pos.y + zelda.HOOK_CHEST, tm.pos.z
        end
    end
    if tx ~= nil then
        local d = dist3(st.x, st.y, st.z, tx, ty, tz)
        if st.back and d < zelda.BOOM_CATCH then return false end
        local fraction = (zelda.BOOM_TURN_FAR - d) * zelda.BOOM_TURN_RATE
        if fraction < zelda.BOOM_TURN_MIN then fraction = zelda.BOOM_TURN_MIN end
        if st.back and fraction < 0.35 then fraction = 0.35 end
        if fraction > 1 then fraction = 1 end
        local want = OF.util.optional("atan2s", st.yaw, tz - st.z, tx - st.x) or st.yaw
        st.yaw = turn_toward(st.yaw, want, fraction)
        st.vy = math.max(-zelda.BOOM_SPEED, math.min(zelda.BOOM_SPEED, (ty - st.y) * 0.3))
    end

    local dx = sins(st.yaw) * zelda.BOOM_SPEED
    local dz = coss(st.yaw) * zelda.BOOM_SPEED

    local wall = (not st.back) and zelda.cast(st.x, st.y, st.z, dx, st.vy, dz) or nil
    if wall ~= nil then

        st.back = true
    else
        st.x, st.y, st.z = st.x + dx, st.y + st.vy, st.z + dz
    end

    local li, m = player_within(st.x, st.y, st.z, zelda.BOOM_HIT, ownerGi, st.hit)
    if li ~= nil then
        st.hit[li] = true
        st.back = true
        if li == 0 then zelda.struck(m, ownerLi, st.yaw) end
    end

    if ownerGi == mine() then zelda.fetch(st) end

    o.oPosX, o.oPosY, o.oPosZ = st.x, st.y, st.z
    o.oFaceAngleYaw = ((o.oFaceAngleYaw or 0) + 0x2000) % 0x10000
    o.oMoveAngleYaw = st.yaw
    return true
end

zelda.boomHitAt = zelda.boomHitAt or nil
function zelda.struck(m, fromLi, yaw)
    if m == nil then return false end
    if zelda.stands_down(fromLi, zelda.BOOM) then return false end
    if not zelda.pvp_allowed() then return false end
    if OF.util.asks(OF.powerups, "ball_may_touch") and not OF.powerups.ball_may_touch(m) then
        return false
    end
    if m.faceAngle ~= nil then m.faceAngle.y = (yaw + 0x8000) % 0x10000 end
    m.forwardVel = zelda.BOOM_KNOCK
    if m.vel ~= nil then m.vel.y = zelda.BOOM_KNOCK_UP end
    set_mario_action(m, ACT_BACKWARD_AIR_KB, 0)
    return true
end

local coinKinds = nil
function zelda.fetch(st)
    if st.coins == nil then st.coins = {} end
    if #st.coins < zelda.BOOM_CARRY and obj_get_first_with_behavior_id ~= nil then
        if coinKinds == nil then
            coinKinds = {}
            local names = OF.powerups ~= nil and OF.powerups.COIN_KINDS or {}
            for _, name in ipairs(names) do
                if type(_G[name]) == "number" then table.insert(coinKinds, _G[name]) end
            end
        end
        for _, kind in ipairs(coinKinds) do
            local coin = obj_get_first_with_behavior_id(kind)
            while coin ~= nil and #st.coins < zelda.BOOM_CARRY do
                if dist3(st.x, st.y, st.z, coin.oPosX or 0, coin.oPosY or 0,
                        coin.oPosZ or 0) < zelda.BOOM_HIT then
                    local taken = false
                    for _, c in ipairs(st.coins) do if c == coin then taken = true end end
                    if not taken then table.insert(st.coins, coin) end
                end
                coin = obj_get_next_with_same_behavior_id(coin)
            end
        end
    end
    for _, coin in ipairs(st.coins) do
        if coin.activeFlags ~= 0 then
            coin.oPosX, coin.oPosY, coin.oPosZ = st.x, st.y, st.z
            coin.oVelY = 0
        end
    end
    return #st.coins
end

local function tip_frame(o, st)
    local _, ownerLi = owner_of(o)
    if ownerLi == nil then return false end
    local owner = gMarioStates[ownerLi]
    if owner == nil or owner.pos == nil then return false end
    if st.age > zelda.HOOK_MAX_FRAMES + 10 then return false end
    if st.reel ~= nil then

        local item = st.reel
        if item.activeFlags == 0 then return false end
        local cx, cy, cz = owner.pos.x, owner.pos.y + zelda.HOOK_CHEST, owner.pos.z
        local d = dist3(item.oPosX, item.oPosY, item.oPosZ, cx, cy, cz)
        if d <= zelda.HOOK_SPEED + zelda.HOOK_REEL_NEAR then
            item.oPosX, item.oPosY, item.oPosZ = cx, owner.pos.y + 40, cz
            return false
        end
        local k = zelda.HOOK_SPEED / d
        item.oPosX = item.oPosX + (cx - item.oPosX) * k
        item.oPosY = item.oPosY + (cy - item.oPosY) * k
        item.oPosZ = item.oPosZ + (cz - item.oPosZ) * k
        item.oVelY = 0
        st.x, st.y, st.z = item.oPosX, item.oPosY, item.oPosZ
        o.oPosX, o.oPosY, o.oPosZ = st.x, st.y, st.z
        zelda.draw_chain(o, cx, cy, cz, st.x, st.y, st.z)
        return true
    end
    if st.victim ~= nil then
        local vli = OF.util.local_from_global(st.victim)
        local vm = vli ~= nil and gMarioStates[vli] or nil
        if vm == nil or vm.pos == nil then return false end
        st.x, st.y, st.z = vm.pos.x, vm.pos.y + zelda.HOOK_CHEST, vm.pos.z
        if dist3(owner.pos.x, owner.pos.y, owner.pos.z, vm.pos.x, vm.pos.y,
                vm.pos.z) < zelda.HOOK_ARRIVE_PLAYER + 30 and st.age > 2 then
            return false
        end
    elseif st.age > 2 and dist3(owner.pos.x, owner.pos.y + zelda.HOOK_CHEST,
            owner.pos.z, st.x, st.y, st.z) < zelda.HOOK_ARRIVE + 40 then
        return false

    elseif not st.miss and st.age > 2 and zelda.ACT_HOOK ~= nil
            and owner.action ~= zelda.ACT_HOOK then
        return false
    elseif st.miss and st.age > 8 then
        return false
    end
    o.oPosX, o.oPosY, o.oPosZ = st.x, st.y, st.z
    zelda.draw_chain(o, owner.pos.x, owner.pos.y + zelda.HOOK_CHEST, owner.pos.z,
        st.x, st.y, st.z)
    return true
end

zelda.tipsOut = 0
function zelda.draw_chain(o, ax, ay, az, bx, by, bz, gap)
    local most = zelda.tipsOut > zelda.CROWD and zelda.LINKS_CROWDED or zelda.LINKS
    local want = math.max(2, math.min(most,
        math.ceil(dist3(ax, ay, az, bx, by, bz) / (gap or zelda.LINK_GAP))))
    local chain = zelda.links[o]
    if chain == nil then chain = {}; zelda.links[o] = chain end
    local bhv = zelda.BEHAVIOUR
    local model = _G[zelda.MODEL_LINK]
    while #chain < want and type(bhv) == "number" and type(model) == "number" do
        local link = OF.slots.spawn_non_sync(bhv, model, ax, ay, az, function(l)
            l.oBehParams2ndByte = 0
        end)
        if link == nil then break end
        OF.util.optional("obj_scale", nil, link, 0.3)
        table.insert(chain, link)
    end
    while #chain > want do
        OF.util.optional("obj_mark_for_deletion", nil, table.remove(chain))
    end
    for i, link in ipairs(chain) do
        local t = i / (#chain + 1)
        link.oPosX = ax + (bx - ax) * t
        link.oPosY = ay + (by - ay) * t
        link.oPosZ = az + (bz - az) * t
    end
    return #chain
end

local function draws_where_it_is(o)
    local flag = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE or 1
    if not OF.util.has_flag(o.oFlags or 0, flag) then
        o.oFlags = (o.oFlags or 0) + flag
    end
end

local function tool_init(o)
    draws_where_it_is(o)
    local kind = o.oBehParams2ndByte or 0
    if kind == 0 then return end
    local st = {
        kind = kind, age = 0,
        x = o.oPosX or 0, y = o.oPosY or 0, z = o.oPosZ or 0,
        yaw = o.oMoveAngleYaw or 0, vy = 0, hit = {},
    }
    if kind == zelda.KIND_CHU then
        st.ux, st.uy, st.uz = 0, 1, 0
        st.fx, st.fy, st.fz = sins(st.yaw), 0, coss(st.yaw)

        if gObjectAnimations ~= nil and gObjectAnimations.bobomb_seg8_anims_0802396C ~= nil then
            o.oAnimations = gObjectAnimations.bobomb_seg8_anims_0802396C
            OF.util.optional("obj_init_animation_with_accel_and_sound", nil, o, 0, 1.0)
        end
    elseif kind == zelda.KIND_BOOM then
        local target = o.oHealth or 0
        st.target = target > 0 and (target - 1) or nil
        st.vy = o.oVelY or 0
    elseif kind == zelda.KIND_TIP then
        local victim = o.oHealth or 0
        st.victim = victim > 0 and (victim - 1) or nil
        st.miss = (o.oAnimState or 0) == 1
    elseif kind == zelda.KIND_CHOMP or kind == zelda.KIND_FLAIL then

        st.vy = o.oVelY or 0
        if zelda.dress_chomp ~= nil then zelda.dress_chomp(o) end
    end
    zelda.live[o] = st
end

function zelda.tool_loop(o)
    draws_where_it_is(o)
    local kind = o.oBehParams2ndByte or 0
    if kind == 0 then return end
    local st = zelda.live[o]
    if st == nil then
        tool_init(o)
        st = zelda.live[o]
        if st == nil then return end
    end
    st.age = st.age + 1
    local alive
    if kind == zelda.KIND_CHU then
        alive = chu_frame(o, st)
        if not alive then
            local ownerGi, ownerLi = owner_of(o)
            zelda.blast(st.x, st.y, st.z, ownerLi)
            if st.touched and ownerGi ~= nil then
                zelda.send({ k = "chu", o = ownerGi, x = math.floor(st.x),
                    y = math.floor(st.y), z = math.floor(st.z) })
            end
        end
    elseif kind == zelda.KIND_BOOM then
        alive = boom_frame(o, st)
    elseif kind == zelda.KIND_TIP then
        alive = tip_frame(o, st)
    elseif kind == zelda.KIND_CHOMP then
        alive = zelda.chomp_frame(o, st)
    elseif kind == zelda.KIND_FLAIL then
        alive = zelda.flail_frame(o, st)
    elseif kind == zelda.KIND_PUFF then
        alive = zelda.puff_frame(o, st)
    end
    if not alive then zelda.remove(o) end
end

if type(hook_behavior) == "function" and zelda.BEHAVIOUR == nil then
    zelda.BEHAVIOUR = hook_behavior(nil, OBJ_LIST_DEFAULT, false,
        tool_init, zelda.tool_loop, "of tool")
end

local function spawn_tool(kind, modelName, x, y, z, yaw, extra, miss, climb)
    local bhv, model = zelda.BEHAVIOUR, _G[modelName]
    if type(bhv) ~= "number" or type(model) ~= "number" then return nil end
    local me = mine()
    local o = OF.slots.spawn_lobby(bhv, model, x, y, z, function(o)
        o.oIntangibleTimer = -1
        o.oMoveAngleYaw = yaw
        o.oFaceAngleYaw = yaw
        o.oBehParams = me + 1
        o.oBehParams2ndByte = kind
        o.oHealth = extra or 0

        o.oAnimState = miss and 1 or 0
        o.oVelY = climb or 0
    end)

    if o ~= nil then tool_init(o) end
    return o
end

function zelda.one_alive(kind)
    local me = mine()
    for o, st in pairs(zelda.live) do
        if st.kind == kind and (o.oBehParams or 0) - 1 == me
            and o.activeFlags ~= 0 then
            return true
        end
    end
    return false
end

zelda.flight = zelda.flight or nil
zelda.pulledAt = -9999
zelda.clock = 0

local function at_load(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if not ok then return nil end
    return result
end

if zelda.ACT_HOOK == nil and type(ACT_GROUP_AIRBORNE) == "number"
    and type(ACT_FLAG_AIR) == "number" then
    zelda.ACT_HOOK = at_load("allocate_mario_action", ACT_GROUP_AIRBORNE | ACT_FLAG_AIR)
end

function zelda.act_hook(m)

    if m.playerIndex ~= nil and m.playerIndex ~= 0 then
        OF.util.optional("set_mario_animation", nil, m, MARIO_ANIM_AIRBORNE_ON_STOMACH
            or MARIO_ANIM_FORWARD_SPINNING or 0)
        local vy = m.vel.y
        perform_air_step(m, 0)
        m.vel.y = vy
        return false
    end
    local f = zelda.flight
    if f == nil then
        set_mario_action(m, ACT_FREEFALL, 0)
        return false
    end
    f.frames = f.frames + 1
    if f.follow ~= nil then
        local li = OF.util.local_from_global(f.follow)
        local them = li ~= nil and gMarioStates[li] or nil
        if them == nil or them.pos == nil or not same_room(li) then
            zelda.land(m)
            return false
        end
        f.x, f.y, f.z = them.pos.x, them.pos.y, them.pos.z
    end
    if f.obj ~= nil then
        local ox, oy, oz = zelda.object_point(f)
        if ox == nil then

            zelda.flight = nil
            set_mario_action(m, ACT_FREEFALL, 0)
            return false
        end
        f.x, f.y, f.z = ox, oy, oz
        if f.riding then return zelda.ride(m, f) end
    end
    local ty = f.y
    local ground = m.floorHeight
    if type(ground) == "number" and ty < ground + zelda.HOOK_SKIM then
        ty = ground + zelda.HOOK_SKIM
    end
    local dx, dy, dz = f.x - m.pos.x, ty - m.pos.y, f.z - m.pos.z
    local d = math.sqrt(dx * dx + dy * dy + dz * dz)
    if f.obj ~= nil and not f.onTop and d < f.arrive + zelda.HOOK_WALL_NEAR then

        f.riding, f.frames = true, 0
        return zelda.ride(m, f)
    end
    if d < f.arrive or f.frames > (f.limit or zelda.HOOK_MAX_FRAMES) then
        zelda.land(m)
        return false
    end
    if f.best == nil or d < f.best - 1 then
        f.best, f.still = d, 0
    else
        f.still = (f.still or 0) + 1
        if f.still >= zelda.HOOK_STUCK then
            zelda.land(m)
            return false
        end
    end

    local s = math.min(f.speed or zelda.HOOK_SPEED, d) / d
    m.vel.x, m.vel.y, m.vel.z = dx * s, dy * s, dz * s
    m.forwardVel = f.speed or zelda.HOOK_SPEED
    m.faceAngle.y = OF.util.optional("atan2s", m.faceAngle.y, dz, dx) or m.faceAngle.y
    OF.util.optional("set_mario_animation", nil, m, MARIO_ANIM_AIRBORNE_ON_STOMACH
        or MARIO_ANIM_FORWARD_SPINNING or 0)
    local near = d < zelda.HOOK_LEDGE_NEAR
    local step = perform_air_step(m, near and (AIR_STEP_CHECK_LEDGE_GRAB or 0) or 0)
    if step == AIR_STEP_GRABBED_LEDGE and ACT_LEDGE_GRAB ~= nil then
        zelda.flight = nil
        set_mario_action(m, ACT_LEDGE_GRAB, 0)
        return false
    end
    if step == AIR_STEP_LANDED and d < f.arrive + zelda.HOOK_WALL_NEAR then
        zelda.flight = nil
        set_mario_action(m, ACT_FREEFALL_LAND, 0)
        return false
    end
    if (step == AIR_STEP_HIT_WALL and d < f.arrive + zelda.HOOK_WALL_NEAR)
        or step == AIR_STEP_HIT_LAVA_WALL then
        zelda.land(m)
        return false
    end
    return false
end

function zelda.ride(m, f)
    if OF.util.has_flag(m.input or 0, INPUT_A_PRESSED) then
        local o = f.obj
        zelda.flight = nil
        m.vel.y = 42 + math.max(0, (o ~= nil and o.oVelY) or 0)
        m.forwardVel = 16
        set_mario_action(m, ACT_JUMP, 0)
        return false
    end
    if OF.util.has_flag(m.input or 0, INPUT_Z_PRESSED) or f.frames > zelda.HOOK_RIDE_MOST then
        zelda.flight = nil
        m.vel.x, m.vel.y, m.vel.z, m.forwardVel = 0, 0, 0, 0
        set_mario_action(m, ACT_FREEFALL, 0)
        return false
    end
    m.pos.x, m.pos.y, m.pos.z = f.x, f.y, f.z
    m.vel.x, m.vel.y, m.vel.z, m.forwardVel = 0, 0, 0, 0
    OF.util.optional("set_mario_animation", nil, m,
        MARIO_ANIM_HANG_ON_OWL or MARIO_ANIM_HANG_ON_CEILING or 0)
    return false
end

function zelda.land(m)
    local f = zelda.flight
    zelda.flight = nil

    local startHang = rawget(_G, "ACT_START_HANGING")
    if f ~= nil and f.hang and type(startHang) == "number" then
        m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
        m.forwardVel = 0
        set_mario_action(m, startHang, 0)
        return true
    end
    if f ~= nil and f.ceiling then
        m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
        m.forwardVel = 0
        set_mario_action(m, ACT_FREEFALL, 0)
        return true
    end
    m.vel.y = zelda.HOOK_HOP
    m.forwardVel = 8
    set_mario_action(m, ACT_FREEFALL, 0)
    if f ~= nil and f.wallN ~= nil and f.obj == nil then
        local flat = math.sqrt(f.wallN.x * f.wallN.x + f.wallN.z * f.wallN.z)
        if flat > 0.01 then
            zelda.wallKick = { nx = f.wallN.x / flat, nz = f.wallN.z / flat,
                px = f.wallN.px, pz = f.wallN.pz, frames = 0 }
        end
    end
    return true
end

zelda.WALL_KICK_REACH = 80
zelda.WALL_KICK_FRAMES = 45
zelda.wallKick = nil

function zelda.wall_kick_step(m)
    local k = zelda.wallKick
    if k == nil or m == nil then return false end
    k.frames = k.frames + 1
    local airborne = m.action == ACT_FREEFALL or m.action == ACT_JUMP
        or m.action == ACT_DOUBLE_JUMP or m.action == ACT_WALL_KICK_AIR
    if not airborne or k.frames > zelda.WALL_KICK_FRAMES then
        zelda.wallKick = nil
        return false
    end
    local away = (m.pos.x - k.px) * k.nx + (m.pos.z - k.pz) * k.nz
    if away > zelda.WALL_KICK_REACH or away < -10 then return false end
    if not OF.util.has_flag(m.input or 0, INPUT_A_PRESSED) then return false end
    zelda.wallKick = nil
    m.faceAngle.y = OF.util.optional("atan2s", m.faceAngle.y, k.nz, k.nx) or m.faceAngle.y
    m.vel.y = 52
    set_mario_action(m, ACT_WALL_KICK_AIR, 0)
    return true
end

if zelda.ACT_HOOK ~= nil then
    at_load("hook_mario_action", zelda.ACT_HOOK, { every_frame = zelda.act_hook })
end

zelda.HOOK_RIDE_MOST = 300
function zelda.on_object(o, x, y, z)
    if o == nil or o.oPosX == nil then return nil end
    local yaw = (o.oFaceAngleYaw or 0) * math.pi / 0x8000
    local dx, dy, dz = x - o.oPosX, y - o.oPosY, z - o.oPosZ
    local c, sn = math.cos(-yaw), math.sin(-yaw)
    return { obj = o, ox = dx * c + dz * sn, oy = dy, oz = -dx * sn + dz * c }
end

function zelda.object_point(f)
    local o = f ~= nil and f.obj or nil
    if o == nil or (o.activeFlags or 0) == 0 then return nil end
    local yaw = (o.oFaceAngleYaw or 0) * math.pi / 0x8000
    local c, sn = math.cos(yaw), math.sin(yaw)
    return o.oPosX + f.ox * c + f.oz * sn, o.oPosY + f.oy, o.oPosZ - f.ox * sn + f.oz * c
end

function zelda.fly(m, x, y, z, arrive, how)
    if m == nil or zelda.ACT_HOOK == nil then return false end
    local d = m.pos ~= nil and dist3(m.pos.x, m.pos.y, m.pos.z, x, y, z) or 0
    local speed = math.max(zelda.HOOK_SPEED, math.min(zelda.HOOK_SPEED_MAX,
        d / zelda.HOOK_FLIGHT))
    zelda.flight = { x = x, y = y, z = z, frames = 0, arrive = arrive or zelda.HOOK_ARRIVE,
        speed = speed,
        limit = math.min(zelda.HOOK_MAX_FRAMES, math.ceil(d / speed) + zelda.HOOK_SPARE) }
    if how ~= nil and how.follow ~= nil then zelda.flight.limit = zelda.HOOK_MAX_FRAMES end
    for k, v in pairs(how or {}) do zelda.flight[k] = v end
    set_mario_action(m, zelda.ACT_HOOK, 0)
    return true
end

local function off_line(sx, sy, sz, ax, ay, az, px, py, pz)
    local t = (px - sx) * ax + (py - sy) * ay + (pz - sz) * az
    local cx, cy, cz = sx + ax * t, sy + ay * t, sz + az * t
    return t, math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2), math.abs(py - cy)
end

zelda.HOOK_CATCH_HIGH = 250
function zelda.player_on_line(sx, sy, sz, yaw, upTo, ax, ay, az)
    if ax == nil then ax, ay, az = sins(yaw), 0, coss(yaw) end
    local me = mine()
    local best, bestT = nil, nil
    for li = 1, (MAX_PLAYERS or 16) - 1 do
        local m = gMarioStates[li]
        local np = gNetworkPlayers[li]
        if m ~= nil and m.pos ~= nil and np ~= nil and np.connected
            and np.globalIndex ~= me and same_room(li) then
            local px, py, pz = m.pos.x, m.pos.y + zelda.HOOK_CHEST, m.pos.z
            local t, across, high = off_line(sx, sy, sz, ax, ay, az, px, py, pz)
            if t > 0 and t <= upTo and (bestT == nil or t < bestT)
                and across < zelda.HOOK_CATCH and high < zelda.HOOK_CATCH_HIGH
                and zelda.cast(sx, sy, sz, (px - sx) * 0.95, (py - sy) * 0.95,
                    (pz - sz) * 0.95) == nil then
                best, bestT = np.globalIndex, t
            end
        end
    end
    return best, bestT
end

function zelda.pole_on_line(sx, sy, sz, ax, ay, az, upTo)
    if obj_get_first == nil or OBJ_LIST_POLELIKE == nil then return nil end
    local best, bestT, bestY = nil, nil, nil
    local o = obj_get_first(OBJ_LIST_POLELIKE)
    local guard = 0
    while o ~= nil and guard < 256 do
        guard = guard + 1
        if o.activeFlags ~= 0 and o.oInteractType == INTERACT_POLE then

            local flat = ax * ax + az * az
            local t, across = -1, math.huge
            if flat > 0.000001 then
                t = ((o.oPosX - sx) * ax + (o.oPosZ - sz) * az) / flat
                local cx, cz = sx + ax * t, sz + az * t
                across = math.sqrt((o.oPosX - cx) ^ 2 + (o.oPosZ - cz) ^ 2)
            end
            local y = sy + ay * t
            local bottom = (o.oPosY or 0) - (o.hitboxDownOffset or 0)
            local top = bottom + (o.hitboxHeight or 0)
            if t > 0 and t <= upTo and (bestT == nil or t < bestT)
                and across < (o.hitboxRadius or 0) + zelda.HOOK_POLE_MARGIN
                and y >= bottom and y <= top then
                best, bestT, bestY = o, t, y
            end
        end
        o = obj_get_next(o)
    end
    return best, bestT, bestY
end

local itemKinds = nil
function zelda.item_on_line(sx, sy, sz, ax, ay, az, upTo)
    if obj_get_first_with_behavior_id == nil then return nil end
    if itemKinds == nil then
        itemKinds = {}
        for _, name in ipairs(zelda.ITEM_KINDS) do
            if type(_G[name]) == "number" then table.insert(itemKinds, _G[name]) end
        end
    end
    local best, bestT = nil, nil
    for _, kind in ipairs(itemKinds) do
        local o = obj_get_first_with_behavior_id(kind)
        while o ~= nil do
            if o.activeFlags ~= 0 then
                local t, across, high = off_line(sx, sy, sz, ax, ay, az,
                    o.oPosX or 0, o.oPosY or 0, o.oPosZ or 0)
                if t > 0 and t <= upTo and (bestT == nil or t < bestT)
                    and math.sqrt(across * across + high * high) < zelda.HOOK_ITEM_CATCH then
                    best, bestT = o, t
                end
            end
            o = obj_get_next_with_same_behavior_id(o)
        end
    end
    return best, bestT
end

function zelda.fire_hook(m, rung)
    if m == nil or m.pos == nil then return false end
    if zelda.flight ~= nil then return false, "Already on the chain." end
    local reach = zelda.HOOK_REACH[rung or 1] or zelda.HOOK_REACH[1]
    local sx, sy, sz, ax, ay, az = zelda.aim(m, reach)
    local yaw = OF.util.optional("atan2s", m.faceAngle.y, az, ax) or m.faceAngle.y

    reach = reach + zelda.HOOK_SLACK
    local dx, dy, dz = ax * reach, ay * reach, az * reach

    local hit = zelda.cast(sx, sy, sz, dx, dy, dz)
    local upTo = reach
    if hit ~= nil then upTo = dist3(sx, sy, sz, hit.x, hit.y, hit.z) end

    local victim, victimT = zelda.player_on_line(sx, sy, sz, yaw, upTo, ax, ay, az)
    local pole, poleT, poleY = zelda.pole_on_line(sx, sy, sz, ax, ay, az, upTo)
    local item, itemT = zelda.item_on_line(sx, sy, sz, ax, ay, az, upTo)
    local nearest = math.min(victimT or math.huge, poleT or math.huge, itemT or math.huge)

    if victim ~= nil and victimT == nearest then
        local vli = OF.util.local_from_global(victim)
        if not zelda.stands_down(vli, zelda.HOOK) then
            local vm = gMarioStates[vli]
            spawn_tool(zelda.KIND_TIP, zelda.MODEL_TIP, vm.pos.x,
                vm.pos.y + zelda.HOOK_CHEST, vm.pos.z, yaw, victim + 1)
            OF.sounds.play(SOUND_ACTION_SPIN)

            if zelda.pvp_allowed() then
                zelda.send({ k = "pull", v = victim })
            else
                zelda.fly(m, vm.pos.x, vm.pos.y, vm.pos.z, zelda.HOOK_ARRIVE_PLAYER,
                    { follow = victim })
            end
            return true
        end
    end

    if pole ~= nil and poleT == nearest then
        spawn_tool(zelda.KIND_TIP, zelda.MODEL_TIP, pole.oPosX, poleY, pole.oPosZ, yaw, 0)
        zelda.fly(m, pole.oPosX, poleY - zelda.HOOK_CHEST, pole.oPosZ,
            zelda.HOOK_ARRIVE_POLE, { pole = true })
        OF.sounds.play(SOUND_ACTION_SPIN)
        return true
    end

    if item ~= nil and itemT == nearest then
        local tip = spawn_tool(zelda.KIND_TIP, zelda.MODEL_TIP, item.oPosX,
            item.oPosY, item.oPosZ, yaw, 0, true)
        if tip ~= nil and zelda.live[tip] ~= nil then zelda.live[tip].reel = item end
        OF.sounds.play(SOUND_ACTION_SPIN)
        return true
    end

    local kind = zelda.hook_kind(hit)
    if kind == "wall" then

        local tx, ty, tz = hit.x + hit.nx * 30, hit.y + hit.ny * 30, hit.z + hit.nz * 30
        spawn_tool(zelda.KIND_TIP, zelda.MODEL_TIP, tx, ty, tz, yaw, 0)
        local how = zelda.on_object(hit.obj, tx, ty - zelda.HOOK_CHEST, tz) or {}

        how.wallN = { x = hit.nx, z = hit.nz, px = hit.x, pz = hit.z }
        zelda.fly(m, tx, ty - zelda.HOOK_CHEST, tz, nil, how)
        OF.sounds.play(SOUND_ACTION_SPIN)
        return true
    elseif kind == "top" then

        spawn_tool(zelda.KIND_TIP, zelda.MODEL_TIP, hit.x, hit.y + 10, hit.z, yaw, 0)
        local how = zelda.on_object(hit.obj, hit.x, hit.y + zelda.HOOK_SKIM, hit.z) or {}
        how.onTop = true
        zelda.fly(m, hit.x, hit.y + zelda.HOOK_SKIM, hit.z, nil, how)
        OF.sounds.play(SOUND_ACTION_SPIN)
        return true
    elseif kind ~= nil then
        spawn_tool(zelda.KIND_TIP, zelda.MODEL_TIP, hit.x, hit.y - 10, hit.z, yaw, 0)
        local how = zelda.on_object(hit.obj, hit.x, hit.y - zelda.HOOK_HEAD, hit.z) or {}
        how.ceiling, how.hang = true, kind == "hang"
        zelda.fly(m, hit.x, hit.y - zelda.HOOK_HEAD, hit.z, zelda.HOOK_ARRIVE_CEIL, how)
        OF.sounds.play(SOUND_ACTION_SPIN)
        return true
    end

    local ex, ey, ez = sx + ax * upTo, sy + ay * upTo, sz + az * upTo
    spawn_tool(zelda.KIND_TIP, zelda.MODEL_TIP, ex, ey, ez, yaw, 0, true)
    OF.sounds.play(SOUND_GENERAL_METAL_POUND)
    return false, "Nothing to hook."
end

function zelda.pulled(fromGlobal)
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return false end
    local li = OF.util.local_from_global(fromGlobal)
    if li == nil or li == 0 or not same_room(li) then return false end
    if zelda.stands_down(li, zelda.HOOK) then return false end
    if not zelda.pvp_allowed() then return false end
    if zelda.clock - zelda.pulledAt < zelda.PULL_IMMUNE then return false end
    local from = gMarioStates[li]
    if from == nil or from.pos == nil then return false end
    zelda.pulledAt = zelda.clock
    return zelda.fly(m, from.pos.x, from.pos.y, from.pos.z, zelda.HOOK_ARRIVE_PLAYER)
end

function zelda.set_chu(m)
    if m == nil or m.pos == nil then return false end
    if zelda.one_alive(zelda.KIND_CHU) then return false, "One is still crawling." end
    local yaw = m.faceAngle.y
    local x = m.pos.x + sins(yaw) * zelda.CHU_AHEAD
    local z = m.pos.z + coss(yaw) * zelda.CHU_AHEAD
    local floor = zelda.cast(x, m.pos.y + 100, z, 0, -zelda.CHU_DROP, 0)
    if floor == nil or zelda.deadly(floor.type) then
        return false, "Nothing to set it down on."
    end
    local o = spawn_tool(zelda.KIND_CHU, zelda.MODEL_CHU, floor.x, floor.y + 1,
        floor.z, yaw, 0)
    if o ~= nil then OF.sounds.play(SOUND_OBJ_BOBOMB_WALK) end
    return o ~= nil
end

zelda.nutAt = -9999
zelda.flashedAt = -9999
zelda.white = 0
zelda.pop = 0
zelda.popPeak = 0

function zelda.nut_cooldown()
    if zelda.mode_hands(mine(), zelda.NUT) then return zelda.NUT_COOLDOWN_ROUND end
    return zelda.NUT_COOLDOWN
end

function zelda.throw_nut(m, reach, aimed)
    if m == nil or m.pos == nil then return false end
    if zelda.clock - zelda.nutAt < zelda.nut_cooldown() then return false, "Too soon." end
    reach = (type(reach) == "number" and reach > 0) and reach or zelda.NUT_AHEAD
    local sx, sy, sz = m.pos.x, m.pos.y + zelda.HOOK_CHEST, m.pos.z
    local x, y, z
    if aimed == true and OF.util.asks(OF.shooter, "throw_aim") then
        x, y, z = OF.shooter.throw_aim(m, reach)
    elseif aimed == nil then
        local _, _, _, ax, ay, az = zelda.aim(m, reach)
        x, y, z = sx + ax * reach, sy + ay * reach, sz + az * reach
    end
    if x == nil then
        local yaw = m.faceAngle.y
        x, y, z = sx + sins(yaw) * reach, m.pos.y + 20, sz + coss(yaw) * reach

        local ground = zelda.cast(x, y, z, 0, -zelda.CHU_DROP, 0)
        if ground ~= nil then y = ground.y + 20 end
    end
    local hit = zelda.cast(sx, sy, sz, x - sx, y - sy, z - sz)
    if hit ~= nil then x, y, z = hit.x, hit.y + 10, hit.z end
    zelda.nutAt = zelda.clock
    zelda.land_nut(mine(), x, y, z)
    zelda.send({ k = "nut", x = math.floor(x), y = math.floor(y), z = math.floor(z) })
    return true
end

zelda.fuses = {}
function zelda.land_nut(fromGlobal, x, y, z)
    local li = OF.util.local_from_global(fromGlobal)
    if li == nil or not same_room(li) then return false end
    if #zelda.fuses >= zelda.NUT_FUSES_MOST then

        local first = table.remove(zelda.fuses, 1)
        zelda.fuse_out(first)
    end
    local fuse = { from = fromGlobal, x = x, y = y, z = z, left = zelda.NUT_FUSE }

    local model = _G[zelda.NUT_FUSE_MODEL]
    if type(id_bhvStaticObject) == "number" and type(model) == "number" then
        fuse.o = OF.slots.spawn_non_sync(id_bhvStaticObject, model, x, y, z, function(o)
            OF.util.optional("obj_scale", nil, o, zelda.NUT_FUSE_SCALE)
        end)
    end
    table.insert(zelda.fuses, fuse)
    if OF.util.asks(OF.sounds, "play_from") then OF.sounds.play_from(fuse.o, SOUND_AIR_BOBOMB_LIT_FUSE) end
    return true
end

function zelda.fuse_out(fuse)
    if fuse.o ~= nil and OF.util.alive(fuse.o) then
        OF.util.optional("obj_mark_for_deletion", nil, fuse.o)
    end
    fuse.o = nil
    return zelda.flash(fuse.from, fuse.x, fuse.y, fuse.z)
end

function zelda.fuse_tick()
    local index = 1
    while index <= #zelda.fuses do
        local fuse = zelda.fuses[index]
        fuse.left = fuse.left - 1
        if fuse.left <= 0 then
            table.remove(zelda.fuses, index)
            zelda.fuse_out(fuse)
        else
            local beat = fuse.left % zelda.NUT_FUSE_BEAT == 0
            if fuse.o ~= nil and OF.util.alive(fuse.o) then
                OF.util.optional("obj_scale", nil, fuse.o,
                    beat and zelda.NUT_FUSE_PULSE or zelda.NUT_FUSE_SCALE)
            end
            if beat then
                OF.slots.spawn_non_sync(id_bhvSparkle or id_bhvSparkleSpawn,
                    _G[zelda.MODEL_FLASH], fuse.x, fuse.y + 20, fuse.z, nil)
                if OF.util.asks(OF.sounds, "play_from") then OF.sounds.play_from(fuse.o, SOUND_AIR_BOBOMB_LIT_FUSE) end
            end
            index = index + 1
        end
    end
end

function zelda.flash(fromGlobal, x, y, z)
    local li = OF.util.local_from_global(fromGlobal)
    if li == nil or not same_room(li) then return false end
    OF.slots.spawn_non_sync(id_bhvSparkleSpawn or id_bhvSparkle, _G[zelda.MODEL_FLASH],
        x, y, z, nil)
    OF.sounds.play(SOUND_GENERAL_BOWSER_BOMB_EXPLOSION or SOUND_OBJ_BULLY_EXPLODE)
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return false end
    if li ~= 0 and zelda.stands_down(li, zelda.NUT) then return false end

    local fromRound = zelda.mode_hands(fromGlobal, zelda.NUT)
    local meInRound = zelda.mode_hands(mine(), zelda.NUT)
    if li ~= 0 and fromRound and not meInRound then return false end
    local hx, hy, hz = m.pos.x, m.pos.y + zelda.HOOK_CHEST, m.pos.z
    local d = dist3(hx, hy, hz, x, y, z)
    if d > math.max(zelda.NUT_FLASH_RADIUS, zelda.NUT_POP_RADIUS) then return false end

    if zelda.cast(hx, hy, hz, (x - hx) * 0.95, (y - hy) * 0.95,
            (z - hz) * 0.95) ~= nil then
        return false
    end
    local out = { x = 0, y = 0, z = 0 }
    local facing = OF.util.optional("djui_hud_world_pos_to_screen_pos", false,
        { x = x, y = y, z = z }, out) == true
    if facing and d <= zelda.NUT_FLASH_RADIUS then
        zelda.white = zelda.NUT_WHITE
    elseif d <= zelda.NUT_POP_RADIUS then
        local peak = zelda.NUT_POP_PEAK * (1 - d / zelda.NUT_POP_RADIUS) * zelda.NUT_POP_AWAY
        if zelda.pop <= 0 or peak > zelda.popPeak then zelda.popPeak = peak end
        zelda.pop = zelda.NUT_POP
    end

    if li == 0 or d > zelda.NUT_RADIUS then return false end
    if zelda.clock - zelda.flashedAt < zelda.NUT_IMMUNE then return false end

    if not (fromRound and meInRound) and not zelda.pvp_allowed() then return false end
    zelda.flashedAt = zelda.clock
    if OF.util.asks(OF.powerups, "freeze") then
        OF.powerups.freeze(m, zelda.NUT_STUN / OF.powerups.FREEZE_FRAMES)
    end
    return true
end

function zelda.white_alpha()
    local a = 0
    if zelda.white > 0 then
        a = math.min(255, math.floor(255 * zelda.white / zelda.NUT_FADE))
    end
    if zelda.pop > 0 then
        a = math.max(a, math.floor(255 * zelda.popPeak * zelda.pop / zelda.NUT_POP))
    end
    return a
end

function zelda.draw_white()
    local a = zelda.white_alpha()
    if a <= 0 then return false end
    djui_hud_set_resolution(RESOLUTION_DJUI)
    OF.util.rect(0, 0, djui_hud_get_screen_width(), djui_hud_get_screen_height(),
        255, 255, 255, a)
    return true
end

function zelda.throw_boomerang(m)
    if m == nil or m.pos == nil then return false end
    if zelda.one_alive(zelda.KIND_BOOM) then return false, "It is still out." end

    local _, _, _, ax, ay, az = zelda.aim(m, zelda.BOOM_SPEED * zelda.BOOM_OUT)
    local yaw = OF.util.optional("atan2s", m.faceAngle.y, az, ax) or m.faceAngle.y
    local flat = math.sqrt(ax * ax + az * az)
    local climb = flat > 0.001 and zelda.BOOM_SPEED * ay / flat or 0
    climb = math.max(-zelda.BOOM_SPEED, math.min(zelda.BOOM_SPEED, climb))
    local target, bestD = 0, nil
    for li = 1, (MAX_PLAYERS or 16) - 1 do
        local them = gMarioStates[li]
        local np = gNetworkPlayers[li]
        if them ~= nil and them.pos ~= nil and np ~= nil and np.connected
            and same_room(li) then
            local d = dist3(m.pos.x, m.pos.y, m.pos.z, them.pos.x, them.pos.y, them.pos.z)
            local at = OF.util.optional("atan2s", 0, them.pos.z - m.pos.z,
                them.pos.x - m.pos.x) or 0
            local off = math.abs(((at - yaw + 0x8000) % 0x10000) - 0x8000)
            if d < zelda.BOOM_SPEED * zelda.BOOM_OUT and off < zelda.BOOM_CONE
                and (bestD == nil or d < bestD) then
                target, bestD = np.globalIndex + 1, d
            end
        end
    end
    local o = spawn_tool(zelda.KIND_BOOM, zelda.MODEL_BOOM,
        m.pos.x + sins(yaw) * 30, m.pos.y + zelda.HOOK_CHEST, m.pos.z + coss(yaw) * 30,
        yaw, target, nil, climb)
    if o ~= nil then OF.sounds.play(SOUND_ACTION_THROW) end
    return o ~= nil
end

zelda.JAR = "jar"
zelda.CHOMP = "chomp"
zelda.BOOTS = "boots"
zelda.KIND_CHOMP = 4
zelda.KIND_FLAIL = 5
zelda.ROW_OF.jar = "gustjar"
zelda.ROW_OF.chomp = "chompchain"
zelda.ROW_OF.boots = "pegasus"
zelda.JAR_REACH = 900
zelda.JAR_CONE = 0x1555
zelda.JAR_PULL = 28
zelda.JAR_MOUTH = 120
zelda.JAR_AHEAD = 100
zelda.JAR_HOLD = 60
zelda.JAR_IMMUNE = 90
zelda.JAR_WALK = 10
zelda.JAR_TURN = 0x400
zelda.JAR_CHARGE = { 60, 120 }

zelda.JAR_BLOW = 8
zelda.JAR_RECOIL = -20

zelda.JAR_SPIT = 56
zelda.JAR_SPIT_UP = 28
zelda.JAR_GUST = 30
zelda.JAR_GUST_UP = 20
zelda.JAR_GUST_MORE = 14

zelda.JAR_SUCK = 0
zelda.JAR_BLOWING = 1

zelda.JAR_SINK = -8
zelda.JAR_FLOAT = 1.5
zelda.JAR_BLOW_UP = 12
zelda.JAR_PUFF_EVERY = 3
zelda.JAR_PUFF_SPEED = 36
zelda.JAR_PUFFS = 10
zelda.JAR_BURST = 8
zelda.JAR_PUFF_LIFE = 24
zelda.MODEL_PUFF = "E_MODEL_WHITE_PARTICLE_SMALL"
zelda.PUFF_SCALE = 1.6
zelda.KIND_PUFF = 7

zelda.CHOMP_ORBIT = 250
zelda.CHOMP_SPIN = 0x0C00
zelda.CHOMP_HIT = 160
zelda.CHOMP_IMMUNE = 60
zelda.CHOMP_SLOW = 19
zelda.CHOMP_SPEED = 60
zelda.CHOMP_LIFT = 5
zelda.CHOMP_FLOAT = 0.5
zelda.CHOMP_FALL = 5.5
zelda.CHOMP_FALL_MOST = 150
zelda.CHOMP_OUT = 20
zelda.CHOMP_HOME = 30
zelda.CHOMP_KNOCK = -36
zelda.CHOMP_KNOCK_UP = 30
zelda.CHOMP_THROWN_KNOCK = -52
zelda.CHOMP_THROWN_UP = 42
zelda.CHOMP_SCALE = 0.6
zelda.MODEL_CHOMP = "E_MODEL_CHAIN_CHOMP"
zelda.DASH_CHARGE = 15
zelda.DASH_SPEED = 64
zelda.DASH_MOST = 150
zelda.DASH_BONK = -16

zelda.DASH_TREE = 300
zelda.DASH_TREE_REST = 1800
zelda.DASH_CHARGING = 0
zelda.DASH_RUNNING = 1

OF.SLOT_NEEDS = OF.SLOT_NEEDS or {}
table.insert(OF.SLOT_NEEDS, function()
    return { _G[zelda.MODEL_CHOMP] }
end)

if zelda.ACT_JAR == nil and type(ACT_GROUP_MOVING) == "number"
    and type(ACT_FLAG_MOVING) == "number" then
    zelda.ACT_JAR = at_load("allocate_mario_action", ACT_GROUP_MOVING | ACT_FLAG_MOVING)
end
if zelda.ACT_JAR_AIR == nil and type(ACT_GROUP_AIRBORNE) == "number"
    and type(ACT_FLAG_AIR) == "number" then
    zelda.ACT_JAR_AIR = at_load("allocate_mario_action", ACT_GROUP_AIRBORNE | ACT_FLAG_AIR)
end
if zelda.ACT_JARRED == nil and type(ACT_GROUP_AIRBORNE) == "number"
    and type(ACT_FLAG_AIR) == "number" then
    zelda.ACT_JARRED = at_load("allocate_mario_action", ACT_GROUP_AIRBORNE | ACT_FLAG_AIR)
end

if zelda.ACT_DASH == nil and type(ACT_GROUP_MOVING) == "number"
    and type(ACT_FLAG_MOVING) == "number" and type(ACT_FLAG_ATTACKING) == "number" then
    zelda.ACT_DASH = at_load("allocate_mario_action",
        ACT_GROUP_MOVING | ACT_FLAG_MOVING | ACT_FLAG_ATTACKING)
end

function zelda.still_mine(tool)
    return zelda.may_use(mine(), tool)
end

function zelda.may_move_me(m, fromLi, tool)
    if m == nil or fromLi == nil or fromLi == 0 then return false end
    if not same_room(fromLi) then return false end
    local np = gNetworkPlayers[fromLi]
    if np == nil or not zelda.may_use(np.globalIndex, tool) then return false end
    if zelda.stands_down(fromLi, tool) then return false end
    if not zelda.pvp_allowed() then return false end
    if OF.util.asks(OF.powerups, "ball_may_touch") and not OF.powerups.ball_may_touch(m) then
        return false
    end
    return true
end

function zelda.mouth_of(them)
    local yaw = them.faceAngle.y
    return them.pos.x + sins(yaw) * zelda.JAR_AHEAD, them.pos.y + zelda.HOOK_CHEST,
        them.pos.z + coss(yaw) * zelda.JAR_AHEAD
end

function zelda.in_cone(them, px, py, pz, reach, cone)
    local jx, jy, jz = zelda.mouth_of(them)
    local d = dist3(jx, jy, jz, px, py, pz)
    if d > (reach or zelda.JAR_REACH) then return nil end
    if d < zelda.JAR_MOUTH then return d end
    local at = OF.util.optional("atan2s", 0, pz - them.pos.z, px - them.pos.x) or 0
    local off = math.abs(((at - them.faceAngle.y + 0x8000) % 0x10000) - 0x8000)
    if off > (cone or zelda.JAR_CONE) then return nil end
    return d
end

local function charge_of(timer)
    if timer >= zelda.JAR_CHARGE[2] then return 2 end
    if timer >= zelda.JAR_CHARGE[1] then return 1 end
    return 0
end
zelda.charge_of = charge_of

function zelda.is_jar(action)
    return action ~= nil and (action == zelda.ACT_JAR or action == zelda.ACT_JAR_AIR)
end

function zelda.start_jar(m)
    if m == nil or zelda.ACT_JAR == nil then return false end
    local air = type(ACT_FLAG_AIR) == "number" and OF.util.has_flag(m.action or 0, ACT_FLAG_AIR)
    if air and zelda.ACT_JAR_AIR == nil then return false, "The jar needs the ground." end
    set_mario_action(m, air and zelda.ACT_JAR_AIR or zelda.ACT_JAR, 0)
    m.actionState = zelda.JAR_SUCK
    m.actionTimer = 0
    m.actionArg = 0
    OF.sounds.play(SOUND_AIR_BLOW_WIND)
    return true
end

function zelda.jar_coins(m)
    if obj_get_first_with_behavior_id == nil then return 0 end
    local jx, jy, jz = zelda.mouth_of(m)
    local moved = 0
    for _, name in ipairs(OF.powerups ~= nil and OF.powerups.COIN_KINDS or {}) do
        local kind = _G[name]
        local coin = type(kind) == "number" and obj_get_first_with_behavior_id(kind) or nil
        while coin ~= nil do
            local d = zelda.in_cone(m, coin.oPosX or 0, coin.oPosY or 0, coin.oPosZ or 0)
            if d ~= nil and d > 1 then
                local k = math.min(zelda.JAR_PULL, d) / d
                coin.oPosX = coin.oPosX + (jx - coin.oPosX) * k
                coin.oPosY = coin.oPosY + (jy - coin.oPosY) * k
                coin.oPosZ = coin.oPosZ + (jz - coin.oPosZ) * k
                coin.oVelY = 0
                moved = moved + 1
            end
            coin = obj_get_next_with_same_behavior_id(coin)
        end
    end
    return moved
end

local function jar_step(m, air)
    if air then
        local step = perform_air_step(m, 0)
        if step == AIR_STEP_LANDED then
            m.vel.y = 0
            set_mario_action(m, zelda.ACT_JAR, 0)
        end
        return true
    end
    if perform_ground_step(m) == GROUND_STEP_LEFT_GROUND then
        if zelda.ACT_JAR_AIR == nil then
            set_mario_action(m, ACT_FREEFALL, 0)
            return false
        end
        set_mario_action(m, zelda.ACT_JAR_AIR, 0)
    end
    return true
end

function zelda.act_jar(m)
    local air = m.action == zelda.ACT_JAR_AIR

    zelda.jar_puffs(m)
    if m.playerIndex ~= nil and m.playerIndex ~= 0 then
        OF.util.optional("set_mario_animation", nil, m, MARIO_ANIM_FIRST_PERSON or 0)
        if air then perform_air_step(m, 0) else perform_ground_step(m) end
        return false
    end

    local state, timer, arg, actWas = m.actionState, m.actionTimer, m.actionArg, m.action
    m.actionTimer = (m.actionTimer or 0) + 1
    if not zelda.still_mine(zelda.JAR) then
        set_mario_action(m, air and ACT_FREEFALL or ACT_IDLE, 0)
        return false
    end
    if air then

        m.vel.y = math.max(zelda.JAR_SINK, (m.vel.y or 0) - zelda.JAR_FLOAT)
    end
    if m.actionState == zelda.JAR_BLOWING then
        mario_set_forward_vel(m, zelda.JAR_RECOIL)
        if air and m.actionTimer == 1 then m.vel.y = zelda.JAR_BLOW_UP end
        local still = jar_step(m, air)
        if still and m.action ~= actWas and zelda.is_jar(m.action) then
            m.actionState, m.actionArg, m.actionTimer = state, arg, (timer or 0) + 1
        end
        if still and m.actionTimer >= zelda.JAR_BLOW then
            mario_set_forward_vel(m, 0)
            set_mario_action(m, m.action == zelda.ACT_JAR_AIR and ACT_FREEFALL or ACT_IDLE, 0)
        end
        return false
    end

    if zelda.b_refused() then
        set_mario_action(m, air and ACT_FREEFALL or ACT_IDLE, 0)
        return false
    end
    local held = m.controller ~= nil and OF.util.has_flag(m.controller.buttonDown or 0, B_BUTTON)
    if not held then
        m.actionArg = charge_of(m.actionTimer)
        m.actionState = zelda.JAR_BLOWING
        m.actionTimer = 0
        OF.sounds.play(SOUND_AIR_BLOW_WIND)
        return false
    end
    if OF.util.has_flag(m.input or 0, INPUT_A_PRESSED) then
        set_mario_action(m, ACT_JUMP, 0)
        return false
    end
    local mag = math.min(32, m.intendedMag or 0)
    if mag > 1 then
        m.faceAngle.y = OF.util.optional("approach_s16_symmetric", nil, m.faceAngle.y,
            m.intendedYaw or m.faceAngle.y, zelda.JAR_TURN) or m.faceAngle.y
    end
    mario_set_forward_vel(m, zelda.JAR_WALK * mag / 32)
    OF.util.optional("set_mario_animation", nil, m,
        (mag > 1 and not air and MARIO_ANIM_TIPTOE or MARIO_ANIM_FIRST_PERSON) or 0)
    if not jar_step(m, air) then return false end
    if m.action ~= actWas and zelda.is_jar(m.action) then
        m.actionState, m.actionArg, m.actionTimer = state, arg, (timer or 0) + 1
    end
    zelda.jar_coins(m)
    return false
end

function zelda.puffs_out(owner)
    local n = 0
    for o, st in pairs(zelda.live) do
        if st.kind == zelda.KIND_PUFF and (o.oBehParams or 0) - 1 == owner
            and o.activeFlags ~= 0 then
            n = n + 1
        end
    end
    return n
end

function zelda.jar_puffs(them)
    if them == nil or them.pos == nil or not zelda.is_jar(them.action) then return 0 end
    local bhv, model = zelda.BEHAVIOUR, _G[zelda.MODEL_PUFF]
    if type(bhv) ~= "number" or type(model) ~= "number" then return 0 end
    local li = them.playerIndex or 0
    local np = gNetworkPlayers[li]
    local owner = np ~= nil and np.globalIndex or 0
    local out = zelda.puffs_out(owner)
    local yaw = them.faceAngle.y
    local jx, jy, jz = zelda.mouth_of(them)
    local made = 0
    local function puff(x, y, z, blow, turn)
        if out + made >= zelda.JAR_PUFFS + zelda.JAR_BURST then return end
        local o = OF.slots.spawn_non_sync(bhv, model, x, y, z, function(p)
            p.oBehParams = owner + 1
            p.oBehParams2ndByte = zelda.KIND_PUFF
            p.oAnimState = blow and 1 or 0
            p.oMoveAngleYaw = (yaw + (turn or 0)) % 0x10000
            p.oIntangibleTimer = -1
        end)
        if o ~= nil then
            OF.util.optional("obj_scale", nil, o, zelda.PUFF_SCALE)
            tool_init(o)
            made = made + 1
        end
    end
    if them.actionState == zelda.JAR_BLOWING then
        if (them.actionTimer or 0) <= 1 then
            for i = 1, zelda.JAR_BURST do
                local turn = math.floor((i - (zelda.JAR_BURST + 1) / 2) * zelda.JAR_CONE
                    * 2 / zelda.JAR_BURST)
                puff(jx, jy, jz, true, turn)
            end
        end
    elseif (them.actionTimer or 0) % zelda.JAR_PUFF_EVERY == 0 and out < zelda.JAR_PUFFS then

        local turn = math.floor(((them.actionTimer or 0) * 0x0F3D) % (zelda.JAR_CONE * 2))
            - zelda.JAR_CONE
        local a = (yaw + turn) % 0x10000
        local far = zelda.JAR_REACH * 0.8
        puff(jx + sins(a) * far, jy + ((them.actionTimer or 0) % 5 - 2) * 30,
            jz + coss(a) * far, false, 0)
    end
    return made
end

function zelda.puff_frame(o, st)
    local _, ownerLi = owner_of(o)
    local them = ownerLi ~= nil and gMarioStates[ownerLi] or nil
    local function done() return false end
    if them == nil or them.pos == nil or st.age > zelda.JAR_PUFF_LIFE then return done() end
    if (o.oAnimState or 0) == 1 then
        st.x = st.x + sins(o.oMoveAngleYaw or 0) * zelda.JAR_PUFF_SPEED
        st.z = st.z + coss(o.oMoveAngleYaw or 0) * zelda.JAR_PUFF_SPEED
    else
        if not zelda.is_jar(them.action) then return done() end
        local jx, jy, jz = zelda.mouth_of(them)
        local d = dist3(st.x, st.y, st.z, jx, jy, jz)
        if d <= zelda.JAR_PUFF_SPEED then return done() end
        local k = zelda.JAR_PUFF_SPEED / d
        st.x, st.y, st.z = st.x + (jx - st.x) * k, st.y + (jy - st.y) * k, st.z + (jz - st.z) * k
    end
    o.oPosX, o.oPosY, o.oPosZ = st.x, st.y, st.z
    return true
end

zelda.jarredBy = nil
zelda.jarredAt = -9999
function zelda.act_jarred(m)
    OF.util.optional("set_mario_animation", nil, m, MARIO_ANIM_AIRBORNE_ON_STOMACH
        or MARIO_ANIM_FORWARD_SPINNING or 0)
    if m.playerIndex ~= nil and m.playerIndex ~= 0 then return false end
    m.actionTimer = (m.actionTimer or 0) + 1
    local li = zelda.jarredBy ~= nil and OF.util.local_from_global(zelda.jarredBy) or nil
    local them = li ~= nil and gMarioStates[li] or nil
    if them == nil or them.pos == nil or not same_room(li) or not zelda.is_jar(them.action)
        or m.actionTimer > zelda.JAR_HOLD then
        return zelda.let_go_of_me(m, nil)
    end
    if them.actionState == zelda.JAR_BLOWING then
        return zelda.let_go_of_me(m, them)
    end
    local jx, jy, jz = zelda.mouth_of(them)
    m.pos.x, m.pos.y, m.pos.z = jx, jy - zelda.HOOK_CHEST, jz
    m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
    m.forwardVel = 0
    return false
end

function zelda.let_go_of_me(m, spitter)
    zelda.jarredBy = nil
    zelda.jarredAt = zelda.clock
    if spitter ~= nil then
        local charge = math.max(0, math.min(2, spitter.actionArg or 0))
        m.faceAngle.y = spitter.faceAngle.y
        m.forwardVel = zelda.JAR_SPIT + zelda.JAR_GUST_MORE * charge
        m.vel.y = zelda.JAR_SPIT_UP + zelda.JAR_GUST_MORE * charge / 2
        set_mario_action(m, ACT_THROWN_FORWARD, 0)
        return true
    end
    m.forwardVel = 0
    set_mario_action(m, ACT_FREEFALL, 0)
    return false
end

zelda.jarBlown = zelda.jarBlown or {}
function zelda.jar_frame(m)
    if m == nil or m.pos == nil or zelda.ACT_JAR == nil then return false end
    if m.action == zelda.ACT_JARRED then return false end
    local acted = false
    for li = 1, (MAX_PLAYERS or 16) - 1 do
        local them = gMarioStates[li]
        if them ~= nil and them.pos ~= nil and zelda.is_jar(them.action) then
            if them.actionState == zelda.JAR_BLOWING then
                if not zelda.jarBlown[li] then
                    zelda.jarBlown[li] = true
                    if zelda.gusted(m, li, them) then acted = true end
                end
            else
                zelda.jarBlown[li] = nil
                if zelda.pulled_by_jar(m, li, them) then acted = true end
            end
        else
            zelda.jarBlown[li] = nil
        end
    end
    return acted
end

local function nearest_in_cone(them, li)
    local mine0 = gMarioStates[0]
    local myD = zelda.in_cone(them, mine0.pos.x, mine0.pos.y + zelda.HOOK_CHEST, mine0.pos.z)
    if myD == nil then return nil end
    for oli = 1, (MAX_PLAYERS or 16) - 1 do
        local other = gMarioStates[oli]
        if oli ~= li and other ~= nil and other.pos ~= nil and same_room(oli) then
            local d = zelda.in_cone(them, other.pos.x, other.pos.y + zelda.HOOK_CHEST, other.pos.z)
            if d ~= nil and d < myD then return nil end
        end
    end
    return myD
end

function zelda.pulled_by_jar(m, li, them)
    if zelda.clock - zelda.jarredAt < zelda.JAR_IMMUNE then return false end
    if not zelda.may_move_me(m, li, zelda.JAR) then return false end
    local d = nearest_in_cone(them, li)
    if d == nil then return false end
    local jx, jy, jz = zelda.mouth_of(them)
    local cx, cy, cz = m.pos.x, m.pos.y + zelda.HOOK_CHEST, m.pos.z
    if zelda.cast(jx, jy, jz, cx - jx, cy - jy, cz - jz) ~= nil then return false end
    if d < zelda.JAR_MOUTH and zelda.ACT_JARRED ~= nil then
        zelda.jarredBy = gNetworkPlayers[li].globalIndex
        set_mario_action(m, zelda.ACT_JARRED, 0)
        m.actionTimer = 0
        OF.sounds.play(SOUND_ACTION_SPIN)
        return true
    end
    local k = math.min(zelda.JAR_PULL, d) / d
    m.pos.x = m.pos.x + (jx - cx) * k
    m.pos.z = m.pos.z + (jz - cz) * k
    if OF.util.has_flag(m.action or 0, ACT_FLAG_AIR or 0) then
        m.pos.y = m.pos.y + (jy - cy) * k
    end
    return true
end

function zelda.gusted(m, li, them)
    if zelda.clock - zelda.jarredAt < zelda.JAR_IMMUNE then return false end
    if not zelda.may_move_me(m, li, zelda.JAR) then return false end
    local reach = zelda.JAR_REACH + 300 * (them.actionArg or 0)
    if zelda.in_cone(them, m.pos.x, m.pos.y + zelda.HOOK_CHEST, m.pos.z, reach) == nil then
        return false
    end
    local charge = math.max(0, math.min(2, them.actionArg or 0))
    zelda.jarredAt = zelda.clock
    local away = OF.util.optional("atan2s", 0, m.pos.z - them.pos.z, m.pos.x - them.pos.x) or 0
    m.faceAngle.y = (away + 0x8000) % 0x10000
    m.forwardVel = -(zelda.JAR_GUST + zelda.JAR_GUST_MORE * charge)
    m.vel.y = zelda.JAR_GUST_UP + zelda.JAR_GUST_MORE * charge / 2
    set_mario_action(m, ACT_BACKWARD_AIR_KB, 0)
    return true
end

function zelda.own_of(kind)
    local me = mine()
    for o, st in pairs(zelda.live) do
        if st.kind == kind and (o.oBehParams or 0) - 1 == me and o.activeFlags ~= 0 then
            return o, st
        end
    end
    return nil
end

function zelda.swing_chomp(m)
    if m == nil or m.pos == nil then return false end
    if zelda.one_alive(zelda.KIND_FLAIL) then return false, "It is still out." end
    local orbit = zelda.own_of(zelda.KIND_CHOMP)
    if orbit == nil then
        local o = spawn_tool(zelda.KIND_CHOMP, zelda.MODEL_CHOMP, m.pos.x,
            m.pos.y + zelda.HOOK_CHEST, m.pos.z, m.faceAngle.y, 0)
        if o ~= nil then OF.sounds.play(SOUND_GENERAL_CHAIN_CHOMP2) end
        return o ~= nil
    end

    local yaw = m.faceAngle.y
    local climb = zelda.CHOMP_LIFT
    zelda.remove(orbit)
    local o = spawn_tool(zelda.KIND_FLAIL, zelda.MODEL_CHOMP,
        m.pos.x + sins(yaw) * 60, m.pos.y + zelda.HOOK_CHEST, m.pos.z + coss(yaw) * 60,
        yaw, 0, nil, climb)
    if o ~= nil then OF.sounds.play(SOUND_ACTION_THROW) end
    return o ~= nil
end

local function dress_chomp(o)
    OF.util.optional("obj_scale", nil, o, zelda.CHOMP_SCALE)
    if gObjectAnimations ~= nil and gObjectAnimations.chain_chomp_seg6_anims_06025178 ~= nil then
        o.oAnimations = gObjectAnimations.chain_chomp_seg6_anims_06025178
        OF.util.optional("obj_init_animation_with_accel_and_sound", nil, o, 0, 1.0)
    end
end
zelda.dress_chomp = dress_chomp

local function chomp_frame(o, st)
    local ownerGi, ownerLi = owner_of(o)
    if ownerLi == nil or not zelda.may_use(ownerGi, zelda.CHOMP) then return false end
    local owner = gMarioStates[ownerLi]
    if owner == nil or owner.pos == nil then return false end
    local a = (st.yaw + st.age * zelda.CHOMP_SPIN) % 0x10000
    st.x = owner.pos.x + sins(a) * zelda.CHOMP_ORBIT
    st.y = owner.pos.y + zelda.HOOK_CHEST
    st.z = owner.pos.z + coss(a) * zelda.CHOMP_ORBIT
    o.oPosX, o.oPosY, o.oPosZ = st.x, st.y, st.z
    o.oFaceAngleYaw = (a + 0x4000) % 0x10000
    o.oMoveAngleYaw = o.oFaceAngleYaw
    zelda.draw_chain(o, owner.pos.x, owner.pos.y + zelda.HOOK_CHEST, owner.pos.z,
        st.x, st.y, st.z)
    zelda.chomp_bites(o, st, ownerLi, false)
    return true
end
zelda.chomp_frame = chomp_frame

local function flail_frame(o, st)
    local ownerGi, ownerLi = owner_of(o)
    if ownerLi == nil or not zelda.may_use(ownerGi, zelda.CHOMP) then return false end
    local owner = gMarioStates[ownerLi]
    if owner == nil or owner.pos == nil then return false end
    local hx, hy, hz = owner.pos.x, owner.pos.y + zelda.HOOK_CHEST, owner.pos.z
    if st.homeFrom == nil then
        if st.age > zelda.CHOMP_OUT then
            st.vy = math.max(-zelda.CHOMP_FALL_MOST, st.vy - zelda.CHOMP_FALL)
        else
            st.vy = st.vy - zelda.CHOMP_FLOAT
        end
        local dx, dz = sins(st.yaw) * zelda.CHOMP_SPEED, coss(st.yaw) * zelda.CHOMP_SPEED
        local wall = zelda.cast(st.x, st.y, st.z, dx, st.vy, dz)
        if wall ~= nil or st.age > zelda.CHOMP_OUT * 2 then
            st.homeFrom = { st.x, st.y, st.z, st.age }
            if OF.util.asks(OF.sounds, "play_from") then OF.sounds.play_from(o, SOUND_GENERAL_CHAIN_CHOMP2) end
        else
            st.x, st.y, st.z = st.x + dx, st.y + st.vy, st.z + dz
        end
    else
        local t = (st.age - st.homeFrom[4]) / zelda.CHOMP_HOME
        if t >= 1 then return false end
        st.x = st.homeFrom[1] + (hx - st.homeFrom[1]) * t
        st.y = st.homeFrom[2] + (hy - st.homeFrom[2]) * t
        st.z = st.homeFrom[3] + (hz - st.homeFrom[3]) * t
    end
    o.oPosX, o.oPosY, o.oPosZ = st.x, st.y, st.z
    o.oFaceAngleYaw = st.yaw
    zelda.draw_chain(o, hx, hy, hz, st.x, st.y, st.z)
    zelda.chomp_bites(o, st, ownerLi, true)
    return true
end
zelda.flail_frame = flail_frame

zelda.bitAt = zelda.bitAt or {}
function zelda.chomp_bites(o, st, ownerLi, thrown)
    if ownerLi == 0 then return false end
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return false end
    if dist3(st.x, st.y, st.z, m.pos.x, m.pos.y + zelda.HOOK_CHEST, m.pos.z) > zelda.CHOMP_HIT then
        return false
    end
    if zelda.clock - (zelda.bitAt[ownerLi] or -9999) < zelda.CHOMP_IMMUNE then return false end
    if not zelda.may_move_me(m, ownerLi, zelda.CHOMP) then return false end
    zelda.bitAt[ownerLi] = zelda.clock
    local away = OF.util.optional("atan2s", 0, m.pos.z - st.z, m.pos.x - st.x) or 0
    m.faceAngle.y = (away + 0x8000) % 0x10000
    m.forwardVel = thrown and zelda.CHOMP_THROWN_KNOCK or zelda.CHOMP_KNOCK
    m.vel.y = thrown and zelda.CHOMP_THROWN_UP or zelda.CHOMP_KNOCK_UP
    set_mario_action(m, ACT_BACKWARD_AIR_KB, 0)
    OF.sounds.play(SOUND_GENERAL_CHAIN_CHOMP2)
    return true
end

function zelda.chomp_weighs(m)
    if m == nil or zelda.own_of(zelda.KIND_CHOMP) == nil then return false end
    if type(ACT_FLAG_AIR) == "number" and OF.util.has_flag(m.action or 0, ACT_FLAG_AIR) then
        return false
    end
    if (m.forwardVel or 0) > zelda.CHOMP_SLOW then
        m.forwardVel = zelda.CHOMP_SLOW
        return true
    end
    return false
end

function zelda.start_dash(m)
    if m == nil or zelda.ACT_DASH == nil then return false end
    if type(ACT_FLAG_AIR) == "number" and OF.util.has_flag(m.action or 0, ACT_FLAG_AIR) then
        return false, "The boots need the ground."
    end
    set_mario_action(m, zelda.ACT_DASH, 0)
    m.actionState = zelda.DASH_CHARGING
    m.actionTimer = 0
    mario_set_forward_vel(m, 0)
    return true
end

function zelda.dash_anim(m)
    local speed = math.abs(tonumber(m.forwardVel) or 0)
    if m.actionState == zelda.DASH_CHARGING then
        speed = zelda.DASH_SPEED * math.min(1, (m.actionTimer or 0) / zelda.DASH_CHARGE)
    end
    local accel = math.floor(math.max(speed, 4) / 4 * 0x10000)
    if set_character_anim_with_accel ~= nil and CHAR_ANIM_RUNNING ~= nil then
        set_character_anim_with_accel(m, CHAR_ANIM_RUNNING, accel)
    else
        OF.util.optional("set_mario_animation", nil, m, MARIO_ANIM_RUNNING or 0)
    end
    return accel
end

function zelda.act_dash(m)
    zelda.dash_anim(m)
    if m.playerIndex ~= nil and m.playerIndex ~= 0 then
        perform_ground_step(m)
        return false
    end
    m.actionTimer = (m.actionTimer or 0) + 1
    if not zelda.still_mine(zelda.BOOTS) then
        set_mario_action(m, ACT_IDLE, 0)
        return false
    end
    m.particleFlags = OF.util.add_flag(m.particleFlags or 0, PARTICLE_DUST)
    if m.actionState == zelda.DASH_CHARGING then

        local held = m.controller ~= nil and not zelda.b_refused()
            and OF.util.has_flag(m.controller.buttonDown or 0, B_BUTTON)
        if not held then
            set_mario_action(m, ACT_IDLE, 0)
            return false
        end
        mario_set_forward_vel(m, 0)
        perform_ground_step(m)
        if m.actionTimer >= zelda.DASH_CHARGE then
            m.actionState = zelda.DASH_RUNNING
            m.actionTimer = 0
            OF.sounds.play(SOUND_ACTION_SPIN)
        end
        return false
    end
    if OF.util.has_flag(m.input or 0, INPUT_A_PRESSED) then
        set_mario_action(m, ACT_LONG_JUMP, 0)
        return false
    end
    local against = (m.intendedMag or 0) > 24 and math.abs(((m.intendedYaw or 0)
        - m.faceAngle.y + 0x8000) % 0x10000 - 0x8000) > 0x6000
    if OF.util.has_flag(m.input or 0, INPUT_Z_PRESSED) or against
        or m.actionTimer > zelda.DASH_MOST then
        set_mario_action(m, ACT_BRAKING, 0)
        return false
    end
    mario_set_forward_vel(m, zelda.DASH_SPEED)
    local step = perform_ground_step(m)
    if step == GROUND_STEP_LEFT_GROUND then
        set_mario_action(m, ACT_FREEFALL, 0)
    elseif step == GROUND_STEP_HIT_WALL then
        zelda.bonk(m)
    end
    return false
end

zelda.treeCoins = zelda.treeCoins or {}
function zelda.bonk(m)
    mario_set_forward_vel(m, zelda.DASH_BONK)
    set_mario_action(m, ACT_BACKWARD_GROUND_KB, 0)
    OF.util.optional("set_camera_shake_from_hit", nil, SHAKE_SMALL_DAMAGE or 3)
    OF.sounds.play(SOUND_ACTION_BONK)
    local tree = type(id_bhvTree) == "number" and m.marioObj ~= nil
        and obj_get_nearest_object_with_behavior_id(m.marioObj, id_bhvTree) or nil
    if tree == nil or dist3(tree.oPosX, 0, tree.oPosZ, m.pos.x, 0, m.pos.z) > zelda.DASH_TREE then
        return false
    end
    local key = math.floor(tree.oPosX) .. "," .. math.floor(tree.oPosZ)
    if zelda.clock - (zelda.treeCoins[key] or -99999) < zelda.DASH_TREE_REST then return false end
    local bhv, model = id_bhvSingleCoinGetsSpawned, E_MODEL_YELLOW_COIN
    if type(bhv) ~= "number" or type(model) ~= "number" then return false end
    local coin = OF.slots.spawn_non_sync(bhv, model, tree.oPosX, tree.oPosY + 400, tree.oPosZ, nil)
    if coin == nil then return false end
    zelda.treeCoins[key] = zelda.clock
    return true
end

if zelda.ACT_JAR ~= nil then
    at_load("hook_mario_action", zelda.ACT_JAR, { every_frame = zelda.act_jar })
end
if zelda.ACT_JAR_AIR ~= nil then
    at_load("hook_mario_action", zelda.ACT_JAR_AIR, { every_frame = zelda.act_jar })
end
if zelda.ACT_JARRED ~= nil then
    at_load("hook_mario_action", zelda.ACT_JARRED, { every_frame = zelda.act_jarred })
end
if zelda.ACT_DASH ~= nil then
    at_load("hook_mario_action", zelda.ACT_DASH, { every_frame = zelda.act_dash })
end

function zelda.b_refused()
    return OF.util.asks(OF.powerups, "b_refused") and OF.powerups.b_refused() == true
end

function zelda.use(m, tool, rung)

    if zelda.b_refused() then return false, "The forge has B." end
    if tool == zelda.HOOK then return zelda.fire_hook(m, rung) end
    if tool == zelda.CHU then return zelda.set_chu(m) end
    if tool == zelda.NUT then return zelda.throw_nut(m) end
    if tool == zelda.BOOM then return zelda.throw_boomerang(m) end
    if tool == zelda.JAR then return zelda.start_jar(m) end
    if tool == zelda.CHOMP then return zelda.swing_chomp(m) end
    if tool == zelda.BOOTS then return zelda.start_dash(m) end
    return false
end
zelda.throw = zelda.use

function zelda.send(msg)
    msg.ofp = zelda.PACKET
    if OF.util.is_host() then
        return zelda.relay(mine(), msg)
    end
    return OF.util.send_to_host(msg)
end

local TOOL_OF = { nut = "nut", pull = "hook", chu = "chu" }

function zelda.chu_went_off(ownerGi, x, y, z)
    for o, st in pairs(zelda.live) do
        if st.kind == zelda.KIND_CHU and (o.oBehParams or 0) - 1 == ownerGi
            and o.activeFlags ~= 0 then
            zelda.remove(o)
            zelda.blast(x, y, z, OF.util.local_from_global(ownerGi))
            return true
        end
    end
    return false
end

function zelda.relay(who, msg)
    if not OF.util.is_host() then return false end
    local tool = TOOL_OF[msg.k or ""]

    local user = msg.k == "chu" and msg.o or who
    if tool == nil or type(user) ~= "number" or not zelda.may_use(user, tool) then
        return false
    end
    if msg.k == "chu" then
        if who ~= mine() then zelda.chu_went_off(user, msg.x or 0, msg.y or 0, msg.z or 0) end
        OF.util.tell_all({ ofp = zelda.PACKET, k = "chu", gi = who, o = user,
            x = msg.x, y = msg.y, z = msg.z })
        return true
    end
    if msg.k == "nut" then
        if who ~= mine() then zelda.land_nut(who, msg.x or 0, msg.y or 0, msg.z or 0) end
        OF.util.tell_all({ ofp = zelda.PACKET, k = "nut", gi = who,
            x = msg.x, y = msg.y, z = msg.z })
        return true
    end
    local vli = OF.util.local_from_global(msg.v)
    if vli == nil then return false end
    if vli == 0 then return zelda.pulled(who) end
    return OF.util.send_to_player(vli, { ofp = zelda.PACKET, k = "pull", gi = who })
end

local function on_packet(data)
    if data == nil or data.ofp ~= zelda.PACKET then return end
    if OF.util.is_host() then
        if not OF.util.asks(OF.pass, "owner") then return end
        local who = OF.pass.owner(data.pk)
        if who == nil then return end
        zelda.relay(who, data)
        return
    end
    if not OF.util.from_host_effect(data) then return end
    if data.gi == mine() then return end
    if data.k == "nut" then
        zelda.land_nut(data.gi, data.x or 0, data.y or 0, data.z or 0)
    elseif data.k == "chu" and type(data.o) == "number" then
        zelda.chu_went_off(data.o, data.x or 0, data.y or 0, data.z or 0)
    elseif data.k == "pull" then
        zelda.pulled(data.gi)
    end
end
zelda.on_packet = on_packet

hook_event(HOOK_ON_PACKET_RECEIVE, on_packet)

hook_event(HOOK_MARIO_UPDATE, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    zelda.clock = zelda.clock + 1
    zelda.fuse_tick()
    if zelda.white > 0 then zelda.white = zelda.white - 1 end
    if zelda.pop > 0 then zelda.pop = zelda.pop - 1 end

    if zelda.flight ~= nil and m.action ~= zelda.ACT_HOOK then zelda.flight = nil end
    if zelda.jarredBy ~= nil and m.action ~= zelda.ACT_JARRED then zelda.jarredBy = nil end
    zelda.wall_kick_step(m)

    zelda.jar_frame(m)
    zelda.chomp_weighs(m)

    local out, gone = 0, nil
    for o, st in pairs(zelda.live) do
        if o.activeFlags == 0 then
            gone = gone or {}
            table.insert(gone, o)
        elseif st.kind == zelda.KIND_TIP then
            out = out + 1
        end
    end
    if gone ~= nil then for _, o in ipairs(gone) do forget(o) end end
    zelda.tipsOut = out
end, OF.LOCAL_MARIO)

zelda.AIMED_ROWS = { "hookshot", "boomerang", "flashnut" }
zelda.DOT = 4

zelda.DOT_READY = { 255, 60, 60 }
zelda.CATCH_EVERY = 3
zelda.catchAt, zelda.catchSaid = -1, false

function zelda.would_catch(m, tool, rung)
    if m == nil or m.pos == nil then return false end
    if tool == zelda.HOOK then
        local reach = zelda.HOOK_REACH[rung or 1] or zelda.HOOK_REACH[1]
        local sx, sy, sz, ax, ay, az = zelda.aim(m, reach)
        if sx == nil then return false end
        reach = reach + zelda.HOOK_SLACK
        local hit = zelda.cast(sx, sy, sz, ax * reach, ay * reach, az * reach)
        local upTo = reach
        if hit ~= nil then upTo = dist3(sx, sy, sz, hit.x, hit.y, hit.z) end
        local yaw = OF.util.optional("atan2s", m.faceAngle.y, az, ax) or m.faceAngle.y
        if zelda.player_on_line(sx, sy, sz, yaw, upTo, ax, ay, az) ~= nil then return true end
        if zelda.pole_on_line(sx, sy, sz, ax, ay, az, upTo) ~= nil then return true end
        if zelda.item_on_line(sx, sy, sz, ax, ay, az, upTo) ~= nil then return true end
        return zelda.hook_kind(hit) ~= nil
    elseif tool == zelda.BOOM then
        local reach = zelda.BOOM_SPEED * zelda.BOOM_OUT
        local sx, sy, sz, ax, ay, az = zelda.aim(m, reach)
        if sx == nil then return false end
        local hit = zelda.cast(sx, sy, sz, ax * reach, ay * reach, az * reach)
        local upTo = reach
        if hit ~= nil then upTo = dist3(sx, sy, sz, hit.x, hit.y, hit.z) end
        return zelda.item_on_line(sx, sy, sz, ax, ay, az, upTo) ~= nil
    end
    return false
end

function zelda.dot_ready(m)
    local P = OF.powerups
    if P == nil or type(P.carries) ~= "function" then return false end
    local tick = OF.util.optional("get_global_timer", 0) or 0
    if zelda.catchAt >= 0 and tick >= zelda.catchAt and tick - zelda.catchAt < zelda.CATCH_EVERY then
        return zelda.catchSaid
    end
    zelda.catchAt = tick
    local ready = false
    if P.carries("hookshot") then
        local slot = type(P.slot_of) == "function" and P.slot_of("hookshot") or nil
        local rung = slot ~= nil and P.carriedStep ~= nil and tonumber(P.carriedStep[slot]) or 1
        ready = zelda.would_catch(m, zelda.HOOK, rung)
    end
    if not ready and P.carries("boomerang") then
        ready = zelda.would_catch(m, zelda.BOOM)
    end
    zelda.catchSaid = ready
    return ready
end

function zelda.draw_aim()
    if not OF.util.asks(OF.powerups, "carries") then return false end
    local aimed = false
    for _, key in ipairs(zelda.AIMED_ROWS) do
        if OF.powerups.carries(key) then aimed = true end
    end
    if not aimed or djui_hud_get_screen_width == nil then return false end
    djui_hud_set_resolution(RESOLUTION_DJUI)
    local w, h = djui_hud_get_screen_width(), djui_hud_get_screen_height()
    local half = zelda.DOT / 2
    if zelda.dot_ready(gMarioStates[0]) then
        local red = zelda.DOT_READY
        djui_hud_set_color(red[1], red[2], red[3], 235)
    else
        djui_hud_set_color(255, 255, 255, 215)
    end
    djui_hud_render_rect(math.floor(w / 2 - half), math.floor(h / 2 - half),
        zelda.DOT, zelda.DOT)
    return true
end

hook_event(HOOK_ON_HUD_RENDER, function()

    if OF.util.menu_has_screen() then return end
    zelda.draw_white()
    zelda.draw_aim()
end)

hook_event(HOOK_ON_LEVEL_INIT, function()
    zelda.live = {}
    zelda.links = {}
    zelda.flight = nil
    zelda.jarredBy = nil
    zelda.jarBlown = {}
    zelda.bitAt = {}

    zelda.fuses = {}
end)

function zelda.ready() return zelda.use ~= nil end
