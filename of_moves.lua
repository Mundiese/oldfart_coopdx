OF = OF or {}
OF.moves = OF.moves or {}

local moves = OF.moves

moves.KEY = "ofMove"
moves.PACKET = "move"
local function at_load(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then
        moves.missing = moves.missing or {}
        moves.missing[name] = true
        return nil
    end
    local ok, result = pcall(fn, ...)
    if not ok then return nil end
    return result
end

local ROLL_HELD_DRAG = 0.5
local ROLL_HELD_FRAMES = 1.5

local ROLL_STEPS = {
    { name = "B still punches" },
    { name = "a quick tuck",           frames = 24,  speed = 30, drag = 0.90 },
    { name = "a proper roll",          frames = 45,  speed = 40, drag = 0.45 },
    { name = "a long roll",            frames = 80,  speed = 48, drag = 0.22 },
    { name = "a roll across the room", frames = 150, speed = 56, drag = 0.12 },
}

local INTO_STEPS = {
    { name = "the button only",             lands = {} },
    { name = "and when a dive lands",       lands = { "ACT_DIVE_SLIDE" } },
    { name = "and out of a long jump",      lands = { "ACT_DIVE_SLIDE",
                                                      "ACT_LONG_JUMP_LAND" } },

    { name = "and out of a plain fall",     lands = { "ACT_DIVE_SLIDE",
                                                      "ACT_LONG_JUMP_LAND",
                                                      "ACT_FREEFALL_LAND" } },

    { name = "and out of a ground pound",   lands = { "ACT_DIVE_SLIDE",
                                                      "ACT_LONG_JUMP_LAND",
                                                      "ACT_FREEFALL_LAND",
                                                      "ACT_GROUND_POUND_LAND" } },
}

local SPIN_STEPS = {
    { name = "B is still a kick" },
    { name = "a flick, still falling",   frames = 12, fall = -8 },
    { name = "a spin that slows you",    frames = 22, fall = -4 },
    { name = "a spin that nearly hangs", frames = 32, fall = -1 },
    { name = "a spin that lifts you",    frames = 32, fall = 6 },
}

local POUND_STEPS = {
    { name = "A does nothing" },
    { name = "a hop",               lift = 30 },
    { name = "a jump",              lift = 52 },
    { name = "a high jump",         lift = 74 },
    { name = "clear over the roof", lift = 100 },
}

local DIVE_STEPS = {
    { name = "B does nothing" },
    { name = "a short dive",           speed = 24 },
    { name = "a proper dive",          speed = 36 },
    { name = "a long dive",            speed = 48 },
    { name = "a dive across the room", speed = 64 },
}

local WALL_STEPS = {
    { name = "the engine's own kick" },
    { name = "a little more",         lift = 8,  push = 4 },
    { name = "a good shove",          lift = 16, push = 10 },
    { name = "a launch",              lift = 26, push = 18 },
    { name = "off the wall and gone", lift = 40, push = 28 },
}

local WINDUP_STEPS = {
    { name = "a plain backflip" },
    { name = "a little spring", full = 30, lift = 16 },
    { name = "a good spring",   full = 45, lift = 30 },
    { name = "a big spring",    full = 60, lift = 48 },
    { name = "worth the wait",  full = 90, lift = 76 },
}

moves.ROWS = {
    { key = "roll",   id = "rl", name = "Ground roll",
      help = "Z and B, aimed with the stick - hold Z for longer, A jumps out",
      steps = ROLL_STEPS,   plain = 1 },
    { key = "into",   id = "in", name = "Ways into the roll",
      help = "hold Z through a landing and it becomes a roll",
      steps = INTO_STEPS,   plain = 1 },
    { key = "spin",   id = "sp", name = "Air spin",
      help = "B in the air with no speed - the jump kick becomes a spin",
      steps = SPIN_STEPS,   plain = 1 },
    { key = "pound",  id = "pb", name = "Bounce out of a ground pound",
      help = "A as the pound lands - the game does nothing with that press",
      steps = POUND_STEPS,  plain = 1 },
    { key = "wall",   id = "wk", name = "Kick off a wall harder",
      help = "added to the engine's own kick, however you got into it",
      steps = WALL_STEPS,   plain = 1 },
    { key = "windup", id = "wu", name = "Wind-up jump",
      help = "stay crouched, then A - the backflip is worth what you waited",
      steps = WINDUP_STEPS, plain = 1 },

    { key = "dive",   id = "pd", name = "Dive out of a ground pound",
      help = "B while pounding, before it lands - the pound's own follow-up",
      steps = DIVE_STEPS,   plain = 1 },
}

moves.BY_KEY = {}
for _, row in ipairs(moves.ROWS) do moves.BY_KEY[row.key] = row end

local function build_into()
    for _, step in ipairs(INTO_STEPS) do
        step.into = {}
        for _, name in ipairs(step.lands or {}) do
            local id = _G[name]
            if type(id) == "number" then step.into[id] = true end
        end
    end
end
build_into()

local function parse()
    local text = gGlobalSyncTable[moves.KEY]
    local set = {}
    if type(text) ~= "string" then return set end
    for id, step in string.gmatch(text, "(%a%a):(%d+)") do
        set[id] = tonumber(step)
    end
    return set
end

local function pack(set)
    local parts = {}
    for _, row in ipairs(moves.ROWS) do
        local step = set[row.key]
        if step ~= nil and step ~= row.plain then
            table.insert(parts, row.id .. ":" .. tostring(step))
        end
    end
    return table.concat(parts, ",")
end

function moves.wire_width()
    local set = {}
    for _, row in ipairs(moves.ROWS) do set[row.key] = #row.steps end
    return #pack(set)
end

function moves.wanted_step(key)
    local row = moves.BY_KEY[key]
    if row == nil then return 1 end
    local step = parse()[row.id]
    if type(step) ~= "number" then return row.plain end
    step = math.floor(step)
    if step < 1 then return 1 end
    if step > #row.steps then return #row.steps end
    return step
end

local MINE_NEED = "modifier_self"
moves.mine = moves.mine or {}
moves.mineStep = moves.mineStep or {}

local function first_on(row)
    local step = row.plain + 1
    if step > #row.steps then step = #row.steps end
    return step
end

function moves.mine_step(key)
    local row = moves.BY_KEY[key]
    if row == nil then return 1 end
    local step = moves.mineStep[key]
    if type(step) ~= "number" then return first_on(row) end
    return OF.util.clamp(math.floor(step), 1, #row.steps)
end

function moves.mine_state(key)
    local row = moves.BY_KEY[key]
    if row == nil then return nil end
    local held = moves.mine[key]
    if held == nil then return nil end
    local roomStep = moves.wanted_step(key)
    if held == false then

        if roomStep == row.plain then return nil end
        return false
    end
    if moves.mine_step(key) == roomStep then return nil end
    return true
end

function moves.mine_any()
    for key in pairs(moves.mine) do
        if moves.mine_state(key) ~= nil then return true end
    end
    return false
end

function moves.settle_mine(key)
    if moves.mine_state(key) == nil then
        moves.mine[key] = nil
        moves.mineStep[key] = nil
    end
end

function moves.set_mine(key, state)
    local row = moves.BY_KEY[key]
    if row == nil then return false, OF.lang.t("No such row.") end
    if state == nil then
        moves.mine[key] = nil
        moves.mineStep[key] = nil
        return true
    end
    moves.mine[key] = state == true
    if state == true and moves.mineStep[key] == nil then
        moves.mineStep[key] = first_on(row)
    end
    moves.settle_mine(key)
    return true
end

function moves.set_mine_step(key, step)
    local row = moves.BY_KEY[key]
    if row == nil then return false, OF.lang.t("No such row.") end
    if type(step) ~= "number" then
        return false, OF.lang.t("That is not a setting.")
    end
    step = math.floor(step)
    if step <= row.plain then return moves.set_mine(key, false) end
    if step > #row.steps then
        return false, OF.lang.t("That row does not go that far.")
    end
    moves.mine[key] = true
    moves.mineStep[key] = step

    moves.settle_mine(key)
    return true
end

function moves.clear_mine()
    moves.mine = {}
    moves.mineStep = {}
    return true
end

function moves.clear_mine_press()
    if not moves.mine_any() then
        return false, OF.lang.t("You have chosen no moves of your own.")
    end
    return moves.clear_mine()
end

function moves.round_holds()
    if not OF.util.asks(OF.lockdown, "menu_stands_down") then return false end
    return OF.lockdown.menu_stands_down() == true
end

function moves.in_force(key, ignoreRound)
    local row = moves.BY_KEY[key]
    if row == nil then return 1, false end
    if not ignoreRound and moves.round_holds() then return row.plain, false end

    local state = moves.mine_state(key)
    if state == true then return moves.mine_step(key), true end

    if state == false then return row.plain, true end
    return moves.wanted_step(key), false
end

function moves.step(key)
    return (moves.in_force(key))
end

function moves.step_is_yours(key)
    local _, mine = moves.in_force(key)
    return mine
end

function moves.suspended(key)
    if not moves.round_holds() then return false end
    local row = moves.BY_KEY[key]
    if row == nil then return false end
    return (moves.in_force(key, true)) ~= row.plain
end

function moves.lobby_step(key)
    local row = moves.BY_KEY[key]
    if row == nil then return 1 end
    if moves.round_holds() then return row.plain end
    return moves.wanted_step(key)
end

function moves.step_for(m, key)
    if m ~= nil and m.playerIndex ~= 0 then return moves.lobby_step(key) end
    return moves.step(key)
end

function moves.stop_for(m, key)
    local row = moves.BY_KEY[key]
    if row == nil then return nil end
    return row.steps[moves.step_for(m, key)]
end

function moves.stop(key)
    local row = moves.BY_KEY[key]
    if row == nil then return nil end
    return row.steps[moves.step(key)]
end

function moves.stop_name(key)
    local stop = moves.stop(key)
    return stop ~= nil and stop.name or "?"
end

function moves.setting(key, field)
    local stop = moves.stop(key)
    if stop == nil then return nil end
    return stop[field]
end

function moves.anything_on()
    for _, row in ipairs(moves.ROWS) do
        if moves.lobby_step(row.key) ~= row.plain then return true end
    end
    return false
end

function moves.quiet()
    if moves.mine_any() then return false end
    local wire = gGlobalSyncTable[moves.KEY]
    return type(wire) ~= "string" or wire == ""
end

function moves.label()
    local said = {}
    for _, row in ipairs(moves.ROWS) do
        local step = moves.lobby_step(row.key)
        if step ~= row.plain then
            table.insert(said, row.name .. ": " .. row.steps[step].name)
        end
    end
    if #said == 0 then return OF.lang.t("the moves the game shipped with") end
    return table.concat(said, ", ")
end

function moves.set_step(key, step, quiet, askerLocal)
    if not OF.util.is_host() then
        return false, OF.lang.t("Only the host sets what the moves are.")
    end

    local row = moves.BY_KEY[key]
    if row == nil then return false, OF.lang.t("No such row.") end

    step = math.floor(tonumber(step) or row.plain)
    if step < 1 then step = 1 end
    if step > #row.steps then step = #row.steps end

    local wasName = row.steps[moves.wanted_step(key)] ~= nil
        and row.steps[moves.wanted_step(key)].name or nil

    local set = {}
    for _, other in ipairs(moves.ROWS) do
        set[other.key] = moves.wanted_step(other.key)
    end
    set[key] = step

    if not OF.util.publish(moves.KEY, pack(set)) then
        return false, OF.lang.t("That is too much to send to the lobby at once.")
    end

    if not quiet then

        local said = row.name .. ": " .. row.steps[step].name
        local who = OF.util.presser(askerLocal)
        if who == nil then

            OF.notify.send_all("@ - @", "info", 4,
                row.name, row.steps[step].name)
        else
            OF.notify.send_all("@ set @", "info", 4, who, said)
            OF.actionlog.by_hand(who, OF.lang.fill("set the moves: @", said),
                wasName, row.steps[step].name)
        end
    end
    return true
end

function moves.next_step(key)
    local row = moves.BY_KEY[key]
    if row == nil then return false, OF.lang.t("No such row.") end
    local step = moves.wanted_step(key) + 1
    if step > #row.steps then step = 1 end

    return moves.set_step(key, step, false, 0)
end

function moves.clear(askerLocal)
    if not OF.util.is_host() then
        return false, OF.lang.t("Only the host sets what the moves are.")
    end
    if not moves.anything_on() then
        return false, OF.lang.t("Nobody has any extra moves.")
    end

    local wasLabel = moves.label()
    if not OF.util.publish(moves.KEY, "") then
        return false, OF.lang.t("That is too much to send to the lobby at once.")
    end
    local who = OF.util.presser(askerLocal)
    if who == nil then
        OF.notify.send_all("The moves are the game's own again", "info", 4)
    else
        OF.notify.send_all("@ put the moves back to the game's own",
            "info", 4, who)
        OF.actionlog.by_hand(who,
            OF.lang.t("put the moves back to the game's own"), wasLabel, nil)
    end
    return true
end

function moves.text()
    local wire = gGlobalSyncTable[moves.KEY]
    if type(wire) ~= "string" then return "" end
    return wire
end

function moves.put_text(text)
    if not OF.util.is_host() then return false end
    text = tostring(text or "")
    if moves.text() == text then return false end
    return OF.util.publish(moves.KEY, text) == true
end

local BALL_VALUES = {
    0x0000, 0x00BD, 0x00F2, 0x0127, 0x00F2, 0x00BD, 0x0088, 0x0053, 0x0088,
    0xFF96, 0xFFCB, 0x0000, 0x0035, 0x006A, 0x0035, 0x0000, 0xFFCB, 0x0000,
    0x3FFF, 0x4000, 0x4001, 0x8019, 0xC00F, 0xC010, 0xC011, 0x3FFF, 0x2000,
    0xFFFF, 0xDFFF, 0xC000, 0xDFFF, 0x0000, 0x2000, 0x0000, 0x3FFE, 0x3FFF,
    0x3FFE, 0xFFF5, 0xC001, 0xC000, 0xC001, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF,
    0x0000, 0xFFFF, 0x0000, 0x0000, 0xFFFF, 0x40A1, 0xFFFF, 0xFFFE, 0x24B2,
    0xFFFF, 0xFFFE, 0x2910, 0xFFFE, 0x0001, 0xC170, 0x0B72, 0xF361, 0x9657,
    0x03DF, 0xF80A, 0xCC89, 0xFD4B, 0xF1AE, 0xD6F2, 0xFFFE, 0x0001, 0xC170,
    0xFA6C, 0x0D54, 0x965C, 0x009F, 0x04F0, 0xCF84, 0x05B7, 0x0663, 0xD414,
    0x0000, 0xFFFF, 0xFFFF, 0x0000, 0xFFFF, 0x0000, 0xFFFF, 0x0000, 0xFFFF,
    0x0000, 0x0000, 0xFFFF, 0xFFFF, 0xFFFF, 0x0000, 0xFFFF, 0xBF5E, 0x01A3,
    0xF9BA, 0x778B, 0x0005, 0x009F, 0x48B2, 0x00C2, 0xFF36, 0xB37D, 0x0000,
    0xFFFF, 0xFFFF, 0x0000, 0xFFFF, 0x0000, 0xFFFF, 0x0000, 0xFFFF, 0x0000,
    0x0000, 0xFFFF, 0xFFFF, 0xFFFF, 0x0000, 0xFFFF, 0xBF5E, 0xFD73, 0x05D4,
    0x770D, 0xFF49, 0xFE2F, 0x49A6, 0xFF67, 0x01FD, 0xB25A,
}

local BALL_INDEX = {
    0x0001, 0x0000, 0x0008, 0x0001, 0x0008, 0x0009, 0x0008, 0x0011, 0x0008, 0x0019,
    0x0008, 0x0021, 0x0007, 0x0029, 0x0002, 0x0030, 0x0001, 0x0032, 0x0001, 0x0033,
    0x0001, 0x0034, 0x0001, 0x0035, 0x0001, 0x0036, 0x0001, 0x0037, 0x0001, 0x0038,
    0x0001, 0x0039, 0x0001, 0x003A, 0x0001, 0x003B, 0x0001, 0x003C, 0x0001, 0x003D,
    0x0001, 0x003E, 0x0001, 0x003F, 0x0001, 0x0040, 0x0001, 0x0041, 0x0001, 0x0042,
    0x0001, 0x0043, 0x0001, 0x0044, 0x0001, 0x0045, 0x0001, 0x0046, 0x0001, 0x0047,
    0x0001, 0x0048, 0x0001, 0x0049, 0x0001, 0x004A, 0x0001, 0x004B, 0x0001, 0x004C,
    0x0001, 0x004D, 0x0001, 0x004E, 0x0001, 0x004F, 0x0001, 0x0050, 0x0008, 0x0051,
    0x0008, 0x0059, 0x0001, 0x0061, 0x0001, 0x0062, 0x0001, 0x0063, 0x0001, 0x0064,
    0x0001, 0x0065, 0x0001, 0x0066, 0x0001, 0x0067, 0x0001, 0x0068, 0x0001, 0x0069,
    0x0001, 0x006A, 0x0008, 0x006B, 0x0008, 0x0073, 0x0001, 0x007B, 0x0001, 0x007C,
    0x0001, 0x007D, 0x0001, 0x007E, 0x0001, 0x007F, 0x0001, 0x0080, 0x0001, 0x0081,
    0x0001, 0x0082, 0x0001, 0x0083, 0x0001, 0x0084,
}

moves.BALL = "of_lobby_ball_tuck"
local BALL_OK = type(_G["smlua_anim_util_register_animation"]) == "function"
    and type(_G["smlua_anim_util_set_animation"]) == "function"
if BALL_OK then
    at_load("smlua_anim_util_register_animation",
        moves.BALL, 0, 0, 0, 0, 8, BALL_VALUES, BALL_INDEX)
end

function moves.has_ball()
    return BALL_OK == true
end

local function wear_ball(m)
    set_character_animation(m, CHAR_ANIM_FORWARD_SPINNING)
    if not BALL_OK or m.marioObj == nil then return false end
    OF.util.optional("smlua_anim_util_set_animation", nil, m.marioObj, moves.BALL)
    return true
end

local ROLL = at_load("allocate_mario_action",
    ACT_GROUP_MOVING | ACT_FLAG_MOVING | ACT_FLAG_SHORT_HITBOX
        | ACT_FLAG_ATTACKING)
local SPIN = at_load("allocate_mario_action",
    ACT_GROUP_AIRBORNE | ACT_FLAG_AIR | ACT_FLAG_ATTACKING)

moves.ROLL, moves.SPIN = ROLL, SPIN

local CUSTOM_ACTION_BIT = ACT_FLAG_CUSTOM_ACTION or (1 << 30)

function moves.is_custom(action)
    if type(action) ~= "number" then return false end
    return OF.util.has_flag(action, CUSTOM_ACTION_BIT)
end

function moves.in_custom_action(m)
    if m == nil then return false end
    return moves.is_custom(m.action)
end

local CUSTOM_WORDS = {}
if ROLL ~= nil then CUSTOM_WORDS[ROLL] = "the roll" end
if SPIN ~= nil then CUSTOM_WORDS[SPIN] = "the air spin" end

function moves.custom_word(action)
    if type(action) ~= "number" then return nil end
    return CUSTOM_WORDS[action]
end

function moves.custom_word_count()
    local count = 0
    for _, _ in pairs(CUSTOM_WORDS) do count = count + 1 end
    return count
end

local ROLL_TURN = 0x2AA

local STEER_INPUT = INPUT_NONZERO_ANALOG or 0x0001

local function steer_the_roll(m)
    if m == nil or m.faceAngle == nil then return false end
    if not OF.util.has_flag(m.input or 0, STEER_INPUT) then return false end

    local face = m.faceAngle.y or 0
    local gap = ((m.intendedYaw or face) - face + 0x8000) % 0x10000 - 0x8000
    if gap > ROLL_TURN then gap = ROLL_TURN
    elseif gap < -ROLL_TURN then gap = -ROLL_TURN end
    if gap == 0 then return false end

    m.faceAngle.y = (face + gap + 0x8000) % 0x10000 - 0x8000
    mario_set_forward_vel(m, m.forwardVel or 0)
    return true
end

moves.steer_the_roll = steer_the_roll

local function aim_the_roll(m)
    if m == nil or m.faceAngle == nil then return false end
    if not OF.util.has_flag(m.input or 0, STEER_INPUT) then return false end

    local want = m.intendedYaw
    if want == nil then return false end
    m.faceAngle.y = (want + 0x8000) % 0x10000 - 0x8000
    mario_set_forward_vel(m, m.forwardVel or 0)
    return true
end

moves.aim_the_roll = aim_the_roll

local function act_roll(m)
    if m == nil then return false end

    local stop = moves.stop_for(m, "roll")

    if stop == nil or stop.frames == nil then
        if m.playerIndex == 0 then
            set_mario_action(m, ACT_CROUCH_SLIDE, 0)
        end
        return false
    end

    if m.actionTimer == 0 and m.forwardVel < stop.speed then
        mario_set_forward_vel(m, stop.speed)
        aim_the_roll(m)
    end
    m.actionTimer = m.actionTimer + 1

    if OF.util.has_flag(m.input or 0, INPUT_A_PRESSED) then
        OF.util.optional("set_jumping_action", nil, m, ACT_LONG_JUMP, 0)

        if m.action == ROLL then set_mario_action(m, ACT_LONG_JUMP, 0) end
        return false
    end

    local held = OF.util.has_flag(m.input or 0, INPUT_Z_DOWN)
    local drag = held and stop.drag * ROLL_HELD_DRAG or stop.drag
    local limit = held and math.floor(stop.frames * ROLL_HELD_FRAMES)
        or stop.frames

    steer_the_roll(m)

    wear_ball(m)

    local step = perform_ground_step(m)
    if step == GROUND_STEP_LEFT_GROUND then
        set_mario_action(m, ACT_FREEFALL, 0)
        return false
    end
    if step == GROUND_STEP_HIT_WALL then
        mario_set_forward_vel(m, 0.0)
        set_mario_action(m, ACT_CROUCH_SLIDE, 0)
        return false
    end

    mario_set_forward_vel(m, m.forwardVel - drag)
    if m.actionTimer >= limit or m.forwardVel < 8.0 then
        set_mario_action(m, ACT_CROUCH_SLIDE, 0)
    end
    return false
end

local SPIN_TURN = 0x2000

local function turn_for_spin(m)
    local gfx = m.marioObj ~= nil and m.marioObj.header ~= nil
        and m.marioObj.header.gfx or nil
    if gfx == nil or gfx.angle == nil then return false end

    local yaw = (gfx.angle.y + m.actionTimer * SPIN_TURN) % 0x10000
    if yaw >= 0x8000 then yaw = yaw - 0x10000 end
    gfx.angle.y = yaw
    return true
end

local function act_spin(m)
    if m == nil then return false end

    local stop = moves.stop_for(m, "spin")
    if stop == nil or stop.frames == nil then
        if m.playerIndex == 0 then
            set_mario_action(m, ACT_FREEFALL, 0)
        end
        return false
    end

    m.actionTimer = m.actionTimer + 1
    if m.actionTimer > stop.frames then
        set_mario_action(m, ACT_FREEFALL, 0)
        return false
    end

    if MARIO_KICKING ~= nil and m.actionTimer <= 8 then
        m.flags = m.flags | MARIO_KICKING
    end

    m.vel.y = stop.fall

    set_character_animation(m, CHAR_ANIM_TWIRL)
    update_air_without_turn(m)

    local step = perform_air_step(m, 0)
    if step == AIR_STEP_LANDED then

        local caught = OF.util.optional("check_fall_damage_or_get_stuck", 0,
            m, ACT_HARD_BACKWARD_GROUND_KB)
        if caught == nil or caught == 0 or caught == false then
            set_mario_action(m, ACT_FREEFALL_LAND, 0)
        end
        return false
    end
    if step == AIR_STEP_HIT_WALL then

        mario_set_forward_vel(m, 0.0)
    end

    turn_for_spin(m)
    return false
end

if ROLL ~= nil then at_load("hook_mario_action", ROLL, { every_frame = act_roll }) end
if SPIN ~= nil then at_load("hook_mario_action", SPIN, { every_frame = act_spin }) end

function moves.substitute_move(m, action, actionArg)
    if m == nil or m.playerIndex ~= 0 or moves.quiet() then return end

    if ROLL ~= nil and moves.setting("roll", "frames") ~= nil
        and actionArg == 9
        and (action == ACT_PUNCHING or action == ACT_MOVE_PUNCHING) then
        return ROLL
    end

    if ROLL ~= nil and moves.setting("roll", "frames") ~= nil
        and actionArg == 0 and action == ACT_MOVE_PUNCHING
        and m.action == ACT_CRAWLING
        and OF.util.has_flag(m.input or 0, INPUT_Z_DOWN) then
        return ROLL
    end

    if SPIN ~= nil and moves.setting("spin", "frames") ~= nil
        and action == ACT_JUMP_KICK then
        return SPIN
    end

    if ROLL ~= nil and moves.setting("roll", "frames") ~= nil
        and OF.util.has_flag(m.input or 0, INPUT_Z_DOWN) then
        local into = moves.setting("into", "into")
        if into ~= nil and into[action] then
            return ROLL
        end
    end

    return
end

function moves.after_set_action(m)
    if m == nil or m.playerIndex ~= 0 or moves.quiet() then return end

    if m.action == ACT_WALL_KICK_AIR then
        local lift = moves.setting("wall", "lift")
        if lift ~= nil then
            m.vel.y = m.vel.y + lift
            mario_set_forward_vel(m,
                (m.forwardVel or 0) + (moves.setting("wall", "push") or 0))
        end
    end

    if m.action == ACT_BACKFLIP then
        local full = moves.setting("windup", "full")
        local lift = moves.setting("windup", "lift")
        local held = moves.crouched or 0
        if full ~= nil and lift ~= nil and held > 0 then
            local share = held / full
            if share > 1 then share = 1 end
            m.vel.y = m.vel.y + lift * share
        end
        moves.crouched = 0
    end
    return
end

function moves.watch(m)
    if m == nil or m.playerIndex ~= 0 or moves.quiet() then return end

    if m.action == ACT_CROUCHING or m.action == ACT_START_CROUCHING then
        moves.crouched = (moves.crouched or 0) + 1
    elseif m.action ~= ACT_BACKFLIP then

        moves.crouched = 0
    end

    if ROLL ~= nil and m.action == ACT_START_CRAWLING
        and moves.setting("roll", "frames") ~= nil
        and OF.util.has_flag(m.input or 0, INPUT_B_PRESSED)
        and OF.util.has_flag(m.input or 0, INPUT_Z_DOWN) then
        set_mario_action(m, ROLL, 0)
        return
    end

    local lift = moves.setting("pound", "lift")
    if lift ~= nil and m.action == ACT_GROUND_POUND_LAND
        and OF.util.has_flag(m.input or 0, INPUT_A_PRESSED) then
        set_mario_action(m, ACT_JUMP, 0)
        m.vel.y = lift
        return
    end

    local speed = moves.setting("dive", "speed")
    if speed ~= nil and m.action == ACT_GROUND_POUND and m.actionState == 1
        and OF.util.has_flag(m.input or 0, INPUT_B_PRESSED) then
        set_mario_action(m, ACT_DIVE, 0)

        if m.action ~= ACT_DIVE then return end

        mario_set_forward_vel(m, speed)

        m.vel.y = 0
    end
    return
end

function moves.build_page(panel)
    local rows = {}

    table.insert(rows, panel.label_row(OF.lang.fill("Now: @", moves.label())))

    table.insert(rows, panel.label_row(
        OF.lang.t("What a button does. A ticks the lobby's box, Z yours.")))

    if OF.util.asks(OF.input, "turbo_toggle") then
        table.insert(rows, panel.header_row(
            OF.lang.t("Rapid fire  (yours only)")))
        table.insert(rows, panel.label_row(OF.lang.t(
            "A button you hold, pressed again and again. Nothing is sent.")))

        for _, entry in ipairs(OF.input.TURBO_BUTTONS or {}) do
            local on = OF.input.turbo_on(entry.button)
            table.insert(rows, panel.with_help(panel.row(panel.tick(on,
                OF.lang.fill("Turbo @", entry.name)),
                on and 140 or 200, on and 255 or 200, on and 160 or 200,
                function() OF.input.turbo_toggle(entry.button) end),
                OF.lang.t(
                    "holding this button repeats it for you, at the rate below")))
        end

        local rate = OF.input.turbo_rate()
        table.insert(rows, panel.with_help(panel.with_right(
            panel.row(OF.lang.t("Repeat rate"), 255, 220, 120,
                function() OF.input.turbo_step_rate() end),
            OF.lang.fill("every @ frames  (about @ a second)",
                tostring(rate), string.format("%.0f", 30 / rate))),
            OF.lang.t("how fast a held button repeats, for every turbo above")))

        table.insert(rows, panel.header_row(
            OF.lang.t("What a button does")))
    end

    if moves.round_holds() then
        table.insert(rows, panel.label_row(
            OF.lang.t("A round has the lobby - its own come back after it.")))
    end

    table.insert(rows, panel.with_help(panel.host_row("speedrun",
        OF.lang.t("Put every move back"), 255, 140, 90,
        function() OF.util.report(moves.clear(0)) end),
        OF.lang.t("every move in the lobby's boxes, back to the game's own")))

    table.insert(rows, panel.with_help(panel.gated_row(MINE_NEED,
        OF.lang.t("Put your own moves back"), 255, 140, 90,
        function() OF.util.report(moves.clear_mine_press()) end),
        OF.lang.t("every box of your own emptied, so the lobby's apply again")))

    for _, row in ipairs(moves.ROWS) do
        local key = row.key

        local roomStep = moves.wanted_step(key)
        local roomOn = roomStep ~= row.plain
        local mine = moves.mine_state(key)

        local lobbyNeed = OF.util.is_host() and "speedrun" or nil

        local help = OF.lang.t(row.help)
        if moves.suspended(key) then
            help = OF.lang.t("Put away until the round ends - your setting is kept.")
        end

        local built = panel.with_help(panel.two_box({
            lobbyOn = roomOn,

            mineBox = panel.mine_shown(mine, roomOn),
            name = OF.lang.t(row.name),
            lobbyNeed = lobbyNeed,
            mineNeed = MINE_NEED,
            r = 255, g = 255, b = 255,
            onLobby = function() OF.util.report(moves.next_step(key)) end,

            onMine = function()
                local want = panel.next_mine_level(mine,
                    moves.mine_step(key) - row.plain,
                    #row.steps - row.plain, roomStep - row.plain)
                if want == nil then
                    OF.util.report(moves.set_mine(key, nil))
                    return
                end
                OF.util.report(moves.set_mine_step(key, want + row.plain))
            end,
        }), help)

        local step, yours = moves.in_force(key)
        local column = nil
        if step ~= row.plain then
            column = panel.two_box_level(OF.lang.t(row.steps[step].name), yours)
        elseif mine == false then

            column = panel.two_box_level(
                OF.lang.t(row.steps[row.plain].name), true)
        end
        built = panel.level_right(built, column ~= nil, column)

        local dialsRoom = (mine == nil) and panel.may(lobbyNeed)
        local need = dialsRoom and lobbyNeed or MINE_NEED
        local at = dialsRoom and roomStep or step
        if panel.may(need) then
            built = panel.with_slider(built, at - 1, #row.steps - 1,
                function(wanted)
                    if dialsRoom then
                        OF.util.report(moves.set_step(key, wanted + 1, false, 0))
                    else

                        OF.util.report(moves.set_mine_step(key, wanted + 1))
                    end
                end)
        else

            built = panel.with_slider(built, at - 1, #row.steps - 1, nil)
        end
        table.insert(rows, built)
    end

    if moves.step("into") ~= moves.BY_KEY["into"].plain
        and moves.setting("roll", "frames") == nil then
        table.insert(rows, panel.label_row(
            OF.lang.t("The ways in do nothing until Ground roll is on.")))
    end

    if ROLL == nil or SPIN == nil then
        table.insert(rows, panel.label_row(
            OF.lang.t("This build has no custom actions - the roll and the spin are off.")))
    elseif not moves.has_ball() then

        table.insert(rows, panel.label_row(
            OF.lang.t("This build cannot hold a custom pose - the roll tumbles instead.")))
    end

    for _, r in ipairs(OF.util.asks(OF.modifiers, "build_rows")
            and OF.modifiers.build_rows(panel, "controls") or {}) do
        table.insert(rows, r)
    end

    table.insert(rows, panel.back_row())
    return rows
end

hook_on_sync_table_change(gGlobalSyncTable, moves.KEY, "moves", function()
    if OF.util.asks(OF.guard, "repair") then OF.guard.repair(moves.KEY) end
end)

hook_event(HOOK_BEFORE_SET_MARIO_ACTION, moves.substitute_move)
hook_event(HOOK_ON_SET_MARIO_ACTION, moves.after_set_action)
hook_event(HOOK_MARIO_UPDATE, moves.watch)

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil then return end
    if data.ofp ~= moves.PACKET then return end
    if not OF.util.from_host(data) then return end
    if data.what == "clearmine" then

        local had = moves.mine_any()
        moves.clear_mine()
        if had then
            OF.notify.show("The host cleared your own move settings",
                "info", 4)
        end
    end
end)

hook_event(HOOK_ON_MODS_LOADED, function()
    local panel = OF.panel
    if panel == nil or type(panel.PAGES) ~= "table" then return end
    if panel.PAGES.moves == nil then
        panel.PAGES.moves = {
            title = "Controls editor", tab = "room", up = "roomrules",
            build = function() return moves.build_page(panel) end,
        }
    end
end)

hook_event(HOOK_ON_LEVEL_INIT, function()
    moves.crouched = 0
end)

function moves.count()
    local n = 0
    if ROLL ~= nil then n = n + 1 end
    if SPIN ~= nil then n = n + 1 end
    return n
end
