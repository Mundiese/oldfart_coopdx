OF = OF or {}
OF.clones = OF.clones or {}

local clones = OF.clones

clones.KEY = "clones"
clones.TOTAL = 24
clones.PER_MAX = 5

clones.OPTS_KEY = "ofClonesOpts"
clones.OPTS_ACTION = "cloneopt"
clones.OPTS = {
    { key = "count", name = "How many each", start = 3,
      help = "how many run behind each player",
      steps = { "one", "two", "three", "four", "five" } },
    { key = "behind", name = "How far behind",
      help = "how long after you each one runs your path", start = 2,
      steps = { "close behind", "a moment behind", "far behind" } },
    { key = "touch", name = "What a touch costs", start = 1,
      help = "what a clone's touch does to its player",
      steps = { "a wedge of health", "three wedges", "a knock and nothing else",
                "you die", "back to the level's entry" } },
    { key = "where", name = "Where they follow", start = 1,
      help = "which levels the clones follow you into",
      steps = { "the fifteen courses", "every level but the castle", "everywhere" } },
}

clones.FIRST = { 30, 45, 75 }
clones.GAP = { 20, 30, 45 }

clones.COST = { 1, 3, 0 }
clones.TOUCH_DIES, clones.TOUCH_RESETS = 4, 5

clones.STAGGER = { 45, 60, 90 }

clones.CLONE_COINS = 3

clones.COIN_CAP = 999

clones.HISTORY = 75 + 45 * 4 + 2

clones.REACH = 60
clones.BELOW = 70
clones.ABOVE = 150

clones.ARM = 20

clones.COOLDOWN = 45

clones.LIGHT = { 64, 44, 112 }
clones.SHADE = { 10, 4, 26 }

clones.MARK = 0x434C4E45

clones.OTHERS_ALPHA = 153
clones.CLONE_SCALE = 1.0
local INVISIBLE = GRAPH_RENDER_INVISIBLE or 16
local HAS_ANIMATION = GRAPH_RENDER_HAS_ANIMATION or 32
local SEATS = MAX_PLAYERS or 16
local HISTORY = clones.HISTORY

function clones.opt(key)
    local text = gGlobalSyncTable[clones.OPTS_KEY]
    if type(text) ~= "string" then text = "" end
    for index, row in ipairs(clones.OPTS) do
        if row.key == key then
            local step = tonumber(string.sub(text, index, index)) or row.start or 1
            if step < 1 or step > #row.steps then step = row.start or 1 end
            return step
        end
    end
    return 1
end

local function rank()
    return OF.modifiers ~= nil and OF.modifiers.ROW_RANK or "speedrun"
end

function clones.set_opt(key, step, askerLocal)
    if askerLocal == nil and not OF.perms.can(rank()) then
        return false, "Your rank cannot do that."
    end
    if not OF.util.is_host() then
        if OF.util.asks(OF.net, "host_does") then
            return OF.net.host_does(clones.OPTS_ACTION, tonumber(step), nil, tostring(key))
        end
        return false, "No host to ask yet - try again in a second."
    end
    local digits, found = {}, false
    for index, row in ipairs(clones.OPTS) do
        local now = clones.opt(row.key)
        if row.key == key then
            now = math.floor(tonumber(step) or row.start or 1)
            if now < 1 or now > #row.steps then now = row.start or 1 end
            found = true
        end
        digits[index] = tostring(now)
    end
    if not found then return false, "No such setting." end
    OF.util.publish(clones.OPTS_KEY, table.concat(digits))
    return true
end

function clones.reset_opts(askerLocal)
    if askerLocal == nil and not OF.perms.can(rank()) then
        return false, "Your rank cannot do that."
    end
    if not OF.util.is_host() then
        if OF.util.asks(OF.net, "host_does") then
            return OF.net.host_does(clones.OPTS_ACTION, 0, nil, "reset")
        end
        return false, "No host to ask yet - try again in a second."
    end
    OF.util.publish(clones.OPTS_KEY, nil)
    return true
