OF = OF or {}
OF.reins = OF.reins or {}

local reins = OF.reins

reins.KEY = "ofReins"
local function at_load(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if not ok then return nil end
    return result
end

local function now_frame()
    return at_load("get_global_timer") or 0
end

reins.MOBS = {
    { key = "goomba", name = "a Goomba", look = "goomba",
      top = 14, hop = 0.55, fall = 75, heavy = 0,
      help = "slow, and it cannot jump for toffee" },
    { key = "koopa", name = "a Koopa", look = "koopa",
      top = 20, hop = 0.80, fall = 75, heavy = 0,
      help = "a steady walk and a shorter hop" },
    { key = "shell", name = "a Koopa shell", look = "shell",
      top = 46, hop = 0.30, fall = 75, heavy = 0.6,
      help = "faster than anything on two legs, and it hardly leaves the floor" },
    { key = "spiny", name = "a Spiny", look = "spiny",
      top = 18, hop = 0.70, fall = 75, heavy = 0,
      help = "a Goomba that gets out more" },
    { key = "bobomb", name = "a Bob-omb", look = "bobomb",
      top = 16, hop = 0.60, fall = 75, heavy = 0,
      help = "a short fuse on short legs" },
    { key = "mole", name = "a Monty Mole", look = "montymole",
      top = 24, hop = 0.85, fall = 75, heavy = 0,
      help = "quick over the ground and no good above it" },
    { key = "bully", name = "a Bully", look = "bully",
      top = 26, hop = 0.65, fall = 75, heavy = 0.3,
      help = "it shoves first and thinks about it later" },
    { key = "chuckya", name = "a Chuckya", look = "chuckya",
      top = 18, hop = 0.90, fall = 75, heavy = 0.2,
      help = "heavy arms, heavier legs" },
    { key = "pokey", name = "a Pokey", look = "pokey",
      top = 12, hop = 0.50, fall = 75, heavy = 0,
      help = "the slowest thing in the desert" },
    { key = "blizzard", name = "a Mr. Blizzard", look = "blizzard",
      top = 12, hop = 0.45, fall = 75, heavy = 0,
      help = "it would rather stand still and throw something" },
    { key = "chomp", name = "a Chain Chomp", look = "chomp",
      top = 34, hop = 1.00, fall = 75, heavy = 0.4,
      help = "faster than you were, and it lands hard" },
    { key = "wiggler", name = "a Wiggler", look = "wiggler",
      top = 30, hop = 0.70, fall = 75, heavy = 0,
      help = "long and cross and surprisingly brisk" },

    { key = "flyguy", name = "a Fly Guy", look = "flyguy",
      top = 22, hop = 1.35, fall = 12, heavy = 0,
      help = "it drifts down like paper" },
    { key = "amp", name = "an Amp", look = "amp",
      top = 26, hop = 1.20, fall = 16, heavy = 0,
      help = "it hangs in the air and hums" },
    { key = "boo", name = "a Boo", look = "boo",
      top = 24, hop = 1.15, fall = 14, heavy = 0,
      help = "it floats, and it is not sorry" },
    { key = "swoop", name = "a Swoop", look = "swoop",
      top = 30, hop = 1.55, fall = 9, heavy = 0,
      help = "the best jump on the list and the softest landing" },
    { key = "sushi", name = "a Sushi", look = "sushi",
      top = 28, hop = 0.50, fall = 22, heavy = 0,
      help = "built for water and embarrassing on land" },

    { key = "thwomp", name = "a Thwomp", look = "thwomp",
      top = 10, hop = 0.35, fall = 75, heavy = 2.6,
      help = "it goes up slowly and comes down like the ceiling" },
    { key = "whomp", name = "a Whomp", look = "whomp",
      top = 13, hop = 0.40, fall = 75, heavy = 1.8,
      help = "a wall that decided to walk" },
    { key = "kingbobomb", name = "King Bob-omb", look = "kingbobomb",
      top = 20, hop = 1.10, fall = 75, heavy = 0.5,
      help = "royalty, and it can still get about" },
}

reins.MOB_BY_KEY = {}
for _, mob in ipairs(reins.MOBS) do reins.MOB_BY_KEY[mob.key] = mob end

local function mob_steps()
    local steps = { { name = "a surprise", roll = true } }
    for _, mob in ipairs(reins.MOBS) do
        table.insert(steps, { name = mob.name, mob = mob })
    end
    return steps
end

local LIVELY_STEPS = {
    { name = "sluggish",           scale = 0.6 },
    { name = "as the creature is", scale = 1.0 },
    { name = "quick",              scale = 1.5 },
    { name = "wound up",           scale = 2.2 },
}

local RIDE_STEPS = {
    { name = "until you get off" },
    { name = "half a minute",   seconds = 30 },
    { name = "a minute",        seconds = 60 },
    { name = "three minutes",   seconds = 180 },
    { name = "ten minutes",     seconds = 600 },
}

local OFF_STEPS = {
    { name = "you stand up where you are" },
    { name = "you go back to where you got on" },
    { name = "you drop to the floor under you" },
}

local TOLD_STEPS = {
    { name = "nobody" },
    { name = "the person it happens to" },
    { name = "the whole lobby" },
}

local PAD_STEPS = {
    { name = "the stick only",           stick = true },
    { name = "the stick and jump",       stick = true, jump = true },
    { name = "the stick and every move", stick = true, jump = true, face = true },
    { name = "the whole pad",            stick = true, jump = true, face = true,
      all = true },
}

local TURN_STEPS = {
    { name = "until I let go" },
    { name = "ten seconds",   seconds = 10 },
    { name = "half a minute", seconds = 30 },
    { name = "a minute",      seconds = 60 },
    { name = "three minutes", seconds = 180 },
}

local BACK_STEPS = {
    { name = "they carry on from there" },
    { name = "they go back to where I took the wheel" },
}

local WATCH_STEPS = {
    { name = "leave my camera alone" },
    { name = "over their shoulder", watch = true },
}

reins.ROWS = {
    { key = "mob", id = "mb", name = "What you ride",
      help = "the creature the next rider is given",
      steps = mob_steps(), plain = 1 },
    { key = "lively", id = "lv", name = "How lively it is",
      help = "one dial over the whole bestiary at once",
      steps = LIVELY_STEPS, plain = 2 },
    { key = "ride", id = "rd", name = "How long a ride lasts",
      help = "every ride ends by itself - this is when",
      steps = RIDE_STEPS, plain = 3 },
    { key = "off", id = "of", name = "When a ride ends",
      help = "where you are standing the moment you are yourself again",
      steps = OFF_STEPS, plain = 1 },
    { key = "told", id = "tl", name = "Who is told",
      help = "for a ride and for a turn at the wheel alike",
      steps = TOLD_STEPS, plain = 2 },
    { key = "pad", id = "pd", name = "The wheel takes",
      help = "how much of their pad the host is holding",
      steps = PAD_STEPS, plain = 2 },
    { key = "turn", id = "tn", name = "How long a turn lasts",
      help = "the wheel lets go by itself as well",
      steps = TURN_STEPS, plain = 3 },
    { key = "back", id = "bk", name = "When the turn ends",
      help = "leave them there, or put them back",
      steps = BACK_STEPS, plain = 1 },
    { key = "watch", id = "wt", name = "While I am driving",
      help = "the host's own camera, and nobody else's",
      steps = WATCH_STEPS, plain = 1 },
}

reins.BY_KEY = {}
for _, row in ipairs(reins.ROWS) do reins.BY_KEY[row.key] = row end

local function parse()
    local text = gGlobalSyncTable ~= nil and gGlobalSyncTable[reins.KEY] or nil
    if type(text) ~= "string" or text == "" then return {} end
    local set = {}
    for id, step in string.gmatch(text, "(%a%a):(%d+)") do
        set[id] = tonumber(step)
    end
    return set
end

local function pack(set)
    local parts = {}
    for _, row in ipairs(reins.ROWS) do
        local step = set[row.key] or row.plain
        if step ~= row.plain then
            table.insert(parts, row.id .. ":" .. tostring(step))
        end
    end
    return table.concat(parts, ",")
end

function reins.wire_width()
    local set = {}
    for _, row in ipairs(reins.ROWS) do

        set[row.key] = (#row.steps == row.plain) and 1 or #row.steps
    end
    return #pack(set)
end

function reins.round_holds()
    if not OF.util.asks(OF.lockdown, "menu_stands_down") then return false end
    return OF.lockdown.menu_stands_down() == true
end

function reins.step(key)
    local row = reins.BY_KEY[key]
    if row == nil then return 1 end
    if reins.round_holds() then return row.plain end
    local step = parse()[row.id]
    if type(step) ~= "number" or step < 1 or step > #row.steps then
        return row.plain
    end
    return step
end

function reins.stop(key)
    local row = reins.BY_KEY[key]
    if row == nil then return nil end
    return row.steps[reins.step(key)]
end

function reins.stop_name(key)
    local stop = reins.stop(key)
    if stop == nil then return "" end
    return stop.name
end

function reins.anything_on()
    for _, row in ipairs(reins.ROWS) do
        if reins.step(row.key) ~= row.plain then return true end
    end
    return false
end

function reins.label()
    if not reins.anything_on() then
        return OF.lang.t("as it comes out of the box")
    end
    local said = {}
    for _, row in ipairs(reins.ROWS) do
        local step = reins.step(row.key)
        if step ~= row.plain then
            table.insert(said, row.name .. ": " .. row.steps[step].name)
        end
    end
    return table.concat(said, ", ")
end

function reins.set_step(key, step, quiet)
    local row = reins.BY_KEY[key]
    if row == nil then return false, "There is no such row." end
    if type(step) ~= "number" then return false, "That is not a step." end

    step = math.floor(step)
    if step < 1 then step = 1 end
    if step > #row.steps then step = #row.steps end

    if not OF.perms.can("possess_other") then
        return false, OF.util.RANK_REFUSAL, "possess_other"
    end
    if not OF.util.is_host() then
        return false, "Only the host sets these."
    end
    if reins.round_holds() then
        return false, "A round has the lobby."
    end

    local set = {}
    for _, other in ipairs(reins.ROWS) do
        set[other.key] = reins.step(other.key)
    end
    set[key] = step
    OF.util.publish(reins.KEY, pack(set))

    if quiet then return true end
    return true, OF.lang.fill("@ is now @.",
        OF.lang.t(row.name), OF.lang.t(row.steps[step].name))
end

function reins.next_step(key)
    local row = reins.BY_KEY[key]
    if row == nil then return false, "There is no such row." end
    local step = reins.step(key) + 1
    if step > #row.steps then step = 1 end
    return reins.set_step(key, step)
end

function reins.clear()
    if not OF.perms.can("possess_other") then
        return false, OF.util.RANK_REFUSAL, "possess_other"
    end
    if not OF.util.is_host() then
        return false, "Only the host sets these."
    end
    OF.util.publish(reins.KEY, "")
    return true, "Every dial is back where it started."
end

function reins.text()
    local wire = gGlobalSyncTable ~= nil and gGlobalSyncTable[reins.KEY] or nil
    if type(wire) ~= "string" then return "" end
    return wire
end

function reins.put_text(text)
    if not OF.util.is_host() then return false end
    text = tostring(text or "")
    if reins.text() == text then return false end
    return OF.util.publish(reins.KEY, text) == true
end

reins.KIND = "mob"
reins.registered = false

if OF.offlimits ~= nil and type(OF.offlimits.register) == "function" then
    reins.registered = OF.offlimits.register({
        kind = reins.KIND, id = "b",
        name = "Creatures to ride", one = "creature",
        items = function()
            local out = {}
            for _, mob in ipairs(reins.MOBS) do
                table.insert(out, { id = mob.key, name = mob.name })
            end
            return out
        end,
    }) == true
end

function reins.pool()
    local out = {}
    for _, mob in ipairs(reins.MOBS) do table.insert(out, mob) end
    if OF.offlimits ~= nil and type(OF.offlimits.keep) == "function" then
        out = OF.offlimits.keep(reins.KIND, out, "key")
    end
    return out
end

function reins.roll()
    local pool = reins.pool()
    if #pool == 0 then return nil end
    return pool[OF.util.random_int(1, #pool)]
end

function reins.wanted_mob()
    local stop = reins.stop("mob")
    if stop == nil then return nil end
    if stop.mob == nil then return reins.roll() end
    if OF.offlimits ~= nil and type(OF.offlimits.allows) == "function"
        and not OF.offlimits.allows(reins.KIND, stop.mob.key) then
        return nil
    end
    return stop.mob
end

reins.riding = nil

local wasAir = false

function reins.riding_name()
    if reins.riding == nil then return "" end
    return reins.riding.mob.name
end

function reins.dressing_available()
    if OF.possess == nil then return false end
    if type(OF.possess.available) ~= "function" then return false end
    return OF.possess.available() == true
end

local function standing_here()
    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    if m == nil or m.pos == nil then return nil end
    return { x = m.pos.x, y = m.pos.y, z = m.pos.z }
end

local function wear(key)
    if not reins.dressing_available() then return false end
    if type(OF.possess.set) ~= "function" then return false end
    return OF.possess.set(0, key) == true
end

local function take_off(was)
    if OF.possess == nil or type(OF.possess.set) ~= "function" then return end
    if was ~= nil and OF.possess.set(0, was) == true then return end
    OF.possess.set(0, nil)
end

function reins.get_on(mob, seconds, lively)
    if mob == nil then return false, "Every creature is off limits." end
    if reins.round_holds() then return false, "A round has the lobby." end

    local scale = lively or 1.0
    local ends = nil
    if seconds ~= nil then ends = now_frame() + math.floor(seconds * 60) end

    local was = nil
    if OF.possess ~= nil and type(OF.possess.as) == "function" then
        was = OF.possess.as(0)
    end

    if reins.riding ~= nil then was = reins.riding.was end

    reins.riding = {
        mob = mob,
        top = mob.top * scale,
        hop = mob.hop * scale,
        fall = mob.fall,
        heavy = mob.heavy,
        ends = ends,
        off = reins.step("off"),
        got_on = standing_here(),
        was = was,
        dressed = false,
    }
    reins.riding.dressed = wear(mob.look)
    return true, OF.lang.fill("You are @.", OF.lang.t(mob.name))
end

function reins.get_off()
    local ride = reins.riding
    if ride == nil then return false, "You are not riding anything." end
    reins.riding = nil

    if ride.dressed then take_off(ride.was) end

    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    if m ~= nil and m.pos ~= nil and m.vel ~= nil then
        if ride.off == 2 and ride.got_on ~= nil then

            OF.util.place_player(0,
                ride.got_on.x, ride.got_on.y, ride.got_on.z)
            m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
            m.forwardVel = 0
        elseif ride.off == 3 then
            local floor = at_load("find_floor_height", m.pos.x, m.pos.y, m.pos.z)

            if type(floor) == "number" and floor > -10000 then
                m.pos.y = floor
                m.vel.y = 0
            end
        end
    end
    return true, "You are yourself again."
end

function reins.step_ride(m)
    local ride = reins.riding
    if ride == nil then return end
    if m == nil or m.playerIndex ~= 0 then return end
    if m.pos == nil or m.vel == nil then return end

    if m.forwardVel > ride.top then m.forwardVel = ride.top end

    local air = m.pos.y > (m.floorHeight or 0) + 1

    if air and not wasAir and m.vel.y > 0 then
        m.vel.y = m.vel.y * ride.hop
    end

    if air then
        if ride.heavy > 0 then m.vel.y = m.vel.y - ride.heavy end

        if m.vel.y < -ride.fall then m.vel.y = -ride.fall end
    end

    wasAir = air
end

function reins.tick_ride()
    local ride = reins.riding
    if ride == nil then return end
    if reins.round_holds() then
        reins.get_off()
        return
    end
    if ride.ends == nil then return end
    if now_frame() >= ride.ends then reins.get_off() end
end

reins.PACKET_RIDE = "reinsride"
reins.PACKET_PAD  = "reinspad"
reins.PACKET_LET  = "reinslet"
reins.PAD_PATIENCE = 40

reins.wheel = {}

reins.driven = nil

function reins.driving_count()
    local n = 0
    for _ in pairs(reins.wheel) do n = n + 1 end
    return n
end

function reins.driving(globalIndex)
    return reins.wheel[globalIndex] ~= nil
end

function reins.being_driven()
    return reins.driven ~= nil
end

local function announce(message)
    if reins.step("told") ~= 3 then return end
    if not OF.util.asks(OF.net, "announce") then return end
    OF.net.announce(message)
end

function reins.take_wheel(globalIndex)
    if not OF.perms.can("possess_other") then
        return false, OF.util.RANK_REFUSAL, "possess_other"
    end
    if not OF.util.is_host() then
        return false, "Only the host can take the wheel."
    end
    if reins.round_holds() then
        return false, "A round has the lobby."
    end

    local localIndex = OF.util.local_from_global(globalIndex)
    if localIndex == nil then return false, "They are not here." end
    if localIndex == 0 then return false, "You are already driving yourself." end

    local stop = reins.stop("turn")
    local ends = nil
    if stop ~= nil and stop.seconds ~= nil then
        ends = now_frame() + math.floor(stop.seconds * 60)
    end

    local was = nil
    local m = gMarioStates ~= nil and gMarioStates[localIndex] or nil
    if m ~= nil and m.pos ~= nil then
        was = { x = m.pos.x, y = m.pos.y, z = m.pos.z }
    end

    if not OF.util.send_to_player(localIndex, {
        ofr = reins.PACKET_PAD,
        take = reins.step("pad"),
        sx = 0, sy = 0, btn = 0,

        told = reins.step("told"),
    }) then
        return false, "They are not here to tell."
    end

    reins.wheel[globalIndex] = { ends = ends, was = was, sent = nil }

    local watch = reins.stop("watch")
    if watch ~= nil and watch.watch and OF.util.asks(OF.spectate, "start") then
        OF.spectate.start(globalIndex)
    end
    announce(OF.lang.t("The host has taken somebody's controller."))
    return true, "You have the wheel."
end

function reins.let_go(globalIndex)
    if not OF.util.is_host() then
        return false, "Only the host is holding anybody's pad."
    end
    local seat = reins.wheel[globalIndex]
    if seat == nil then return false, "You are not driving them." end
    reins.wheel[globalIndex] = nil

    local localIndex = OF.util.local_from_global(globalIndex)
    if localIndex ~= nil and localIndex ~= 0 then
        local back = (reins.step("back") == 2) and seat.was or nil
        OF.util.send_to_player(localIndex, {
            ofr = reins.PACKET_LET,
            bx = back ~= nil and back.x or 0,
            by = back ~= nil and back.y or 0,
            bz = back ~= nil and back.z or 0,
            put = back ~= nil and 1 or 0,
        })
    end
    return true, "You let go."
end

local function pad_now()
    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    if m == nil or m.controller == nil then return 0, 0, 0 end
    local c = m.controller
    local sx = math.floor((c.stickX or 0) / 4 + 0.5) * 4
    local sy = math.floor((c.stickY or 0) / 4 + 0.5) * 4
    return sx, sy, math.floor(c.buttonDown or 0)
end

function reins.drive_frame()
    if not OF.util.is_host() then return end
    if next(reins.wheel) == nil then return end

    local now = now_frame()
    local sx, sy, btn = pad_now()
    local take = reins.step("pad")
    local stamp = tostring(sx) .. "," .. tostring(sy) .. ","
        .. tostring(btn) .. "," .. tostring(take)

    for globalIndex, seat in pairs(reins.wheel) do
        if seat.ends ~= nil and now >= seat.ends then
            reins.let_go(globalIndex)
        elseif seat.sent ~= stamp then
            local localIndex = OF.util.local_from_global(globalIndex)
            if localIndex == nil or localIndex == 0 then
                reins.wheel[globalIndex] = nil
            else
                OF.util.send_to_player(localIndex, {
                    ofr = reins.PACKET_PAD, take = take,
                    sx = sx, sy = sy, btn = btn, told = 0,
                })
                seat.sent = stamp
            end
        end
    end
end

function reins.wear_the_pad(m)
    local held = reins.driven
    if held == nil then return end
    if m == nil or m.playerIndex ~= 0 or m.controller == nil then return end

    if now_frame() - held.seen > reins.PAD_PATIENCE then
        reins.driven = nil
        return
    end

    local take = PAD_STEPS[held.take] or PAD_STEPS[2]
    local c = m.controller

    if take.stick then
        c.stickX = held.sx
        c.stickY = held.sy
        local mag = math.sqrt(held.sx * held.sx + held.sy * held.sy)
        if mag > 64 then mag = 64 end
        c.stickMag = mag
        c.rawStickX = held.sx
        c.rawStickY = held.sy
    end

    local mask = 0
    if take.jump then mask = mask | A_BUTTON end
    if take.face then mask = mask | B_BUTTON | Z_TRIG end
    if take.all then mask = 0xFFFF end
    if mask ~= 0 then
        c.buttonDown = (c.buttonDown & ~mask) | (held.btn & mask)
    end
end

function reins.put_on(globalIndex)
    if not OF.perms.can("possess_other") then
        return false, OF.util.RANK_REFUSAL, "possess_other"
    end
    if not OF.util.is_host() then
        return false, "Only the host puts somebody on a creature."
    end
    if reins.round_holds() then
        return false, "A round has the lobby."
    end

    local mob = reins.wanted_mob()
    if mob == nil then return false, "Every creature is off limits." end

    local stop = reins.stop("ride")
    local seconds = (stop ~= nil and stop.seconds ~= nil) and stop.seconds or 0
    local lively = reins.stop("lively")

    local scale = math.floor((lively ~= nil and lively.scale or 1.0) * 100)

    local localIndex = OF.util.local_from_global(globalIndex)
    if localIndex == nil then return false, "They are not here." end

    if localIndex == 0 then
        local ok, said = reins.get_on(mob,
            seconds ~= 0 and seconds or nil, scale / 100)
        if ok then announce(OF.lang.t("Somebody in here is a creature now.")) end
        return ok, said
    end

    if not OF.util.send_to_player(localIndex, {
        ofr = reins.PACKET_RIDE, mob = mob.key, secs = seconds,
        scale = scale, off = 0, told = reins.step("told"),
    }) then
        return false, "They are not here to tell."
    end
    announce(OF.lang.t("Somebody in here is a creature now."))
    return true, OF.lang.fill("They are @.", OF.lang.t(mob.name))
end

function reins.take_off_player(globalIndex)
    if not OF.util.is_host() then
        return false, "Only the host takes somebody off a creature."
    end
    local localIndex = OF.util.local_from_global(globalIndex)
    if localIndex == nil then return false, "They are not here." end
    if localIndex == 0 then return reins.get_off() end
    if not OF.util.send_to_player(localIndex, {
        ofr = reins.PACKET_RIDE, mob = "off", secs = 0, scale = 100, off = 1,
        told = 0,
    }) then
        return false, "They are not here to tell."
    end
    return true, "They are themselves again."
end

function reins.everybody_back()
    local held = reins.driving_count()
    if OF.util.is_host() then
        for globalIndex in pairs(reins.wheel) do reins.let_go(globalIndex) end
        reins.wheel = {}
        for _, entry in ipairs(reins.roster()) do
            if entry.localIndex ~= 0 then
                reins.take_off_player(entry.globalIndex)
            end
        end
    end
    reins.get_off()
    return true, OF.lang.fill("Everybody is back on their feet. Wheels let go: @",
        tostring(held))
end

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil or data.ofr ~= reins.PACKET_PAD then return end
    if not OF.util.from_host(data) then return end

    local first = reins.driven == nil
    reins.driven = {
        sx = data.sx or 0, sy = data.sy or 0, btn = data.btn or 0,
        take = data.take or 2, seen = now_frame(),
    }

    if first and (data.told or 0) >= 2 then
        OF.notify.show("The host has your controller", "warn", 6)
    end
end)

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil or data.ofr ~= reins.PACKET_LET then return end
    if not OF.util.from_host(data) then return end

    local had = reins.driven ~= nil
    reins.driven = nil

    if (data.put or 0) == 1 then
        local m = gMarioStates ~= nil and gMarioStates[0] or nil
        if m ~= nil and m.pos ~= nil and m.vel ~= nil then

            OF.util.place_player(0, data.bx or 0, data.by or 0, data.bz or 0)
            m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
            m.forwardVel = 0
        end
    end
    if had then
        OF.notify.show("You have your controller back", "good", 5)
    end
end)

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil or data.ofr ~= reins.PACKET_RIDE then return end
    if not OF.util.from_host(data) then return end

    if (data.off or 0) == 1 then
        reins.get_off()
        return
    end

    local mob = reins.MOB_BY_KEY[data.mob or ""]
    if mob == nil then return end
    local seconds = (data.secs or 0)
    local ok = reins.get_on(mob, seconds ~= 0 and seconds or nil,
        (data.scale or 100) / 100)

    if ok and (data.told or 0) >= 2 then
        OF.notify.show("The host put you on @", "warn", 6, mob.name)
    end
end)

function reins.roster()
    local out = {}
    if type(OF.util.connected_players) ~= "function" then return out end
    for _, entry in ipairs(OF.util.connected_players()) do
        table.insert(out, {
            localIndex = entry.localIndex,
            globalIndex = network_global_index_from_local(entry.localIndex),
            name = entry.np.name,
        })
    end
    return out
end

function reins.ladder_row(panel, key)
    local row = reins.BY_KEY[key]
    local step = reins.step(key)
    local text = row.name .. ": " .. row.steps[step].name

    local built = panel.with_help(panel.host_row("possess_other", text,
        255, 255, 255,
        function() OF.util.report(reins.next_step(key)) end),
        OF.lang.t(row.help))
    return panel.with_slider(built, step - 1, #row.steps - 1,
        function(wanted) OF.util.report(reins.set_step(key, wanted + 1)) end)
end

local function get_on_here()
    local stop = reins.stop("ride")
    local lively = reins.stop("lively")
    return reins.get_on(reins.wanted_mob(),
        stop ~= nil and stop.seconds or nil,
        lively ~= nil and lively.scale or 1.0)
end

hook_event(HOOK_MARIO_UPDATE, reins.step_ride)
hook_event(HOOK_BEFORE_MARIO_UPDATE, reins.wear_the_pad)

hook_event(HOOK_UPDATE, function()
    reins.tick_ride()
    reins.drive_frame()
end)

hook_event(HOOK_ON_LEVEL_INIT, function()
    reins.get_off()
    reins.driven = nil
    if OF.util.is_host() then
        for globalIndex in pairs(reins.wheel) do reins.let_go(globalIndex) end
        reins.wheel = {}
    end
end)

hook_event(HOOK_ON_PLAYER_DISCONNECTED, function(m)
    if m == nil then return end
    local globalIndex = network_global_index_from_local(m.playerIndex)
    if globalIndex ~= nil then reins.wheel[globalIndex] = nil end
end)

function reins.count()
    return #reins.MOBS
end
