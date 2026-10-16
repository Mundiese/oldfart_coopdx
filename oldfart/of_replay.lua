OF = OF or {}
OF.replay = OF.replay or {}

local replay = OF.replay

replay.CAP = 300

replay.END_FRAMES = 90
replay.LONG_FRAMES = 180

replay.KILL_FRAMES = 80

replay.KILL_FRESH = 150

replay.KILL_LATE = 20

replay.LEAST = 15

replay.PACKET_WHO = "rpkill"
replay.PACKET_SKIP = "rpskip"
replay.OPT_END = "replay"
replay.OPT_KILL = "killcam"
local INVISIBLE = GRAPH_RENDER_INVISIBLE or 16
local HAS_ANIMATION = GRAPH_RENDER_HAS_ANIMATION or 32

local ENGINE_POS_H, ENGINE_POS_V = 0.3, 0.3
local ENGINE_FOC_H, ENGINE_FOC_V = 0.8, 0.3

local SEATS = MAX_PLAYERS or 16
local CAP = replay.CAP
local SLOTS = CAP * SEATS

local bx, by, bz, byaw, banim, bframe, blive = {}, {}, {}, {}, {}, {}, {}
local bpitch, broll = {}, {}

local beye = {}
for k = 1, SLOTS do
    bx[k], by[k], bz[k] = 0, 0, 0
    byaw[k], banim[k], bframe[k], blive[k] = 0, 0, 0, 0
    bpitch[k], broll[k] = 0, 0
    beye[k] = 0
end

local written = 0

local scoreWas = {}
for s = 0, SEATS - 1 do scoreWas[s] = 0 end
local lastScorer, lastScoredAt = nil, -1

local function slot(seat, index)
    return seat * CAP + (index % CAP) + 1
end

function replay.held()
    if written < CAP then return written end
    return CAP
end

function replay.written()
    return written
end

function replay.size()
    return #blive
end

function replay.empty()
    written = 0
    for s = 0, SEATS - 1 do scoreWas[s] = 0 end
    lastScorer, lastScoredAt = nil, -1
end

function replay.sample(seat, index)
    if index < 0 or index >= written or index < written - CAP then return nil end
    local k = slot(seat, index)
    if blive[k] ~= 1 then return nil end
    return bx[k], by[k], bz[k], byaw[k], banim[k], bframe[k], bpitch[k],
        broll[k]
end

local function inside(i)
    if not OF.util.asks(OF.roundscope, "inside") then return i == 0 end
    return OF.roundscope.inside(i)
end

local function same_room(np, me)
    return np.currLevelNum == me.currLevelNum
        and np.currAreaIndex == me.currAreaIndex
        and np.currActNum == me.currActNum
end

local DRAWN_STRAY = 300
local function drawn_pose(m, gfx)
    local pos = gfx ~= nil and gfx.pos or nil
    local ang = gfx ~= nil and gfx.angle or nil
    local x, y, z = m.pos.x, m.pos.y, m.pos.z
    if pos ~= nil and type(pos.x) == "number" then
        local dx, dy, dz = pos.x - x, pos.y - y, pos.z - z
        if dx * dx + dy * dy + dz * dz <= DRAWN_STRAY * DRAWN_STRAY then
            x, y, z = pos.x, pos.y, pos.z
        end
    end
    if ang ~= nil and type(ang.y) == "number" then
        return x, y, z, ang.x or 0, ang.y, ang.z or 0
    end
    return x, y, z, 0, m.faceAngle.y, 0
end

replay.drawn_pose = drawn_pose