end

function clones.delay(k)
    local step = clones.opt("behind")
    return (clones.FIRST[step] or 45) + (clones.GAP[step] or 30) * ((k or 1) - 1)
end

function clones.arrive(k)
    local step = clones.opt("behind")
    k = k or 1
    local at = clones.delay(1) + (clones.STAGGER[step] or 60) * (k - 1)
    return math.max(at, clones.delay(k))
end

function clones.follows_in(levelNum)
    if levelNum == nil or levelNum <= 0 then return false end
    local where = clones.opt("where")
    if where == 3 then return true end
    if where == 2 then return levelNum ~= (LEVEL_CASTLE or 6)
        and levelNum ~= (LEVEL_CASTLE_GROUNDS or 16)
        and levelNum ~= (LEVEL_CASTLE_COURTYARD or 26) end
    return (OF.util.course_of_level(levelNum) or 0) > 0
end

function clones.lobby_on()
    local modifiers = OF.modifiers
    if modifiers == nil or type(modifiers.active) ~= "function" then return false end
    return (modifiers.active()[clones.KEY] or 0) > 0
end

clones.ROW = "ofClones"
function clones.my_wish()
    local modifiers = OF.modifiers
    if modifiers == nil or type(modifiers.mine_state) ~= "function" then return 0 end
    local state = modifiers.mine_state(clones.KEY)
    if state == true then return 1 end
    if state == false then return -1 end
    return 0
end

function clones.publish_wish()
    local want = clones.my_wish()
    local row = gPlayerSyncTable ~= nil and gPlayerSyncTable[0] or nil
    if row == nil or (tonumber(row[clones.ROW]) or 0) == want then return false end

    OF.util.publish_row(0, "ofClones", want)
    return true
end

function clones.wants(i)
    local row = gPlayerSyncTable ~= nil and gPlayerSyncTable[i] or nil
    local wish = row ~= nil and tonumber(row[clones.ROW]) or 0
    if wish > 0 then return true end
    if wish < 0 then return false end
    return clones.lobby_on()
end

function clones.owner(i)
    if not clones.wants(i) then return false end
    local np = gNetworkPlayers[i]
    if np == nil or not np.connected then return false end
    if OF.util.asks(OF.spectate, "is_spectating") and OF.spectate.is_spectating(i) then
        return false
    end
    if OF.util.asks(OF.roundscope, "inside") and OF.roundscope.inside(i) then
        return false
    end

    if i == 0 and OF.util.asks(OF.modifiers, "in_force")
        and (OF.modifiers.in_force(clones.KEY) or 0) <= 0 then
        return false
    end
    return clones.follows_in(np.currLevelNum)
end

function clones.has(i)
    if not clones.owner(i) then return false end
    if i ~= 0 then
        local np, me = gNetworkPlayers[i], gNetworkPlayers[0]
        if me == nil or np.currLevelNum ~= me.currLevelNum
            or np.currAreaIndex ~= me.currAreaIndex
            or np.currActNum ~= me.currActNum then
            return false
        end
    end
    if OF.util.asks(OF.roundscope, "about") and OF.roundscope.about(i) then
        return false
    end
    return true
end

function clones.per_player()
    local owners = 0
    for i = 0, SEATS - 1 do
        if clones.owner(i) then owners = owners + 1 end
    end
    local wanted = clones.opt("count")
    local share = math.max(1, math.floor(clones.TOTAL / math.max(1, owners)))
    return math.min(wanted, share, clones.PER_MAX)
end

local px, py, pz, ppitch, pyaw, proll, panim, pframe = {}, {}, {}, {}, {}, {}, {}, {}
for k = 1, SEATS * HISTORY do
    px[k], py[k], pz[k] = 0, 0, 0
    ppitch[k], pyaw[k], proll[k], panim[k], pframe[k] = 0, 0, 0, 0, 0
end

