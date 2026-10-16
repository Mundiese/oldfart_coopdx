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

local ROLL_KICK_GRACE = 3

local ROLL_STEPS = {
    { name = "B still punches" },
    { name = "a quick tuck",  frames = 24, speed = 30, drag = 0.90, bite = true },
    { name = "a proper roll", frames = 45, speed = 40, drag = 0.45, bite = true },
    { name = "a long roll",   frames = 80, speed = 48, drag = 0.22, bite = true },
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

    { name = "and out of a wall kick",      lands = { "ACT_DIVE_SLIDE",
                                                      "ACT_LONG_JUMP_LAND",
                                                      "ACT_FREEFALL_LAND",
                                                      "ACT_GROUND_POUND_LAND" },
                                            froms = { { land = "ACT_JUMP_LAND",
                                                        from = "ACT_WALL_KICK_AIR" } } },

    { name = "and out of a bonk",           lands = { "ACT_DIVE_SLIDE",
                                                      "ACT_LONG_JUMP_LAND",
                                                      "ACT_FREEFALL_LAND",
                                                      "ACT_GROUND_POUND_LAND",
                                                      "ACT_BACKWARD_GROUND_KB" },
                                            froms = { { land = "ACT_JUMP_LAND",
                                                        from = "ACT_WALL_KICK_AIR" } } },
}

local SPIN_STEPS = {
    { name = "B is still a kick" },
    { name = "a flick, still falling",   frames = 12, fall = -8 },
    { name = "a spin that slows you",    frames = 22, fall = -4 },
    { name = "a spin that nearly hangs", frames = 32, fall = -1 },
    { name = "a spin that lifts you",    frames = 32, fall = 6 },
    { name = "and it hurts all the way",
      frames = 32, fall = 6, bite = true },
}

local POUND_STEPS = {
    { name = "A does nothing" },
    { name = "a hop",               lift = 30 },
    { name = "a jump",              lift = 52 },
    { name = "a high jump",         lift = 74 },
    { name = "clear over the roof", lift = 100 },
    { name = "and it keeps your speed",        lift = 100, keep = true },
    { name = "higher the further you fell",
      lift = 42, keep = true, perUnit = 0.04, most = 140 },
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
    { name = "and off other players", lift = 40, push = 28, players = true },
}

local WINDUP_STEPS = {
    { name = "a plain backflip" },
    { name = "a little spring", full = 30, lift = 16 },
    { name = "a good spring",   full = 45, lift = 30 },
    { name = "a big spring",    full = 60, lift = 48 },
    { name = "worth the wait",  full = 90, lift = 76 },
    { name = "and the lobby can see it",
      full = 90, lift = 76, show = true },
    { name = "and overcharging costs a wedge",
      full = 90, lift = 76, show = true, cost = true },
}

local SPINJUMP_STEPS = {
    { name = "A is the game's own jump" },
    { name = "a corkscrew",        lift = 40, rise = 4.0, fall = 4.0, most = 75,
                                   turn = 0x1400, frames = 90 },
    { name = "a jump that hangs",  lift = 52, rise = 2.6, fall = 3.0, most = 62,
                                   turn = 0x1C00, frames = 110 },
    { name = "a jump that floats", lift = 62, rise = 2.0, fall = 1.8, most = 40,
                                   turn = 0x2400, frames = 140 },
    { name = "clear over the roof", lift = 78, rise = 1.6, fall = 1.4, most = 30,
                                   turn = 0x2C00, frames = 170 },
}

local SPINPOUND_STEPS = {
    { name = "Z is the game's own pound" },
    { name = "a drill",             drop = 62, turn = 0x2400 },
    { name = "a hard drill",        drop = 80, turn = 0x3000 },
    { name = "a drill you feel",    drop = 96, turn = 0x3800 },
    { name = "and the ground shakes",
      drop = 96, turn = 0x3800, shake = true },
    { name = "and the landing has reach",
      drop = 96, turn = 0x3800, shake = true, reach = 90 },
}

local DASH_STEPS = {
    { name = "X does nothing" },
    { name = "a short burst",          speed = 48, frames = 8,  charges = 1 },
    { name = "a long burst",           speed = 64, frames = 12, charges = 1 },
    { name = "and a wall kick gives it back",
      speed = 64, frames = 12, charges = 1, refill = true },
    { name = "twice before you land",
      speed = 64, frames = 12, charges = 2, refill = true },
}

local SPRINT_STEPS = {
    { name = "X does nothing on the ground" },
    { name = "hold X running - a sprint",  on = true },
}

moves.SPRINT = { full = 90, refill = 0.5, again = 30, scale = 1.45, top = 48 }
moves.SPRINT_FREE = { stamina = false }
moves.sprintState = moves.sprintState or { stamina = 90, spent = false }

function moves.sprint_reset()
    moves.sprintState.stamina = moves.SPRINT.full
    moves.sprintState.spent = false
end

function moves.sprint_stamina()
    return moves.sprintState.stamina
end

function moves.sprint_step(m, held, opts)
    if m == nil then return false end
    local s, st = moves.SPRINT, moves.sprintState
    local bar = opts == nil or opts.stamina ~= false
    if bar and st.spent and st.stamina >= s.again then st.spent = false end
    local run = tonumber(m.forwardVel) or 0
    if held and m.action == ACT_WALKING and run > 4
        and (not bar or (not st.spent and st.stamina > 0)) then
        if bar then
            st.stamina = math.max(st.stamina - 1, 0)
            if st.stamina <= 0 then st.spent = true end
        end
        OF.util.speed_up(m, math.min(s.top, run * s.scale), true)
        return true
    end
    if bar then st.stamina = math.min(st.stamina + s.refill, s.full) end
    return false
end