local function record_frame()
    local me = gNetworkPlayers[0]
    if me == nil then return end
    local index = written
    for s = 0, SEATS - 1 do
        local k = slot(s, index)
        local np = gNetworkPlayers[s]
        local m = gMarioStates[s]
        local o = m ~= nil and m.marioObj or nil
        if np ~= nil and np.connected and o ~= nil and same_room(np, me)
            and inside(s) then
            local gfx = o.header ~= nil and o.header.gfx or nil
            local info = gfx ~= nil and gfx.animInfo or nil
            bx[k], by[k], bz[k], bpitch[k], byaw[k], broll[k] = drawn_pose(m, gfx)
            banim[k] = info ~= nil and info.animID or 0
            bframe[k] = info ~= nil and info.animFrame or 0
            local body = m.marioBodyState
            beye[k] = body ~= nil and tonumber(body.eyeState) or 0
            blive[k] = 1

            local row = gPlayerSyncTable[s]
            local score = row ~= nil and row.ofScore or nil
            if type(score) == "number" then
                if score > scoreWas[s] and index > 0 then
                    lastScorer, lastScoredAt = s, index
                end
                scoreWas[s] = score
            end
        else
            blive[k] = 0
        end
    end
    written = written + 1
end

function replay.recording()
    local modes = OF.gamemodes
    if modes == nil or modes.state() ~= modes.ACTIVE then return false end
    return inside(0)
end

function replay.last_scorer()
    if lastScorer == nil or lastScoredAt < written - CAP then return nil end
    return lastScorer
end

function replay.end_frames()
    local modes = OF.gamemodes
    if modes == nil then return 0 end
    local pick = modes.option_now(replay.OPT_END)
    if pick == "short" then return replay.END_FRAMES end
    if pick == "long" then return replay.LONG_FRAMES end
    return 0
end

function replay.kill_cam_on()
    local modes = OF.gamemodes
    if modes == nil then return false end
    return modes.option_now(replay.OPT_KILL) == "on"
end

local play = { kind = nil, from = 0, len = 0, span = 0, slow = 0, t = 0,
               shown = 0, follow = nil, killer = nil, victim = nil, camYaw = 0,
               started = 0 }
replay.play = play

replay.SLOW_TAIL = 20

replay.KILL_SLOW_TAIL = 0
replay.SLOW = 0.5

replay.JUMP = 600

local standins = {}
local animOf = {}

local rootOf = {}

local wasX, wasY, wasZ, wasLive = {}, {}, {}, {}
for s = 0, SEATS - 1 do
    wasX[s], wasY[s], wasZ[s], wasLive[s] = 0, 0, 0, 0
end

local ROOT_SCALE = 0xBD
replay.ROOT_SCALE = ROOT_SCALE

local function anim_pointer(id)
    local a = animOf[id]
    if a == nil then
        a = OF.util.optional("get_mario_vanilla_animation", nil, id)
        if a == nil then return nil end
        animOf[id] = a
    end
    return a
end

replay.anim_pointer = anim_pointer

function replay.playing()
    return play.kind
end

function replay.standins()
    return standins
end

function replay.shown()
    if play.kind == nil then return nil end
    return play.shown
end

function replay.cursor(t)
    local fast = play.span - play.slow
    local at
    if t <= fast then
        at = t
    else
        at = fast + (t - fast) * replay.SLOW
    end
    if at > play.span - 1 then at = play.span - 1 end
    if at < 0 then at = 0 end
    return play.from + at
end

function replay.standin_alive(o)
    return o ~= nil and o.activeFlags ~= 0 and o.oBehParams == replay.STANDIN_MARK
end

local function remove_standins()
    for s = 0, SEATS - 1 do
        local o = standins[s]
        if o ~= nil then
            if replay.standin_alive(o) then
                OF.util.optional("obj_mark_for_deletion", nil, o)
            end
            standins[s] = nil
        end
    end
end

local function spawn_standins()
    remove_standins()
    for s = 0, SEATS - 1 do
        local np = gNetworkPlayers[s]
        local m = gMarioStates[s]
        local seen = false
        for index = play.from, play.from + play.span - 1 do
            if blive[slot(s, index)] == 1 then
                seen = true
                break
            end
        end
        wasLive[s] = 0
        if seen and np ~= nil and np.connected and m ~= nil
            and m.marioObj ~= nil then
            local model = OF.util.optional("obj_get_model_id_extended", nil,
                m.marioObj)
            local k = slot(s, play.from)
            if model ~= nil then
                local global = np.globalIndex
                local gfx = m.marioObj.header.gfx
                local info = gfx.animInfo
                local root = info ~= nil and tonumber(info.animYTrans) or 0
                if root == nil or root == 0 then root = ROOT_SCALE end
                rootOf[s] = root
                local scale = gfx.scale
                standins[s] = OF.slots.spawn_non_sync(
                    id_bhvStaticObject, model, bx[k], by[k], bz[k],
                    function(o)
                        o.globalPlayerIndex = global

                        o.hookRender = 1
                        o.oBehParams = replay.STANDIN_MARK
                        o.oIntangibleTimer = -1
                        o.oInteractType = 0
                        o.oCollisionDistance = 0
                        o.oAnimState = 0

                        if scale ~= nil and o.header ~= nil then
                            local to = o.header.gfx.scale
                            to.x, to.y, to.z = scale.x, scale.y, scale.z
                        end
                    end)
            end
        end
    end