local written = {}
for s = 0, SEATS - 1 do written[s] = 0 end

local function slot(seat, index)
    return seat * HISTORY + (index % HISTORY) + 1
end

function clones.written(seat)
    return written[seat or 0] or 0
end

local function record(s)
    local m = gMarioStates[s]
    local o = m ~= nil and m.marioObj or nil
    if o == nil then return false end
    local gfx = o.header ~= nil and o.header.gfx or nil
    local k = slot(s, written[s])
    local x, y, z, pitch, yaw, roll
    if OF.util.asks(OF.replay, "drawn_pose") then
        x, y, z, pitch, yaw, roll = OF.replay.drawn_pose(m, gfx)
    else
        x, y, z, pitch, yaw, roll = m.pos.x, m.pos.y, m.pos.z, 0, m.faceAngle.y, 0
    end
    px[k], py[k], pz[k] = x, y, z
    ppitch[k], pyaw[k], proll[k] = pitch, yaw, roll
    local info = gfx ~= nil and gfx.animInfo or nil
    panim[k] = info ~= nil and info.animID or 0
    pframe[k] = info ~= nil and info.animFrame or 0
    written[s] = written[s] + 1
    return true
end
clones.record = record

function clones.at(s, delay)
    local n = written[s] or 0
    local index = n - 1 - delay
    if index < 0 or index < n - HISTORY then return nil end
    local k = slot(s, index)
    return px[k], py[k], pz[k], ppitch[k], pyaw[k], proll[k], panim[k], pframe[k]
end

local bodies = {}
local shownFor = {}
local modelOf = {}
local rootOf = {}

local arrived = {}
local gone, seenRow, seenRound = {}, {}, {}
for s = 0, SEATS - 1 do
    bodies[s], shownFor[s], arrived[s], gone[s] = {}, {}, {}, 0
end

function clones.bodies(s)
    return bodies[s or 0]
end

local function alive(o)
    return o ~= nil and o.activeFlags ~= 0 and o.oBehParams == clones.MARK
end

local function drop(s, k)
    local o = bodies[s][k]
    if o ~= nil and alive(o) then OF.util.optional("obj_mark_for_deletion", nil, o) end
    bodies[s][k] = nil
    shownFor[s][k] = nil
end

local function bit(k)
    return math.floor(2 ^ (k - 1))
end

function clones.retired(s, k)
    return OF.util.has_flag(gone[s or 0] or 0, bit(k))
end

clones.GONE_ROW = "ofClonesGone"
clones.ROUNDS = 1000

local function gone_value(s)
    local row = gPlayerSyncTable ~= nil and gPlayerSyncTable[s] or nil
    local v = row ~= nil and tonumber(row[clones.GONE_ROW]) or 0
    v = math.floor(v or 0)
    if v < 0 then v = 0 end
    return v
end

local function split(v)
    return math.floor(v / 32), v % 32
end

local function publish_gone(v)
    if gPlayerSyncTable == nil or gPlayerSyncTable[0] == nil then return false end
    if gone_value(0) == v then return false end

    OF.util.publish_row(0, "ofClonesGone", v)
    return true
end

clones.puffs = 0
function clones.puff(s, x, y, z, sound)
    local bhv = id_bhvBlackSmokeUpward or id_bhvStarKeyCollectionPuffSpawner
    if bhv == nil or OF.slots == nil then return false end
    local made = OF.slots.spawn_non_sync(bhv, E_MODEL_NONE or 0, x, y + 40, z, nil)
    if made == nil then return false end
    clones.puffs = clones.puffs + 1
    local m = gMarioStates[s]
    local o = m ~= nil and m.marioObj or nil
    if sound ~= nil and o ~= nil and o.header ~= nil then
        OF.util.optional("play_sound", nil, sound, o.header.gfx.cameraToObject)
    end
    return true
end

