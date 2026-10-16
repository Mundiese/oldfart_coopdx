OF = OF or {}
OF.gm_downhill = OF.gm_downhill or {}
local DH = OF.gm_downhill

local K = {}

K.ROLE_RIDE = "shredding"
K.ROW_KEY = "ofDhState"
K.SPIN_RATE = 0x900
K.CLEAN = 0x2000
K.GRAB_SHORT, K.GRAB_LONG = 10, 25
K.BIG_AIR = 40

K.SPIN_PAY = { 1, 2, 4, 6, 9 }

K.TRICK_POINTS = 100
K.COIN_POINTS = 50

K.COMBO_GAP = 45
K.COMBO_STEP, K.COMBO_MOST = 0.5, 5.0

K.CRASH = 1

K.SLOPE_TOP = 80.0
K.PUSH_OFF = 30.0
K.REMOUNT = 15

K.FOOT_RADIUS = 700

K.FINISH_PAY = { 5, 3, 2 }
K.FINISH_REST = 1

K.AIR_EVERY, K.AIR_UP, K.AIR_GAP = 6, 330, 160
K.AIR_REACH = 120

K.RUN_SECONDS = 90

K.FLIP_RATE = 0xA00
K.FLIP_PAY = { 3, 7, 12 }

K.FLIP_MIDDLE = 80

K.TWEAK_PAY = 1
K.OFFAXIS_PAY = 3
K.UBER_NEEDS = 4
K.UBER_PAY = 8
K.ROLL_RATE = 0x900
K.GRAB_DEAD = 24

K.STICK_ARM = 24
K.GRABS = { centre = "indy", up = "nose grab", down = "tail grab",
            left = "melon", right = "method" }

function DH.settle(value, unit, rate)
    local target = math.floor(value / unit + 0.5) * unit
    local off = value - target
    if off > rate then return rate end
    if off < -rate then return -rate end
    return off
end

function DH.grab_name(stickX, stickY)
    local x, y = stickX or 0, stickY or 0
    if math.abs(x) < K.GRAB_DEAD and math.abs(y) < K.GRAB_DEAD then return K.GRABS.centre end
    if math.abs(y) >= math.abs(x) then
        return y > 0 and K.GRABS.up or K.GRABS.down
    end
    return x < 0 and K.GRABS.left or K.GRABS.right
end

K.FALL_GAP = 1200
K.FALL_FRAMES = 8

K.MARIO_TALL = 160
K.FALL_DROP = 8 * K.MARIO_TALL
K.AIR_MOST = 90
K.CRUMB_EVERY = 6
K.CRUMBS = 40
K.BACK_CRUMBS = 8

K.SLIDES = {
    ccm = { level = "LEVEL_CCM", area = 2, top = "floodGoal", foot = "floodStart" },
    pss = { level = "LEVEL_PSS", area = 1, top = "lineStart", foot = "lineFinish" },
    ttm = { level = "LEVEL_TTM", area = 2, footArea = 4,

            topAt = { x = 7000, y = 4781, z = 6750, yaw = 225 },
            footAt = { x = -7285, y = -1866, z = -4812, yaw = 0 } },
}
DH.SLIDES = K.SLIDES

K.SLIDE_ROADS = {
    { level = "LEVEL_CCM", area = 2, points = {
        { -4762, 6660, -6143 }, { -4133, 6455, -6100 }, { -2000, 6100, -5944 },
        { -1200, 6033, -5833 }, { 1022, 5611, -6033 }, { 3833, 5033, -6233 },
        { 6055, 4598, -5766 }, { 6677, 4462, -4877 }, { 6277, 4417, -3344 },
        { 4788, 4280, -1844 }, { 2211, 4086, -555 }, { 522, 3687, -222 },
        { -724, 3443, -466 }, { -1350, 3302, -1288 }, { -1255, 3039, -3000 },
        { -2233, 2785, -4533 }, { -3288, 2622, -4820 }, { -4266, 2480, -4555 },
        { -4900, 2333, -3944 }, { -5066, 2175, -2977 }, { -4833, 2018, -1999 },
        { -4122, 1866, -1366 }, { -3200, 1736, -1088 }, { -222, 1027, -1200 },
        { 1333, 761, -1733 }, { 2488, 562, -2944 }, { 2977, 361, -4988 },
        { 3754, 329, -5689 }, { 5805, 86, -5980 }, { 6566, -449, -4133 },
        { 6689, -1119, -888 }, { 6688, -2127, 1200 }, { 6666, -2573, 3555 },
        { 6600, -2667, 4333 }, { 6366, -2832, 5722 }, { 5844, -3021, 6355 },
        { 2955, -3394, 6255 }, { 1788, -3512, 5988 }, { -89, -3720, 5188 },
        { -732, -3910, 4144 }, { -722, -4095, 2688 }, { -1333, -4198, 1255 },
        { -2377, -4302, 788 }, { -4500, -4684, 277 }, { -5466, -4790, 11 },
        { -6044, -4860, -333 }, { -6388, -5079, -1155 }, { -6510, -5389, -2666 },
        { -6476, -5555, -3622 }, { -6488, -5684, -4777 }, { -6488, -5829, -6088 },
        { -6507, -5841, -6400 },
    } },
}
DH.SLIDE_ROADS = K.SLIDE_ROADS