end

local TURN = 65536
local function fold(value)
    value = math.floor(value + 0.5) % TURN
    if value >= 0x8000 then value = value - TURN end
    return value
end
replay.fold = fold

function replay.lerp_angle(a, b, f)
    local d = fold(b - a)
    return fold(a + d * f)
end
local lerp_angle = replay.lerp_angle

function replay.at(seat, at)
    local i = math.floor(at)
    local f = at - i
    if i < written - CAP then i, f = written - CAP, 0 end
    local ka = slot(seat, i)
    local kb = slot(seat, i + 1)
    local liveA = i >= 0 and i < written and blive[ka] == 1
    local liveB = f > 0 and i + 1 < written and blive[kb] == 1
    if not liveA and not liveB then return nil end
    if not liveB then kb, f = ka, 0 end
    if not liveA then ka, f = kb, 0 end
    local dx, dy, dz = bx[kb] - bx[ka], by[kb] - by[ka], bz[kb] - bz[ka]
    local jump = dx * dx + dy * dy + dz * dz > replay.JUMP * replay.JUMP
    if jump then

        if f >= 0.5 then ka = kb end
        f = 0
    end
    local frame = bframe[ka]
    local anim = banim[ka]
    if f > 0 then
        if banim[kb] == anim and bframe[kb] >= frame then
            frame = frame + (bframe[kb] - frame) * f
        elseif f >= 0.5 then
            anim, frame = banim[kb], bframe[kb]
        end
    end
    return bx[ka] + dx * f, by[ka] + dy * f, bz[ka] + dz * f,
        lerp_angle(byaw[ka], byaw[kb], f), anim, math.floor(frame),
        lerp_angle(bpitch[ka], bpitch[kb], f),
        lerp_angle(broll[ka], broll[kb], f), jump
end
local sample_at = replay.at

function replay.eye_at(seat, at)
    local i = math.floor(at + 0.5)
    if i >= written then i = written - 1 end
    if i < 0 or i < written - CAP then return nil end
    local k = slot(seat, i)
    if blive[k] ~= 1 then return nil end
    return beye[k]
end

replay.STANDIN_MARK = 0x52504C59