local function retire_body(s, k, loud)
    local o = bodies[s][k]
    if loud and alive(o) and (shownFor[s][k] or 0) > 0 then
        clones.puff(s, o.oPosX, o.oPosY, o.oPosZ, SOUND_OBJ_DEFAULT_DEATH)
    end
    drop(s, k)
end

function clones.read_gone(s)
    local v = gone_value(s)
    if seenRow[s] == v then return false end
    local first = seenRow[s] == nil
    local round, set = split(v)
    if not first and round ~= seenRound[s] then
        for k in pairs(bodies[s]) do retire_body(s, k, true) end
        written[s] = 0
        arrived[s] = {}
    end
    for k = 1, clones.PER_MAX do
        if OF.util.has_flag(set, bit(k)) and not OF.util.has_flag(gone[s] or 0, bit(k)) then
            retire_body(s, k, not first)
        end
    end
    gone[s], seenRow[s], seenRound[s] = set, v, round
    return true
end

function clones.retire(k)
    if k == nil or k < 1 or k > clones.PER_MAX then return false end
    local round, set = split(gone_value(0))
    if OF.util.has_flag(set, bit(k)) then return false end
    publish_gone(round * 32 + set + bit(k))
    clones.read_gone(0)
    return true
end

function clones.start_over()
    local round = split(gone_value(0))
    publish_gone(((round + 1) % clones.ROUNDS) * 32)
    clones.read_gone(0)
    return true
end

function clones.forget(s)
    for k in pairs(bodies[s]) do drop(s, k) end
    written[s] = 0
    arrived[s] = {}
    gone[s] = 0
    seenRow[s], seenRound[s] = nil, nil
    if s == 0 then
        local round, set = split(gone_value(0))
        if set ~= 0 then publish_gone(round * 32) end
    end
end

function clones.clear()
    for s = 0, SEATS - 1 do clones.forget(s) end
    clones.light_back()
    return true
end

local function model_of(m)
    if m == nil or m.marioObj == nil then return nil end
    return OF.util.optional("obj_get_model_id_extended", nil, m.marioObj)
end

local function spawn(s, k, x, y, z)
    local m = gMarioStates[s]
    local np = gNetworkPlayers[s]
    local model = model_of(m)
    if model == nil or np == nil or OF.slots == nil then return nil end
    local gfx = m.marioObj.header.gfx
    local info = gfx.animInfo
    local root = info ~= nil and tonumber(info.animYTrans) or 0
    if root == nil or root == 0 then
        root = OF.replay ~= nil and OF.replay.ROOT_SCALE or 0xBD
    end
    rootOf[s] = root
    local scale = gfx.scale
    local global = np.globalIndex
    local o = OF.slots.spawn_non_sync(id_bhvStaticObject, model, x, y, z, function(o)
        o.globalPlayerIndex = global
        o.oBehParams = clones.MARK

        o.hookRender = 1
        o.oIntangibleTimer = -1
        o.oInteractType = 0
        o.oCollisionDistance = 0
        o.oAnimState = 0
        if o.header ~= nil then
            local to = o.header.gfx.scale
            to.x, to.y, to.z = clones.CLONE_SCALE, clones.CLONE_SCALE, clones.CLONE_SCALE
        end
    end)
    if o == nil then return nil end
    modelOf[s] = model
    bodies[s][k] = o
    shownFor[s][k] = 0
    return o
end

clones.JUMP = 600