function DH.slide_key()
    local said = OF.util.asks(OF.gamemodes, "option_showing")
        and OF.gamemodes.option_showing("downhill", "slide") or nil
    if K.SLIDES[said or ""] == nil then return "ccm" end
    return said
end

function DH.slide()
    return K.SLIDES[DH.slide_key()]
end

function DH.end_of(slide, which)
    if slide == nil then return nil end
    local level = _G[slide.level]
    if level == nil then return nil end
    local area = slide.area
    if which == "foot" and slide.footArea ~= nil then area = slide.footArea end
    local at
    if which == "top" and slide.topAt ~= nil then
        at = OF.util.asks(OF.warp, "land_spot") and OF.warp.land_spot(slide.topAt) or slide.topAt
    elseif which == "foot" and slide.footAt ~= nil then
        at = OF.util.asks(OF.warp, "land_spot") and OF.warp.land_spot(slide.footAt) or slide.footAt
    else
        at = OF.gamemodes.surveyed({ level = level, area = slide.area }, slide[which])
    end
    if at == nil then return nil end
    return { level = level, area = area, x = at.x, y = at.y, z = at.z, yaw = at.yaw or 0 }
end

local function wrap(a)
    a = a % 0x10000
    if a >= 0x8000 then a = a - 0x10000 end
    return a
end
DH.wrap = wrap