function moves.sprint_row(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    local stop = moves.stop("sprint")
    if stop == nil or not stop.on then return false end
    if OF.util.asks(OF.powerups, "wearing") and OF.powerups.wearing("cape") then
        return false
    end
    local pad = m.controller
    local held = pad ~= nil and OF.util.has_flag(pad.buttonDown or 0, X_BUTTON or 0x0040)

    return moves.sprint_step(m, held, moves.SPRINT_FREE)
end

local RAGDOLL_STEPS = {
    { name = "Y does nothing" },
    { name = "Y throws you down", on = true },
}

local CLASS_STEPS = {
    { name = "everybody moves the same" },
    { name = "dealt round the lobby",         dealt = true },
    { name = "Mario - the all-rounder",       class = 1 },
    { name = "Luigi - a flutter and a slide", class = 2 },
    { name = "Wario - slow and heavy-handed", class = 3 },
    { name = "Yoshi - a flutter and a gulp",  class = 4 },
}

moves.ROWS = {
    { key = "roll",   id = "rl", name = "Ground roll",
      help = "Z and B with the stick - hold Z longer, A jumps out",
      steps = ROLL_STEPS,   plain = 1 },
    { key = "into",   id = "in", name = "Ways into the roll",
      help = "hold Z through a landing and it becomes a roll",
      steps = INTO_STEPS,   plain = 1 },
    { key = "spin",   id = "sp", name = "Air spin",
      help = "B in the air at no speed - the jump kick becomes a spin",
      steps = SPIN_STEPS,   plain = 1 },
    { key = "pound",  id = "pb", name = "Bounce out of a ground pound",
      help = "A as the pound lands - a press the game ignores",
      steps = POUND_STEPS,  plain = 1 },
    { key = "wall",   id = "wk", name = "Kick off a wall harder",
      help = "added to the engine's own kick, however you got into it",
      steps = WALL_STEPS,   plain = 1 },
    { key = "windup", id = "wu", name = "Wind-up jump",
      help = "stay crouched, then A - the backflip is worth the wait",
      steps = WINDUP_STEPS, plain = 1 },

    { key = "dive",   id = "pd", name = "Dive out of a ground pound",
      help = "B while pounding, before it lands - the pound's follow-up",
      steps = DIVE_STEPS,   plain = 1 },

    { key = "spinjump", id = "sj", name = "Spin jump",
      help = "spin the stick, then jump - no button, and still your jump",
      steps = SPINJUMP_STEPS, plain = 1 },
    { key = "spinpound", id = "sq", name = "Spin pound",
      help = "Z out of a spin jump - the ground pound's own press",
      steps = SPINPOUND_STEPS, plain = 1 },

    { key = "dash", id = "da", name = "Air dash",
      help = "X in the air - one burst the way the stick points",
      steps = DASH_STEPS, plain = 1 },

    { key = "ragdoll", id = "rg", name = "Ragdoll",
      help = "Y (key M): go limp - hits throw you, B lifts a limp player",
      steps = RAGDOLL_STEPS, plain = 1 },

    { key = "class", id = "cl", name = "Character classes",
      help = "be Mario, Luigi, Wario or Yoshi, with moves of their own",
      steps = CLASS_STEPS, plain = 1 },

    { key = "sprint", id = "sr", name = "Sprint",
      help = "X held while running - a sprint that never runs dry",
      steps = SPRINT_STEPS, plain = 1 },
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
        step.fromInto = {}
        for _, pair in ipairs(step.froms or {}) do
            local land = _G[pair.land]
            local from = _G[pair.from]
            if type(land) == "number" and type(from) == "number" then
                step.fromInto[land] = step.fromInto[land] or {}
                step.fromInto[land][from] = true
            end
        end
    end
end
build_into()

local parsedText, parsedSet = nil, {}
local function parse()
    local text = gGlobalSyncTable[moves.KEY]
    if type(text) ~= "string" then text = nil end
    if text == parsedText and parsedSet ~= nil then return parsedSet end
    local set = {}
    if text ~= nil then
        for id, step in string.gmatch(text, "(%a%a):(%d+)") do
            set[id] = tonumber(step)
        end
    end
    parsedText, parsedSet = text, set
    return set
end
moves.parse_wire = parse

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

    if moves.mine_step(key) == roomStep and #row.steps <= 2 then return nil end
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

function moves.b_refused()
    return OF.util.asks(OF.powerups, "b_refused") and OF.powerups.b_refused() == true
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

moves.ACTION = "moves"
function moves.set_step(key, step, quiet, askerLocal)
    if not OF.util.is_host() then
        if OF.util.asks(OF.net, "host_does") then
            return OF.net.host_does(moves.ACTION, tonumber(step), nil, tostring(key))
        end
        return false, OF.lang.t("No host to ask yet - try again in a second.")
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
        if who ~= nil then
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
        if OF.util.asks(OF.net, "host_does") then
            return OF.net.host_does(moves.ACTION, 0, nil, "clear")
        end
        return false, OF.lang.t("No host to ask yet - try again in a second.")
    end
    if not moves.anything_on() then
        return false, OF.lang.t("Nobody has any extra moves.")
    end

    local wasLabel = moves.label()
    if not OF.util.publish(moves.KEY, "") then
        return false, OF.lang.t("That is too much to send to the lobby at once.")
    end

    local who = OF.util.presser(askerLocal)
    if who ~= nil then
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

local BALL_FRAMES = 12

local BALL_VALUES = {
    0x0000, 0x0076, 0x007F, 0x008C, 0x00B8, 0x00CE, 0x00C8, 0x00B1,
    0x0097, 0x0086, 0x0070, 0x0067, 0x006A, 0xFFE5, 0xFFCD, 0xFFC2,
    0xFFC8, 0xFFDD, 0xFFFB, 0x001B, 0x0033, 0x003E, 0x0038, 0x0023,
    0x0005, 0x0000, 0x1555, 0x2AAB, 0x4000, 0x5555, 0x6AAB, 0x8000,
    0x9555, 0xAAAB, 0xC000, 0xD555, 0xEAAB, 0x0000, 0x0000, 0x4000,
    0x0000, 0x4000, 0x0000, 0x0000, 0x238E, 0x0000, 0x0000, 0x24FA,
    0x0000, 0x0000, 0x8000, 0x02D8, 0xFA50, 0xCE39, 0x0000, 0xFD28,
    0x4E39, 0x0000, 0x0000, 0x1C72, 0x0000, 0x0000, 0x8000, 0xFD28,
    0x05B0, 0xCE39, 0x0000, 0x02D8, 0x4E39, 0x0000, 0x0000, 0x1C72,
    0x0000, 0x0000, 0x8000, 0x0000, 0x0444, 0x9555, 0x0000, 0x0000,
    0x6EEF, 0x0000, 0x0000, 0xF777, 0x0000, 0x0000, 0x8000, 0x0000,
    0xFBBC, 0x9555, 0x0000, 0x0000, 0x6EEF, 0x0000, 0x0000, 0xF777,
}

local BALL_INDEX = {
    0x0001, 0x0000, 0x000C, 0x0001, 0x000C, 0x000D, 0x000C, 0x0019,
    0x0001, 0x0025, 0x0001, 0x0026, 0x0001, 0x0027, 0x0001, 0x0028,
    0x0001, 0x0029, 0x0001, 0x002A, 0x0001, 0x002B, 0x0001, 0x002C,
    0x0001, 0x002D, 0x0001, 0x002E, 0x0001, 0x002F, 0x0001, 0x0030,
    0x0001, 0x0031, 0x0001, 0x0032, 0x0001, 0x0033, 0x0001, 0x0034,
    0x0001, 0x0035, 0x0001, 0x0036, 0x0001, 0x0037, 0x0001, 0x0038,
    0x0001, 0x0039, 0x0001, 0x003A, 0x0001, 0x003B, 0x0001, 0x003C,
    0x0001, 0x003D, 0x0001, 0x003E, 0x0001, 0x003F, 0x0001, 0x0040,
    0x0001, 0x0041, 0x0001, 0x0042, 0x0001, 0x0043, 0x0001, 0x0044,
    0x0001, 0x0045, 0x0001, 0x0046, 0x0001, 0x0047, 0x0001, 0x0048,
    0x0001, 0x0049, 0x0001, 0x004A, 0x0001, 0x004B, 0x0001, 0x004C,
    0x0001, 0x004D, 0x0001, 0x004E, 0x0001, 0x004F, 0x0001, 0x0050,
    0x0001, 0x0051, 0x0001, 0x0052, 0x0001, 0x0053, 0x0001, 0x0054,
    0x0001, 0x0055, 0x0001, 0x0056, 0x0001, 0x0057, 0x0001, 0x0058,
    0x0001, 0x0059, 0x0001, 0x005A, 0x0001, 0x005B, 0x0001, 0x005C,
    0x0001, 0x005D, 0x0001, 0x005E, 0x0001, 0x005F,
}

moves.BALL = "of_lobby_ball_tuck"
local BALL_OK = type(_G["smlua_anim_util_register_animation"]) == "function"
    and type(_G["smlua_anim_util_set_animation"]) == "function"
if BALL_OK then
    at_load("smlua_anim_util_register_animation",
        moves.BALL, 0, 0, 0, 0, BALL_FRAMES, BALL_VALUES, BALL_INDEX)
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

local WIND_FLAG = ACT_FLAG_ALLOW_VERTICAL_WIND_ACTION or (1 << 24)

local SPINJUMP = at_load("allocate_mario_action",
    ACT_GROUP_AIRBORNE | ACT_FLAG_AIR | WIND_FLAG)
local SPINPOUND = at_load("allocate_mario_action",
    ACT_GROUP_AIRBORNE | ACT_FLAG_AIR | ACT_FLAG_ATTACKING)

local DASH = at_load("allocate_mario_action", ACT_GROUP_AIRBORNE | ACT_FLAG_AIR)
moves.DASH = DASH

moves.ROLL, moves.SPIN = ROLL, SPIN
moves.SPINJUMP, moves.SPINPOUND = SPINJUMP, SPINPOUND

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
if SPINJUMP ~= nil then CUSTOM_WORDS[SPINJUMP] = "the spin jump" end
if SPINPOUND ~= nil then CUSTOM_WORDS[SPINPOUND] = "the spin pound" end
if DASH ~= nil then CUSTOM_WORDS[DASH] = "the air dash" end

function moves.custom_word(action)
    if type(action) ~= "number" then return nil end
    return CUSTOM_WORDS[action]
end

function moves.custom_word_count()
    local count = 0
    for _, _ in pairs(CUSTOM_WORDS) do count = count + 1 end
    return count
end

local ROLL_TURN = 0x600
local ROLL_STICK = 64

local STEER_INPUT = INPUT_NONZERO_ANALOG or 0x0001

local AIR_FLAG = ACT_FLAG_AIR or (1 << 11)

local function steer_the_roll(m)
    if m == nil or m.faceAngle == nil then return false end
    if not OF.util.has_flag(m.input or 0, STEER_INPUT) then return false end
    local pad = m.controller
    local sx = pad ~= nil and pad.stickX or 0
    local lean = sx / ROLL_STICK
    if lean > 1 then lean = 1 elseif lean < -1 then lean = -1 end
    local turn = math.floor(-lean * ROLL_TURN + 0.5)
    if turn == 0 then return false end

    local face = m.faceAngle.y or 0
    m.faceAngle.y = (face + turn + 0x8000) % 0x10000 - 0x8000
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

local FLOOR_DRAG = {}
do
    local named = {
        { SURFACE_CLASS_VERY_SLIPPERY, 0.25 },
        { SURFACE_CLASS_SLIPPERY,      0.55 },
        { SURFACE_CLASS_DEFAULT,       1.00 },
        { SURFACE_CLASS_NOT_SLIPPERY,  1.80 },
    }
    for i = 1, 4 do
        local one = named[i]
        if one ~= nil and one[1] ~= nil then FLOOR_DRAG[one[1]] = one[2] end
    end
end

function moves.floor_drag(m)
    if m == nil then return 1.0 end
    local class = OF.util.optional("mario_get_floor_class", nil, m)
    if class == nil then return 1.0 end
    return FLOOR_DRAG[class] or 1.0
end

local function act_roll(m)
    if m == nil then return false end

    local stop = moves.stop_for(m, "roll")

    if stop == nil or stop.frames == nil then
        if m.playerIndex == 0 then
            set_mario_action(m, ACT_CROUCH_SLIDE, 0)
        end
        return false
    end

    if m.actionTimer == 0 and m.forwardVel < stop.speed
        and m.actionArg ~= moves.REV_ARG then
        mario_set_forward_vel(m, stop.speed)
        aim_the_roll(m)
    end
    m.actionTimer = m.actionTimer + 1

    if stop.bite and MARIO_KICKING ~= nil then
        m.flags = m.flags | MARIO_KICKING
    end

    if OF.util.has_flag(m.input or 0, INPUT_A_PRESSED) then
        OF.util.optional("set_jumping_action", nil, m, ACT_LONG_JUMP, 0)

        if m.action == ROLL then set_mario_action(m, ACT_LONG_JUMP, 0) end
        return false
    end

    local held = OF.util.has_flag(m.input or 0, INPUT_Z_DOWN)
    local drag = held and stop.drag * ROLL_HELD_DRAG or stop.drag

    if stop.ground then drag = drag * moves.floor_drag(m) end
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

        if stop.kick and ACT_WALL_KICK_AIR ~= nil then
            m.faceAngle.y = (m.faceAngle.y + 0x8000 + 0x8000) % 0x10000 - 0x8000
            set_mario_action(m, ACT_WALL_KICK_AIR, 0)
            return false
        end
        mario_set_forward_vel(m, 0.0)
        set_mario_action(m, ACT_CROUCH_SLIDE, 0)
        return false
    end

    mario_set_forward_vel(m, m.forwardVel - drag)

    if stop.slope then

        if moves.sonic_slope(m) > 0 then m.actionTimer = m.actionTimer - 1 end
    elseif stop.ground then
        OF.util.optional("apply_slope_accel", nil, m)
    end

    local ending = m.actionTimer >= limit or m.forwardVel < 8.0

    if not ending then
        moves.rollGrace = 0
    elseif stop.kick then
        moves.rollGrace = (moves.rollGrace or 0) + 1
        if moves.rollGrace <= ROLL_KICK_GRACE then
            if m.forwardVel < 8.0 then mario_set_forward_vel(m, 8.0) end
            return false
        end
    end

    if ending then
        set_mario_action(m, ACT_CROUCH_SLIDE, 0)
    end
    return false
end

local SPIN_TURN = 0x2000

local function add_gfx_yaw(m, add)
    local gfx = m ~= nil and m.marioObj ~= nil and m.marioObj.header ~= nil
        and m.marioObj.header.gfx or nil
    if gfx == nil or gfx.angle == nil then return false end

    local yaw = (gfx.angle.y + add) % 0x10000
    if yaw >= 0x8000 then yaw = yaw - 0x10000 end
    gfx.angle.y = yaw
    return true
end

moves.add_gfx_yaw = add_gfx_yaw

local function turn_for_spin(m)
    return add_gfx_yaw(m, m.actionTimer * SPIN_TURN)
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

    if MARIO_KICKING ~= nil and (stop.bite or m.actionTimer <= 8) then
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

local function stick_angle(x, y)
    return math.atan(y, x) * (0x8000 / math.pi)
end

local SPIN_WINDOW = 10

local SPIN_SWEEP = 0xA000

local SPIN_ARMED = 8

local SPIN_PUSH = 8.0

moves.spinRing = moves.spinRing or {}
moves.spinArmed = moves.spinArmed or 0

local function drop_the_spin()
    for i = 1, SPIN_WINDOW do moves.spinRing[i] = 0 end
    moves.spinLast = nil
    moves.spinAt = 0
end
drop_the_spin()

function moves.spin_armed()
    return (moves.spinArmed or 0) > 0
end

function moves.read_the_spin(m)
    if (moves.spinArmed or 0) > 0 then
        moves.spinArmed = moves.spinArmed - 1
    end

    if m == nil or m.controller == nil then drop_the_spin() return false end
    if OF.panel ~= nil and OF.panel.open == true then
        drop_the_spin()
        return false
    end
    if (m.intendedMag or 0) < SPIN_PUSH then drop_the_spin() return false end

    local angle = stick_angle(m.controller.stickX or 0, m.controller.stickY or 0)
    local last = moves.spinLast
    moves.spinLast = angle

    if last == nil then return false end

    local gap = (angle - last + 0x8000) % 0x10000 - 0x8000

    local at = (moves.spinAt or 0) % SPIN_WINDOW + 1
    moves.spinAt = at
    moves.spinRing[at] = gap

    local swept = 0
    for i = 1, SPIN_WINDOW do swept = swept + (moves.spinRing[i] or 0) end

    if swept >= SPIN_SWEEP or swept <= -SPIN_SWEEP then
        moves.spinArmed = SPIN_ARMED
        return true
    end
    return false
end

local function pose_length(m)
    local obj = m ~= nil and m.marioObj or nil
    local head = obj ~= nil and obj.header or nil
    local gfx = head ~= nil and head.gfx or nil
    local info = gfx ~= nil and gfx.animInfo or nil
    local cur = info ~= nil and info.curAnim or nil
    local last = cur ~= nil and cur.loopEnd or nil
    if type(last) ~= "number" or last < 1 then return nil end
    return last
end

local function drive_the_pose(m, turned)

    if not wear_ball(m) then return false end
    local last = pose_length(m)
    if last == nil then return false end

    local play = OF.util.binding("set_anim_to_frame")
    if play == nil then return false end

    local round = (turned or 0) % 0x10000
    play(m, math.floor(last * round / 0x10000) % last)
    return true
end

moves.drive_the_pose = drive_the_pose

local function spin_jump_gravity(m)
    if m == nil or m.vel == nil then return 0 end
    local stop = moves.stop_for(m, "spinjump")
    if stop == nil or stop.rise == nil then

        return -1
    end
    if m.vel.y > 0 then
        m.vel.y = m.vel.y - stop.rise
    else
        m.vel.y = m.vel.y - stop.fall
    end
    local most = stop.most or 75
    if m.vel.y < -most then m.vel.y = -most end
    return 0
end

local function act_spin_jump(m)
    if m == nil then return false end

    local stop = moves.stop_for(m, "spinjump")
    if stop == nil or stop.lift == nil then
        if m.playerIndex == 0 then
            set_mario_action(m, ACT_FREEFALL, 0)
        end
        return false
    end

    m.actionTimer = m.actionTimer + 1

    if OF.util.has_flag(m.input or 0, INPUT_B_PRESSED) and not moves.b_refused() then
        OF.util.optional("check_kick_or_dive_in_air", nil, m)

        if m.action == SPINJUMP then set_mario_action(m, ACT_DIVE, 0) end
        return false
    end

    if OF.util.has_flag(m.input or 0, INPUT_Z_PRESSED) then
        local drill = moves.stop_for(m, "spinpound")
        if SPINPOUND ~= nil and drill ~= nil and drill.drop ~= nil then
            set_mario_action(m, SPINPOUND, 0)
        else
            set_mario_action(m, ACT_GROUND_POUND, 0)
        end
        return false
    end

    if m.actionTimer > stop.frames then
        set_mario_action(m, ACT_FREEFALL, 0)
        return false
    end

    local turned = m.actionTimer * stop.turn

    set_character_animation(m, CHAR_ANIM_TWIRL)
    update_air_without_turn(m)

    local step = perform_air_step(m, 0)
    if step == AIR_STEP_LANDED then

        local caught = OF.util.optional("check_fall_damage_or_get_stuck", 0,
            m, ACT_HARD_BACKWARD_GROUND_KB)
        if caught == nil or caught == 0 or caught == false then
            set_mario_action(m, ACT_DOUBLE_JUMP_LAND, 0)
        end
        return false
    end
    if step == AIR_STEP_HIT_WALL then

        mario_set_forward_vel(m, 0.0)
    end

    add_gfx_yaw(m, turned)
    return false
end

local DRILL_FULL = 24
local DRILL_MOST = 2.5

local function drill_turned(at)
    local slope = (DRILL_MOST - 1) / DRILL_FULL
    if at <= DRILL_FULL then
        return at + slope * (at * (at + 1) / 2)
    end
    return DRILL_FULL + slope * (DRILL_FULL * (DRILL_FULL + 1) / 2)
        + DRILL_MOST * (at - DRILL_FULL)
end

moves.drill_turned = drill_turned

local POUND_PARTICLES = (PARTICLE_MIST_CIRCLE or (1 << 16))
    | (PARTICLE_HORIZONTAL_STAR or (1 << 4))

local DRILL_SOUND = SOUND_ACTION_TWIRL

local function widen_the_reach(m, stop)
    if stop == nil or stop.reach == nil then return false end
    if m == nil or m.playerIndex ~= 0 or m.marioObj == nil then return false end
    if moves.hitbox == nil then moves.hitbox = m.marioObj.hitboxRadius end
    m.marioObj.hitboxRadius = (moves.hitbox or 0) + stop.reach
    return true
end

function moves.settle_the_reach(m)
    if moves.hitbox == nil then return false end
    if m ~= nil and m.action == SPINPOUND and SPINPOUND ~= nil then return false end
    if m ~= nil and m.marioObj ~= nil then
        m.marioObj.hitboxRadius = moves.hitbox
    end
    moves.hitbox = nil
    return true
end

local function act_spin_pound(m)
    if m == nil then return false end

    local stop = moves.stop_for(m, "spinpound")
    if stop == nil or stop.drop == nil then

        if m.playerIndex == 0 then
            set_mario_action(m, ACT_GROUND_POUND, 0)
        end
        return false
    end

    if m.actionTimer == 0 then

        if DRILL_SOUND ~= nil and m.marioObj ~= nil then
            OF.util.optional("play_sound", nil, DRILL_SOUND,
                m.marioObj.header.gfx.cameraToObject)
        end

        mario_set_forward_vel(m, 0.0)
    end

    m.actionTimer = m.actionTimer + 1

    m.vel.y = -stop.drop

    widen_the_reach(m, stop)

    local turned = drill_turned(m.actionTimer) * stop.turn
    drive_the_pose(m, turned)

    local step = perform_air_step(m, 0)
    if step == AIR_STEP_LANDED then
        if stop.shake then
            m.particleFlags = (m.particleFlags or 0) | POUND_PARTICLES
            OF.util.optional("set_camera_shake_from_hit", nil, SHAKE_GROUND_POUND)
        end
        OF.util.optional("play_mario_heavy_landing_sound", nil, m,
            SOUND_ACTION_TERRAIN_HEAVY_LANDING)

        local caught = OF.util.optional("check_fall_damage", 0,
            m, ACT_HARD_BACKWARD_GROUND_KB)
        if caught == nil or caught == 0 or caught == false then
            set_mario_action(m, ACT_GROUND_POUND_LAND, 0)
        end
        return false
    end
    if step == AIR_STEP_HIT_WALL then

        mario_set_forward_vel(m, -16.0)
        if m.vel.y > 0.0 then m.vel.y = 0.0 end
        m.particleFlags = (m.particleFlags or 0)
            | (PARTICLE_VERTICAL_STAR or (1 << 1))
        set_mario_action(m, ACT_BACKWARD_AIR_KB, 0)
        return false
    end

    add_gfx_yaw(m, turned)
    return false
end

local DASH_POSE = CHAR_ANIM_DIVE or 136

moves.dashLeft = moves.dashLeft or 0

function moves.dash_yaw(m)
    if m == nil then return 0 end
    if (m.intendedMag or 0) > 0 and m.intendedYaw ~= nil then
        local eighth = 0x2000
        local snapped = math.floor((m.intendedYaw + eighth / 2) / eighth) * eighth

        return ((snapped + 0x8000) % 0x10000) - 0x8000
    end
    return m.faceAngle.y
end

local function act_dash(m)
    if m == nil then return false end

    local stop = moves.stop_for(m, "dash")
    if stop == nil or stop.frames == nil then
        if m.playerIndex == 0 then set_mario_action(m, ACT_FREEFALL, 0) end
        return false
    end

    m.actionTimer = m.actionTimer + 1
    if m.actionTimer > stop.frames then

        mario_set_forward_vel(m, stop.speed / 2)
        set_mario_action(m, ACT_FREEFALL, 0)
        return false
    end

    m.vel.y = 0
    m.peakHeight = m.pos.y
    mario_set_forward_vel(m, stop.speed)
    set_character_animation(m, DASH_POSE)

    local step = perform_air_step(m, 0)
    if step == AIR_STEP_LANDED then
        set_mario_action(m, ACT_FREEFALL_LAND, 0)
    elseif step == AIR_STEP_HIT_WALL then

        mario_set_forward_vel(m, 0)
        set_mario_action(m, ACT_AIR_HIT_WALL, 0)
    end
    return false
end

function moves.try_dash(m)
    if DASH == nil or m == nil or m.playerIndex ~= 0 then return false end
    local stop = moves.stop("dash")
    if stop == nil or stop.frames == nil then return false end

    local action = m.action or 0
    local airborne = OF.util.action_group(action)
        == OF.util.action_group(ACT_GROUP_AIRBORNE)
    if not airborne then

        moves.dashLeft = stop.charges or 1
        return false
    end

    if stop.refill and action == ACT_WALL_KICK_AIR
        and moves.dashWas ~= ACT_WALL_KICK_AIR then
        moves.dashLeft = math.max(moves.dashLeft or 0, 1)
    end
    moves.dashWas = action

    if action == DASH then return false end
    local pad = m.controller
    local pressed = pad ~= nil and pad.buttonPressed or 0
    if not OF.util.has_flag(pressed, X_BUTTON or 0x0040) then return false end
    if (moves.dashLeft or 0) < 1 then return false end

    m.faceAngle.y = moves.dash_yaw(m)
    set_mario_action(m, DASH, 0)
    if m.action ~= DASH then return false end
    moves.dashLeft = moves.dashLeft - 1
    return true
end

if ROLL ~= nil then at_load("hook_mario_action", ROLL, { every_frame = act_roll }) end
if SPIN ~= nil then at_load("hook_mario_action", SPIN, { every_frame = act_spin }) end

if SPINJUMP ~= nil then
    at_load("hook_mario_action", SPINJUMP,
        { every_frame = act_spin_jump, gravity = spin_jump_gravity })
end
if SPINPOUND ~= nil then
    at_load("hook_mario_action", SPINPOUND, { every_frame = act_spin_pound })
end
if DASH ~= nil then at_load("hook_mario_action", DASH, { every_frame = act_dash }) end
moves.act_dash = act_dash

moves.MARIO, moves.LUIGI, moves.WARIO, moves.YOSHI = 1, 2, 3, 4
moves.CLASS_NAMES = { "Mario", "Luigi", "Wario", "Yoshi" }

function moves.my_class()
    local stop = moves.stop("class")
    if stop == nil then return 0 end
    if stop.dealt == true then
        return moves.dealt_for(network_global_index_from_local ~= nil
            and network_global_index_from_local(0) or 0)
    end
    return stop.class or 0
end

function moves.dealt_for(globalIndex)
    return (math.floor(globalIndex or 0) % 4) + 1
end

function moves.class_of(localIndex)
    if localIndex == nil then return 0 end
    if localIndex == 0 then return moves.my_class() end
    local row = gPlayerSyncTable[localIndex]
    local class = row ~= nil and tonumber(row.ofClass) or 0
    class = math.floor(class or 0)
    if class < 1 or class > 4 then return 0 end
    return class
end

moves.LUIGI_SCUTTLE = -12
moves.SCUTTLE_FRAMES = 60
moves.LUIGI_SLIDE = 0.6
moves.WARIO_TOP = 27.2
moves.WARIO_KICK = 42.6
moves.WARIO_HIT = 2.2
moves.YOSHI_FLUTTER = 4
moves.FLUTTER_FRAMES = 30

moves.LUIGI_JUMP = 1.15
moves.LEG_STEP = { [2] = 3, [4] = 2 }
moves.WARIO_LUNGE = 26
moves.WARIO_POP = 36
moves.WARIO_KICK_PUSH = 40
moves.legFrame = moves.legFrame or {}

moves.GULP_REACH = 150
moves.GULP_CONE = 0x2000
moves.MOUTH_FRAMES = 90
moves.MASH_OUT = 30
moves.SPIT_AHEAD = 100
moves.GULP_ACK = 10
moves.BURST_HOLD = 30
moves.FULL_SPEED = 28

local SWALLOWED = at_load("allocate_mario_action",
    ACT_GROUP_AUTOMATIC | ACT_FLAG_STATIONARY | ACT_FLAG_INTANGIBLE
        | ACT_FLAG_INVULNERABLE)
moves.SWALLOWED = SWALLOWED

local class = { gulp = nil, gulpFrames = 0, acked = false,
                mouth = nil, mouthLeft = 0, mouthCount = 0, burstHold = 0,
                scuttle = 0, flutter = 0, prevSpeed = 0 }
moves.classState = class

local function sfx(m, sound)
    if sound ~= nil and m ~= nil and m.marioObj ~= nil then
        OF.util.optional("play_sound", nil, sound,
            m.marioObj.header.gfx.cameraToObject)
    end
end

local function here(localIndex)
    if localIndex == nil or localIndex == 0 then return false end
    local together = OF.together
    if together == nil or type(together.still_there) ~= "function" then return false end
    return together.still_there(network_global_index_from_local(localIndex)) ~= nil
end

function moves.gulp_target(m)
    local best, bestGap = nil, moves.GULP_REACH + 1
    for _, entry in ipairs(OF.util.connected_players()) do
        local i = entry.localIndex
        local them = gMarioStates[i]
        if i ~= 0 and them ~= nil and here(i) and them.action ~= ACT_BUBBLED
            and them.action ~= SWALLOWED then
            local dx, dz = them.pos.x - m.pos.x, them.pos.z - m.pos.z
            local gap = math.sqrt(dx * dx + dz * dz)
            local dy = math.abs(them.pos.y - m.pos.y)
            local off = (atan2s(dz, dx) - m.faceAngle.y + 0x8000) % 0x10000 - 0x8000
            if gap < bestGap and dy < 160 and math.abs(off) <= moves.GULP_CONE then
                best, bestGap = i, gap
            end
        end
    end
    return best
end

function moves.yoshi_b(m)
    if moves.my_class() ~= moves.YOSHI or SWALLOWED == nil then return nil end
    if class.gulp ~= nil then
        if class.gulpFrames >= 1 then moves.spit() end
        return 1
    end
    local target = moves.gulp_target(m)
    if target == nil then return nil end
    class.gulp = network_global_index_from_local(target)
    class.gulpFrames = 0
    class.acked = false
    OF.util.publish_row(0, "ofGulp", class.gulp + 1)
    sfx(m, SOUND_GENERAL_YOSHI_TALK)
    return 1
end

function moves.spit()
    if class.gulp == nil then return false end
    class.gulp = nil
    class.acked = false
    OF.util.publish_row(0, "ofGulp", 0)
    return true
end

function moves.leave_mouth(m, eater, burst)
    local eaterGlobal = class.mouth
    class.mouth = nil
    if eater ~= nil and eater.pos ~= nil then
        local yaw = eater.faceAngle.y
        m.pos.x = eater.pos.x + sins(yaw) * moves.SPIT_AHEAD
        m.pos.z = eater.pos.z + coss(yaw) * moves.SPIT_AHEAD
        m.pos.y = eater.pos.y + 40
        m.faceAngle.y = yaw
        mario_set_forward_vel(m, burst and 20 or 32)
        m.vel.y = 20
        set_mario_action(m, ACT_THROWN_FORWARD, 0)
    else
        m.vel.y = 0
        set_mario_action(m, ACT_FREEFALL, 0)
    end
    m.invincTimer = 30
    if burst and eaterGlobal ~= nil then
        OF.util.publish_row(0, "ofMouth", -(eaterGlobal + 1))
        class.burstHold = moves.BURST_HOLD
    else
        OF.util.publish_row(0, "ofMouth", 0)
    end
    return true
end

local function act_swallowed(m)
    if m == nil or m.pos == nil then return false end
    local node = m.marioObj ~= nil and m.marioObj.header.gfx.node or nil
    if node ~= nil then
        node.flags = OF.util.add_flag(node.flags, GRAPH_RENDER_INVISIBLE)
    end
    m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
    m.forwardVel = 0
    if m.playerIndex ~= 0 then return false end

    local eaterIndex = class.mouth ~= nil and OF.util.local_from_global(class.mouth) or nil
    local eater = eaterIndex ~= nil and here(eaterIndex) and gMarioStates[eaterIndex] or nil
    if eater == nil or moves.round_holds() then
        moves.leave_mouth(m, nil, false)
        return false
    end
    m.pos.x, m.pos.y, m.pos.z = eater.pos.x, eater.pos.y + 60, eater.pos.z

    local pressed = m.controller ~= nil and m.controller.buttonPressed or 0
    if OF.util.has_flag(pressed, A_BUTTON)
        or (OF.util.has_flag(pressed, B_BUTTON) and not moves.b_refused()) then
        class.mouthCount = class.mouthCount + 1
        class.mouthLeft = class.mouthLeft - 1
    end
    class.mouthLeft = class.mouthLeft - 1

    local row = gPlayerSyncTable[eaterIndex]
    local still = row ~= nil and row.ofGulp == network_global_index_from_local(0) + 1
    if class.mouthCount >= moves.MASH_OUT then
        moves.leave_mouth(m, eater, true)
    elseif not still or class.mouthLeft <= 0 or moves.class_of(eaterIndex) ~= moves.YOSHI then
        moves.leave_mouth(m, eater, false)
    end
    return false
end
moves.act_swallowed = act_swallowed

if SWALLOWED ~= nil then
    at_load("hook_mario_action", SWALLOWED, { every_frame = act_swallowed })
end

local function swallowable(m)
    if moves.step("class") == 1 or moves.round_holds() then return false end
    if m.action == ACT_BUBBLED or (m.invincTimer or 0) > 0 then return false end
    if OF.util.action_group(m.action) == OF.util.action_group(ACT_GROUP_CUTSCENE) then
        return false
    end
    local together = OF.together
    if together ~= nil and together.ACT_CARRIED ~= nil
        and m.action == together.ACT_CARRIED then
        return false
    end
    return true
end

local function into_a_mouth(m)
    if SWALLOWED == nil or m.action == SWALLOWED or not swallowable(m) then return end
    local mine = network_global_index_from_local(0) + 1
    for _, entry in ipairs(OF.util.connected_players()) do
        local i = entry.localIndex
        local row = gPlayerSyncTable[i]
        if i ~= 0 and row ~= nil and row.ofGulp == mine
            and moves.class_of(i) == moves.YOSHI and here(i) then
            local them = gMarioStates[i]
            local dx, dz = them.pos.x - m.pos.x, them.pos.z - m.pos.z
            if dx * dx + dz * dz <= 300 * 300 then
                class.mouth = network_global_index_from_local(i)
                class.mouthLeft = moves.MOUTH_FRAMES
                class.mouthCount = 0
                OF.util.publish_row(0, "ofMouth", class.mouth + 1)
                if drop_and_set_mario_action ~= nil then
                    drop_and_set_mario_action(m, SWALLOWED, 0)
                else
                    set_mario_action(m, SWALLOWED, 0)
                end
                return
            end
        end
    end
end

local function hold_a_mouth(m)
    if class.gulp == nil then return end
    if moves.my_class() ~= moves.YOSHI then moves.spit(); return end
    local inside = OF.util.local_from_global(class.gulp)
    if inside == nil or not here(inside) then moves.spit(); return end
    local mine = network_global_index_from_local(0) + 1
    local said = gPlayerSyncTable[inside] ~= nil and gPlayerSyncTable[inside].ofMouth or nil
    if said == mine then
        class.acked = true
    elseif class.acked then

        if said == -mine then
            m.hurtCounter = (m.hurtCounter or 0) + 4
            m.invincTimer = 30
            set_mario_action(m, OF.util.has_flag(m.action or 0, ACT_FLAG_AIR)
                and ACT_BACKWARD_AIR_KB or ACT_BACKWARD_GROUND_KB, 0)
        end
        moves.spit()
        return
    elseif class.gulpFrames > moves.GULP_ACK then
        moves.spit()
        return
    end
    if class.acked and (m.forwardVel or 0) > moves.FULL_SPEED then
        mario_set_forward_vel(m, moves.FULL_SPEED)
    end
    class.gulpFrames = class.gulpFrames + 1
end

local function in_a_jump(m)
    return m.action == ACT_JUMP or m.action == ACT_DOUBLE_JUMP
        or m.action == ACT_FREEFALL
end

function moves.class_watch(m)
    if m == nil or m.playerIndex ~= 0 then return end
    local mine = moves.my_class()
    local row = gPlayerSyncTable[0]
    if row ~= nil and (tonumber(row.ofClass) or 0) ~= mine then
        OF.util.publish_row(0, "ofClass", mine)
    end
    if class.burstHold > 0 then
        class.burstHold = class.burstHold - 1
        if class.burstHold <= 0 then OF.util.publish_row(0, "ofMouth", 0) end
    end
    into_a_mouth(m)
    hold_a_mouth(m)
    if mine == 0 then return end

    local grounded = not OF.util.has_flag(m.action or 0, ACT_FLAG_AIR)
    if grounded then class.scuttle, class.flutter = 0, 0 end
    local holdingA = OF.util.has_flag(m.input or 0, INPUT_A_DOWN)

    if mine == moves.LUIGI then

        if in_a_jump(m) and holdingA and m.vel.y < moves.LUIGI_SCUTTLE
            and class.scuttle < moves.SCUTTLE_FRAMES then
            m.vel.y = moves.LUIGI_SCUTTLE
            class.scuttle = class.scuttle + 1

            if class.scuttle % 6 == 1 then
                m.particleFlags = OF.util.add_flag(m.particleFlags, PARTICLE_DUST)
            end
        end

        if m.action == ACT_BACKFLIP and m.vel.y < 0 and holdingA then
            set_mario_action(m, ACT_TWIRLING, 0)
        end

        if (m.action == ACT_BRAKING or m.action == ACT_DECELERATING)
            and m.forwardVel < class.prevSpeed and m.forwardVel > 0 then
            mario_set_forward_vel(m, class.prevSpeed
                - (class.prevSpeed - m.forwardVel) * moves.LUIGI_SLIDE)
        end
    elseif mine == moves.WARIO then
        if m.action == ACT_WALKING and m.forwardVel > moves.WARIO_TOP then
            mario_set_forward_vel(m, moves.WARIO_TOP)
        end
    elseif mine == moves.YOSHI then

        if in_a_jump(m) and holdingA and m.vel.y < moves.YOSHI_FLUTTER
            and class.flutter < moves.FLUTTER_FRAMES then
            m.vel.y = math.min(m.vel.y + 6, moves.YOSHI_FLUTTER)
            class.flutter = class.flutter + 1
        end
    end
    class.prevSpeed = m.forwardVel or 0
end

function moves.leg_off(seat)
    moves.legFrame[seat] = nil
    return false
end

function moves.class_look(m)
    if m == nil or m.pos == nil then return false end
    local seat = m.playerIndex or 0
    local mine = moves.class_of(seat)

    if mine ~= moves.LUIGI and mine ~= moves.YOSHI then return moves.leg_off(seat) end
    if not in_a_jump(m) or m.vel.y > moves.YOSHI_FLUTTER then return moves.leg_off(seat) end
    local held = m.controller ~= nil
        and OF.util.has_flag(m.controller.buttonDown or 0, A_BUTTON)
    if not held then return moves.leg_off(seat) end
    if mine == moves.LUIGI and m.vel.y > moves.LUIGI_SCUTTLE + 0.5 then return moves.leg_off(seat) end
    set_character_animation(m, CHAR_ANIM_RUNNING)

    local loop = 20
    local info = m.marioObj ~= nil and m.marioObj.header ~= nil
        and m.marioObj.header.gfx.animInfo or nil
    local anim = info ~= nil and info.curAnim or nil
    if anim ~= nil and type(anim.loopEnd) == "number" and anim.loopEnd > 1 then
        loop = anim.loopEnd
    end
    local at = ((moves.legFrame[seat] or 0) + (moves.LEG_STEP[mine] or 2)) % loop
    moves.legFrame[seat] = at
    OF.util.optional("set_anim_to_frame", nil, m, at)
    return true
end

local LUIGI_JUMPS = { "ACT_JUMP", "ACT_DOUBLE_JUMP", "ACT_TRIPLE_JUMP",
    "ACT_BACKFLIP", "ACT_SIDE_FLIP", "ACT_WALL_KICK_AIR" }

function moves.class_set_action(m)
    if m == nil or m.playerIndex ~= 0 then return end
    local mine = moves.my_class()
    if mine == moves.LUIGI then
        for _, name in ipairs(LUIGI_JUMPS) do
            if m.action == _G[name] and (m.vel.y or 0) > 0 then
                m.vel.y = m.vel.y * moves.LUIGI_JUMP
                return
            end
        end
    elseif mine == moves.WARIO then
        if m.action == ACT_WALL_KICK_AIR then
            m.vel.y = moves.WARIO_KICK
            m.forwardVel = moves.WARIO_KICK_PUSH
            m.particleFlags = OF.util.add_flag(m.particleFlags, PARTICLE_VERTICAL_STAR)
            sfx(m, SOUND_ACTION_HIT_3)
        elseif m.action == ACT_PUNCHING or m.action == ACT_MOVE_PUNCHING then
            if (m.forwardVel or 0) < moves.WARIO_LUNGE then
                m.forwardVel = moves.WARIO_LUNGE
            end
            m.particleFlags = OF.util.add_flag(m.particleFlags, PARTICLE_HORIZONTAL_STAR)
            sfx(m, SOUND_ACTION_HIT_3)
        end
    end
end

function moves.heavy_hit(attacker, victim)
    if attacker == nil or victim == nil or victim.playerIndex ~= 0 then return false end
    if moves.class_of(attacker.playerIndex) ~= moves.WARIO then return false end
    if moves.round_holds() then return false end
    local speed = (victim.forwardVel or 0) * moves.WARIO_HIT
    if speed > 48 then speed = 48 end
    if speed < -48 then speed = -48 end
    mario_set_forward_vel(victim, speed)
    if OF.util.has_flag(victim.action or 0, ACT_FLAG_AIR) and victim.vel.y < moves.WARIO_POP then
        victim.vel.y = moves.WARIO_POP
    end
    return true
end

hook_event(HOOK_ON_PVP_ATTACK, function(attacker, victim)
    moves.heavy_hit(attacker, victim)
end)

moves.REV_STEP = 2
moves.REV_MOST = 8
moves.REV_KEEP = (31 / 32) * (31 / 32)
moves.REV_LOW = 43
moves.REV_HIGH = 64
moves.REV_ARG = 1

moves.ROLL_DOWNHILL = 3.34
moves.ROLL_UPHILL = 0.83
moves.ROLL_TOP = 72

local REV = at_load("allocate_mario_action",
    ACT_GROUP_STATIONARY | ACT_FLAG_STATIONARY | ACT_FLAG_SHORT_HITBOX)
moves.REV = REV

local rev = { charge = 0 }
moves.revState = rev

function moves.rev_speed(charge)
    local c = OF.util.clamp(charge or 0, 0, moves.REV_MOST)
    return moves.REV_LOW + c * (moves.REV_HIGH - moves.REV_LOW) / moves.REV_MOST
end

local function rev_sound(m)
    if SOUND_ACTION_SPIN == nil or m.marioObj == nil then return end
    OF.util.optional("play_sound_with_freq_scale", nil, SOUND_ACTION_SPIN,
        m.marioObj.header.gfx.cameraToObject, 1.0 + 0.6 * rev.charge / moves.REV_MOST)
end

local function act_rev(m)
    if m == nil then return false end
    wear_ball(m)
    if m.playerIndex ~= 0 then return false end

    if moves.setting("roll", "rev") ~= true then
        set_mario_action(m, ACT_CROUCHING, 0)
        return false
    end
    if (m.intendedMag or 0) > 0 then m.faceAngle.y = m.intendedYaw end
    if m.actionTimer == 0 then
        rev.charge = moves.REV_STEP
        rev_sound(m)
    else

        if not OF.util.has_flag(m.input or 0, INPUT_Z_DOWN) then
            mario_set_forward_vel(m, moves.rev_speed(rev.charge))
            set_mario_action(m, ROLL, moves.REV_ARG)
            return false
        end
        if OF.util.has_flag(m.input or 0, INPUT_A_PRESSED) then
            set_mario_action(m, ACT_JUMP, 0)
            return false
        end
        rev.charge = rev.charge * moves.REV_KEEP
        if OF.util.has_flag(m.input or 0, INPUT_B_PRESSED) and not moves.b_refused() then
            rev.charge = math.min(rev.charge + moves.REV_STEP, moves.REV_MOST)
            rev_sound(m)
            m.particleFlags = OF.util.add_flag(m.particleFlags, PARTICLE_DUST)
        end
    end
    m.actionTimer = m.actionTimer + 1
    mario_set_forward_vel(m, 0)
    if perform_ground_step(m) == GROUND_STEP_LEFT_GROUND then
        set_mario_action(m, ACT_FREEFALL, 0)
    end
    return false
end
moves.act_rev = act_rev

if REV ~= nil then at_load("hook_mario_action", REV, { every_frame = act_rev }) end

function moves.sonic_slope(m)
    local floor = m ~= nil and m.floor or nil
    if floor == nil or floor.normal == nil then return 0 end
    local nx, nz = floor.normal.x or 0, floor.normal.z or 0
    local steep = math.sqrt(nx * nx + nz * nz)
    if steep < 0.01 then return 0 end
    local downhill = atan2s(nz, nx)
    local along = coss(((m.faceAngle.y - downhill + 0x8000) % 0x10000) - 0x8000)
    local add
    if along > 0 then
        add = moves.ROLL_DOWNHILL * steep * along
    else
        add = moves.ROLL_UPHILL * steep * along
    end
    local speed = math.min((m.forwardVel or 0) + add, moves.ROLL_TOP)
    mario_set_forward_vel(m, speed)
    return add
end

function moves.substitute_move(m, action, actionArg)
    if m == nil or m.playerIndex ~= 0 or moves.quiet() then return end

    if (action == ACT_PUNCHING or action == ACT_MOVE_PUNCHING
            or action == ACT_JUMP_KICK) and moves.b_refused() then
        return
    end

    if moves.REV ~= nil and moves.setting("roll", "rev") == true
        and actionArg == 9 and action == ACT_PUNCHING
        and m.action == ACT_CROUCHING then
        return moves.REV
    end

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

    if actionArg == 0 and (action == ACT_PUNCHING or action == ACT_MOVE_PUNCHING) then
        local spent = moves.yoshi_b(m)
        if spent ~= nil then return spent end
    end

    if SPINJUMP ~= nil and moves.setting("spinjump", "lift") ~= nil
        and moves.spin_armed()
        and (action == ACT_JUMP or action == ACT_DOUBLE_JUMP)
        and not OF.util.has_flag(m.action or 0, AIR_FLAG) then
        return SPINJUMP
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

        local fromInto = moves.setting("into", "fromInto")
        local leaving = fromInto ~= nil and fromInto[action] or nil
        if leaving ~= nil and leaving[m.action] then
            return ROLL
        end
    end

    return
end

function moves.after_set_action(m)
    if m == nil or m.playerIndex ~= 0 or moves.quiet() then return end

    moves.class_set_action(m)

    if m.action == ACT_WALL_KICK_AIR then
        local lift = moves.setting("wall", "lift")
        if lift ~= nil then
            m.vel.y = m.vel.y + lift
            mario_set_forward_vel(m,
                (m.forwardVel or 0) + (moves.setting("wall", "push") or 0))
        end
    end

    if m.action == ACT_GROUND_POUND then
        moves.pounded = m.forwardVel or 0
    end

    if SPINJUMP ~= nil and m.action == SPINJUMP then
        local lift = moves.setting("spinjump", "lift")
        if lift ~= nil then m.vel.y = lift end
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

local CHARGE_PARTICLE = PARTICLE_SPARKLES or (1 << 3)

local function show_the_charge(m)
    if not moves.setting("windup", "show") then return false end
    m.particleFlags = (m.particleFlags or 0) | CHARGE_PARTICLE
    return true
end

local WEDGE_TICKS = 4

local WEDGE_FLOOR = 0x200

local function bill_the_overcharge(m)
    if not moves.setting("windup", "cost") then return false end
    local full = moves.setting("windup", "full")
    if full == nil or (moves.crouched or 0) ~= full + 1 then return false end
    if (m.health or 0) < WEDGE_FLOOR then return false end
    m.hurtCounter = (m.hurtCounter or 0) + WEDGE_TICKS
    return true
end

local BODY_REACH = 120
local BODY_OVER = 200
local BODY_UNDER = 100

local function body_in_reach(m)
    local me = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if me == nil or m.pos == nil then return nil end
    if not OF.util.asks(OF.util, "connected_players") then return nil end

    local best, bestSquare = nil, BODY_REACH * BODY_REACH
    for _, other in ipairs(OF.util.connected_players()) do
        local np = other.np

        if other.localIndex ~= 0 and np ~= nil
            and np.currLevelNum == me.currLevelNum
            and np.currAreaIndex == me.currAreaIndex
            and np.currPositionValid ~= false then
            local om = gMarioStates[other.localIndex]
            if om ~= nil and om.pos ~= nil then
                local dy = (tonumber(m.pos.y) or 0) - (tonumber(om.pos.y) or 0)
                if dy <= BODY_OVER and dy >= -BODY_UNDER then
                    local dx = (tonumber(m.pos.x) or 0) - (tonumber(om.pos.x) or 0)
                    local dz = (tonumber(m.pos.z) or 0) - (tonumber(om.pos.z) or 0)
                    local square = dx * dx + dz * dz
                    if square < bestSquare then best, bestSquare = om, square end
                end
            end
        end
    end
    return best
end

local function kick_off_a_body(m)
    if ACT_WALL_KICK_AIR == nil then return false end
    if not moves.setting("wall", "players") then return false end
    if not OF.util.has_flag(m.action or 0, ACT_FLAG_AIR) then return false end
    if m.action == ACT_WALL_KICK_AIR then return false end
    if not OF.util.has_flag(m.input or 0, INPUT_A_PRESSED) then return false end

    local om = body_in_reach(m)
    if om == nil then return false end

    local away = OF.util.optional("atan2s", nil,
        (tonumber(m.pos.z) or 0) - (tonumber(om.pos.z) or 0),
        (tonumber(m.pos.x) or 0) - (tonumber(om.pos.x) or 0))
    if away ~= nil and m.faceAngle ~= nil then
        m.faceAngle.y = (away + 0x8000) % 0x10000 - 0x8000
    end
    set_mario_action(m, ACT_WALL_KICK_AIR, 0)
    return true
end

local WALL_KICK_COYOTE = 3

local WALL_KICK_RAY = 100.0

local function ray_finds_a_wall(m)
    if m == nil or m.pos == nil or m.faceAngle == nil then return nil end

    local dirX = OF.util.optional("sins", nil, m.faceAngle.y)
    local dirZ = OF.util.optional("coss", nil, m.faceAngle.y)
    if dirX == nil or dirZ == nil then return nil end

    local info = OF.util.optional("collision_find_surface_on_ray", nil,
        m.pos.x, m.pos.y, m.pos.z,
        dirX * WALL_KICK_RAY, 0, dirZ * WALL_KICK_RAY)
    local surf = info ~= nil and info.surface or nil
    if surf == nil or surf.normal == nil then return nil end

    if surf.type == SURFACE_BURNING or surf.type == SURFACE_CAMERA_BOUNDARY
        or surf.type == SURFACE_RAYCAST then
        return nil
    end
    if surf.type == SURFACE_VANISH_CAP_WALLS
        and OF.util.has_flag(m.flags or 0, MARIO_VANISH_CAP or 0) then
        return nil
    end

    local ny = tonumber(surf.normal.y) or 1.0
    if ny > -0.01 and ny < 0.01 then return surf end
    return nil
end

local function kick_off_a_stale_wall(m)
    if ACT_WALL_KICK_AIR == nil then return false end
    if (moves.wallCoyote or 0) <= 0 then return false end
    if not OF.util.has_flag(m.action or 0, ACT_FLAG_AIR) then return false end
    if m.action == ACT_WALL_KICK_AIR then return false end
    if not OF.util.has_flag(m.input or 0, INPUT_A_PRESSED) then return false end

    local surf = ray_finds_a_wall(m)
    if surf == nil then return false end

    m.wall = surf
    if m.wallNormal ~= nil then
        m.wallNormal.x = surf.normal.x
        m.wallNormal.z = surf.normal.z
    end

    local away = OF.util.optional("atan2s", nil, surf.normal.z, surf.normal.x)
    if away ~= nil and m.faceAngle ~= nil then m.faceAngle.y = away end

    set_mario_action(m, ACT_WALL_KICK_AIR, 0)
    moves.wallCoyote = 0
    return true
end

function moves.watch(m)

    moves.class_look(m)
    if m == nil or m.playerIndex ~= 0 then return end

    moves.class_watch(m)

    moves.settle_the_reach(m)

    if moves.quiet() then

        moves.spinArmed = 0

        moves.wallCoyote = 0
        return
    end

    if m.prevAction == ACT_AIR_HIT_WALL then
        moves.wallCoyote = WALL_KICK_COYOTE
    elseif (moves.wallCoyote or 0) > 0 then
        moves.wallCoyote = moves.wallCoyote - 1
    end

    moves.read_the_spin(m)

    local wasAction = moves.wasAction
    moves.wasAction = m.action

    if moves.try_dash(m) then return end

    moves.sprint_row(m)

    if m.action == ACT_CROUCHING or m.action == ACT_START_CROUCHING then
        moves.crouched = (moves.crouched or 0) + 1
        show_the_charge(m)
        bill_the_overcharge(m)
    elseif m.action ~= ACT_BACKFLIP then

        moves.crouched = 0
    end

    if ROLL ~= nil and m.action == ACT_START_CRAWLING
        and moves.setting("roll", "frames") ~= nil
        and OF.util.has_flag(m.input or 0, INPUT_B_PRESSED)
        and OF.util.has_flag(m.input or 0, INPUT_Z_DOWN)
        and not moves.b_refused() then
        set_mario_action(m, ROLL, 0)
        return
    end

    if wasAction == m.action and kick_off_a_body(m) then
        return
    end

    if wasAction == m.action and moves.setting("wall", "lift") ~= nil
        and kick_off_a_stale_wall(m) then
        return
    end

    local lift = moves.setting("pound", "lift")
    if lift ~= nil and m.action == ACT_GROUND_POUND_LAND
        and OF.util.has_flag(m.input or 0, INPUT_A_PRESSED) then

        local perUnit = moves.setting("pound", "perUnit")
        if perUnit ~= nil then
            local fell = (m.peakHeight or m.pos.y) - m.pos.y
            if fell < 0 then fell = 0 end
            lift = lift + fell * perUnit
            local most = moves.setting("pound", "most")
            if most ~= nil and lift > most then lift = most end
        end

        local kept = moves.setting("pound", "keep") and (moves.pounded or 0) or nil

        set_mario_action(m, ACT_JUMP, 0)
        m.vel.y = lift

        if kept ~= nil and kept > 0 then mario_set_forward_vel(m, kept) end
        moves.pounded = 0
        return
    end

    local speed = moves.setting("dive", "speed")
    if speed ~= nil and m.action == ACT_GROUND_POUND and m.actionState == 1
        and OF.util.has_flag(m.input or 0, INPUT_B_PRESSED)
        and not moves.b_refused() then
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

    table.insert(rows, panel.with_help(panel.gated_row("speedrun",
        OF.lang.t("Reset this page"), 255, 140, 90,
        function() OF.util.report(moves.clear(0)) end),
        OF.lang.t("every move in the lobby's boxes, back to the game's own")))
    table.insert(rows, panel.with_help(panel.gated_row(MINE_NEED,
        OF.lang.t("Reset this page, your own boxes only"), 255, 140, 90,
        function() OF.util.report(moves.clear_mine_press()) end),
        OF.lang.t("every box of your own emptied, so the lobby's apply again")))

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

    for _, row in ipairs(moves.ROWS) do
        local key = row.key

        local roomStep = moves.wanted_step(key)
        local roomOn = roomStep ~= row.plain
        local mine = moves.mine_state(key)

        local lobbyNeed = "speedrun"
        local help = OF.util.say_buttons(OF.lang.t(row.help), true)
        if moves.suspended(key) then
            help = OF.lang.t("put away until the round ends - your setting is kept")
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

        local roomStop = roomOn and OF.util.say_buttons(OF.lang.t(row.steps[roomStep].name), true) or nil
        local mineStep = nil
        if mine == false then mineStep = row.plain
        elseif mine == true then mineStep = moves.mine_step(key) end
        local mineStop = (mineStep ~= nil and row.steps[mineStep] ~= nil)
            and OF.util.say_buttons(OF.lang.t(row.steps[mineStep].name), true) or nil
        local column, youPart = panel.two_box_column(roomStop, mineStop, mine ~= nil)
        built = panel.level_right(built, column ~= nil, column)
        built.rightMine = youPart

        local function name_at(stepAt)
            if stepAt == nil then return OF.lang.t("follow lobby") end
            local said = row.steps[stepAt]
            return said ~= nil and OF.util.say_buttons(OF.lang.t(said.name), true) or tostring(stepAt)
        end
        local mineNext = panel.next_mine_level(mine,
            moves.mine_step(key) - row.plain,
            #row.steps - row.plain, roomStep - row.plain)
        local roomNextAt = roomStep + 1
        if roomNextAt > #row.steps then roomNextAt = 1 end
        built = panel.two_slider(built, {
            steps = #row.steps - 1, room = roomStep - 1,
            mine = mineStep ~= nil and (mineStep - 1) or nil,
            mayRoom = panel.may(lobbyNeed), mayMine = panel.may(MINE_NEED),
            setRoom = function(wanted)
                OF.util.report(moves.set_step(key, wanted + 1, false, 0))
            end,
            setMine = function(wanted)
                OF.util.report(moves.set_mine_step(key, wanted + 1))
            end,
            clearMine = function() OF.util.report(moves.set_mine(key, nil)) end,
            roomNext = name_at(roomNextAt),
            mineNext = name_at(mineNext ~= nil and (mineNext + row.plain) or nil),
        })
        table.insert(rows, built)
    end

    if moves.step("into") ~= moves.BY_KEY["into"].plain
        and moves.setting("roll", "frames") == nil then
        table.insert(rows, panel.label_row(
            OF.lang.t("The ways in do nothing until Ground roll is on.")))
    end

    if ROLL == nil or SPIN == nil or SPINJUMP == nil or SPINPOUND == nil then
        table.insert(rows, panel.label_row(
            OF.lang.t("This build has no custom actions - four of these rows are off.")))
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

    if OF.util.asks(OF.net, "register_action") then
        OF.net.register_action(moves.ACTION, "speedrun", function(fromLocal, x, _, z)
            if not OF.util.is_host() then return false, "Only the host." end
            if tostring(z) == "clear" then return moves.clear(fromLocal) end
            return moves.set_step(tostring(z), tonumber(x), false, fromLocal)
        end)
    end
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
    moves.pounded = 0

    drop_the_spin()
    moves.spinArmed = 0
    moves.settle_the_reach(gMarioStates[0])
end)

function moves.count()
    local n = 0
    if ROLL ~= nil then n = n + 1 end
    if SPIN ~= nil then n = n + 1 end
    if SPINJUMP ~= nil then n = n + 1 end
    if SPINPOUND ~= nil then n = n + 1 end
    if DASH ~= nil then n = n + 1 end
    return n
end