local function pose(o, s, delay, k)
    local node = o.header.gfx.node
    local flags = tonumber(node.flags) or 0
    local x, y, z, pitch, yaw, roll, anim, frame = clones.at(s, delay)
    if x == nil then
        if not OF.util.has_flag(flags, INVISIBLE) then node.flags = flags + INVISIBLE end
        shownFor[s][k] = 0
        return false
    end
    if OF.util.has_flag(flags, INVISIBLE) then flags = flags - INVISIBLE end
    if OF.util.has_flag(flags, HAS_ANIMATION) then flags = flags - HAS_ANIMATION end
    node.flags = flags
    local dx, dy, dz = x - o.oPosX, y - o.oPosY, z - o.oPosZ
    if (shownFor[s][k] or 0) == 0
        or dx * dx + dy * dy + dz * dz > clones.JUMP * clones.JUMP then
        OF.util.optional("obj_skip_interpolation", nil, o)
    end
    o.oPosX, o.oPosY, o.oPosZ = x, y, z
    o.oFaceAnglePitch, o.oFaceAngleYaw, o.oFaceAngleRoll = pitch, yaw, roll
    o.oMoveAngleYaw = yaw
    local gfx = o.header.gfx

    local sc = gfx.scale
    if sc ~= nil then sc.x, sc.y, sc.z = clones.CLONE_SCALE, clones.CLONE_SCALE, clones.CLONE_SCALE end
    gfx.pos.x, gfx.pos.y, gfx.pos.z = x, y, z
    gfx.angle.x, gfx.angle.y, gfx.angle.z = pitch, yaw, roll
    local pointer = OF.util.asks(OF.replay, "anim_pointer") and OF.replay.anim_pointer(anim) or nil
    if pointer ~= nil then
        local info = gfx.animInfo
        info.curAnim = pointer
        info.animID = anim
        info.animAccel = 0
        info.animFrame = frame
        info.animYTrans = rootOf[s] or 0xBD
    end
    shownFor[s][k] = (shownFor[s][k] or 0) + 1
    return true
end

local function draw(s, count)
    local m = gMarioStates[s]
    local model = model_of(m)
    for k = 1, clones.PER_MAX do
        local o = bodies[s][k]
        if o ~= nil and not alive(o) then
            bodies[s][k], shownFor[s][k] = nil, nil
            o = nil
        end
        if k > count or clones.retired(s, k) then

            if o ~= nil then drop(s, k) end
        else
            local delay = clones.delay(k)
            if o == nil then

                local x, y, z = nil, nil, nil
                if clones.written(s) > clones.arrive(k) then
                    x, y, z = clones.at(s, delay)
                end
                if x ~= nil then
                    o = spawn(s, k, x, y, z)
                    if o ~= nil and not arrived[s][k] then
                        arrived[s][k] = true
                        clones.puff(s, x, y, z, SOUND_GENERAL_VANISH_SFX)
                    end
                end
            elseif model ~= nil and model ~= modelOf[s] and OF.slots ~= nil then

                OF.slots.set_model(o, model)
                modelOf[s] = model
            end
            if o ~= nil then pose(o, s, delay, k) end
        end
    end
end

local lit = {}

local function body_of(s)
    local m = s ~= nil and gMarioStates[s] or nil
    return m ~= nil and m.marioBodyState or nil
end

function clones.drawn_state(s, state)
    state = tonumber(state) or 0
    if s == 0 then return state end
    return state - state % 0x200 + 0x100 + clones.OTHERS_ALPHA
end

local function tint(s)
    local body = body_of(s)
    if body == nil or lit[s] ~= nil then return body ~= nil end
    lit[s] = { body.lightR, body.lightG, body.lightB, body.shadeR, body.shadeG, body.shadeB,
               body.modelState }
    body.lightR, body.lightG, body.lightB = clones.LIGHT[1], clones.LIGHT[2], clones.LIGHT[3]
    body.shadeR, body.shadeG, body.shadeB = clones.SHADE[1], clones.SHADE[2], clones.SHADE[3]
    body.modelState = clones.drawn_state(s, body.modelState)
    return true
end

local function untint(s)
    local was = lit[s]
    if was == nil then return false end
    lit[s] = nil
    local body = body_of(s)
    if body == nil then return false end
    if body.lightR == clones.LIGHT[1] and body.lightG == clones.LIGHT[2]
        and body.lightB == clones.LIGHT[3] and body.shadeR == clones.SHADE[1]
        and body.shadeG == clones.SHADE[2] and body.shadeB == clones.SHADE[3] then
        body.lightR, body.lightG, body.lightB = was[1], was[2], was[3]
        body.shadeR, body.shadeG, body.shadeB = was[4], was[5], was[6]
    end

    if was[7] ~= nil and body.modelState == clones.drawn_state(s, was[7]) then
        body.modelState = was[7]
    end
    return true
