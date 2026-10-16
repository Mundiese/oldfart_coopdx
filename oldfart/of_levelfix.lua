OF = OF or {}
OF.levelfix = OF.levelfix or {}

local levelfix = OF.levelfix

local function at_load(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if not ok then return nil end
    return result
end

levelfix.DDD_PARTS = {
    { id = id_bhvBowsersSub,    what = "the submarine" },
    { id = id_bhvBowserSubDoor, what = "the sub door" },
}

local function ddd_keep(o)
    if o == nil then return false end
    if o.activeFlags ~= 0 then return false end
    o.activeFlags = ACTIVE_FLAG_ACTIVE
    return true
end

levelfix.dddKept = 0

local function ddd_loop(o)
    if ddd_keep(o) then levelfix.dddKept = levelfix.dddKept + 1 end
end

local ddd_init = ddd_loop

levelfix.ddd_init = ddd_init
levelfix.ddd_loop = ddd_loop

local CANNON_CLOSED = 0

function levelfix.cannons_sealed()
    local arena = OF.arena
    if arena == nil or arena.option_on == nil then return false end
    local ok, on = pcall(arena.option_on, "cannons")
    return ok and on == true
end

local function cannon_lid_init(o)
    if o == nil then return end
    if not levelfix.cannons_sealed() then return end

    if o.activeFlags == 0 then

        o.activeFlags = ACTIVE_FLAG_ACTIVE
        local gfx = o.header ~= nil and o.header.gfx or nil
        local node = gfx ~= nil and gfx.node or nil
        if node ~= nil and type(node.flags) == "number" then
            node.flags = node.flags | GRAPH_RENDER_ACTIVE
        end
    end
    o.oAction = CANNON_CLOSED
end

local function cannon_lid_loop(o)
    if o == nil then return end
    if not levelfix.cannons_sealed() then return end
    if o.oAction ~= CANNON_CLOSED then o.oAction = CANNON_CLOSED end
end

levelfix.cannon_lid_init = cannon_lid_init
levelfix.cannon_lid_loop = cannon_lid_loop

local CANNON_SECS = 5
local CANNON_HOLD = CANNON_SECS * 30

local IN_CANNON = ACT_IN_CANNON or 0x00001371
local A_PRESS = A_BUTTON or 0x8000

local CANNON_AIMING = 2

levelfix.cannonFrames = 0

levelfix.cannonShots = 0

function levelfix.cannon_frames()
    return levelfix.cannonFrames
end

function levelfix.cannon_left()
    if levelfix.cannonFrames <= 0 then return nil end
    local left = CANNON_HOLD - levelfix.cannonFrames
    if left < 0 then left = 0 end
    return math.ceil(left / 30)
end

local function auto_fire_wanted()
    local util = OF.util
    if util == nil then return false end
    if util.asks(OF.lockdown, "round_or_run") and OF.lockdown.round_or_run() then
        return true
    end
    if not util.asks(OF.rules, "value") then return false end
    return (OF.rules.value("cannonfire") or 0) == 1
end

local function cannon_update(m)

    if m == nil or m.playerIndex ~= 0 then return end

    if m.action ~= IN_CANNON or m.usedObj == nil then
        levelfix.cannonFrames = 0
        return
    end

    local util = OF.util
    if util == nil then
        levelfix.cannonFrames = 0
        return
    end

    if not auto_fire_wanted() then
        levelfix.cannonFrames = 0
        return
    end

    if levelfix.cannons_sealed() then
        levelfix.cannonFrames = 0
        return
    end

    if not util.can_play(0) then
        levelfix.cannonFrames = 0
        return
    end

    if m.actionState ~= CANNON_AIMING then return end

    levelfix.cannonFrames = levelfix.cannonFrames + 1
    if levelfix.cannonFrames < CANNON_HOLD then return end

    local pad = m.controller
    if pad == nil then return end

    if not util.has_flag(pad.buttonPressed or 0, A_PRESS) then
        pad.buttonPressed = (pad.buttonPressed or 0) + A_PRESS
        levelfix.cannonShots = levelfix.cannonShots + 1

        if util.asks(OF.notify, "show") then
            OF.notify.show("Out you go - nobody camps in a cannon", "warn", 4)
        end
    end
end

levelfix.cannon_update = cannon_update

local CANNON_HUD_SCALE = 0.9

local function render_cannon()
    if OF.util == nil then return end

    if OF.util.menu_has_screen() then return end

    local left = levelfix.cannon_left()
    if left == nil then return end

    if type(OF.util.banner_low) ~= "function" then return end

    local text = OF.lang.fill("Firing in @s", tostring(left))
    OF.util.banner_low(text, CANNON_HUD_SCALE, 255, 210, 140, 255)
end

levelfix.render_cannon = render_cannon

local CANNON_YAW_WALL = 0x4000

local CANNONS_ALL_ROUND = 2

local TURN = 0x10000

local function wrap_s16(value)
    return ((value + 0x8000) % TURN) - 0x8000
end

levelfix.cannonTurns = 0
levelfix.cannonWalled = 0

local function turn_all_round_wanted()
    local util = OF.util
    if util == nil then return false end
    if not util.asks(OF.rules, "value") then return false end
    return (OF.rules.value("cannons") or 0) == CANNONS_ALL_ROUND
end

levelfix.turn_all_round_wanted = turn_all_round_wanted

local function cannon_turn(m)

    if m == nil or m.action ~= IN_CANNON or m.usedObj == nil then return end

    if m.actionState ~= CANNON_AIMING then return end

    local body = m.marioObj
    if body == nil then return end

    local input = tonumber(body.oMarioCannonInputYaw) or 0

    if input >= CANNON_YAW_WALL or input <= -CANNON_YAW_WALL then
        levelfix.cannonWalled = levelfix.cannonWalled + 1
    end

    if not turn_all_round_wanted() then return end
    if input == 0 then return end

    local base = tonumber(body.oMarioCannonObjectYaw) or 0
    body.oMarioCannonObjectYaw = wrap_s16(base + input)
    body.oMarioCannonInputYaw = 0
    levelfix.cannonTurns = levelfix.cannonTurns + 1
end

levelfix.cannon_turn = cannon_turn

levelfix.bodiesKept = 0

function levelfix.keep_bodies()

    local states = gMarioStates
    if states == nil then return 0 end
    local put = 0
    for index = 0, MAX_PLAYERS - 1 do
        local m = states[index]
        local body = m ~= nil and m.marioObj or nil
        if body ~= nil and body.activeFlags == 0 then
            body.activeFlags = ACTIVE_FLAG_ACTIVE
            levelfix.bodiesKept = levelfix.bodiesKept + 1
            put = put + 1
        end
    end
    return put
end

local CHOMP_TRIGGER = 1
local CHOMP_LUNGE = 2
local ON_GROUND = 3

local function text_taken()
    local lockdown = OF.lockdown
    return lockdown ~= nil and type(lockdown.text_is_taken) == "function"
        and lockdown.text_is_taken() == true
end

local function chomp_loop(o)
    if o == nil then return false end
    local trigger = CHAIN_CHOMP_RELEASED_TRIGGER_CUTSCENE or CHOMP_TRIGGER
    if o.oChainChompReleaseStatus ~= trigger then return false end
    if ((o.oMoveFlags or 0) & (OBJ_MOVE_MASK_ON_GROUND or ON_GROUND)) == 0 then return false end
    if not text_taken() then return false end
    o.oChainChompReleaseStatus = CHAIN_CHOMP_RELEASED_LUNGE_AROUND or CHOMP_LUNGE
    o.oTimer = 0
    levelfix.chompsFreed = levelfix.chompsFreed + 1
    return true
end
levelfix.chompsFreed = 0
levelfix.chomp_loop = chomp_loop

levelfix.LIFT_REACH = 1000
levelfix.liftsCalled = 0

local function lift_loop(o)
    if o == nil or o.oAction ~= 0 then return false end
    if (o.oElevatorUnk100 or 0) == 2 then return false end
    local bottom, middle = o.oElevatorUnkF4, o.oElevatorUnkFC
    if type(bottom) ~= "number" or type(middle) ~= "number" then return false end
    if o.oPosY <= bottom then return false end
    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    if m == nil or m.pos == nil or m.marioObj == nil then return false end
    if m.pos.y >= middle then return false end
    local dx, dy, dz = m.pos.x - o.oPosX, m.pos.y - bottom, m.pos.z - o.oPosZ
    if dx * dx + dy * dy + dz * dz > levelfix.LIFT_REACH * levelfix.LIFT_REACH then return false end
    o.oAction = 2
    at_load("network_send_object", o, false)
    levelfix.liftsCalled = levelfix.liftsCalled + 1
    return true
end
levelfix.lift_loop = lift_loop

levelfix.HOOKS = {
    { id = id_bhvBowsersSub,    list = OBJ_LIST_SURFACE, replace = false,
      init = ddd_init,          loop = ddd_loop,
      why = "the DDD submarine, which the save flags delete" },
    { id = id_bhvBowserSubDoor, list = OBJ_LIST_SURFACE, replace = false,
      init = ddd_init,          loop = ddd_loop,
      why = "the DDD sub door, which goes with it" },
    { id = id_bhvCannonClosed,  list = OBJ_LIST_SURFACE, replace = false,
      init = cannon_lid_init,   loop = cannon_lid_loop,
      why = "the cannon lid, which is the floor over the shaft" },
    { id = id_bhvChainChomp,    list = OBJ_LIST_GENACTOR, replace = false,
      init = nil,               loop = chomp_loop,
      why = "the Chain Chomp, which waited for a dialog a round never lets open" },
    { id = id_bhvHmcElevatorPlatform, list = OBJ_LIST_SURFACE, replace = false,
      init = nil,               loop = lift_loop,
      why = "Hazy Maze Cave's lift, which stayed up for a player below" },
    { id = id_bhvMeshElevator,  list = OBJ_LIST_SURFACE, replace = false,
      init = nil,               loop = lift_loop,
      why = "the mesh lift, the same" },
}

levelfix.installed = {}

for _, entry in ipairs(levelfix.HOOKS) do
    if entry.id ~= nil then
        if at_load("hook_behavior", entry.id, entry.list, entry.replace,
                   entry.init, entry.loop) ~= nil then
            table.insert(levelfix.installed, entry.why)
        end
    end
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, cannon_update, OF.LOCAL_MARIO)

hook_event(HOOK_BEFORE_MARIO_UPDATE, cannon_turn)

hook_event(HOOK_BEFORE_MARIO_UPDATE, function()
    levelfix.keep_bodies()
end)
hook_event(HOOK_ON_HUD_RENDER, render_cannon)

function levelfix.count()
    return #levelfix.installed
end