local eyesHeld = {}
local eyesAt = -1
function replay.standin_render(o)
    if play.kind == nil or o == nil or o.oBehParams ~= replay.STANDIN_MARK then
        return false
    end
    local s = OF.util.local_from_global(o.globalPlayerIndex)
    if s == nil or standins[s] == nil then return false end
    local eye = replay.eye_at(s, play.shown or play.from)
    local m = gMarioStates[s]
    local body = m ~= nil and m.marioBodyState or nil
    if eye == nil or body == nil then return false end

    local tick = OF.util.optional("get_global_timer", 0) or 0
    if tick ~= eyesAt then replay.eyes_back() eyesAt = tick end
    if body.eyeState ~= eye then
        eyesHeld[#eyesHeld + 1] = { body = body, was = body.eyeState, put = eye }
        body.eyeState = eye
    end
    return true
end

function replay.eyes_back()
    for k = #eyesHeld, 1, -1 do
        local held = eyesHeld[k]
        if held.body.eyeState == held.put then held.body.eyeState = held.was end
        eyesHeld[k] = nil
    end
end

local function pose(o, s, at)
    local node = o.header.gfx.node
    local flags = tonumber(node.flags) or 0
    local x, y, z, yaw, anim, frame, pitch, roll, jump = sample_at(s, at)
    if x == nil then
        if not OF.util.has_flag(flags, INVISIBLE) then
            node.flags = flags + INVISIBLE
        end
        wasLive[s] = 0
        return
    end
    if OF.util.has_flag(flags, INVISIBLE) then flags = flags - INVISIBLE end

    if OF.util.has_flag(flags, HAS_ANIMATION) then flags = flags - HAS_ANIMATION end
    node.flags = flags

    local ddx, ddy, ddz = x - wasX[s], y - wasY[s], z - wasZ[s]
    if wasLive[s] ~= 1 or jump
        or ddx * ddx + ddy * ddy + ddz * ddz > replay.JUMP * replay.JUMP then
        OF.util.optional("obj_skip_interpolation", nil, o)
    end
    wasX[s], wasY[s], wasZ[s], wasLive[s] = x, y, z, 1

    o.oPosX, o.oPosY, o.oPosZ = x, y, z
    o.oFaceAnglePitch, o.oFaceAngleYaw, o.oFaceAngleRoll = pitch, yaw, roll
    o.oMoveAngleYaw = yaw
    local gfx = o.header.gfx
    gfx.pos.x, gfx.pos.y, gfx.pos.z = x, y, z
    gfx.angle.x, gfx.angle.y, gfx.angle.z = pitch, yaw, roll
    local pointer = anim_pointer(anim)
    if pointer ~= nil then
        local info = gfx.animInfo
        info.curAnim = pointer
        info.animID = anim
        info.animAccel = 0
        info.animFrame = frame

        info.animYTrans = rootOf[s] or ROOT_SCALE
    end
end

local function to_radians(a)
    return a * math.pi / 32768
end

local function yaw_toward(ax, az, bx2, bz2)
    return fold(math.atan(bx2 - ax, bz2 - az) * 32768 / math.pi)
end

local function along(x, y, z, dist, pitch, yaw)
    local p, w = to_radians(pitch), to_radians(yaw)
    return x + dist * math.cos(p) * math.sin(w),
           y + dist * math.sin(p),
           z + dist * math.cos(p) * math.cos(w)
end

replay.WALL_GAP = 60
local FLOOR_GAP = 60
local CEIL_GAP = 40

local NO_FLOOR = -10000

function replay.clear_view(fx, fy, fz, px, py, pz)
    local dx, dy, dz = px - fx, py - fy, pz - fz
    local hit = OF.util.optional("collision_find_surface_on_ray", nil,
        fx, fy, fz, dx, dy, dz)
    if hit ~= nil and hit.surface ~= nil and hit.hitPos ~= nil then
        local hx, hy, hz = hit.hitPos.x, hit.hitPos.y, hit.hitPos.z
        local reach = math.sqrt((hx - fx) ^ 2 + (hy - fy) ^ 2 + (hz - fz) ^ 2)
        local full = math.sqrt(dx * dx + dy * dy + dz * dz)
        if full > 0 then
            local keep = math.max(reach - replay.WALL_GAP, 0) / full
            px, py, pz = fx + dx * keep, fy + dy * keep, fz + dz * keep
        end
    end
    local floor = OF.util.optional("find_floor_height", nil, px, py + 50, pz)
    if type(floor) == "number" and floor > NO_FLOOR and py < floor + FLOOR_GAP then
        py = floor + FLOOR_GAP
    end
    local ceil = OF.util.optional("find_ceil_height", nil, px, py, pz)
    if type(ceil) == "number" and py > ceil - CEIL_GAP and ceil - CEIL_GAP > fy then
        py = ceil - CEIL_GAP
    end
    return px, py, pz
end
local clear_view = replay.clear_view

local holding = false

local function put(vec, x, y, z)
    if vec == nil then return end
    vec.x, vec.y, vec.z = x, y, z
end

local EASE_POS = 0.3
local EASE_FOCUS = 0.45
local cam = { px = 0, py = 0, pz = 0, fx = 0, fy = 0, fz = 0 }
replay.cam = cam

local lensWas = { pos = {}, focus = {}, curPos = {}, curFocus = {},
                  goalPos = {}, goalFocus = {} }
local lensKept, lensYaw = false, nil
local function keep_lens(s)
    for key, into in pairs(lensWas) do
        local from = s[key]
        if from ~= nil then into.x, into.y, into.z = from.x, from.y, from.z
        else into.x = nil end
    end
    lensYaw = s.yaw
    lensKept = true
end
local function give_lens_back(s)
    if not lensKept then return end
    lensKept = false
    for key, from in pairs(lensWas) do
        local into = s[key]
        if into ~= nil and from.x ~= nil then
            into.x, into.y, into.z = from.x, from.y, from.z
        end
    end
    if lensYaw ~= nil then s.yaw = lensYaw end
end

local function drive(px, py, pz, fx, fy, fz, cut)
    local s = gLakituState
    if s == nil then return false end
    if not holding then keep_lens(s) end
    if cut then
        cam.px, cam.py, cam.pz = px, py, pz
        cam.fx, cam.fy, cam.fz = fx, fy, fz
    else
        cam.px = cam.px + (px - cam.px) * EASE_POS
        cam.py = cam.py + (py - cam.py) * EASE_POS
        cam.pz = cam.pz + (pz - cam.pz) * EASE_POS
        cam.fx = cam.fx + (fx - cam.fx) * EASE_FOCUS
        cam.fy = cam.fy + (fy - cam.fy) * EASE_FOCUS
        cam.fz = cam.fz + (fz - cam.fz) * EASE_FOCUS

        cam.px, cam.py, cam.pz = clear_view(cam.fx, cam.fy, cam.fz,
            cam.px, cam.py, cam.pz)
    end
    put(s.pos, cam.px, cam.py, cam.pz)
    put(s.curPos, cam.px, cam.py, cam.pz)
    put(s.goalPos, cam.px, cam.py, cam.pz)
    put(s.focus, cam.fx, cam.fy, cam.fz)
    put(s.curFocus, cam.fx, cam.fy, cam.fz)
    put(s.goalFocus, cam.fx, cam.fy, cam.fz)
    s.posHSpeed, s.posVSpeed = 0, 0
    s.focHSpeed, s.focVSpeed = 0, 0

    s.yaw = yaw_toward(cam.fx, cam.fz, cam.px, cam.pz)
    holding = true
    if cut then OF.util.optional("skip_camera_interpolation", nil) end
    return true
end

local function release()
    if not holding then return false end
    holding = false
    local s = gLakituState
    if s == nil then return false end
    give_lens_back(s)
    s.posHSpeed, s.posVSpeed = ENGINE_POS_H, ENGINE_POS_V
    s.focHSpeed, s.focVSpeed = ENGINE_FOC_H, ENGINE_FOC_V
    OF.util.optional("skip_camera_interpolation", nil)
    return true
end

function replay.holds_camera()
    return holding
end

local function approach_yaw(from, to, step)
    local d = fold(to - from)
    if d > step then d = step elseif d < -step then d = -step end
    return fold(from + d)
end

local CHASE_DIST = 650
local CHASE_PITCH = -0x0A00

local CHASE_LIFT = 100
local ORBIT = 0x30
local SHOULDER_BACK = 260
local SHOULDER_UP = 190

local SHOULDER_SIDE = 70

local KILL_LOOK = 0.7

local KILL_NEAR = 80

local function chase_shot(at, cut)
    local seat = play.follow
    if seat == nil then return false end
    local x, y, z, yaw, _, _, _, _, jump = sample_at(seat, at)
    if x == nil then return false end
    if jump then cut = true end
    local fx, fy, fz = x, y + CHASE_LIFT, z
    local want = fold(yaw + play.t * ORBIT)
    if cut then play.camYaw = want end
    play.camYaw = approach_yaw(play.camYaw, want, 0x280)
    local px, py, pz = along(fx, fy, fz, -CHASE_DIST, CHASE_PITCH, play.camYaw)
    px, py, pz = clear_view(fx, fy, fz, px, py, pz)
    return drive(px, py, pz, fx, fy, fz, cut)
end

local function kill_shot(at, cut)
    local kx, ky, kz, _, _, _, _, _, kjump = sample_at(play.killer, at)
    local vx, vy, vz, _, _, _, _, _, vjump = sample_at(play.victim, at)
    if kx == nil or vx == nil then
        play.follow = play.victim
        return chase_shot(at, cut)
    end
    if kjump or vjump then cut = true end
    local dx, dz = vx - kx, vz - kz
    local apart = math.sqrt(dx * dx + dz * dz)
    if apart > KILL_NEAR or cut then
        local want = yaw_toward(kx, kz, vx, vz)
        if cut then play.camYaw = want end
        play.camYaw = approach_yaw(play.camYaw, want, 0x600)
    end
    local view = play.camYaw
    local fx = kx + (vx - kx) * KILL_LOOK
    local fy = ky + (vy - ky) * KILL_LOOK + 80
    local fz = kz + (vz - kz) * KILL_LOOK
    local back = SHOULDER_BACK + math.min(apart * 0.15, 240)
    local ex, ey, ez = kx, ky + SHOULDER_UP, kz
    local px, py, pz = along(ex, ey, ez, -back, 0, view)
    local side = to_radians(view + 0x4000)
    px = px - SHOULDER_SIDE * math.sin(side)
    pz = pz - SHOULDER_SIDE * math.cos(side)
    px, py, pz = clear_view(fx, fy, fz, px, py, pz)
    return drive(px, py, pz, fx, fy, fz, cut)
end

local function camera_taken()
    if OF.util.asks(OF.spectate, "driving") and OF.spectate.driving() then
        return true
    end
    if OF.util.asks(OF.camera, "driving") and OF.camera.driving() then
        return true
    end
    return false
end

local HUD_BITS = {}
for _, name in ipairs({ "HUD_DISPLAY_FLAG_LIVES", "HUD_DISPLAY_FLAG_COIN_COUNT",
    "HUD_DISPLAY_FLAG_STAR_COUNT", "HUD_DISPLAY_FLAG_CAMERA_AND_POWER",
    "HUD_DISPLAY_FLAG_CAMERA", "HUD_DISPLAY_FLAG_POWER",
    "HUD_DISPLAY_FLAG_TIMER", "HUD_DISPLAY_FLAG_KEYS" }) do
    local value = _G[name]
    if type(value) == "number" then HUD_BITS[#HUD_BITS + 1] = value end
end
replay.HUD_BITS = HUD_BITS
replay.HUD_HOLDER = "replay"
local hudHeld = false
local function hold_hud(on)
    if not on and not hudHeld then return end
    hudHeld = on
    if not OF.util.asks(OF.util, "hud_hide") then return end
    for _, bit in ipairs(HUD_BITS) do
        OF.util.hud_hide(bit, replay.HUD_HOLDER, on)
    end
end

local function start(kind, len, endAt, tail)
    if play.kind ~= nil then return false, "already playing" end
    if camera_taken() then return false, "another camera has the picture" end
    tail = tail or 0

    local slowCost = tail * (1 / replay.SLOW - 1)
    local oldest = written - replay.held()
    local from = endAt - math.floor(len - slowCost)
    if from < oldest then from = oldest end
    local span = endAt - from
    if span < replay.LEAST then return false, "nothing recorded" end

    if tail > math.floor(span / 3) then tail = math.floor(span / 3) end
    play.kind = kind
    play.from = from
    play.span = span
    play.slow = tail
    play.len = math.floor(span - tail + tail / replay.SLOW + 0.5)
    play.t = 0
    play.shown = from
    play.started = OF.util.optional("get_global_timer", 0) or 0
    spawn_standins()
    return true
end

function replay.stop()
    if play.kind == nil and not holding then return false end
    play.kind = nil
    play.follow, play.killer, play.victim = nil, nil, nil
    replay.eyes_back()
    remove_standins()
    release()
    hold_hud(false)
    return true
end

function replay.decider()
    local modes = OF.gamemodes
    local mode = modes ~= nil and OF.util.asks(modes, "current") and modes.current()
        or nil
    if mode ~= nil and type(mode.replayDecider) == "function" then
        local ok, picked = pcall(mode.replayDecider)
        if ok and type(picked) == "number" then return picked end
    end
    if modes ~= nil and OF.util.asks(modes, "winners") then
        local list = modes.winners()
        if list[1] ~= nil then return list[1] end
    end
    local scorer = replay.last_scorer()
    if scorer ~= nil then return scorer end
    return 0
end

function replay.start_ending()
    local frames = replay.end_frames()
    if frames <= 0 then return false, "off" end
    if not inside(0) then return false, "not taking part" end
    local ok, why = start("end", frames, written, replay.SLOW_TAIL)
    if not ok then return false, why end
    play.follow = replay.decider()
    if blive[slot(play.follow, play.from)] ~= 1 then

        for s = 0, SEATS - 1 do
            if blive[slot(s, play.from)] == 1 then
                play.follow = s
                break
            end
        end
    end
    return true
end

function replay.start_kill(killerLocal, deathAt, late)
    if not replay.kill_cam_on() then return false, "off" end
    if killerLocal == nil or killerLocal == 0 then return false, "nobody" end
    local frames = replay.KILL_FRAMES - math.max(late or 0, 0)
    local ok, why = start("kill", frames, deathAt, replay.KILL_SLOW_TAIL)
    if not ok then return false, why end
    play.killer, play.victim, play.follow = killerLocal, 0, 0
    return true
end

local killNote = { by = nil, at = -9999 }
replay.killNote = killNote

local function now()
    return OF.util.optional("get_global_timer", 0) or 0
end

function replay.note_killer(globalIndex)
    if type(globalIndex) ~= "number" then return false end
    killNote.by, killNote.at = globalIndex, now()
    return true
end

function replay.tell_victim(globalIndex)
    if not replay.kill_cam_on() then return false end
    local li = OF.util.local_from_global(globalIndex)
    if li == nil or li == 0 then return false end
    return OF.util.send_raw(li, { ofp = replay.PACKET_WHO })
end

local DYING = {}
for _, name in ipairs({ "ACT_STANDING_DEATH", "ACT_DEATH_ON_BACK",
    "ACT_DEATH_ON_STOMACH", "ACT_ELECTROCUTION", "ACT_SUFFOCATION",
    "ACT_QUICKSAND_DEATH", "ACT_DROWNING", "ACT_WATER_DEATH" }) do
    local value = _G[name]
    if type(value) == "number" then DYING[value] = true end
end

function replay.dying(m)
    return m ~= nil and DYING[m.action] == true
end

local deathAt = nil
local deathFrame = -9999

local skipped = {}

local function everyone_skipped()
    local any = false
    for i = 0, SEATS - 1 do
        local np = gNetworkPlayers[i]
        if np ~= nil and np.connected and inside(i) then
            any = true
            if not skipped[np.globalIndex] then return false end
        end
    end
    return any
end

function replay.extra_frames()
    local frames = replay.end_frames()
    if frames <= replay.END_FRAMES then return 0 end
    if everyone_skipped() then return 0 end
    return frames - replay.END_FRAMES
end

function replay.skip()
    if play.kind == nil then return false end
    local kind = play.kind
    replay.stop()
    if kind == "end" then
        local np = gNetworkPlayers[0]
        if OF.util.is_host() then
            if np ~= nil then skipped[np.globalIndex] = true end
        else
            OF.util.send_to_host({ ofp = replay.PACKET_SKIP })
        end
    end
    return true
end

local function on_packet(data)
    if type(data) ~= "table" then return end
    if data.ofp == replay.PACKET_WHO then
        replay.note_killer(tonumber(data.from))
    elseif data.ofp == replay.PACKET_SKIP then
        if not OF.util.is_host() then return end
        local modes = OF.gamemodes
        if modes == nil or modes.state() ~= modes.MOMENT then return end
        local _, global = OF.util.asked_by(data)
        if global ~= nil then skipped[global] = true end
    end
end

local lastState = nil

local function menu_open()
    return OF.util.menu_has_screen()
end

local function playback_frame()
    local m = gMarioStates[0]
    local modes = OF.gamemodes

    if play.kind == "kill" then
        if modes.state() ~= modes.ACTIVE or not replay.dying(m)
            or OF.util.optional("is_transition_playing", false) then
            return replay.stop()
        end
    end
    if m ~= nil and m.controller ~= nil and not menu_open()
        and OF.util.has_flag(m.controller.buttonPressed or 0, B_BUTTON) then
        return replay.skip()
    end
    if play.t >= play.len then
        return replay.stop()
    end

    local at = replay.cursor(play.t)
    play.shown = at
    for s = 0, SEATS - 1 do
        local o = standins[s]
        if o ~= nil then
            local np = gNetworkPlayers[s]
            if not replay.standin_alive(o) then
                standins[s] = nil
            elseif np == nil or not np.connected then

                OF.util.optional("obj_mark_for_deletion", nil, o)
                standins[s] = nil
            else
                pose(o, s, at)
            end
        end
    end
    local cut = play.t == 0
    if play.kind == "kill" then kill_shot(at, cut) else chase_shot(at, cut) end
    hold_hud(true)
    play.t = play.t + 1
    return true
end

local function update()
    local modes = OF.gamemodes
    if modes == nil then return end
    local state = modes.state()

    if state ~= lastState then
        if state == modes.MOMENT and lastState == modes.ACTIVE then
            skipped = {}
            replay.start_ending()
        elseif state == modes.ACTIVE and lastState ~= modes.ACTIVE then
            replay.empty()
        end
        if state ~= modes.MOMENT and state ~= modes.ACTIVE then
            replay.stop()
            replay.empty()
            killNote.by, killNote.at = nil, -9999
            deathAt = nil
        end
        lastState = state
    end

    if replay.recording() then record_frame() end

    local m = gMarioStates[0]
    if state == modes.ACTIVE and replay.dying(m) then
        if deathAt == nil then
            deathAt = written
            deathFrame = now()
        end
        if play.kind == nil and killNote.by ~= nil
            and now() - killNote.at <= replay.KILL_FRESH
            and now() - deathFrame <= replay.KILL_LATE then
            local killer = OF.util.local_from_global(killNote.by)
            killNote.by = nil
            replay.start_kill(killer, deathAt, now() - deathFrame)
        end
    else
        deathAt = nil
    end

    if play.kind ~= nil then playback_frame() end
end

local function hide_bodies(m)
    if play.kind == nil or m == nil or m.marioObj == nil then return end
    local node = m.marioObj.header.gfx.node
    local flags = tonumber(node.flags) or 0
    if not OF.util.has_flag(flags, INVISIBLE) then
        node.flags = flags + INVISIBLE
    end
end

local hudUnder = {}
local hudOpts = { under = hudUnder }

local function hud()
    replay.eyes_back()
    if play.kind == nil then return end
    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)
    local title = OF.lang.t(play.kind == "kill" and "Kill cam" or "Replay")
    for k = #hudUnder, 1, -1 do hudUnder[k] = nil end

    if play.kind == "kill" and play.killer ~= nil then
        local np = gNetworkPlayers[play.killer]
        if np ~= nil then
            hudUnder[#hudUnder + 1] = { scale = 0.8, r = 240, g = 240, b = 240,
                text = OF.lang.fill("Seen from @", OF.util.plain(np.name)) }
        end
    end

    if play.slow > 0 and play.t > play.span - play.slow then
        hudUnder[#hudUnder + 1] = { scale = 0.7, r = 255, g = 210, b = 120,
            text = OF.lang.t("Slow motion") }
    end
    hudUnder[#hudUnder + 1] = { scale = 0.7, r = 200, g = 200, b = 200,
        text = OF.lang.t("B to skip") }
    OF.util.banner_low(title, 1.1, 255, 90, 70, 255, hudOpts)
end

replay.update = update
replay.hide_bodies = hide_bodies
replay.record = record_frame
replay.hud = hud

hook_event(HOOK_UPDATE, update)
hook_event(HOOK_MARIO_UPDATE, hide_bodies)
hook_event(HOOK_ON_PACKET_RECEIVE, on_packet)
hook_event(HOOK_ON_OBJECT_RENDER, replay.standin_render)

function replay.ready()
    return true
end