end

function clones.light_back()
    for s in pairs(lit) do untint(s) end
end

function clones.on_render(o)

    if o == nil or o.globalPlayerIndex == nil then return false end
    local s = OF.util.local_from_global(o.globalPlayerIndex)
    if s == nil then return false end
    if o.oBehParams == clones.MARK then return tint(s) end
    untint(s)
    return false
end

local hitAt = -9999

local function frame_now()
    return OF.util.optional("get_global_timer", 0) or 0
end

local function has(value, flag)
    return flag ~= nil and OF.util.has_flag(value or 0, flag)
end

function clones.vulnerable(m)
    if m == nil or (m.health or 0) < 0x100 then return false end
    if (tonumber(m.invincTimer) or 0) > 0 then return false end
    if frame_now() - hitAt < clones.COOLDOWN then return false end
    local action = m.action or 0
    if has(action, ACT_FLAG_INTANGIBLE) or has(action, ACT_FLAG_INVULNERABLE) then
        return false
    end
    if OF.ragdoll ~= nil and OF.ragdoll.ACTION ~= nil and action == OF.ragdoll.ACTION then
        return false
    end
    return true
end

function clones.touch(m)
    m = m or gMarioStates[0]
    if m == nil or not clones.has(0) or not clones.vulnerable(m) then return nil end

    for k = 1, clones.PER_MAX do
        local o = bodies[0][k]
        if alive(o) and (shownFor[0][k] or 0) > clones.ARM and not clones.retired(0, k) then
            local dx, dz = o.oPosX - m.pos.x, o.oPosZ - m.pos.z
            local dy = o.oPosY - m.pos.y
            if dx * dx + dz * dz < clones.REACH * clones.REACH
                and dy > -clones.ABOVE and dy < clones.BELOW then
                return o, k
            end
        end
    end
    return nil
end

function clones.hit(m, o, k)
    local touch = clones.opt("touch")
    if touch == clones.TOUCH_DIES or touch == clones.TOUCH_RESETS then
        hitAt = frame_now()
        if k ~= nil then clones.retire(k) end
        if touch == clones.TOUCH_DIES then

            m.hurtCounter = 31
        elseif OF.util.asks(OF.net, "reload_here") then
            local sent, why = OF.net.reload_here()
            if not sent and why ~= nil and OF.util.asks(OF.notify, "show") then
                OF.notify.show(why, "info", 4)
            end
        end
        if CHAR_SOUND_ATTACKED ~= nil then
            OF.util.optional("play_character_sound", nil, m, CHAR_SOUND_ATTACKED)
        end
        return true
    end
    local cost = clones.COST[touch] or 1
    o.oDamageOrCoinValue = cost
    o.oInteractionSubtype = 0
    hitAt = frame_now()
    local done = OF.util.optional("take_damage_and_knock_back", 0, m, o)

    if k ~= nil then clones.retire(k) end
    if done ~= nil and done ~= 0 and done ~= false then return true end

    if not has(m.flags, MARIO_METAL_CAP) then
        m.hurtCounter = (m.hurtCounter or 0) + 4 * cost
    end
    local air = has(m.action, ACT_FLAG_AIR)
    m.faceAngle.y = OF.util.optional("obj_angle_to_object", m.faceAngle.y, m.marioObj, o)
        or m.faceAngle.y
    m.forwardVel = -16
    local knock = air and ACT_BACKWARD_AIR_KB or ACT_BACKWARD_GROUND_KB
    if knock ~= nil then OF.util.optional("set_mario_action", nil, m, knock, cost) end
    if CHAR_SOUND_ATTACKED ~= nil then
        OF.util.optional("play_character_sound", nil, m, CHAR_SOUND_ATTACKED)
    end
    return true