function DH.judge(turned, grab, holding, air, flipped, how)
    how = how or {}
    local off = wrap(turned)
    local ahead = math.abs(off) <= K.CLEAN
    local back = math.abs(wrap(off + 0x8000)) <= K.CLEAN
    local upright = math.abs(wrap(flipped or 0)) <= K.CLEAN
        and math.abs(wrap(how.rolled or 0)) <= K.CLEAN
    if holding or not (ahead or back) or not upright then return false, 0, nil end
    local halves = math.floor(math.abs(turned) / 0x8000 + 0.5)
    local pay = 0
    if halves > 0 then pay = K.SPIN_PAY[math.min(halves, #K.SPIN_PAY)] end
    local flips = math.floor(math.abs(flipped or 0) / 0x10000 + 0.5)
    if flips > 0 then pay = pay + K.FLIP_PAY[math.min(flips, #K.FLIP_PAY)] end
    local grabbed = 0
    if (grab or 0) >= K.GRAB_LONG then grabbed = 2 elseif (grab or 0) >= K.GRAB_SHORT then grabbed = 1 end
    pay = pay + grabbed
    local offAxis = halves > 0 and flips > 0
    if offAxis then pay = pay + K.OFFAXIS_PAY end
    local tweaked = grabbed > 0 and (how.tweak or 0) >= K.GRAB_SHORT
    if tweaked then pay = pay + K.TWEAK_PAY end
    local rolls = math.floor(math.abs(how.rolled or 0) / 0x10000 + 0.5)
    local uber = how.ready == true and rolls > 0
    if uber then pay = pay + K.UBER_PAY end
    if pay > 0 and (air or 0) >= K.BIG_AIR then pay = pay + 1 end
    if pay == 0 then return true, 0, nil end
    local name = tostring(halves * 180)
    if offAxis then name = ((flipped or 0) > 0 and "cork " or "rodeo ") .. name end
    if flips > 0 then
        name = name .. ((flipped or 0) > 0 and " front" or " back") .. " flip" .. (flips > 1 and ("x" .. flips) or "")
    end
    if grabbed > 0 then
        if how.grabName ~= nil then
            name = name .. " " .. how.grabName .. (tweaked and " tweaked" or "")
        else
            name = name .. "g"
        end
    end
    if uber then name = "uber " .. name end
    return true, pay, name
end

function DH.multiplier(n)
    if (n or 0) <= 1 then return 1 end
    return math.min(K.COMBO_MOST, 1 + K.COMBO_STEP * (n - 1))
end

local me = {
    points = 0, runs = 0, times = {}, runStart = nil,

    air = false, travel = 0, turned = 0, grab = 0, frames = 0, flipped = 0,

    crumbs = {}, crumbAt = 0, crumbTick = 0, falling = 0, airFor = 0,

    pot = 0, count = 0, names = {}, ground = 0, ticker = {},
    sinceRide = 0, lifting = false, done = false,
    airTaken = {}, written = nil, said = nil,
}
DH.me = me

function DH.land_clean(pay, name)
    if pay <= 0 then return 0 end
    local again = name ~= nil and me.names[name]
    if again then pay = pay / 2 end
    if name ~= nil then me.names[name] = true end
    me.pot = me.pot + pay
    if not again then me.count = me.count + 1 end
    me.ticker = me.ticker or {}
    table.insert(me.ticker, name or "air")
    if #me.ticker > 3 then table.remove(me.ticker, 1) end

    if OF.util.asks(OF.hud, "banner") then
        OF.hud.banner("medal", string.upper(OF.lang.t(name or "air")), nil, { quiet = true })
    end
    return pay
end

function DH.chain_points()
    return math.floor(me.pot * K.TRICK_POINTS * DH.multiplier(me.count) + 0.5)
end

local function chain_over()
    me.pot, me.count, me.names, me.ticker = 0, 0, {}, {}
end

function DH.bank()
    if me.pot <= 0 then
        chain_over()
        return 0
    end
    local paid = DH.chain_points()
    me.points = me.points + paid
    chain_over()
    if paid > 0 then
        OF.gamemodes.cue("good", nil, "dhbank")

    end
    DH.write_row()
    return paid
end

function DH.crash()
    chain_over()
    OF.gamemodes.cue("bad", nil, "dhcrash")

    DH.write_row()
end

function DH.parse_row(text)
    local out = { points = 0, runs = 0, times = {} }
    if type(text) ~= "string" then return out end
    local c, r, t = text:match("^(%d+)|(%d+)|([%d,]*)$")
    out.points = tonumber(c) or 0
    out.runs = tonumber(r) or 0
    for word in string.gmatch(t or "", "%d+") do table.insert(out.times, tonumber(word)) end
    return out
end

function DH.row_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    return DH.parse_row(row ~= nil and row[K.ROW_KEY] or nil)
end

function DH.write_row()
    local times = {}
    for _, t in ipairs(me.times) do table.insert(times, string.format("%.0f", t)) end
    local text = string.format("%.0f|%.0f|%s", me.points, me.runs, table.concat(times, ","))
    if text == me.written then return end
    me.written = text
    OF.util.publish_row(0, "ofDhState", text)
end

function DH.bonus_of(localIndex, entries)
    local mine = DH.row_of(localIndex)
    local total = 0
    for run, myTime in ipairs(mine.times) do
        local faster = 0
        for _, entry in ipairs(entries) do
            if entry.localIndex ~= localIndex then
                local t = DH.row_of(entry.localIndex).times[run]
                if t ~= nil and (t < myTime
                    or (t == myTime and entry.localIndex < localIndex)) then
                    faster = faster + 1
                end
            end
        end
        total = total + (K.FINISH_PAY[faster + 1] or K.FINISH_REST) * K.TRICK_POINTS
    end
    return total
end

function DH.riders_all()
    local list = {}
    for _, entry in ipairs(OF.gamemodes.with_role(K.ROLE_RIDE)) do table.insert(list, entry) end
    return list
end

function DH.score_of(localIndex)
    return DH.row_of(localIndex).points + DH.bonus_of(localIndex, DH.riders_all())
end

K.RUNS = { two = 2, one = 1, three = 3 }
function DH.runs_wanted()
    return K.RUNS[OF.gamemodes.option_now("runs") or "two"] or 2
end

local function ride() return OF.shellride or {} end

local function on_the_ride(m)
    return OF.util.asks(OF.shellride, "on_the_ride") and OF.shellride.on_the_ride(m)
end

K.lastSpeed = 0

function DH.shape_ride(m, air)
    if m == nil or m.playerIndex ~= 0 then return end
    if air then return end
    local v = m.forwardVel or 0
    local floor = m.floor
    if floor ~= nil and floor.normal ~= nil and v > 0 then
        local nx, nz = floor.normal.x or 0, floor.normal.z or 0
        local yaw = (m.faceAngle.y or 0) * math.pi / 0x8000
        local down = nx * math.sin(yaw) + nz * math.cos(yaw)
        if down > 0.05 then

            v = math.min(K.SLOPE_TOP, math.max(v, K.lastSpeed) + 4 * down - 0.5)
        end
    end
    m.forwardVel = v
    K.lastSpeed = v
end

function DH.ride_air(m)
    if m == nil or m.playerIndex ~= 0 or not DH.live() then return false end
    if not me.air then
        me.air, me.turned, me.grab, me.frames, me.flipped = true, 0, 0, 0, 0
        me.grabName, me.tweak, me.uber, me.rolled, me.holding = nil, 0, 0, 0, false
        me.ready = (me.count or 0) >= K.UBER_NEEDS
        me.travel = m.faceAngle.y or 0
        local up0 = (m.controller ~= nil and m.controller.stickY) or 0

        local pad = m.controller ~= nil and ((m.controller.buttonDown or 0)
            | (m.controller.buttonPressed or 0)) or 0
        me.flipArmed = (pad & A_BUTTON) ~= 0 or math.abs(up0) < K.STICK_ARM
    end
    me.frames = me.frames + 1
    local stick = (m.controller ~= nil and m.controller.stickX) or 0
    local turn
    if math.abs(stick) >= K.STICK_ARM then
        turn = math.floor(K.SPIN_RATE * math.max(-1, math.min(1, stick / 64)))
    else
        turn = DH.settle(me.turned, 0x8000, K.SPIN_RATE)
    end
    me.turned = me.turned - turn
    m.faceAngle.y = wrap((m.faceAngle.y or 0) - turn)

    local up = (m.controller ~= nil and m.controller.stickY) or 0
    if not me.flipArmed and math.abs(up) < K.STICK_ARM then me.flipArmed = true end
    local flip = 0
    if me.flipArmed and math.abs(up) >= K.STICK_ARM then
        flip = math.floor(K.FLIP_RATE * math.max(-1, math.min(1, up / 64)))
    elseif me.flipArmed then
        flip = -DH.settle(me.flipped, 0x10000, K.FLIP_RATE)
    end
    me.flipped = me.flipped + flip
    m.faceAngle.x = wrap(me.flipped)
    local down = (m.controller ~= nil and m.controller.buttonDown) or 0
    local z = (down & Z_TRIG) ~= 0
    local b = (down & B_BUTTON) ~= 0

    if z and me.grab == 0 and me.grabName == nil then
        me.grabName = DH.grab_name(m.controller.stickX, m.controller.stickY)
    end
    if z then me.grab = me.grab + 1 end
    if z and b then me.tweak = me.tweak + 1 end

    if b and not z and me.ready then
        me.uber = me.uber + 1
        me.rolled = me.rolled + K.ROLL_RATE
    end
    m.faceAngle.z = wrap(me.rolled)
    me.holding = z or b

    local v = (m.forwardVel or 0)
    if v > 32 then v = v - 0.35 end
    m.forwardVel = v
    local s, c = math.sin(me.travel * math.pi / 0x8000), math.cos(me.travel * math.pi / 0x8000)
    m.vel.x, m.vel.z = v * s, v * c
    m.slideVelX, m.slideVelZ = m.vel.x, m.vel.z
    return true
end

function DH.ride_land(m)
    if m == nil or m.playerIndex ~= 0 or not me.air then return nil end
    me.air = false
    local clean, pay, name = DH.judge(me.turned, me.grab, me.holding, me.frames, me.flipped,
        { grabName = me.grabName, tweak = me.tweak, uber = me.uber, rolled = me.rolled,
          ready = me.ready })
    m.faceAngle.x, m.faceAngle.z = 0, 0
    me.flipped, me.rolled, me.uber, me.tweak, me.grabName = 0, 0, 0, 0, nil
    me.ground = 0
    if not clean then
        m.faceAngle.y = me.travel
        DH.crash()
        return K.CRASH
    end
    m.faceAngle.y = me.travel
    if pay > 0 then
        local got = DH.land_clean(pay, name)
        if got > 0 then OF.gamemodes.cue("good", nil, "dhtrick") end
    end
    return nil
end

function DH.live()
    local cur = OF.gamemodes.current()
    return cur ~= nil and cur.key == "downhill"
        and OF.gamemodes.state() == OF.gamemodes.ACTIVE
end

local function riding_me()
    if OF.gamemodes.role(0) ~= K.ROLE_RIDE then return false end
    return OF.util.can_play(0)
end

local function in_slide(index)
    local np = gNetworkPlayers[index or 0]
    local slide = DH.slide()
    if np == nil or slide == nil then return false end
    return np.currLevelNum == _G[slide.level]
end

local function show(name, model, x, y, z)
    return OF.gamemodes.show_token(name, model, { x = x, y = y, z = z }, nil)
end
local function hide(name) OF.gamemodes.hide_token(name) end

K.CAM_BACK, K.CAM_UP, K.CAM_FRAMES = 700, 260, 3
me.camOwed = 0
function DH.camera_behind(m)
    me.camOwed = K.CAM_FRAMES
    DH.camera_frame(m)
end
local function put3(v, x, y, z)
    if v ~= nil then v.x, v.y, v.z = x, y, z end
end
function DH.camera_frame(m)
    if (me.camOwed or 0) <= 0 or m == nil or m.pos == nil then return false end
    me.camOwed = me.camOwed - 1
    local yaw = (m.faceAngle.y or 0) * math.pi / 0x8000
    local cx = m.pos.x - math.sin(yaw) * K.CAM_BACK
    local cz = m.pos.z - math.cos(yaw) * K.CAM_BACK
    local cy = m.pos.y + K.CAM_UP
    local fy = m.pos.y + 120
    local s = gLakituState
    if s ~= nil then
        put3(s.pos, cx, cy, cz)
        put3(s.curPos, cx, cy, cz)
        put3(s.goalPos, cx, cy, cz)
        put3(s.focus, m.pos.x, fy, m.pos.z)
        put3(s.curFocus, m.pos.x, fy, m.pos.z)
        put3(s.goalFocus, m.pos.x, fy, m.pos.z)
        s.yaw = wrap((m.faceAngle.y or 0) + 0x8000)
    end
    local c = m.area ~= nil and m.area.camera or nil
    if c ~= nil then
        put3(c.pos, cx, cy, cz)
        put3(c.focus, m.pos.x, fy, m.pos.z)
        c.yaw = wrap((m.faceAngle.y or 0) + 0x8000)
    end
    if OF.util.optional("camera_config_is_free_cam_enabled", false) then
        OF.util.optional("center_free_camera", nil)
    end
    OF.util.optional("skip_camera_interpolation", nil)
    return true
end

function DH.to_top(m)
    local top = DH.end_of(DH.slide(), "top")
    if top == nil or m == nil then return false end
    local np = gNetworkPlayers[0]
    if np ~= nil and (np.currLevelNum ~= top.level or np.currAreaIndex ~= top.area) then

        local place = OF.gamemodes.round_place()
        OF.net.warp_local(top.level, top.area, place ~= nil and place.act or 1)
        me.lifting = true
        return true
    end
    local y = top.y
    if find_floor_height ~= nil then
        local f = find_floor_height(top.x, top.y + 300, top.z)
        if type(f) == "number" and f > -10000 then y = f end
    end
    if OF.util.asks(OF.doorways, "put_at") then
        OF.doorways.put_at(m, top.x, y, top.z)
    else
        m.pos.x, m.pos.y, m.pos.z = top.x, y, top.z
    end
    local yaw = math.floor((top.yaw or 0) * 0x10000 / 360) % 0x10000
    m.faceAngle.y = wrap(yaw)
    m.intendedYaw = m.faceAngle.y
    m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
    local r = ride()
    if r.RIDE_GROUND ~= nil then
        mario_set_forward_vel(m, K.PUSH_OFF)
        set_mario_action(m, r.RIDE_GROUND, 1)
    end
    me.lifting = false
    me.runStart = OF.gamemodes.since_start()
    DH.camera_behind(m)
    return true
end

function DH.check_foot(m)
    if me.done or me.runStart == nil then return false end
    local foot = DH.end_of(DH.slide(), "foot")
    local np = gNetworkPlayers[0]
    if foot == nil or np == nil then return false end
    if np.currLevelNum ~= foot.level or np.currAreaIndex ~= foot.area then return false end
    local dx, dy, dz = m.pos.x - foot.x, m.pos.y - foot.y, m.pos.z - foot.z
    if dx * dx + dz * dz > K.FOOT_RADIUS * K.FOOT_RADIUS or math.abs(dy) > 600 then
        return false
    end
    DH.bank()
    me.runs = me.runs + 1
    table.insert(me.times, math.max(1, math.floor((OF.gamemodes.since_start() - me.runStart) * 10)))
    me.runStart = nil
    me.airTaken = {}
    DH.write_row()

    local gained = me.points - (me.runFrom or 0)
    me.runFrom = me.points
    local better = me.bestRun ~= nil and gained > me.bestRun
    if me.bestRun == nil or gained > me.bestRun then me.bestRun = gained end
    if OF.util.asks(OF.hud, "banner") then
        if better then
            OF.hud.banner("objective", OF.lang.t("NEW BEST RUN"),
                OF.lang.fill("@ points", tostring(math.floor(gained))))
        elseif me.runs >= DH.runs_wanted() then
            OF.hud.banner("objective", OF.lang.t("ALL RUNS DONE"), OF.lang.t("Counted at the end"))
        end
    end
    if me.runs >= DH.runs_wanted() then
        me.done = true
        return true
    end
    DH.to_top(m)
    return true
end

function DH.air_coins()
    local slide = DH.slide()
    local level = slide ~= nil and _G[slide.level] or nil
    if level == nil or OF.gm_shellrace == nil or OF.gm_shellrace.route_between == nil then
        return {}
    end
    local top = DH.end_of(slide, "top")
    local foot = DH.end_of(slide, "foot")
    if top == nil or foot == nil or top.area ~= foot.area then return {} end
    local road = OF.gm_shellrace.route_between(level, slide.area, top, foot, K.SLIDE_ROADS)
    if road == nil then return {} end
    local out = {}
    for i = K.AIR_EVERY, #road.points - 2, K.AIR_EVERY do
        local a, b = road.points[i], road.points[i + 1]
        local dx, dz = b.x - a.x, b.z - a.z
        local len = math.max(1, math.sqrt(dx * dx + dz * dz))
        for k = 0, 2 do
            table.insert(out, { x = a.x + dx / len * K.AIR_GAP * k,
                                y = a.y + K.AIR_UP,
                                z = a.z + dz / len * K.AIR_GAP * k })
        end
    end
    return out
end

K.airCoins = nil
function DH.take_air_coins(m)
    if K.airCoins == nil then K.airCoins = DH.air_coins() end
    if me.runStart == nil then return 0 end
    local got = 0
    for i, c in ipairs(K.airCoins) do
        if not me.airTaken[i] then
            local dx, dy, dz = m.pos.x - c.x, m.pos.y + 60 - c.y, m.pos.z - c.z
            if dx * dx + dy * dy + dz * dz < K.AIR_REACH * K.AIR_REACH then
                me.airTaken[i] = true
                me.points = me.points + K.COIN_POINTS
                got = got + 1
            end
        end
    end
    if got > 0 then
        OF.gamemodes.cue("good", nil, "dhcoin")
        DH.write_row()
    end
    return got
end

function DH.draw_flip(m)
    if m == nil or m.marioObj == nil then return false end
    local r = ride()
    if r.RIDE_AIR == nil or m.action ~= r.RIDE_AIR then return false end
    local pitch = m.faceAngle.x or 0
    local roll = m.faceAngle.z or 0
    if (pitch == 0 and roll == 0) or not DH.live() then return false end
    local gfx = m.marioObj.header.gfx
    gfx.angle.x = pitch

    gfx.angle.z = roll
    local a = pitch * math.pi / 0x8000
    gfx.pos.y = gfx.pos.y + K.FLIP_MIDDLE * (1 - math.cos(a))
    return true
end

function DH.drop_crumb(m)
    local np = gNetworkPlayers[0]
    if np == nil then return end
    me.crumbTick = me.crumbTick + 1
    if me.crumbTick < K.CRUMB_EVERY then return end
    me.crumbTick = 0
    me.crumbAt = me.crumbAt + 1
    me.crumbs[me.crumbAt] = { x = m.pos.x, y = m.pos.y, z = m.pos.z, yaw = m.faceAngle.y or 0,
        level = np.currLevelNum, area = np.currAreaIndex }
    me.crumbs[me.crumbAt - K.CRUMBS] = nil
end

function DH.fall_frame(m)
    local air = OF.util.has_flag(m.action or 0, ACT_FLAG_AIR or 0x800)
    if not air then
        me.falling, me.airFor = 0, 0
        me.groundY = m.pos.y
        return false
    end
    me.airFor = me.airFor + 1
    local floorY = tonumber(m.floorHeight)
    local gap = (m.floor == nil or floorY == nil or floorY < -10000) and math.huge
        or (m.pos.y - floorY)
    local dropped = (me.groundY or m.pos.y) - m.pos.y
    if (m.vel.y or 0) < 0 and gap > K.FALL_GAP and dropped >= K.FALL_DROP then
        me.falling = me.falling + 1
    else
        me.falling = 0
    end
    return me.falling >= K.FALL_FRAMES or me.airFor >= K.AIR_MOST
end

function DH.back_on_slide(m)
    local np = gNetworkPlayers[0]
    local spot, at = nil, nil
    for i = me.crumbAt - K.BACK_CRUMBS, me.crumbAt - K.CRUMBS + 1, -1 do
        local c = me.crumbs[i]
        if c ~= nil and np ~= nil and c.level == np.currLevelNum and c.area == np.currAreaIndex then
            spot, at = c, i
            break
        end
    end
    if spot == nil then
        for i = me.crumbAt, me.crumbAt - K.BACK_CRUMBS + 1, -1 do
            local c = me.crumbs[i]
            if c ~= nil and np ~= nil and c.level == np.currLevelNum and c.area == np.currAreaIndex then
                spot, at = c, i
            end
        end
    end
    me.air, me.flipped, me.falling, me.airFor, me.rolled = false, 0, 0, 0, 0
    m.faceAngle.x, m.faceAngle.z = 0, 0
    if me.pot > 0 then DH.crash() end

    if spot == nil then return DH.to_top(m) end

    for i = at + 1, me.crumbAt do me.crumbs[i] = nil end
    me.crumbAt = at
    if OF.util.asks(OF.doorways, "put_at") then
        OF.doorways.put_at(m, spot.x, spot.y, spot.z)
    else
        m.pos.x, m.pos.y, m.pos.z = spot.x, spot.y, spot.z
    end
    m.faceAngle.y = spot.yaw
    m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
    local r = ride()
    if r.RIDE_GROUND ~= nil then
        mario_set_forward_vel(m, K.PUSH_OFF)
        set_mario_action(m, r.RIDE_GROUND, 1)
    end
    DH.camera_behind(m)
    return true
end

local mode = {
    key = "downhill",
    name = "Shell Shred",
    blurb = "down a slide on a shell - chain stylish tricks for points",
    aims = { [K.ROLE_RIDE] = "Chain tricks your way down - most points wins." },
    how = "Everybody rides a shell down a slide.\n"
        .. "A hops. In the air the stick spins and flips you, Z grabs.\n"
        .. "The stick as Z goes down names the grab.\n"
        .. "B over a grab tweaks it.\n"
        .. "A spin with a flip is a cork or a rodeo.\n"
        .. "A full combo lets B roll an uber.\n"
        .. "Land upright, facing ahead or back, Z let go - or crash.\n"
        .. "B still held at the ground is a crash too.\n"
        .. "Fall off the slide and you are put back on it, combo lost.\n"
        .. "Tricks in a row build a chain; it banks when you ride on.\n"
        .. "Every new trick in a chain raises its multiplier, up to x5.\n"
        .. "A crash loses the chain. A repeated trick pays half.\n"
        .. "Air coins and quick runs add a little. Most points wins.",
    minPlayers = 2,

    maps = "own",
    startPlace = setmetatable({}, { __index = function(_, field)
        local top = DH.end_of(DH.slide(), "top")
        if field == "level" then return top ~= nil and top.level or LEVEL_CCM end
        if field == "area" then return top ~= nil and top.area or 2 end
        if field == "act" then return 1 end
        return nil
    end }),

    room = { sweep = { "cannons", "pickups", "enemies", "bosses", "projectiles",
                       "spawners" },
             rules = { interactions = PLAYER_INTERACTIONS_NONE } },

    unsolidInAFight = true,
    music = SEQ_LEVEL_SLIDE,
    defaultLimit = 180,
    teams = false,

    placeOption = "slide",

    boardTitle = "Points",
    options = {
        { key = "slide", name = "Slide",
          help = "which slide everybody comes down",
          choices = {
              { key = "ccm", name = "Cool, Cool Mountain",
                help = "the penguin's race, with coins over the road" },
              { key = "pss", name = "Princess's Secret Slide",
                help = "the castle's own slide" },
              { key = "ttm", name = "Tall, Tall Mountain",
                help = "the long one, through three warps" },
          } },
        { key = "runs", name = "Runs",
          help = "how many times everybody comes down",
          choices = {

              { key = "two", name = "two", help = "the points of both count" },
              { key = "one", name = "one", help = "a single run decides it" },
              { key = "three", name = "three", help = "a longer round" },
          } },
    },
}
DH.mode = mode
mode.shape_ride = DH.shape_ride
mode.ride_air = DH.ride_air
mode.ride_land = DH.ride_land

function mode.terms()
    return OF.lang.t("most points from trick chains")
end

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, K.ROLE_RIDE)
    end
    if options == nil or tonumber(options.limit) == nil then
        OF.util.publish("ofGmLimit", DH.runs_wanted() * K.RUN_SECONDS)
    end
end

function mode.late_join(localIndex)
    OF.gamemodes.set_role(localIndex, K.ROLE_RIDE)
    return K.ROLE_RIDE
end

function mode.side_place(side)
    if side ~= nil then return nil end
    local top = DH.end_of(DH.slide(), "top")
    if top == nil then return nil end
    return { x = top.x, y = top.y, z = top.z, level = top.level, area = top.area }
end

function mode.death_place()
    local top = DH.end_of(DH.slide(), "top")
    if top == nil then return nil end
    return { x = top.x, y = top.y + 50, z = top.z, level = top.level, area = top.area }
end

function DH.forget()
    me.points, me.runs, me.times, me.runStart = 0, 0, {}, nil
    me.air, me.travel, me.turned, me.grab, me.frames, me.holding = false, 0, 0, 0, 0, false
    me.grabName, me.tweak, me.uber, me.rolled, me.ready = nil, 0, 0, 0, false
    me.flipped, me.crumbs, me.crumbAt, me.crumbTick, me.falling, me.airFor = 0, {}, 0, 0, 0, 0
    me.pot, me.count, me.names, me.ground, me.ticker = 0, 0, {}, 0, {}
    me.sinceRide, me.lifting, me.done = 0, false, false
    me.airTaken, me.written, me.said = {}, nil, nil
    me.runFrom, me.bestRun = 0, nil
    K.lastSpeed = 0
    K.airCoins = nil
end

function mode.on_start()
    DH.forget()
end

function mode.cleanup()
    DH.forget()
    for index = 0, MAX_PLAYERS - 1 do hide("dhShell" .. index) end
    for i = 1, 64 do hide("dhCoin" .. i) end
    OF.util.publish_row(0, "ofDhState", nil)
end

local RIDE_GROUPS = nil
local function may_ride(m)
    if m == nil or m.action == nil then return false end
    if (m.health or 0) < 0x100 then return false end
    if RIDE_GROUPS == nil then
        RIDE_GROUPS = { [ACT_GROUP_STATIONARY] = true, [ACT_GROUP_MOVING] = true,
                        [ACT_GROUP_AIRBORNE] = true }
    end
    return RIDE_GROUPS[m.action & ACT_GROUP_MASK] == true
end

function mode.before_mario_update(m)
    if m == nil or m.playerIndex ~= 0 or not DH.live() then return end
    if not riding_me() or me.done then return end
    local r = ride()
    if r.RIDE_GROUND == nil then return end
    if me.runStart == nil and me.runs == 0 and not me.lifting then
        me.runStart = OF.gamemodes.since_start()
    end

    if me.air and m.action ~= r.RIDE_AIR then
        me.air, me.flipped, me.rolled = false, 0, 0
        m.faceAngle.x, m.faceAngle.z = 0, 0
    end
    if on_the_ride(m) then me.sinceRide = 0 return end
    me.sinceRide = me.sinceRide + 1
    if me.sinceRide < K.REMOUNT or not may_ride(m) then return end
    me.sinceRide = 0
    if (m.forwardVel or 0) < K.PUSH_OFF then mario_set_forward_vel(m, K.PUSH_OFF) end
    set_mario_action(m, r.RIDE_GROUND, 1)
end

function mode.update()
    if not DH.live() or not riding_me() then return end
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return end
    DH.camera_frame(m)
    if me.written == nil then DH.write_row() end
    if me.done then return end
    if me.lifting then

        local top = DH.end_of(DH.slide(), "top")
        local np = gNetworkPlayers[0]
        if top ~= nil and np ~= nil and np.currLevelNum == top.level
            and np.currAreaIndex == top.area and np.currAreaSyncValid ~= false then
            DH.to_top(m)
        end
        return
    end

    if not me.air and on_the_ride(m) and m.action == ride().RIDE_GROUND then
        me.ground = me.ground + 1
        if me.ground >= K.COMBO_GAP and me.pot > 0 then DH.bank() end
        DH.drop_crumb(m)
    end

    if me.runStart ~= nil and DH.fall_frame(m) then
        DH.back_on_slide(m)
        return
    end
    DH.take_air_coins(m)
    DH.check_foot(m)
end

function mode.scenery()
    if not DH.live() then return end
    for index = 0, MAX_PLAYERS - 1 do
        local m = gMarioStates[index]
        local np = gNetworkPlayers[index]
        if m ~= nil and np ~= nil and np.connected and OF.gamemodes.role(index) == K.ROLE_RIDE
            and in_slide(index) and on_the_ride(m) then

            local shell = OF.gamemodes.tokens["dhShell" .. index]
            if shell == nil or shell.activeFlags == 0 then
                show("dhShell" .. index, E_MODEL_KOOPA_SHELL, m.pos.x, m.pos.y, m.pos.z)
            end
        else
            hide("dhShell" .. index)
        end
    end
    local coinsHere = K.airCoins or {}
    for i = 1, 64 do
        local c = coinsHere[i]
        if c ~= nil and not me.airTaken[i] and me.runStart ~= nil and in_slide(0) then

            OF.gamemodes.show_token("dhCoin" .. i, E_MODEL_YELLOW_COIN,
                { x = c.x, y = c.y, z = c.z }, nil, nil, true)
        else
            hide("dhCoin" .. i)
        end
    end
end

function mode.host_update()
    if not DH.live() then return end
    local riding, done = 0, 0
    for _, entry in ipairs(DH.riders_all()) do
        if OF.util.can_play(entry.localIndex) then
            riding = riding + 1
            if DH.row_of(entry.localIndex).runs >= DH.runs_wanted() then done = done + 1 end
        end
    end
    if riding > 0 and done >= riding then mode.on_timeout() end
end

function mode.on_timeout()
    local bestScore, names = OF.gamemodes.best_of(DH.riders_all(),
        function(entry) return DH.score_of(entry.localIndex) end)
    if bestScore == nil or bestScore <= 0 then
        OF.gamemodes.finish("Nobody landed a trick.")
    elseif #names > 1 then
        OF.gamemodes.finish("A draw at @ points each.", nil, bestScore)
    else
        OF.gamemodes.finish("@ wins with @ points.", names[1], names[1], bestScore)
    end
end

function mode.board()
    local rows = {}
    for _, entry in ipairs(DH.riders_all()) do
        local value = DH.score_of(entry.localIndex)
        table.insert(rows, { localIndex = entry.localIndex, name = entry.np.name,
            right = OF.lang.fill("@ points", tostring(value)), value = value })
    end
    table.sort(rows, function(a, b)
        if a.value ~= b.value then return a.value > b.value end
        return a.localIndex < b.localIndex
    end)
    return rows
end

function mode.standing(localIndex)
    return OF.lang.fill("@ points", tostring(DH.score_of(localIndex)))
end

local clusterOut = {}
function mode.cluster()
    local rows = mode.board()
    if #rows == 0 or not OF.util.asks(OF.hud, "ordinal") then return nil end
    local mine = nil
    for index, row in ipairs(rows) do
        if row.localIndex == 0 then mine = index end
    end
    local function plate(row, label)
        return { label = label or string.sub(OF.util.plain(row.name or ""), 1, 14),
            score = row.value or 0, localIndex = row.localIndex }
    end
    local you = mine or 1
    clusterOut.you = plate(rows[you], OF.hud.ordinal(you))
    local other = rows[you == 1 and 2 or 1]
    clusterOut.leader = other ~= nil and plate(other) or nil
    clusterOut.leaderIndex = nil
    if rows[2] == nil or (rows[1].value or 0) > (rows[2].value or 0) then
        clusterOut.leaderIndex = rows[1].localIndex
    end
    clusterOut.target, clusterOut.left, clusterOut.right = nil, nil, nil
    return clusterOut
end

function mode.hud()
    if not DH.live() then return end
    if riding_me() then

        OF.util.legend({
            OF.lang.t("A - hop"),
            OF.lang.t("Stick in the air - spin"),
            OF.lang.t("Z in the air - grab, let go to land"),
            OF.lang.t("B - tweak a grab, or roll an uber"),
        })
    end

    if me.pot > 0 and OF.util.asks(OF.hud, "state_line") then
        OF.hud.state_line("chain", OF.lang.t("Chain"), { prio = 50, tone = "good",
            figure = "x" .. string.format("%.1f", DH.multiplier(me.count)) })
    end
end

function DH.place_shell(m)
    if m == nil or m.playerIndex == nil or not DH.live() then return false end
    local shell = OF.gamemodes.tokens["dhShell" .. m.playerIndex]
    local r = ride()
    if shell == nil or shell.activeFlags == 0 or r.place_shell == nil then return false end
    if not on_the_ride(m) then return false end
    return r.place_shell(shell, m)
end

hook_event(HOOK_MARIO_UPDATE, function(m)
    DH.draw_flip(m)
    DH.place_shell(m)
end)

local footTarget = { id = "foot", label = "the bottom", tone = { 120, 255, 140 },
    priority = 90, compass = "offscreen" }
local footList = { footTarget }
function mode.targets(viewer)
    local _ = viewer
    local foot = DH.end_of(DH.slide(), "foot")
    if foot == nil then return nil end
    local spot = { x = foot.x, y = foot.y, z = foot.z, level = foot.level, area = foot.area }
    if not OF.gamemodes.in_place_room(spot) then return nil end
    footTarget.pos = spot
    return footList
end

OF.gamemodes.register(mode)
DH.K = K