end

function clones.chasing(s)
    s = s or 0
    local n = 0
    for k = 1, clones.PER_MAX do
        local o = bodies[s][k]
        if alive(o) and (shownFor[s][k] or 0) > 0 and not clones.retired(s, k) then
            n = n + 1
        end
    end
    return n
end

function clones.star_keeps_you(o)
    if o ~= nil and has(tonumber(o.oInteractionSubtype) or 0, INT_SUBTYPE_NO_EXIT or 0x400) then
        return true
    end
    local level = gNetworkPlayers[0] ~= nil and gNetworkPlayers[0].currLevelNum or nil
    if level == (LEVEL_BOWSER_1 or 30) or level == (LEVEL_BOWSER_2 or 33)
        or level == (LEVEL_BOWSER_3 or 34) then
        return false
    end
    local settings = gServerSettings
    return settings ~= nil and (tonumber(settings.stayInLevelAfterStar) or 0) ~= 0
end

local owed = nil

function clones.star_back()
    local one = owed
    owed = nil
    if one == nil then return false end
    local m = gMarioStates[0]
    if m == nil then return false end
    m.numCoins = math.max(0, (m.numCoins or 0) - one)
    return true
end

function clones.star_allow(m, o, interactType)
    clones.star_back()
    if interactType ~= INTERACT_STAR_OR_KEY then return end

    if m == nil or m.playerIndex ~= 0 or (m.health or 0) < 0x100 then return end
    if not clones.has(0) then return end
    local pay = clones.chasing(0) * clones.CLONE_COINS
    if pay <= 0 or clones.star_keeps_you(o) then return end
    local was = m.numCoins or 0
    m.numCoins = math.min(clones.COIN_CAP, was + pay)
    owed = m.numCoins - was
end

function clones.star_taken(m, o, interactType, interacted)
    local paid = owed
    owed = nil
    if interactType ~= INTERACT_STAR_OR_KEY then
        if paid ~= nil then owed = paid; clones.star_back() end
        return
    end
    if m == nil or m.playerIndex ~= 0 then return end
    if interacted ~= true then
        if paid ~= nil then owed = paid; clones.star_back() end
        return
    end
    if not clones.has(0) then return end
    local chasing = clones.chasing(0)
    if paid == nil and chasing > 0 and clones.star_keeps_you(o) then
        clones.drop_coins(m, chasing * clones.CLONE_COINS)
    end
    if chasing > 0 or next(bodies[0]) ~= nil then clones.start_over() end
end

function clones.drop_coins(m, n)
    if m == nil or m.pos == nil or OF.slots == nil then return 0 end
    local bhv, model = id_bhvSingleCoinGetsSpawned, E_MODEL_YELLOW_COIN
    if bhv == nil or model == nil then return 0 end
    local made = 0
    for _ = 1, math.min(n or 0, clones.CLONE_COINS * clones.PER_MAX) do
        if OF.slots.spawn_non_sync(bhv, model, m.pos.x, m.pos.y + 60, m.pos.z, nil) ~= nil then
            made = made + 1
        end
    end
    return made
end

local roomWas = nil

local function room_key()
    local me = gNetworkPlayers[0]
    if me == nil then return nil end
    return tostring(me.currLevelNum) .. "/" .. tostring(me.currAreaIndex) .. "/"
        .. tostring(me.currActNum)
end

local seatRoom = {}

function clones.update()

    clones.light_back()
    clones.star_back()
    clones.publish_wish()
    local room = room_key()
    if room ~= roomWas then

        roomWas = room
        clones.clear()
    end
    local per = clones.per_player()
    for s = 0, SEATS - 1 do
        if clones.has(s) then
            local np = gNetworkPlayers[s]
            local here = tostring(np.currLevelNum) .. "/" .. tostring(np.currAreaIndex)
            if seatRoom[s] ~= here then
                clones.forget(s)
                seatRoom[s] = here
            end
            clones.read_gone(s)
            record(s)

            local row = gPlayerSyncTable[s]
            if (row ~= nil and row.ofPicking == true)
                or (gPlayerSyncTable[0] ~= nil and gPlayerSyncTable[0].ofPicking == true) then
                draw(s, 0)
            else
                draw(s, per)
            end
        elseif written[s] ~= 0 or next(bodies[s]) ~= nil then
            clones.forget(s)
            seatRoom[s] = nil
        end
    end
    local m = gMarioStates[0]
    local o, k = clones.touch(m)
    if o ~= nil then clones.hit(m, o, k) end
end

function clones.count_name()
    local row = clones.OPTS[1]
    return OF.lang.fill("@ each", OF.lang.t(row.steps[clones.opt("count")]))
end

function clones.note()
    local n = 0
    for s = 0, SEATS - 1 do
        for _ in pairs(bodies[s]) do n = n + 1 end
    end
    if n == 0 then return nil end
    return OF.lang.fill("@ out", tostring(n))
end

function clones.build_page(panel)
    local rows = {}
    local modifiers = OF.modifiers
    table.insert(rows, panel.label_row(OF.lang.t(
        "Dark copies run your path behind you - keep moving.")))
    local entry = modifiers ~= nil and modifiers.BY_KEY[clones.KEY] or nil
    if entry ~= nil then table.insert(rows, modifiers.two_box_row(panel, entry)) end
    table.insert(rows, panel.with_help(panel.gated_confirm_row(rank(),
        "clonesreset", OF.lang.t("Reset this page"), 200, 200, 200,
        function() OF.util.report(clones.reset_opts()) end),
        OF.lang.t("every setting below, back to where it starts")))
    if modifiers ~= nil and modifiers.round_holds() then
        table.insert(rows, panel.label_row(
            OF.lang.t("A round has these - the settings come back after it.")))
    end
    table.insert(rows, panel.with_help(panel.header_row(OF.lang.t("How they follow")),
        OF.lang.t("how many, how far behind, the touch, and where")))
    for _, row in ipairs(clones.OPTS) do
        local key = row.key
        local step = clones.opt(key)
        local built = panel.gated_row(rank(), OF.lang.t(row.name), 255, 255, 255,
            function()
                OF.util.report(clones.set_opt(key, step % #row.steps + 1))
            end)
        built = panel.with_right(built, OF.lang.t(row.steps[step]))
        if panel.may(rank()) then
            built = panel.with_slider(built, step - 1, #row.steps - 1, function(wanted)
                OF.util.report(clones.set_opt(key, wanted + 1))
            end)
        else
            built = panel.with_slider(built, step - 1, #row.steps - 1, nil)
        end
        table.insert(rows, panel.with_help(built, OF.lang.t(row.help)))
    end
    table.insert(rows, panel.back_row())
    return rows
end

hook_event(HOOK_ON_MODS_LOADED, function()
    if OF.util.asks(OF.net, "register_action") then
        OF.net.register_action(clones.OPTS_ACTION, rank(),
            function(fromLocal, x, _, z)
                if not OF.util.is_host() then return false, "Only the host." end
                if tostring(z) == "reset" then return clones.reset_opts(fromLocal) end
                return clones.set_opt(tostring(z), tonumber(x), fromLocal)
            end)
    end
    local panel = OF.panel
    if panel ~= nil and type(panel.PAGES) == "table" and panel.PAGES.clones == nil then
        panel.PAGES.clones = {
            title = "Cosmic Clones", tab = "room", up = "chance",
            build = function() return clones.build_page(panel) end,
        }
    end
end)

hook_event(HOOK_UPDATE, clones.update)
hook_event(HOOK_ON_OBJECT_RENDER, clones.on_render)
hook_event(HOOK_ALLOW_INTERACT, clones.star_allow)
hook_event(HOOK_ON_INTERACT, clones.star_taken)

function clones.ready()
    return true
end
