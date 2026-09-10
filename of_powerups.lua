OF = OF or {}
OF.powerups = OF.powerups or {}

local powerups = OF.powerups

powerups.PACKET_ASK = "giveask"
powerups.PACKET = "give"
local FULL_HEALTH = 0x880

local function no_setup(o) end

powerups.LENGTHS = { 0.25, 0.5, 1, 2, 4, 8 }
powerups.LENGTH_NAMES = {
    "a quarter as long", "half as long", "as long as the game gives",
    "twice as long", "four times as long", "eight times as long",
}

powerups.AMOUNTS = { 1, 5, 10, 25, 50, 100 }

powerups.POOLS = {
    { key = "any",  name = "anything at all", kinds = { good = true, warn = true, bad = true } },
    { key = "kind", name = "only kind ones",  kinds = { good = true } },
    { key = "mean", name = "only mean ones",  kinds = { warn = true, bad = true } },
    { key = "catchup", name = "kinder to whoever is losing",
      kinds = { good = true, warn = true, bad = true }, lifts = true },
}

powerups.KINDER = { good = 3 }

function powerups.kindness(kind)
    return powerups.KINDER[kind] or 1
end

powerups.howLong = 3
powerups.amount = 6
powerups.pool   = 1

powerups.stays = powerups.stays or {}

local function clamp_index(value, list, fallback)
    value = tonumber(value)
    if value == nil then return fallback end
    value = math.floor(value)
    if value < 1 or value > #list then return fallback end
    return value
end

function powerups.set_length(index)
    powerups.howLong = clamp_index(index, powerups.LENGTHS, powerups.howLong)
    return true
end

function powerups.set_amount(index)
    powerups.amount = clamp_index(index, powerups.AMOUNTS, powerups.amount)
    return true
end

function powerups.set_pool(index)
    powerups.pool = clamp_index(index, powerups.POOLS, powerups.pool)
    return true
end

function powerups.can_stay(entry)
    local key = entry
    if type(entry) == "table" then key = entry.key end
    if type(key) ~= "string" then return false end
    return powerups.HELD ~= nil and powerups.HELD[key] ~= nil
end

function powerups.staying(key)
    if not powerups.can_stay(key) then return false end
    return powerups.stays[key] == true
end

function powerups.set_stays(key, on)
    if not powerups.can_stay(key) then return false end
    powerups.stays[key] = on and true or false
    return true
end

function powerups.length_name()
    return powerups.LENGTH_NAMES[powerups.howLong] or powerups.LENGTH_NAMES[3]
end

function powerups.pool_name()
    local pool = powerups.POOLS[powerups.pool] or powerups.POOLS[1]
    return pool.name
end

function powerups.settings(key)
    local out = {
        ln = powerups.howLong,
        am = powerups.amount,

        fv = powerups.staying(key) and 1 or 0,
    }
    if key ~= nil then out.st = powerups.step(key) end
    return out
end

local function indexes_from(opts)
    if type(opts) ~= "table" then opts = {} end
    return clamp_index(opts.ln, powerups.LENGTHS, 3),
        clamp_index(opts.am, powerups.AMOUNTS, #powerups.AMOUNTS),
        tonumber(opts.fv) == 1
end

function powerups.settings_from(opts)
    local length, amount, forever = indexes_from(opts)
    local step = nil
    if type(opts) == "table" then step = tonumber(opts.st) end
    local hand = type(opts) == "table" and tonumber(opts.hd) == 1
    return powerups.LENGTHS[length], powerups.AMOUNTS[amount], forever, step,
        hand
end

function powerups.given_note(entry, opts)
    if type(entry) ~= "table" then return nil end
    local name = OF.lang.t(entry.name)
    local length, amount, forever = indexes_from(opts)
    if entry.timed and forever then
        return OF.lang.fill("@, @", name,
            OF.lang.t("until it is switched off"))
    end
    if entry.timed then
        return OF.lang.fill("@, @", name,
            OF.lang.t(powerups.LENGTH_NAMES[length] or ""))
    end
    if entry.counted then
        return OF.lang.fill("@, @ of them", name,
            tostring(powerups.AMOUNTS[amount]))
    end

    local levels = powerups.step_list(entry.key)
    if levels ~= nil then
        local at = powerups.clamp_step(entry.key,
            type(opts) == "table" and tonumber(opts.st) or nil)
        local stop = at ~= nil and levels[at] or nil
        if type(stop) == "table" and stop.name ~= nil then
            return OF.lang.fill("@, @", name, OF.lang.t(stop.name))
        end
    end
    return name
end

function powerups.frames(base, scale, ceiling)
    local want = math.floor((base or 0) * (scale or 1))
    if want < 1 then want = 1 end
    if ceiling ~= nil and want > ceiling then want = ceiling end
    return want
end

powerups.U16_MAX = 65535
powerups.S16_MAX = 32767
powerups.U8_MAX = 255

powerups.SQUISH_MAX = 254

powerups.GROUPS = {
    "Caps", "Strength", "Gear", "Health", "Lives and coins",
    "Toys", "Wild",
}

powerups.ACTION_GROUPS = {
    "Off the ground", "Mischief", "Punishment", "What they lose",
}

powerups.GROUP_HELP = {
    ["Caps"]            = "the three the game has, all of them at once, and the way out of all of it",
    ["Strength"]        = "what somebody can do, rather than what can be done to them",
    ["Flowers"]         = "one mechanism in five weathers - a thrown ball that attacks what it lands on",
    ["Gear"]            = "four things a player has, granted for as long as the row is on",
    ["Health"]          = "the meter, both directions, and the hit that never lands",
    ["Lives and coins"] = "the counters that go up, and the coin field underneath them",
    ["Toys"]            = "a real object in the level - four to go and fetch, and two that fetch them",
    ["Wild"]            = "rows that stand for other rows - the lot, a roll of the dice, the last one again",

    ["Off the ground"]  = "everything that takes their feet off the floor",
    ["Made to move"]    = "an action put on them, as if they had pressed it themselves",
    ["Launched"]        = "thrown by something the level would have thrown them with",

    ["Thrown"]          = "thrown by somebody, the way the game throws players",
    ["Mischief"]        = "nothing that hurts - things they feel and nothing they keep",
    ["Nothing that touches them"] = "their screen, their ears and their coins - and Mario exactly as he was",
    ["Pratfalls"]       = "a fall they did not ask for, and get straight back up from",
    ["Punishment"]      = "damage, and the four ways this menu can end a run",
    ["An ending of its own"] = "deaths with a shape - each one looks like something that happened",
    ["What they lose"]  = "taking away what somebody already had",
    ["The cap itself"]  = "their hat, and where it ends up",
}

function powerups.say_group_help(rows)
    if type(rows) ~= "table" then return 0 end
    local given = 0
    for _, r in ipairs(rows) do
        if r.heading == true and r.help == nil then
            local said = powerups.GROUP_HELP[OF.util.plain(r.text)]
            if said ~= nil then
                r.help = OF.lang.t(said)
                given = given + 1
            end
        end
    end
    return given
end

powerups.LIST = {

    { key = "wing",    name = "Wing Cap",        kind = "good", group = "Caps",
      carry = true,
      note = "triple jump and fly - on until it is off" },

    { key = "glide",   name = "Wings any time", kind = "good", group = "Caps",
      carry = true,
      note = "a press of A in the air, and they fly - any time" },
    { key = "metal",   name = "Metal Cap",       kind = "good", group = "Caps",
      carry = true,
      note = "no damage, walk under water, sink - on until off" },
    { key = "vanish",  name = "Vanish Cap",      kind = "good", group = "Caps",
      carry = true,
      note = "through some walls, untouchable - on until off" },
    { key = "allcaps", name = "All three caps",  kind = "good", group = "Caps",
      carry = true,
      note = "all three at once - the engine allows it" },
    { key = "nocap",   name = "Remove caps",     kind = "warn", group = "Caps",
      note = "ends caps, suits and anything carried" },

    { key = "invinc",  name = "Star power", kind = "good", group = "Strength",
      timed = true,
      note = "ten seconds untouchable, and it flickers" },

    { key = "triple",  name = "The winged triple jump", kind = "good", group = "Strength",
      kept = true,
      note = "Yoshi's spin jump on every bounce - press again to stop" },

    { key = "surf",    name = "Surfboard", kind = "good", group = "Strength",
      note = "water, lava and quicksand are all floor" },

    { key = "soar",    name = "Weightless flight", kind = "good", group = "Strength", carry = true,
      note = "point anywhere and go - take off with a triple jump" },

    { key = "fire",    name = "Fire Mario", kind = "good", group = "Strength", sub = "Flowers", carry = true,
      note = "Every swing throws fire. Other players burn." },

    { key = "ice",     name = "Ice Mario", kind = "good", group = "Strength", sub = "Flowers", carry = true,
      note = "Every swing throws ice. Other players freeze." },

    { key = "gale",    name = "Bubble Mario", kind = "good", group = "Strength", sub = "Flowers", carry = true,
      note = "Every swing throws a bubble. It carries them off." },

    { key = "spark",   name = "Thunder Mario", kind = "good", group = "Strength", sub = "Flowers", carry = true,
      note = "Every swing throws a jolt. Other players seize." },

    { key = "dream",   name = "Dream Mario", kind = "good", group = "Strength", sub = "Flowers", carry = true,
      note = "Every swing throws a yawn. Any input wakes them." },

    { key = "airmask", name = "Gas mask", kind = "good", group = "Gear",
      carry = true,
      note = "the purple haze takes nothing off them" },

    { key = "springheel", name = "Spring heels", kind = "good",
      group = "Gear", carry = true,
      note = "the ground pushes back harder every time they leave it" },
    { key = "wallgrip", name = "Wall grip", kind = "good",
      group = "Gear", carry = true,
      note = "lean on a wall and they slide down it, not drop" },

    { key = "feather", name = "Feather fall", kind = "good", group = "Gear",
      carry = true,
      note = "gravity takes less off them, however far they drop" },

    { key = "healfull",  name = "Full health",     kind = "good", group = "Health",
      note = "the whole pie, and any damage still landing" },
    { key = "heal",    name = "Heal them slowly", kind = "good", group = "Health",
      timed = true,
      note = "a wedge every four frames, as a heart does" },
    { key = "poison",  name = "Poison them", kind = "bad", group = "Health",
      timed = true,
      note = "drains on the meter, and it can finish them" },

    { key = "shield",  name = "One hit they can ignore", kind = "good",
      group = "Health", carry = true,
      note = "eats the next hit that lands on them, then it is spent" },

    { key = "life",    name = "Extra life",      kind = "good", group = "Lives and coins",
      note = "one more life on the counter" },
    { key = "lives10", name = "A handful of lives", kind = "good", group = "Lives and coins", counted = true,
      note = "as many as the amount dial says" },
    { key = "lifemax", name = "Lives to the top", kind = "good", group = "Lives and coins",
      note = "up to the level's maximum, clamped to a byte" },

    { key = "coins",   name = "Hand them coins", kind = "good", group = "Lives and coins", counted = true,
      note = "stops one short, so the coin star survives" },

    { key = "magnet",  name = "Coins come to them", kind = "good", group = "Lives and coins", carry = true,
      note = "a pull on every coin near them - amount sets it" },

    { key = "double",  name = "Their coins count twice", kind = "good",
      group = "Lives and coins", carry = true,
      note = "every coin they run into is paid to them twice" },

    { key = "capbox",  name = "Toss them a cap box", kind = "good", group = "Toys",
      note = "one of the three, on the floor - ten seconds" },
    { key = "coinburst", name = "Scatter coins around them", kind = "good", group = "Toys",
      note = "five to pick up, so the coin star still counts" },

    { key = "runaway", name = "A prize that runs away", kind = "warn", group = "Toys",
      note = "a life on legs - it flees, and it flickers out" },
    { key = "teasecap", name = "A cap box that dodges", kind = "warn", group = "Toys",
      note = "one of the three, backing off as they close in" },

    { key = "snowball", name = "Put them where a snowball lands", kind = "warn",
      group = "Toys",
      note = "it arcs - where it stops, they are standing" },

    { key = "pearl",   name = "Hand them a ball to throw", kind = "good",
      group = "Toys",
      note = "they hold Z and tap D-pad right, then hold the throw" },

    { key = "jackpot", name = "The lot", kind = "good", group = "Wild",
      note = "every kind thing on this page, in one press" },
    { key = "surprise", name = "Surprise them", kind = "warn", group = "Wild",
      note = "one row at random, out of the pool you set" },

    { key = "again",   name = "The same again", kind = "warn", group = "Wild",
      note = "whatever the last press named, to this one" },
}

powerups.ACTIONS = {

    { key = "moon",    name = "Send to the moon", kind = "bad", group = "Off the ground",
      note = "straight up, and the trip down is the joke" },

    { key = "knockup", name = "Knock them off their feet", kind = "warn", group = "Off the ground",
      note = "the engine's own knockback, backwards" },

    { key = "spintop", name = "Spin them into the air", kind = "warn", group = "Off the ground",
      note = "high up, and spinning all the way down" },
    { key = "toss",    name = "Throw them across the room", kind = "warn", group = "Off the ground",
      note = "at whoever is nearest, or straight ahead alone" },

    { key = "spring",  name = "Rubber legs", kind = "warn", group = "Off the ground", carry = true,
      note = "the floor lets go of them at every landing" },

    { key = "tripled", name = "Send them up on a triple jump", kind = "warn",
      group = "Off the ground",
      note = "six hundred units up, and the somersault on the way" },

    { key = "dive",      name = "Trip them into a dive", kind = "warn", group = "Off the ground", sub = "Made to move",
      note = "head first across the room, into the slide" },
    { key = "backflip",  name = "Backflip them", kind = "warn", group = "Off the ground", sub = "Made to move",
      note = "up and backwards, exactly as Z and A would" },
    { key = "sideflip",  name = "Side-flip them", kind = "warn", group = "Off the ground", sub = "Made to move",
      note = "off sideways, the way the stick was pointing" },
    { key = "longjumped",  name = "Long-jump them", kind = "warn", group = "Off the ground", sub = "Made to move",
      note = "with the run-up, so it is a jump and not a hop" },

    { key = "slidekick", name = "Slide-kick them", kind = "warn", group = "Off the ground", sub = "Made to move",
      note = "off across the floor on their side, kicking" },
    { key = "pound",     name = "Ground-pound them", kind = "warn", group = "Off the ground", sub = "Made to move",
      note = "the spin, the drop, and whatever is underneath" },

    { key = "cannon",    name = "Fire them out of a cannon", kind = "warn", group = "Off the ground", sub = "Launched",
      note = "a hundred units a frame, and a quarter gravity" },
    { key = "updraught", name = "Catch them in an updraught", kind = "warn", group = "Off the ground", sub = "Launched",
      note = "a long way up, steerable, into a dive slide" },
    { key = "gust",      name = "Gust - and their hat with it", kind = "warn", group = "Off the ground", sub = "Launched",
      note = "blown backwards - the engine takes the cap off" },
    { key = "ballbounce",  name = "Bounce them like a ball", kind = "warn", group = "Off the ground", sub = "Launched",
      note = "three bounces, higher each time, then a slide" },

    { key = "pipe",      name = "Pop them out of a pipe", kind = "warn",
      group = "Off the ground", sub = "Launched",
      note = "gone for eleven frames, then up out of the floor" },

    { key = "spawnspin", name = "Drop them in like a new arrival", kind = "warn",
      group = "Off the ground", sub = "Launched",
      note = "straight up, spinning, and back down where they stood" },

    { key = "thrown",    name = "Throw them the way Chuckya does", kind = "warn", group = "Off the ground", sub = "Thrown",
      note = "forwards and spinning, and the ground stops it" },
    { key = "wallkick",  name = "Wall-kick them off nothing", kind = "warn", group = "Off the ground", sub = "Thrown",
      note = "the kick, three times its own height, with no wall" },

    { key = "jumpkick",  name = "Jump kick", kind = "warn", group = "Off the ground", sub = "Thrown",
      note = "the flying kick, and it really is an attack" },

    { key = "thrownback", name = "Throw them over backwards", kind = "warn",
      group = "Off the ground", sub = "Thrown",
      note = "the same throw as the one above, the other way" },

    { key = "bonk",      name = "Bonk them off nothing", kind = "warn",
      group = "Off the ground", sub = "Thrown",
      note = "a wall that was not there - they pick themselves up" },

    { key = "planted", name = "Plant them in the ground", kind = "warn", group = "Mischief",
      note = "stuck to the knees - mashing A digs them out" },
    { key = "sleep",   name = "Send them to sleep", kind = "warn", group = "Mischief",
      note = "a yawn and a nap - any input wakes them" },

    { key = "flatten", name = "Flatten", kind = "warn", group = "Mischief",
      timed = true,
      note = "eight seconds of pancake - slow, no B, no Z" },
    { key = "freeze",  name = "Freeze them", kind = "bad", group = "Mischief",
      timed = true,
      note = "three seconds with the controller unplugged" },

    { key = "shakescreen",   name = "Shake their screen", kind = "warn",
      group = "Mischief", sub = "Nothing that touches them",
      note = "the floor is fine - only the camera moves" },

    { key = "fanfare", name = "Play them a fanfare", kind = "good",
      group = "Mischief", sub = "Nothing that touches them",
      note = "the star jingle and nothing else - well done" },

    { key = "repel",   name = "Coins run from them", kind = "bad",
      group = "Mischief", sub = "Nothing that touches them", timed = true,
      note = "the pull reversed, until the timer runs out" },

    { key = "headfirst",   name = "Plant them head first", kind = "warn", group = "Mischief", sub = "Pratfalls",
      note = "upside down to the shoulders - A digs them out" },
    { key = "bottomfirst", name = "Plant them on their bottom", kind = "warn", group = "Mischief", sub = "Pratfalls",
      note = "the pound landing, without the pound - longer" },
    { key = "shockbounce", name = "Bounce them on the spot", kind = "warn", group = "Mischief", sub = "Pratfalls",
      note = "Bowser's shockwave hop - six bounces, no damage" },
    { key = "slide",       name = "Send them sliding", kind = "warn", group = "Mischief", sub = "Pratfalls",
      note = "on their backside or their face - the slope picks" },

    { key = "flatback",    name = "Put them flat on their back", kind = "warn",
      group = "Mischief", sub = "Pratfalls",
      note = "the big hit's landing, without the hit" },

    { key = "shock",   name = "Zap", kind = "bad", group = "Punishment",
      note = "the shock stun - deadly on the last wedge" },
    { key = "burn",    name = "Set alight", kind = "bad", group = "Punishment",
      note = "burns until it burns out - water puts it out" },
    { key = "lavatoss",    name = "Lava launch", kind = "bad", group = "Punishment",
      note = "the lava throw, damage and all - Metal is free" },
    { key = "boom",    name = "Blow them up", kind = "bad", group = "Punishment",
      note = "a bob-omb blast without the bob-omb" },

    { key = "firework", name = "Send them up as a firework", kind = "bad",
      group = "Punishment", ends = true,
      note = "alight, up, a bang at the top, and gone" },

    { key = "wound",   name = "Drain their health", kind = "bad", group = "Punishment",
      steps = "wedges",
      note = "whole wedges, drained rather than dropped" },

    { key = "bubbleput",  name = "Quick death", kind = "bad", group = "Punishment", sub = "An ending of its own",
      ends = true,
      note = "costs a life and floats them until popped" },

    { key = "sink",    name = "Suck them under", kind = "bad", group = "Punishment", sub = "An ending of its own", ends = true,
      note = "six seconds down, then the quicksand ending" },
    { key = "standing",  name = "Drop them where they stand", kind = "bad", group = "Punishment", sub = "An ending of its own", ends = true,
      note = "the fall-over death - eighty frames of it" },
    { key = "electro",   name = "Electrocute them", kind = "bad", group = "Punishment", sub = "An ending of its own", ends = true,
      note = "the shortest ending the game has - forty-three frames" },
    { key = "suffocate", name = "Take their air", kind = "bad", group = "Punishment", sub = "An ending of its own", ends = true,
      note = "the gas-cave ending, and the slowest of the three" },
    { key = "pop",     name = "Pop their bubble", kind = "good", group = "Punishment", sub = "An ending of its own",
      note = "only somebody actually in one - no life back" },

    { key = "takelife", name = "Take a life", kind = "bad", group = "What they lose",
      note = "one off the counter, never below zero" },
    { key = "takecoins", name = "Empty their pockets", kind = "bad", group = "What they lose",
      note = "coins to nothing - the coin star is back on" },

    { key = "spillcoins", name = "Empty their pockets onto the floor",
      kind = "bad", group = "What they lose",
      note = "up to five hit the floor, and each one pays the lobby" },
    { key = "dropit",  name = "Make them drop everything", kind = "warn", group = "What they lose",
      note = "held object gone, and off whatever they rode" },

    { key = "capoff",  name = "Knock their cap into their hands", kind = "warn", group = "What they lose", sub = "The cap itself",
      note = "off the head, carried - everything hurts more" },
    { key = "blowcap", name = "Blow their cap away", kind = "warn", group = "What they lose", sub = "The cap itself",
      note = "it lands somewhere - they have to fetch it" },
    { key = "capback", name = "Put their cap back on", kind = "good", group = "What they lose", sub = "The cap itself",
      note = "undoes both rows above, and no save write" },
}

powerups.EVERY = {}
for _, entry in ipairs(powerups.LIST) do
    table.insert(powerups.EVERY, entry)
end
for _, entry in ipairs(powerups.ACTIONS) do
    table.insert(powerups.EVERY, entry)
end

function powerups.coins_without_eating_the_star(m, gift)
    local want = (m.numCoins or 0) + gift
    local need = gLevelValues.coinsRequiredForCoinStar
    if type(need) ~= "number" or need <= 0 then return want end

    local course = OF.util.optional("get_level_course_num", nil,
        gNetworkPlayers[0] ~= nil and gNetworkPlayers[0].currLevelNum or 0)

    local MAIN_COURSES = 15
    if type(course) ~= "number" or course < COURSE_MIN or course > MAIN_COURSES then
        return want
    end

    if m.numCoins < need and want >= need then return need - 1 end
    return want
end

function powerups.find(key)
    for _, entry in ipairs(powerups.EVERY) do
        if entry.key == key then return entry end
    end
    return nil
end

local function cap_duration(flag)
    if gLevelValues == nil then return 1800 end
    if flag == MARIO_WING_CAP then return gLevelValues.wingCapDuration or 1800 end
    if flag == MARIO_METAL_CAP then return gLevelValues.metalCapDuration or 1800 end
    if flag == MARIO_VANISH_CAP then return gLevelValues.vanishCapDuration or 1800 end
    return 1800
end

local function set_bit(value, bit)
    if OF.util.has_flag(value, bit) then return value end
    return value + bit
end

local function clear_bit(value, bit)
    if OF.util.has_flag(value, bit) then return value - bit end
    return value
end

local function give_cap(m, flag, scale, quiet)
    m.flags = clear_bit(m.flags, MARIO_CAP_IN_HAND)
    m.flags = set_bit(m.flags, flag)
    m.flags = set_bit(m.flags, MARIO_CAP_ON_HEAD)

    local duration = powerups.frames(cap_duration(flag), scale or 1,
        powerups.U16_MAX)
    if duration > m.capTimer then m.capTimer = duration end

    if not quiet then OF.sounds.play(SOUND_MENU_STAR_SOUND) end
end

local heldCap = nil
local capsAreHeld = false

function powerups.round_takes_caps()
    if not OF.util.asks(OF.lockdown, "menu_stands_down") then return false end
    if not OF.lockdown.menu_stands_down() then return false end
    if OF.util.asks(OF.rules, "rounds_keep_handouts")
        and OF.rules.rounds_keep_handouts() then
        return false
    end
    return true
end

local function worn_special_cap(m)
    for _, flag in ipairs({ MARIO_WING_CAP, MARIO_METAL_CAP, MARIO_VANISH_CAP }) do
        if flag ~= nil and OF.util.has_flag(m.flags or 0, flag)
            and not OF.util.intangible_borrowed(flag) then
            return flag
        end
    end
    return nil
end

function powerups.held_cap()
    if heldCap == nil then return nil end
    return heldCap.flag, heldCap.frames
end

function powerups.cap_round_update()
    local now = powerups.round_takes_caps()
    if now == capsAreHeld then return false end
    capsAreHeld = now

    local m = gMarioStates[0]
    if m == nil then heldCap = nil; return false end

    if now then
        local flag = worn_special_cap(m)
        local left = m.capTimer or 0

        if flag == nil or left <= 1 then heldCap = nil; return false end
        heldCap = { flag = flag, frames = left }
        m.capTimer = 1
        return true
    end

    local put = heldCap
    heldCap = nil
    if put == nil then return false end

    local full = cap_duration(put.flag)
    local scale = full > 0 and (put.frames / full) or 1
    give_cap(m, put.flag, scale, true)
    return true
end

powerups.INVINC_FRAMES = 30 * 10

powerups.SQUISH_FRAMES = 240

powerups.FREEZE_FRAMES = 90

powerups.SUIT_FRAMES = 30 * 20

powerups.MOON_HEIGHT = 12000

function powerups.moon(m)

    if not OF.util.place_player(m.playerIndex or 0,
        m.pos.x, m.pos.y + powerups.MOON_HEIGHT, m.pos.z) then
        return
    end
    m.vel.x = 0
    m.vel.y = 0
    m.vel.z = 0
    m.forwardVel = 0
    set_mario_action(m, ACT_FREEFALL, 0)
end

function powerups.star_power(m, scale, quiet)
    if m == nil then return false end
    local now = m.invincTimer or 0
    if now < 0 then return false end

    local want = powerups.frames(powerups.INVINC_FRAMES, scale or 1,
        powerups.S16_MAX)
    if want > now then m.invincTimer = want end
    if not quiet then OF.sounds.play(SOUND_MENU_STAR_SOUND) end
    return true
end

function powerups.winged_triple_jump(m)
    if m == nil then return false end
    m.specialTripleJump = 1
    return true
end

function powerups.pop_bubble(m)
    if m == nil then return false end
    if m.action ~= ACT_BUBBLED then return false end
    if mario_pop_bubble == nil then return false end
    mario_pop_bubble(m)
    return true
end

local S8_MAX = 127

function powerups.lives_to_the_top(m)
    if m == nil then return false end

    local top = nil
    if gLevelValues ~= nil then top = gLevelValues.maxLives end
    if type(top) ~= "number" or top <= 0 then return false end
    if top > S8_MAX then top = S8_MAX end
    if m.numLives >= top then return false end
    m.numLives = top
    return true
end

function powerups.take_a_life(m)
    if m == nil then return false end
    if m.numLives <= 0 then return false end
    m.numLives = m.numLives - 1
    return true
end

function powerups.knock_the_cap_off(m)
    if m == nil then return false end
    m.flags = clear_bit(m.flags, MARIO_CAP_ON_HEAD)
    m.flags = set_bit(m.flags, MARIO_CAP_IN_HAND)
    return true
end

powerups.FLATTEN_VALUES = {}
for _, scale in ipairs(powerups.LENGTHS) do
    powerups.FLATTEN_VALUES[
        powerups.frames(powerups.SQUISH_FRAMES, scale, powerups.SQUISH_MAX)] = true
end

function powerups.is_their_flatten(value)
    return powerups.FLATTEN_VALUES[value] == true
end

function powerups.flatten(m, scale)
    if m == nil then return false end

    local want = powerups.frames(powerups.SQUISH_FRAMES, scale or 1,
        powerups.SQUISH_MAX)
    if want > (m.squishTimer or 0) then m.squishTimer = want end
    return true
end

function powerups.freeze(m, scale)
    if m == nil then return false end

    local want = powerups.frames(powerups.FREEZE_FRAMES, scale or 1,
        powerups.U8_MAX)
    if want > (m.freeze or 0) then m.freeze = want end
    return true
end

function powerups.zap(m)
    if m == nil then return false end
    local action = m.action or 0

    if ACT_WATER_SHOCKED ~= nil
        and (OF.util.has_flag(action, ACT_FLAG_SWIMMING)
            or OF.util.has_flag(action, ACT_FLAG_METAL_WATER)) then
        set_mario_action(m, ACT_WATER_SHOCKED, 0)
        return true
    end
    local offGround = OF.util.has_flag(action, ACT_FLAG_AIR)
        or OF.util.has_flag(action, ACT_FLAG_ON_POLE)
        or OF.util.has_flag(action, ACT_FLAG_HANGING)
    set_mario_action(m, ACT_SHOCKED, offGround and 0 or 1)
    return true
end

function powerups.set_alight(m)
    if m == nil or m.marioObj == nil then return false end
    if OF.util.has_flag(m.action or 0, ACT_FLAG_SWIMMING) then return false end

    if (m.waterLevel or -10000) - m.pos.y > 50 then return false end

    local burning = ACT_BURNING_JUMP
    if ACT_BURNING_FALL ~= nil
        and OF.util.has_flag(m.action or 0, ACT_FLAG_AIR)
        and (tonumber(m.vel ~= nil and m.vel.y) or 0) <= 0 then
        burning = ACT_BURNING_FALL
    end

    m.marioObj.oMarioBurnTimer = 0
    set_mario_action(m, burning, 1)
    return true
end

local EXPLOSION_BHV = id_bhvExplosion or 161
local EXPLOSION_MODEL = E_MODEL_EXPLOSION or 47

function powerups.blow_up(m)
    if m == nil then return false end
    if spawn_non_sync_object == nil then return false end

    local blast = spawn_non_sync_object(EXPLOSION_BHV, EXPLOSION_MODEL,
        m.pos.x, m.pos.y + 60, m.pos.z, no_setup)
    return blast ~= nil
end

powerups.FUSE_SECONDS = 12
powerups.FUSE_FRAMES = powerups.FUSE_SECONDS * 30

powerups.FUSE_WARN_FRAMES = 3 * 30

powerups.fuse = powerups.fuse or nil

function powerups.fuse_stop()
    local names = (powerups.STEPS.boom or {}).names
    return names ~= nil and #names or 1
end

function powerups.light_the_fuse(m)
    if m == nil then return false end

    if powerups.fuse ~= nil then return false, "That fuse is already lit." end
    powerups.fuse = powerups.FUSE_FRAMES
    OF.sounds.play(SOUND_GENERAL_SHORT_STAR)
    if OF.util.asks(OF.notify, "show") then
        OF.notify.show("Lit. Ground pound to put it out.", "warn")
    end
    return true
end

function powerups.fuse_left()
    return powerups.fuse or 0
end

function powerups.put_the_fuse_out(said)
    if powerups.fuse == nil then return false end
    powerups.fuse = nil
    if said and OF.util.asks(OF.notify, "show") then
        OF.notify.show("Fuse out.", "good")
    end
    return true
end

function powerups.fuse_update(m)
    if powerups.fuse == nil then return false end
    if m == nil then return false end

    local action = m.action or 0
    if OF.util.action_group(action)
        == OF.util.action_group(ACT_GROUP_CUTSCENE) then

        powerups.put_the_fuse_out(false)
        return true
    end
    if ACT_GROUND_POUND_LAND ~= nil and action == ACT_GROUND_POUND_LAND then
        powerups.put_the_fuse_out(true)
        return true
    end

    powerups.fuse = powerups.fuse - 1
    if powerups.fuse == powerups.FUSE_WARN_FRAMES
        and OF.util.asks(OF.notify, "show") then
        OF.notify.show("The fuse is nearly gone.", "bad")
    end
    if powerups.fuse > 0 then return true end

    powerups.fuse = nil
    powerups.blow_up(m)
    return true
end

powerups.HURT_PER_WEDGE = 4

function powerups.wound(m, wedges)
    if m == nil then return false end
    local want = (m.hurtCounter or 0)
        + powerups.HURT_PER_WEDGE * (tonumber(wedges) or 1)
    if want > powerups.U8_MAX - 1 then want = powerups.U8_MAX - 1 end
    if want <= (m.hurtCounter or 0) then return false end
    m.hurtCounter = want
    return true
end

function powerups.suck_under(m)
    if m == nil then return false end
    if ACT_QUICKSAND_DEATH == nil then return false end
    local action = m.action or 0
    if OF.util.has_flag(action, ACT_FLAG_AIR) then return false end
    if OF.util.has_flag(action, ACT_FLAG_SWIMMING) then return false end
    if OF.util.has_flag(action, ACT_FLAG_ON_POLE) then return false end
    if OF.util.has_flag(action, ACT_FLAG_HANGING) then return false end
    m.quicksandDepth = 0.0
    set_mario_action(m, ACT_QUICKSAND_DEATH, 0)
    return true
end

powerups.ENDINGS = {
    standing  = "ACT_STANDING_DEATH",
    electro   = "ACT_ELECTROCUTION",
    suffocate = "ACT_SUFFOCATION",
}

function powerups.end_them(m, key)
    if m == nil then return false end
    local name = powerups.ENDINGS[key]
    if name == nil then return false end
    local action = _G[name]
    if type(action) ~= "number" then return false end
    if not powerups.on_their_feet(m) then
        return false, "Only somebody standing on the floor."
    end
    set_mario_action(m, action, 0)
    return true
end

powerups.FIREWORK_ARG = 2

powerups.LAVA_BOOST_GRAVITY = 3.2

powerups.FIREWORK_LIFT = 200.0

powerups.FIREWORK_FRAMES =
    math.ceil(powerups.FIREWORK_LIFT / powerups.LAVA_BOOST_GRAVITY)

powerups.FIREWORK_DEAD_HEALTH = 0xFF

local fireworkAt = {}

function powerups.firework_burst(m)
    if m == nil then return false end
    powerups.blow_up(m)
    if m.playerIndex ~= 0 then return true end

    if m.action ~= ACT_LAVA_BOOST then
        set_mario_action(m, ACT_LAVA_BOOST, 0)
    end
    m.health = powerups.FIREWORK_DEAD_HEALTH
    return true
end

function powerups.firework_update(m)
    if m == nil then return end
    local index = m.playerIndex
    if index == nil then return end
    local flying = (m.action == ACT_LAVA_BOOST)
        and ((m.actionArg or 0) == powerups.FIREWORK_ARG)
    local left = fireworkAt[index]
    if not flying then

        if left ~= nil and left > 0 then powerups.firework_burst(m) end
        fireworkAt[index] = nil
        return
    end

    if left == nil then left = powerups.FIREWORK_FRAMES end

    if left <= 0 then return end
    left = left - 1
    fireworkAt[index] = left
    if left > 0 then return end
    powerups.firework_burst(m)
end

function powerups.firework(m)
    if m == nil then return false end
    if ACT_LAVA_BOOST == nil then return false end
    if OF.util.has_flag(m.action or 0, ACT_FLAG_SWIMMING) then
        return false, "Not while they are in the water."
    end
    if ACT_BUBBLED ~= nil and m.action == ACT_BUBBLED then
        return false, "They are already in a bubble."
    end

    OF.util.optional("drop_and_set_mario_action", nil, m, ACT_LAVA_BOOST,
        powerups.FIREWORK_ARG)

    if m.action ~= ACT_LAVA_BOOST
        or (m.actionArg or 0) ~= powerups.FIREWORK_ARG then
        set_mario_action(m, ACT_LAVA_BOOST, powerups.FIREWORK_ARG)
    end

    m.forwardVel = 0
    m.vel.x = 0
    m.vel.z = 0
    m.vel.y = powerups.FIREWORK_LIFT
    return true
end

local function at_load(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then
        powerups.missing = powerups.missing or {}
        powerups.missing[name] = true
        return nil
    end
    local ok, result = pcall(fn, ...)
    if not ok then return nil end
    return result
end

local SURF_GROUND = at_load("allocate_mario_action",
    ACT_GROUP_MOVING | ACT_FLAG_MOVING | ACT_FLAG_RIDING_SHELL | ACT_FLAG_ATTACKING)
local SURF_AIR = at_load("allocate_mario_action",
    ACT_GROUP_AIRBORNE | ACT_FLAG_AIR | ACT_FLAG_RIDING_SHELL | ACT_FLAG_ATTACKING)

local SURF_PUSH_OFF = 32.0

powerups.SURF_GROUND, powerups.SURF_AIR = SURF_GROUND, SURF_AIR

local SURF_JUMP_VEL = 42.0
local SURF_JUMP_FROM_SPEED = 0.25

local function act_surf_ground(m)
    if m == nil then return false end

    if (m.input & INPUT_A_PRESSED) ~= 0 then
        if set_mario_y_vel_based_on_fspeed ~= nil then
            set_mario_y_vel_based_on_fspeed(m, SURF_JUMP_VEL, SURF_JUMP_FROM_SPEED)
        end
        set_mario_action(m, SURF_AIR, 0)
        return false
    end
    if (m.input & INPUT_Z_PRESSED) ~= 0 then
        if m.forwardVel < 24.0 then mario_set_forward_vel(m, 24.0) end
        set_mario_action(m, ACT_CROUCH_SLIDE, 0)
        return false
    end

    update_shell_speed(m)
    set_character_animation(m, CHAR_ANIM_RIDING_SHELL)

    local step = perform_ground_step(m)
    if step == GROUND_STEP_LEFT_GROUND then
        set_mario_action(m, SURF_AIR, 0)
    elseif step == GROUND_STEP_HIT_WALL then

        set_mario_particle_flags(m, PARTICLE_VERTICAL_STAR, false)
        set_mario_action(m, ACT_BACKWARD_GROUND_KB, 0)
    end
    return false
end

local function act_surf_air(m)
    if m == nil then return false end
    set_character_animation(m, CHAR_ANIM_JUMP_RIDING_SHELL)
    update_air_without_turn(m)

    local step = perform_air_step(m, 0)
    if step == AIR_STEP_LANDED then
        set_mario_action(m, SURF_GROUND, 1)
    elseif step == AIR_STEP_HIT_WALL then
        mario_set_forward_vel(m, 0.0)
    end
    return false
end

if SURF_GROUND ~= nil and SURF_AIR ~= nil then
    at_load("hook_mario_action", SURF_GROUND, { every_frame = act_surf_ground })
    at_load("hook_mario_action", SURF_AIR, { every_frame = act_surf_air })
end

function powerups.surf(m)
    if m == nil or SURF_GROUND == nil then return false end
    if m.forwardVel < SURF_PUSH_OFF then mario_set_forward_vel(m, SURF_PUSH_OFF) end
    set_mario_action(m, SURF_GROUND, 0)
    return true
end

local CAP_BEHPARAMS_FIELD = 0x40

local BLOWN_CAP_SPEED = 50.0

local CAP_ARC_SPEED   = 26.0
local CAP_ARC_LIFT    = 16.0
local CAP_ARC_GRAVITY = 2.4
local CAP_GRACE_FRAMES = 120

powerups.CAP_GRACE = CAP_GRACE_FRAMES

local capGraceUntil = nil

local function cap_clock()
    return OF.util.optional("get_global_timer", 0) or 0
end

local function loose_cap_of(m)
    if m == nil then return nil end
    return OF.util.optional("obj_get_first_with_behavior_id_and_field_s32",
        nil, id_bhvNormalCap, CAP_BEHPARAMS_FIELD, (m.playerIndex or 0) + 1)
end

local function throw_the_cap(m)
    local loose = loose_cap_of(m)
    if loose == nil then return false end
    if loose.oForwardVel ~= nil then loose.oForwardVel = CAP_ARC_SPEED end
    if loose.oVelY ~= nil then loose.oVelY = CAP_ARC_LIFT end
    if loose.oGravity ~= nil then loose.oGravity = CAP_ARC_GRAVITY end
    return true
end

function powerups.cap_grace_left()
    if capGraceUntil == nil then return 0 end
    local left = capGraceUntil - cap_clock()
    if left <= 0 then
        capGraceUntil = nil
        return 0
    end
    return left
end

function powerups.end_cap_grace()
    capGraceUntil = nil
end

function powerups.blow_the_cap_away(m)
    if m == nil then return false end
    if mario_blow_off_cap == nil then return false end

    local proper = OF.util.optional("does_mario_have_normal_cap_on_head", nil, m)
    if proper ~= nil then
        if proper == 0 or proper == false then
            return false, "Not wearing their own cap."
        end
    else
        if not OF.util.has_flag(m.flags or 0, MARIO_NORMAL_CAP) then
            return false, "Not wearing their own cap."
        end
        if not OF.util.has_flag(m.flags or 0, MARIO_CAP_ON_HEAD) then
            return false, "Their cap is not on their head."
        end
    end
    if OF.util.optional("does_mario_have_blown_cap", false, m) == true then
        return false, "Their cap is already lying about somewhere."
    end
    mario_blow_off_cap(m, BLOWN_CAP_SPEED)

    if OF.util.has_flag(m.flags or 0, MARIO_CAP_ON_HEAD) then
        return false, "The game would not take their cap off."
    end

    throw_the_cap(m)
    capGraceUntil = cap_clock() + CAP_GRACE_FRAMES
    return true
end

function powerups.cap_back_on(m)
    if m == nil then return false end
    m.cap = 0
    m.flags = clear_bit(m.flags, MARIO_CAP_IN_HAND)
    m.flags = set_bit(m.flags, MARIO_NORMAL_CAP)
    m.flags = set_bit(m.flags, MARIO_CAP_ON_HEAD)
    powerups.take_back_the_loose_cap(m)
    powerups.end_cap_grace()
    return true
end

function powerups.take_back_the_loose_cap(m)
    if m == nil then return false end
    local loose = loose_cap_of(m)
    if loose == nil then return false end
    OF.util.optional("obj_mark_for_deletion", nil, loose)
    return true
end

powerups.HEAL_TICKS = 31

powerups.POISON_TICKS = 48

function powerups.heal_slowly(m, scale)
    if m == nil then return false end

    m.hurtCounter = 0
    local want = powerups.frames(powerups.HEAL_TICKS, scale or 1,
        powerups.U8_MAX)
    if want > (m.healCounter or 0) then m.healCounter = want end
    return true
end

function powerups.poison(m, scale)
    if m == nil then return false end
    m.healCounter = 0
    local want = powerups.frames(powerups.POISON_TICKS, scale or 1,
        powerups.U8_MAX)
    if want > (m.hurtCounter or 0) then m.hurtCounter = want end
    return true
end

function powerups.empty_pockets(m)
    if m == nil then return false end
    if (m.numCoins or 0) <= 0 then return false end
    m.numCoins = 0
    return true
end

powerups.POCKET_SPILL = 5

powerups.spilled = powerups.spilled or {}

function powerups.spill_pockets(m)
    if m == nil or m.pos == nil then return false end
    local pocket = m.numCoins or 0
    if pocket <= 0 then return false, "Their pockets are already empty." end

    local want = math.min(pocket, powerups.POCKET_SPILL)
    local dropped = 0
    for _ = 1, want do

        if OF.util.coin_put(powerups.spilled,
            m.pos.x, m.pos.y + 60, m.pos.z) then
            dropped = dropped + 1
        end
    end

    if dropped == 0 then
        return false, "Their coins have nowhere to land."
    end

    powerups.empty_pockets(m)
    return true
end

function powerups.plant_in_ground(m)
    if m == nil then return false end
    local action = m.action or 0
    if OF.util.has_flag(action, ACT_FLAG_AIR) then return false end
    if OF.util.has_flag(action, ACT_FLAG_SWIMMING) then return false end
    if OF.util.has_flag(action, ACT_FLAG_ON_POLE) then return false end
    if OF.util.has_flag(action, ACT_FLAG_HANGING) then return false end
    set_mario_action(m, ACT_FEET_STUCK_IN_GROUND, 0)
    return true
end

function powerups.send_to_sleep(m)
    if m == nil then return false end
    local action = m.action or 0

    if OF.util.has_flag(action, ACT_FLAG_AIR) then return false end
    if OF.util.has_flag(action, ACT_FLAG_SWIMMING) then return false end
    if OF.util.has_flag(action, ACT_FLAG_ON_POLE) then return false end
    if OF.util.has_flag(action, ACT_FLAG_HANGING) then return false end
    set_mario_action(m, ACT_START_SLEEPING, 0)
    return true
end

function powerups.drop_everything(m)
    if m == nil then return false end
    local held = m.heldObj
    OF.util.optional("mario_stop_riding_and_holding", nil, m)

    return held ~= nil or m.riddenObj ~= nil
end

powerups.LAVA_HURT_CAPPED = 12
powerups.LAVA_HURT_BARE = 18

function powerups.lava_launch(m)
    if m == nil then return false end
    if not OF.util.has_flag(m.flags or 0, MARIO_METAL_CAP) then
        local hurt = powerups.LAVA_HURT_BARE
        if OF.util.has_flag(m.flags or 0, MARIO_CAP_ON_HEAD) then
            hurt = powerups.LAVA_HURT_CAPPED
        end
        local now = (m.hurtCounter or 0) + hurt
        if now > powerups.U8_MAX then now = powerups.U8_MAX end
        m.hurtCounter = now
    end
    OF.util.optional("drop_and_set_mario_action", nil, m, ACT_LAVA_BOOST, 0)

    if m.action ~= ACT_LAVA_BOOST then
        set_mario_action(m, ACT_LAVA_BOOST, 0)
    end
    return true
end

function powerups.knock_over(m)
    if m == nil then return false end
    set_mario_action(m, ACT_BACKWARD_AIR_KB, 0)
    return true
end

powerups.TWIRL_LIFT = 70.0

function powerups.twirl(m)
    if m == nil then return false end
    if ACT_TWIRLING == nil then return false end
    if OF.util.has_flag(m.action or 0, ACT_FLAG_SWIMMING) then
        return false, "Not while they are in the water."
    end
    m.vel.y = powerups.TWIRL_LIFT
    set_mario_action(m, ACT_TWIRLING, 0)
    return true
end

powerups.TOSS_SPEED = 120.0
powerups.TOSS_LIFT = 45.0

function powerups.toss(m)
    if m == nil or m.pos == nil then return false end

    local me = gNetworkPlayers[0]
    local best, bestDistance = nil, nil
    for _, other in ipairs(OF.util.connected_players()) do
        local np = other.np
        if other.localIndex ~= 0 and me ~= nil and np ~= nil
            and np.currLevelNum == me.currLevelNum
            and np.currAreaIndex == me.currAreaIndex then
            local om = gMarioStates[other.localIndex]
            if om ~= nil and om.pos ~= nil then
                local dx = (tonumber(om.pos.x) or 0) - (tonumber(m.pos.x) or 0)
                local dz = (tonumber(om.pos.z) or 0) - (tonumber(m.pos.z) or 0)
                local away = dx * dx + dz * dz
                if bestDistance == nil or away < bestDistance then
                    best, bestDistance = om, away
                end
            end
        end
    end

    if best ~= nil then

        local yaw = OF.util.optional("atan2s", nil,
            (tonumber(best.pos.z) or 0) - (tonumber(m.pos.z) or 0),
            (tonumber(best.pos.x) or 0) - (tonumber(m.pos.x) or 0))

        if yaw ~= nil then
            yaw = (yaw + 0x8000) % 0x10000
            if yaw >= 0x8000 then yaw = yaw - 0x10000 end
            m.faceAngle.y = yaw
        end
    end

    set_mario_action(m, ACT_BACKWARD_AIR_KB, 0)

    OF.util.optional("mario_set_forward_vel", nil, m, -powerups.TOSS_SPEED)
    m.vel.y = powerups.TOSS_LIFT
    return true
end

function powerups.quake()
    if set_camera_shake_from_hit == nil then return false end
    set_camera_shake_from_hit(SHAKE_FALL_DAMAGE)
    OF.util.optional("set_environmental_camera_shake", nil,
        SHAKE_ENV_BOWSER_JUMP)
    return true
end

powerups.STUCK = {
    headfirst   = "ACT_HEAD_STUCK_IN_GROUND",
    bottomfirst = "ACT_BUTT_STUCK_IN_GROUND",
}

powerups.SHOCKBOUNCE_FRAMES = 48

powerups.SLIDE_SPEED = 40.0

function powerups.stick_them_in(m, key)
    if m == nil then return false end
    local name = powerups.STUCK[key]
    if name == nil then return false end
    local action = _G[name]
    if type(action) ~= "number" then return false end

    if not powerups.on_their_feet(m) then
        return false, "Only somebody standing on the floor."
    end
    set_mario_action(m, action, 0)
    return true
end

function powerups.shockbounce(m)
    if m == nil then return false end
    if ACT_SHOCKWAVE_BOUNCE == nil then return false end
    if not powerups.on_their_feet(m) then
        return false, "Only somebody standing on the floor."
    end
    set_mario_action(m, ACT_SHOCKWAVE_BOUNCE, 0)
    return true
end

function powerups.send_them_sliding(m)
    if m == nil then return false end
    if ACT_BEGIN_SLIDING == nil then return false end
    if not powerups.on_their_feet(m) then
        return false, "Only somebody standing on the floor."
    end
    OF.util.optional("mario_set_forward_vel", nil, m, powerups.SLIDE_SPEED)
    set_mario_action(m, ACT_BEGIN_SLIDING, 0)
    return true
end

powerups.LONG_JUMP_RUNUP = 32.0

powerups.DIVE_RUNUP = 33.0
powerups.DIVE_LIFT = 25.0

powerups.MOVES = {
    dive      = { action = "ACT_DIVE", runup = powerups.DIVE_RUNUP,
                  lift = powerups.DIVE_LIFT },

    flatback  = { action = "ACT_HARD_BACKWARD_GROUND_KB" },

    tripled   = { action = "ACT_TRIPLE_JUMP" },
    backflip  = { action = "ACT_BACKFLIP" },
    sideflip  = { action = "ACT_SIDE_FLIP" },
    longjumped = { action = "ACT_LONG_JUMP", runup = powerups.LONG_JUMP_RUNUP },
    slidekick = { action = "ACT_SLIDE_KICK" },
    pound     = { action = "ACT_GROUND_POUND" },
}

function powerups.on_their_feet(m)
    if m == nil then return false end
    local action = m.action or 0
    if OF.util.has_flag(action, ACT_FLAG_AIR) then return false end
    if OF.util.has_flag(action, ACT_FLAG_SWIMMING) then return false end
    if OF.util.has_flag(action, ACT_FLAG_ON_POLE) then return false end
    if OF.util.has_flag(action, ACT_FLAG_HANGING) then return false end
    return true
end

function powerups.make_them_move(m, key)
    if m == nil then return false end
    local move = powerups.MOVES[key]
    if move == nil then return false end
    local action = _G[move.action]
    if type(action) ~= "number" then return false end
    if not powerups.on_their_feet(m) then
        return false, "Only somebody standing on the floor."
    end

    if move.runup ~= nil and (m.forwardVel or 0) < move.runup then
        m.forwardVel = move.runup
    end
    set_mario_action(m, action, 0)

    if move.lift ~= nil then m.vel.y = move.lift end
    return true
end

powerups.CANNON_SPEED = 100.0

powerups.CANNON_PITCH = 0x1800

function powerups.cannon(m)
    if m == nil then return false end
    if ACT_SHOT_FROM_CANNON == nil then return false end
    if OF.util.has_flag(m.action or 0, ACT_FLAG_SWIMMING) then
        return false, "Not while they are in the water."
    end

    m.faceAngle.x = powerups.CANNON_PITCH
    m.forwardVel = powerups.CANNON_SPEED * coss(powerups.CANNON_PITCH)
    m.vel.y = powerups.CANNON_SPEED * sins(powerups.CANNON_PITCH)
    set_mario_action(m, ACT_SHOT_FROM_CANNON, 0)
    return true
end

powerups.UPDRAUGHT_LIFT = 115.0

function powerups.updraught(m)
    if m == nil then return false end
    if ACT_VERTICAL_WIND == nil then return false end
    if OF.util.has_flag(m.action or 0, ACT_FLAG_SWIMMING) then
        return false, "Not while they are in the water."
    end
    m.vel.y = powerups.UPDRAUGHT_LIFT
    set_mario_action(m, ACT_VERTICAL_WIND, 0)
    return true
end

powerups.THROWN_SPEED = 40.0
powerups.THROWN_LIFT = 40.0

powerups.WALLKICK_LIFT = 109.0

powerups.SPAWN_SPIN_LIFT = 80.0

powerups.BONK_SPEED = -14.0
powerups.BONK_LIFT = 18.0

powerups.LAUNCHES = {
    wallkick  = { action = "ACT_WALL_KICK_AIR", lift = powerups.WALLKICK_LIFT },
    jumpkick  = { action = "ACT_JUMP_KICK" },

    pipe       = { action = "ACT_EMERGE_FROM_PIPE" },
    spawnspin  = { action = "ACT_SPAWN_SPIN_AIRBORNE",
                   lift = powerups.SPAWN_SPIN_LIFT },

    thrownback = { action = "ACT_THROWN_BACKWARD", arg = 1,
                   speed = -powerups.THROWN_SPEED, lift = powerups.THROWN_LIFT },
    bonk       = { action = "ACT_SOFT_BONK", speed = powerups.BONK_SPEED,
                   lift = powerups.BONK_LIFT },
}

function powerups.throw_them_forward(m)
    if m == nil then return false end
    if ACT_THROWN_FORWARD == nil then return false end
    if OF.util.has_flag(m.action or 0, ACT_FLAG_SWIMMING) then
        return false, "Not while they are in the water."
    end

    m.forwardVel = powerups.THROWN_SPEED
    m.vel.y = powerups.THROWN_LIFT
    set_mario_action(m, ACT_THROWN_FORWARD, 1)
    return true
end

function powerups.launch_them(m, key)
    if m == nil then return false end
    local launch = powerups.LAUNCHES[key]
    if launch == nil then return false end
    local action = _G[launch.action]
    if type(action) ~= "number" then return false end
    if OF.util.has_flag(m.action or 0, ACT_FLAG_SWIMMING) then
        return false, "Not while they are in the water."
    end

    if launch.speed ~= nil then m.forwardVel = launch.speed end
    set_mario_action(m, action, launch.arg or 0)
    if launch.lift ~= nil then m.vel.y = launch.lift end
    return true
end

powerups.GUST_GRAVITY = 0.4
powerups.GUST_SPEED = -24.0
powerups.GUST_LIFT = 12.0

local function fold_s16(value)
    return ((value + 0x8000) % 0x10000) - 0x8000
end

function powerups.gust(m, blowYaw)
    if m == nil then return false end
    if ACT_GETTING_BLOWN == nil then return false end
    if OF.util.has_flag(m.action or 0, ACT_FLAG_SWIMMING) then
        return false, "Not while they are in the water."
    end

    if type(blowYaw) == "number" and m.faceAngle ~= nil then
        m.faceAngle.y = fold_s16(blowYaw + 0x8000)
    end
    m.unkC4 = powerups.GUST_GRAVITY
    m.forwardVel = powerups.GUST_SPEED
    m.vel.y = powerups.GUST_LIFT
    set_mario_action(m, ACT_GETTING_BLOWN, 0)
    return true
end

function powerups.fanfare()
    if play_power_star_jingle == nil then return false end
    play_power_star_jingle(true)
    return true
end

powerups.JACKPOT_SKIPS = {
    jackpot = true, surprise = true, fanfare = true, capback = true,
}

powerups.lastGiven = nil

function powerups.jackpot(scale, amount, quiet)
    local given = 0
    powerups.drop_carried()
    for _, entry in ipairs(powerups.EVERY) do
        if entry.kind == "good" and not powerups.JACKPOT_SKIPS[entry.key] then
            if powerups.run(entry.key, scale, amount, quiet) then
                given = given + 1
            end
        end
    end
    return given > 0
end

local rollState = nil

local function roll_one(n)
    if rollState == nil then
        if OF.util.asks(OF.util, "random_int") then
            rollState = OF.util.random_int(1, 2147483647)
        else

            rollState = math.floor(math.random(2147483647))
        end
    end
    rollState = (1664525 * rollState + 1013904223) % 4294967296
    return math.floor(rollState / 65536) % n + 1
end

function powerups.lag_of(globalIndex)
    if type(globalIndex) ~= "number" then return 0 end
    if not OF.util.asks(OF.gamemodes, "finishing_order") then return 0 end

    local localIndex = OF.util.local_from_global(globalIndex)
    if localIndex == nil then return 0 end

    local board, column = OF.gamemodes.finishing_order()
    if type(board) ~= "table" or #board < 2 then return 0 end
    if type(column) ~= "function" then return 0 end

    local mine = nil
    for _, entry in ipairs(board) do
        if entry.localIndex == localIndex then mine = entry end
    end
    if mine == nil then return 0 end

    local said = column(mine)
    local ahead, behind, passed = 0, 0, false
    for _, entry in ipairs(board) do
        if entry == mine then
            passed = true
        elseif column(entry) ~= said then
            if passed then behind = behind + 1 else ahead = ahead + 1 end
        end
    end

    if ahead + behind == 0 then return 0 end
    return ahead / (ahead + behind)
end

function powerups.draw_odds(poolIndex, globalIndex)
    local pool = powerups.POOLS[clamp_index(poolIndex, powerups.POOLS, 1)]
    local lag = pool.lifts == true and powerups.lag_of(globalIndex) or 0

    local odds = {}
    for _, entry in ipairs(powerups.EVERY) do

        if entry.key ~= "surprise" and entry.key ~= "jackpot"
            and entry.key ~= "again" and pool.kinds[entry.kind] then
            local lift = entry.lift
            if lift == nil then
                lift = (tonumber(entry.weight) or 1)
                    * powerups.kindness(entry.kind)
            end
            odds[#odds + 1] = {
                key = entry.key,
                weight = OF.util.draw_weight(
                    { weight = entry.weight, lift = lift }, lag),
            }
        end
    end
    return odds
end

function powerups.roll(poolIndex, globalIndex, roll)
    local odds = powerups.draw_odds(poolIndex, globalIndex)
    if #odds == 0 then return nil end

    local picked = OF.util.pick_weighted(odds, 0, roll or roll_one)
    if picked == nil then return nil end
    return picked.key
end

powerups.CAP_BOXES = {
    { bhv = "id_bhvWingCap",   model = "E_MODEL_MARIOS_WING_CAP" },
    { bhv = "id_bhvMetalCap",  model = "E_MODEL_MARIOS_METAL_CAP" },
    { bhv = "id_bhvVanishCap", model = "E_MODEL_MARIOS_CAP" },
}

local CAP_BOX_REACH = 260

local CAP_BOX_LIFT = 140

function powerups.toss_a_cap_box(m, mark)
    if m == nil or m.pos == nil then return false end
    if spawn_non_sync_object == nil then return false end

    local pick = powerups.CAP_BOXES[roll_one(#powerups.CAP_BOXES)]
    local bhv, model = _G[pick.bhv], _G[pick.model]
    if type(bhv) ~= "number" or type(model) ~= "number" then
        return false, "This build has no cap box to throw."
    end

    local yaw = (m.faceAngle ~= nil and tonumber(m.faceAngle.y)) or 0
    local setup = no_setup
    if mark ~= nil then
        setup = function(o) o.oBehParams2ndByte = mark end
    end
    local box = spawn_non_sync_object(bhv, model,
        m.pos.x + sins(yaw) * CAP_BOX_REACH,
        m.pos.y + CAP_BOX_LIFT,
        m.pos.z + coss(yaw) * CAP_BOX_REACH, setup)
    if box == nil then return false end

    if mark ~= nil then powerups.shy = true end
    return true
end

powerups.COIN_BURST = 5

function powerups.scatter_coins(m)
    if m == nil or m.pos == nil then return false end
    if spawn_non_sync_object == nil then return false end
    local bhv, model = id_bhvSingleCoinGetsSpawned, E_MODEL_YELLOW_COIN
    if type(bhv) ~= "number" or type(model) ~= "number" then
        return false, "This build has no coins to scatter."
    end

    local made = 0
    for _ = 1, powerups.COIN_BURST do

        local coin = spawn_non_sync_object(bhv, model,
            m.pos.x, m.pos.y + 60, m.pos.z, no_setup)
        if coin ~= nil then made = made + 1 end
    end

    return made > 0
end

function powerups.bounce_them(m)
    if m == nil then return false end
    if ACT_CRAZY_BOX_BOUNCE == nil then return false end
    if OF.util.has_flag(m.action or 0, ACT_FLAG_SWIMMING) then
        return false, "Not while they are in the water."
    end
    set_mario_action(m, ACT_CRAZY_BOX_BOUNCE, 0)
    return true
end

powerups.SUITS = {

    wing    = { caps = { MARIO_WING_CAP } },
    metal   = { caps = { MARIO_METAL_CAP } },
    vanish  = { caps = { MARIO_VANISH_CAP } },
    allcaps = { caps = { MARIO_WING_CAP, MARIO_METAL_CAP, MARIO_VANISH_CAP } },
    fire   = { ball = 1 },
    ice    = { ball = 2 },
    gale   = { ball = 3 },
    spark  = { ball = 4 },
    dream  = { ball = 5 },
    spring = {},
    glide  = { caps = { MARIO_WING_CAP }, wing = true },

    soar   = { caps = { MARIO_WING_CAP }, free = true },
    magnet = { drift = 1 },
    repel  = { drift = -1 },

    airmask    = { grant = true },
    springheel = { grant = true },
    wallgrip   = { grant = true },
    feather    = { grant = true },

    shield     = { guard = true },

    double     = { coins = 2 },
}

powerups.GRANTS = {
    airmask    = { cheat = "gasmask" },
    springheel = { cheat = "springs", rung = 2 },
    wallgrip   = { cheat = "grip" },
    feather    = { cheat = "float", rung = 3 },
}

powerups.STEPS = {
    springheel = { cheat = "springs", plain = 2 },
    feather    = { cheat = "float",   plain = 3 },

    boom       = { plain = 1, names = { "now", "on a twelve-second fuse" } },
    wound      = { plain = 1, names = {
        "one wedge", "two wedges", "three wedges", "four wedges",
        "five wedges", "six wedges", "seven wedges", "the whole meter",

        "as many wedges as it draws",
    } },
}

function powerups.wedges_asked(step)
    local names = powerups.STEPS.wound.names
    local at = powerups.clamp_step("wound", step) or 1
    if at < #names then return at end
    return math.random(1, #names - 2)
end

powerups.NAMED_STEPS = {}

powerups.steps = powerups.steps or {}

function powerups.step_list(key)
    local spec = powerups.STEPS[key or ""]
    if spec == nil then return nil end
    if spec.names ~= nil then
        local made = powerups.NAMED_STEPS[key]
        if made == nil then
            made = {}
            for n, name in ipairs(spec.names) do made[n] = { name = name } end
            powerups.NAMED_STEPS[key] = made
        end
        return made
    end
    if OF.cheats == nil or type(OF.cheats.GRANTED) ~= "table" then return nil end
    local ladder = OF.cheats.GRANTED[spec.cheat]
    if type(ladder) ~= "table" or type(ladder.levels) ~= "table" then return nil end
    if #ladder.levels < 2 then return nil end
    return ladder.levels
end

function powerups.step_count(entry)
    local key = entry
    if type(entry) == "table" then key = entry.key end
    local levels = powerups.step_list(key)
    if levels == nil then return 1 end
    return #levels
end

function powerups.clamp_step(key, index)
    local levels = powerups.step_list(key)
    if levels == nil then return nil end
    local spec = powerups.STEPS[key]
    local at = math.floor(tonumber(index) or 0)
    if at < 1 or at > #levels then at = spec.plain or 1 end
    if at > #levels then at = #levels end
    return at
end

function powerups.step(key)
    if powerups.step_list(key) == nil then return nil end
    return powerups.clamp_step(key, powerups.steps[key]
        or (powerups.STEPS[key] or {}).plain)
end

function powerups.set_step(key, index)
    local at = powerups.clamp_step(key, index)
    if at == nil then return false end
    powerups.steps[key] = at
    if powerups.mine[key] == true then
        powerups.mineStop[key] = at
        powerups.settle_mine(key)
    end
    return true
end

function powerups.step_name_at(key, at)
    local levels = powerups.step_list(key)
    if levels == nil or type(at) ~= "number" or at <= 0 then return nil end
    local stop = levels[at]
    if type(stop) ~= "table" then return nil end
    return stop.name
end

function powerups.step_name(key)
    return powerups.step_name_at(key, powerups.step(key))
end

function powerups.granting(cheatKey)
    for slot, key in pairs(powerups.worn) do
        local grant = powerups.GRANTS[key]
        if grant ~= nil and grant.cheat == cheatKey then
            return powerups.wornRung[slot] or grant.rung or 1
        end
    end
    return nil
end

powerups.SLOT_CAP = "cap"
powerups.SLOT_FLOWER = "flower"
powerups.SLOT_PULL = "pull"
function powerups.slot_of(key)
    local suit = key ~= nil and powerups.SUITS[key] or nil
    if suit == nil then return nil end
    if suit.caps ~= nil then return powerups.SLOT_CAP end
    if suit.ball ~= nil then return powerups.SLOT_FLOWER end
    if suit.drift ~= nil then return powerups.SLOT_PULL end
    return key
end

function powerups.share_slot(one, other)
    local a = powerups.slot_of(one)
    if a == nil then return false end
    return a == powerups.slot_of(other)
end

powerups.worn = {}
powerups.wornRung = {}
powerups.wornPull = 0
powerups.swinging = false

function powerups.worn_in(slot)
    if slot == nil then return nil end
    return powerups.worn[slot]
end

function powerups.wearing(key)
    local slot = powerups.slot_of(key)
    if slot == nil then return false end
    return powerups.worn[slot] == key
end

function powerups.any_worn()
    return next(powerups.worn) ~= nil
end

function powerups.worn_keys()
    local keys = {}
    for _, key in pairs(powerups.worn) do keys[#keys + 1] = key end
    table.sort(keys)
    return keys
end

powerups.PULL_MAX = 0.9
powerups.PULL_MIN = 0.01

function powerups.magnet_pull(amount)
    local pull = (tonumber(amount) or 100) / 100
    if pull > powerups.PULL_MAX then pull = powerups.PULL_MAX end
    if pull < powerups.PULL_MIN then pull = powerups.PULL_MIN end
    return pull
end

function powerups.wear(m, key, scale, amount, quiet, step)
    if m == nil then return false end
    local suit = powerups.SUITS[key]
    if suit == nil then return false end

    if suit.caps ~= nil then

        for index, flag in ipairs(suit.caps) do
            give_cap(m, flag, scale, index < #suit.caps or quiet)
        end
    else
        local want = powerups.frames(powerups.SUIT_FRAMES, scale or 1,
            powerups.U16_MAX)
        if want > (m.capTimer or 0) then m.capTimer = want end
        if not quiet then OF.sounds.play(SOUND_MENU_STAR_SOUND) end
    end

    local slot = powerups.slot_of(key)
    powerups.worn[slot] = key
    powerups.wornPull = powerups.magnet_pull(amount)

    powerups.wornRung[slot] = powerups.clamp_step(key, step)
    powerups.swinging = false
    return true
end

function powerups.take_off(slot)
    if slot == nil then
        powerups.worn = {}
        powerups.wornRung = {}
        powerups.swinging = false
        return true
    end
    powerups.worn[slot] = nil
    powerups.wornRung[slot] = nil
    if slot == powerups.SLOT_FLOWER then powerups.swinging = false end
    return true
end

local WORN_KEY = "ofWorn"
powerups.WORN_KEY = WORN_KEY

powerups.carried = {}
powerups.carriedAmount = {}
powerups.carriedStep = {}

function powerups.carried_in(slot)
    if slot == nil then return nil end
    return powerups.carried[slot]
end

function powerups.carries(key)
    local slot = powerups.slot_of(key)
    if slot == nil then return false end
    return powerups.carried[slot] == key
end

function powerups.any_carried()
    return next(powerups.carried) ~= nil
end

function powerups.carried_keys()
    local keys = {}
    for _, key in pairs(powerups.carried) do keys[#keys + 1] = key end
    table.sort(keys)
    return keys
end

local WORN_JOIN = ","
function powerups.publish_carried()
    local keys = powerups.carried_keys()
    OF.util.publish_row(0, WORN_KEY,
        #keys > 0 and table.concat(keys, WORN_JOIN) or nil)
    return true
end

function powerups.carried_by(globalIndex)
    local mine = network_global_index_from_local(0)
    if globalIndex == nil or globalIndex == mine then
        return powerups.carried_keys()
    end

    local localIndex = OF.util.local_from_global(globalIndex)
    if localIndex == nil then return {} end
    local row = gPlayerSyncTable[localIndex]
    if row == nil then return {} end
    local said = row[WORN_KEY]
    if type(said) ~= "string" or said == "" then return {} end
    local keys = {}

    for piece in string.gmatch(said, "[^" .. WORN_JOIN .. "]+") do
        keys[#keys + 1] = piece
    end
    return keys
end

function powerups.carrying(globalIndex, key)
    if key == nil then return false end
    for _, carried in ipairs(powerups.carried_by(globalIndex)) do
        if carried == key then return true end
    end
    return false
end

function powerups.carry(m, key, amount, quiet, step)
    if m == nil then return false end
    if powerups.SUITS[key] == nil then return false end
    local slot = powerups.slot_of(key)

    if powerups.carried[slot] == key then
        powerups.drop_carried(slot)
        powerups.take_off(slot)

        powerups.set_mine(key, false)
        if not quiet then OF.sounds.play(SOUND_MENU_CAMERA_BUZZ) end
        return true
    end

    powerups.mineAmount[key] = amount
    powerups.mineStop[key] = powerups.clamp_step(key, step)
    powerups.set_mine(key, true)

    powerups.carried[slot] = key
    powerups.carriedAmount[slot] = amount

    powerups.carriedStep[slot] = step

    powerups.publish_carried()

    return powerups.wear(m, key, 1, amount, quiet, step)
end

function powerups.drop_carried(slot)
    if slot == nil then
        if not powerups.any_carried() then return false end
        powerups.carried = {}
        powerups.carriedAmount = {}
        powerups.carriedStep = {}
        powerups.publish_carried()
        return true
    end
    if powerups.carried[slot] == nil then return false end
    powerups.carried[slot] = nil
    powerups.carriedAmount[slot] = nil
    powerups.carriedStep[slot] = nil
    powerups.publish_carried()
    return true
end

local function wanted_now()
    local out, stops = {}, {}
    local function put(key)
        local slot = powerups.slot_of(key)
        if slot == nil or out[slot] ~= nil then return end
        local at = powerups.in_force(key)
        if at <= 0 then return end
        out[slot] = key
        stops[slot] = powerups.clamp_step(key, at)
    end

    for key, chose in pairs(powerups.mine) do
        if chose == true then put(key) end
    end

    if powerups.room_any() then
        for _, entry in ipairs(powerups.EVERY) do
            if powerups.room_stop(entry.key) ~= nil then put(entry.key) end
        end
    end
    return out, stops
end

function powerups.carried_update(m)
    if m == nil then return false end

    local did = false
    for key, kept in pairs(powerups.KEPT) do
        if powerups.wished(key) or powerups.kept_given(key) then
            local want = powerups.in_force(key) > 0
            local on = kept.is_on(m) == true
            if want ~= on then
                powerups.kept_set(m, key, want)
                did = true
            elseif not want and not on then

                powerups.keptGiven[key] = nil
            end
        end
    end

    local want, stops = wanted_now()

    if next(want) == nil and not powerups.any_carried() then return did end

    if powerups.round_takes_caps() then
        if powerups.any_worn() then powerups.take_off(); did = true end
        return did
    end

    for slot, key in pairs(powerups.carried) do
        if want[slot] ~= key then
            powerups.drop_carried(slot)
            powerups.take_off(slot)
            did = true
        end
    end

    for slot, key in pairs(want) do
        if powerups.carried[slot] ~= key then

            powerups.carried[slot] = key
            powerups.carriedAmount[slot] = powerups.mineAmount[key]
            powerups.carriedStep[slot] = stops[slot]
            powerups.publish_carried()
            did = true
        end
        if powerups.worn[slot] ~= key or (m.capTimer or 0) <= 0 then
            powerups.wear(m, key, 1, powerups.carriedAmount[slot], true,
                powerups.carriedStep[slot])
            did = true
        end
    end
    return did
end

powerups.KEPT = {
    triple = {

        is_on = function(m) return (m.specialTripleJump or 0) ~= 0 end,
        on    = function(m) return powerups.winged_triple_jump(m) end,
        off   = function(m)
            m.specialTripleJump = 0
            return true
        end,
    },
}

powerups.keptGiven = powerups.keptGiven or {}

function powerups.kept_set(m, key, on)
    local kept = powerups.KEPT[key]
    if m == nil or kept == nil then return false end
    local did
    if on then did = kept.on(m) == true else did = kept.off(m) == true end
    if did and (m.playerIndex or 0) == 0 then
        powerups.keptGiven[key] = on and true or nil
    end
    return did
end

function powerups.kept_given(key)
    return powerups.keptGiven[key] == true
end

function powerups.is_toggle(entry)
    if type(entry) ~= "table" then return false end
    return entry.carry == true or entry.kept == true
end

function powerups.kept_on(globalIndex, key)
    local kept = powerups.KEPT[key]
    if kept == nil or globalIndex == nil then return false end
    local localIndex = OF.util.local_from_global(globalIndex)
    if localIndex == nil then return false end
    local m = gMarioStates[localIndex]
    if m == nil then return false end
    return kept.is_on(m) == true
end

function powerups.toggled_on(globalIndex, entry)
    if type(entry) ~= "table" then return false end
    if entry.carry then return powerups.carrying(globalIndex, entry.key) end
    if entry.kept then return powerups.kept_on(globalIndex, entry.key) end
    return false
end

function powerups.keep(m, key, quiet, hand)
    local kept = powerups.KEPT[key]
    if m == nil or kept == nil then return false end

    if kept.is_on(m) then
        if hand then

            return false
        end
        local off = powerups.kept_set(m, key, false)

        if off then powerups.set_mine(key, false) end
        if off and not quiet then OF.sounds.play(SOUND_MENU_CAMERA_BUZZ) end
        return off
    end
    local on = powerups.kept_set(m, key, true)
    if on then powerups.set_mine(key, true) end
    return on
end

local ROOM_KEY = "ofRoomPowers"
powerups.ROOM_KEY = ROOM_KEY

local roomAt, roomSet = nil, nil

function powerups.room_text()
    local said = gGlobalSyncTable[ROOM_KEY]
    if type(said) ~= "string" then return "" end
    return said
end

local function room_piece(piece)
    local key, at = string.match(piece, "^([^=]+)=(%d+)$")
    if key == nil then key, at = piece, nil end
    local entry = powerups.find(key)
    if entry == nil or not powerups.is_toggle(entry) then return nil end

    return key, powerups.clamp_step(key, at ~= nil and tonumber(at) or nil)
end

function powerups.room_parse(packed)
    local set, filled = {}, {}
    if packed == nil or packed == "" then return set end
    local said = {}
    for piece in string.gmatch(packed, "[^,]+") do
        local key, at = room_piece(piece)
        if key ~= nil then said[key] = { at = at } end
    end
    for _, entry in ipairs(powerups.EVERY) do
        local one = said[entry.key]
        if one ~= nil then
            local slot = powerups.slot_of(entry.key)
            if slot == nil or filled[slot] == nil then
                if slot ~= nil then filled[slot] = entry.key end
                set[entry.key] = one.at or 1
            end
        end
    end
    return set
end

function powerups.room()
    local text = powerups.room_text()
    if roomSet == nil or roomAt ~= text then
        roomAt = text
        roomSet = powerups.room_parse(text)
    end
    return roomSet
end

function powerups.room_stop(key)
    if key == nil then return nil end
    return powerups.room()[key]
end

function powerups.room_on(key)
    return powerups.room_stop(key) ~= nil
end

function powerups.room_any()
    return next(powerups.room()) ~= nil
end

function powerups.room_packed(set)
    local parts = {}
    for _, entry in ipairs(powerups.EVERY) do
        local at = set[entry.key]
        if at ~= nil then
            local piece = entry.key
            local plain = powerups.clamp_step(entry.key, nil)
            if plain ~= nil and at ~= plain then
                piece = piece .. "=" .. tostring(at)
            end
            table.insert(parts, piece)
        end
    end
    return table.concat(parts, ",")
end

local roomRegistered = false

local function register_room_action()
    if roomRegistered then return end
    if not OF.util.asks(OF.net, "register_action") then return end
    roomRegistered = true

    OF.net.register_action("roompower", "powerup_other",
        function(_, key, at)
            if not OF.util.is_host() then return false, "Only the host." end

            local stop = math.floor(tonumber(at) or 0)
            return powerups.write_room(tostring(key), stop > 0,
                stop > 0 and stop or nil)
        end)

    OF.net.register_action("roompowerclear", "powerup_other", function()
        if not OF.util.is_host() then return false, "Only the host." end
        return powerups.write_room_set({})
    end)
end

function powerups.write_room(key, value, at)
    local entry = powerups.find(key)
    if entry == nil or not powerups.is_toggle(entry) then
        return false, "No such powerup."
    end
    local set = powerups.room_parse(powerups.room_text())
    if value then
        set[key] = powerups.clamp_step(key,
            type(at) == "number" and math.floor(at) or nil) or 1
        local slot = powerups.slot_of(key)
        if slot ~= nil then
            for other in pairs(set) do
                if other ~= key and powerups.slot_of(other) == slot then
                    set[other] = nil
                end
            end
        end
    else
        set[key] = nil
    end
    return powerups.write_room_set(set)
end

function powerups.write_room_set(set)
    if not OF.util.publish(ROOM_KEY, powerups.room_packed(set)) then
        return false, "The lobby would not take that."
    end
    return true
end

function powerups.set_room(key, value, at)
    local entry = powerups.find(key)
    if entry == nil or not powerups.is_toggle(entry) then
        return false, "No such powerup."
    end
    if not OF.perms.can("powerup_other") then
        return false, "Your rank cannot set the lobby's powerups. ("
            .. OF.perms.tier_name(OF.perms.required("powerup_other")) .. "+)"
    end
    register_room_action()
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does("roompower", key,
            value and math.floor(at or 1) or 0)
    end

    if not OF.util.is_host() then
        return false, "No host to ask yet - try again in a second."
    end
    return powerups.write_room(key, value, at)
end

function powerups.set_room_stop(key, at)
    if type(at) ~= "number" then return false, "That is not a setting." end
    at = math.floor(at)
    if at <= 0 then return powerups.set_room(key, false) end
    return powerups.set_room(key, true, at)
end

function powerups.clear_room()
    if not OF.perms.can("powerup_other") then
        return false, "Your rank cannot set the lobby's powerups. ("
            .. OF.perms.tier_name(OF.perms.required("powerup_other")) .. "+)"
    end
    register_room_action()
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does("roompowerclear")
    end
    if not OF.util.is_host() then
        return false, "No host to ask yet - try again in a second."
    end
    return powerups.write_room_set({})
end

powerups.mine = powerups.mine or {}
powerups.mineStop = powerups.mineStop or {}
powerups.mineAmount = powerups.mineAmount or {}

function powerups.mine_stop(key)
    return powerups.clamp_step(key, powerups.mineStop[key])
end

function powerups.mine_state(key)
    local held = powerups.mine[key]
    if held == nil then return nil end
    local room = powerups.room_stop(key)
    if held == false then

        if room == nil then return nil end
        return false
    end
    if room ~= nil and (powerups.mine_stop(key) or 1) == room then return nil end
    return true
end

function powerups.wished(key)
    if key == nil then return false end
    if powerups.mine[key] ~= nil then return true end
    return powerups.room_stop(key) ~= nil
end

function powerups.settle_mine(key)
    if powerups.mine_state(key) ~= nil then return false end
    powerups.mine[key] = nil
    powerups.mineStop[key] = nil
    powerups.mineAmount[key] = nil
    return true
end

function powerups.set_mine(key, state)
    local entry = powerups.find(key)
    if entry == nil or not powerups.is_toggle(entry) then
        return false, "No such powerup."
    end
    if state ~= nil and state ~= true and state ~= false then
        return false, "That is not a setting."
    end

    if state == true then

        if powerups.mineStop[key] == nil then
            powerups.mineStop[key] = powerups.step(key)
        end

        local slot = powerups.slot_of(key)
        if slot ~= nil then
            for other, chose in pairs(powerups.mine) do
                if other ~= key and chose == true
                    and powerups.slot_of(other) == slot then
                    powerups.mine[other] = nil
                    powerups.mineStop[other] = nil
                    powerups.mineAmount[other] = nil
                end
            end
        end
    else
        local slot = powerups.slot_of(key)
        if slot ~= nil and powerups.carried[slot] == key then
            powerups.drop_carried(slot)
            powerups.take_off(slot)
        end

        local kept = powerups.KEPT[key]
        local m = gMarioStates[0]
        if kept ~= nil and powerups.mine[key] == true
            and m ~= nil and kept.is_on(m) then
            powerups.kept_set(m, key, false)
        end
    end

    powerups.mine[key] = state
    if state == nil then
        powerups.mineStop[key] = nil
        powerups.mineAmount[key] = nil
    end
    powerups.settle_mine(key)
    return true
end

function powerups.forget_mine()
    local had = next(powerups.mine) ~= nil
    powerups.mine = {}
    powerups.mineStop = {}
    powerups.mineAmount = {}
    powerups.keptGiven = {}
    return had
end

function powerups.refuse_all()
    for _, entry in ipairs(powerups.EVERY) do
        if entry.carry == true then powerups.set_mine(entry.key, false) end
    end
    return true
end

function powerups.in_force(key, ignoreRound)
    local entry = powerups.find(key)
    if entry == nil or not powerups.is_toggle(entry) then return 0, false end
    if not ignoreRound and powerups.round_takes_caps() then return 0, false end

    local state = powerups.mine_state(key)
    if state == true then return powerups.mine_stop(key) or 1, true end

    if state == false then return 0, true end

    local slot = powerups.slot_of(key)
    if slot ~= nil then
        for other, chose in pairs(powerups.mine) do
            if chose == true and other ~= key
                and powerups.slot_of(other) == slot then
                return 0, false
            end
        end
    end

    local at = powerups.room_stop(key)
    if at ~= nil then return at, false end
    return 0, false
end

powerups.SOAR_CRUISE = 34.0
powerups.SOAR_BOOST = 68.0
powerups.SOAR_PITCH_RATE = 0x180
powerups.SOAR_PITCH_MAX = 0x3C00
powerups.SOAR_LEVEL = 0x100
powerups.SOAR_DEADZONE = 8
powerups.SOAR_STICK_FULL = 64

powerups.soarPitch = 0
powerups.soaring = false

local function toward_zero(value)
    if value >= 0 then return math.floor(value) end
    return -math.floor(-value)
end

local function walk_to(value, target, step)
    if value > target then
        value = value - step
        if value < target then return target end
        return value
    end
    if value < target then
        value = value + step
        if value > target then return target end
        return value
    end
    return target
end

function powerups.free_flight_watch(m)
    if m == nil then
        powerups.soaring = false
        return false
    end

    local key = powerups.worn[powerups.SLOT_CAP]
    local suit = key ~= nil and powerups.SUITS[key] or nil
    if suit == nil or not suit.free
        or ACT_FLYING == nil or m.action ~= ACT_FLYING then
        powerups.soaring = false
        return false
    end
    return true
end

function powerups.free_flight_step(m)
    if m == nil then return false end

    if not powerups.free_flight_watch(m) then return false end

    if not powerups.soaring then
        powerups.soaring = true
        powerups.soarPitch = 0
    end

    local controller = m.controller
    local stickY = (controller ~= nil and tonumber(controller.stickY)) or 0
    local held = (controller ~= nil and tonumber(controller.buttonDown)) or 0

    local pitch = powerups.soarPitch
    if stickY > powerups.SOAR_DEADZONE or stickY < -powerups.SOAR_DEADZONE then
        pitch = pitch
            - stickY * powerups.SOAR_PITCH_RATE / powerups.SOAR_STICK_FULL
    else
        pitch = walk_to(pitch, 0, powerups.SOAR_LEVEL)
    end
    if pitch > powerups.SOAR_PITCH_MAX then pitch = powerups.SOAR_PITCH_MAX end
    if pitch < -powerups.SOAR_PITCH_MAX then pitch = -powerups.SOAR_PITCH_MAX end
    powerups.soarPitch = pitch

    local speed = powerups.SOAR_CRUISE
    if OF.util.has_flag(held, A_BUTTON) then speed = powerups.SOAR_BOOST end

    local yaw = m.faceAngle ~= nil and (tonumber(m.faceAngle.y) or 0) or 0
    local flat = speed * coss(pitch)

    m.forwardVel = speed
    if m.faceAngle ~= nil then m.faceAngle.x = toward_zero(pitch) end
    if m.vel ~= nil then
        m.vel.x = flat * sins(yaw)
        m.vel.y = speed * sins(pitch)
        m.vel.z = flat * coss(yaw)
        m.slideVelX = m.vel.x
        m.slideVelZ = m.vel.z
    end
    return true
end

powerups.BALL_BEHAVIOUR = "id_bhvBouncingFireballFlame"
powerups.BALL_AHEAD = 90
powerups.BALL_LIFT = 40
powerups.BALL_HIT = 110
powerups.BALL_SWEEP = 170

powerups.BALLS = {
    [1] = { model = "E_MODEL_RED_FLAME",  attack = "ATTACK_FROM_ABOVE",
            hurts = "burn" },
    [2] = { model = "E_MODEL_BLUE_FLAME", attack = "ATTACK_KICK_OR_TRIP",
            hurts = "hold" },
    [3] = { model = "E_MODEL_BUBBLE",     attack = "ATTACK_FROM_BELOW",
            hurts = "blow" },

    [4] = { model = "E_MODEL_SPARKLES",   attack = "ATTACK_FAST_ATTACK",
            hurts = "shock" },
    [5] = { model = "E_MODEL_MIST",       attack = "ATTACK_PUNCH",
            hurts = "sleep" },
}

powerups.ENEMY_LISTS = {
    "OBJ_LIST_GENACTOR", "OBJ_LIST_PUSHABLE", "OBJ_LIST_DESTRUCTIVE",
}
powerups.ENEMY_TOUCH = {
    "INTERACT_BOUNCE_TOP", "INTERACT_BOUNCE_TOP2", "INTERACT_DAMAGE",
    "INTERACT_KOOPA", "INTERACT_BULLY", "INTERACT_MR_BLIZZARD",
    "INTERACT_HIT_FROM_BELOW",
}

local enemyLists, enemyBits = nil, nil

local function numbers_of(names)
    local out = {}
    for _, name in ipairs(names) do
        local value = _G[name]
        if type(value) == "number" then table.insert(out, value) end
    end
    return out
end

local function enemy_lists()
    if enemyLists == nil then enemyLists = numbers_of(powerups.ENEMY_LISTS) end
    return enemyLists
end

local function enemy_bits()
    if enemyBits == nil then enemyBits = numbers_of(powerups.ENEMY_TOUCH) end
    return enemyBits
end

local function is_enemy(object)
    local interact = object.oInteractType
    if type(interact) ~= "number" then return false end
    for _, bit in ipairs(enemy_bits()) do
        if OF.util.has_flag(interact, bit) then return true end
    end
    return false
end

local function may_hit(object)
    local id = object.oSyncID
    if type(id) ~= "number" or id == 0 then return true end
    return OF.util.optional("sync_object_is_owned_locally", true, id) == true
end

local function apart(object, x, y, z)
    local dx = (object.oPosX or 0) - x
    local dy = (object.oPosY or 0) - y
    local dz = (object.oPosZ or 0) - z
    return dx * dx + dy * dy + dz * dz
end

local function spend(ball)
    ball.oBehParams2ndByte = 0
end

local function hit_enemies(live)
    if INT_STATUS_INTERACTED == nil or INT_STATUS_WAS_ATTACKED == nil then
        return 0
    end

    local sweep = powerups.BALL_SWEEP * powerups.BALL_SWEEP
    local hit = 0
    for _, list in ipairs(enemy_lists()) do
        local object = OF.util.optional("obj_get_first", nil, list)
        local seen = 0

        while object ~= nil and seen < 96 do
            seen = seen + 1
            if object.activeFlags ~= 0 and is_enemy(object) and may_hit(object) then
                for _, ball in ipairs(live) do
                    local which = ball.oBehParams2ndByte or 0
                    local kind = powerups.BALLS[which]
                    local attack = kind ~= nil and _G[kind.attack] or nil
                    if kind ~= nil and type(attack) == "number" and attack ~= 0
                        and apart(object, ball.oPosX or 0, ball.oPosY or 0,
                            ball.oPosZ or 0) < sweep then
                        object.oInteractStatus = INT_STATUS_INTERACTED
                            + INT_STATUS_WAS_ATTACKED + attack
                        spend(ball)
                        hit = hit + 1
                        break
                    end
                end
            end
            object = OF.util.optional("obj_get_next", nil, object)
        end
    end
    return hit
end

powerups.ICE_HOLD = 0.5

local FIGHTING = 2

powerups.QUIET_ROOM_NOTE = "enemies only, until Players touching is fighting"
powerups.ONE_AT_A_TIME =
    "One cap, one flower, one coin field - everything else stacks."
function powerups.row_note(entry)
    if type(entry) ~= "table" then return nil end
    local suit = powerups.SUITS[entry.key]
    if suit ~= nil and suit.ball ~= nil and not powerups.room_is_fighting() then
        return OF.lang.t(powerups.QUIET_ROOM_NOTE)
    end
    return OF.lang.t(entry.note)
end

function powerups.room_is_fighting()
    if not OF.util.asks(OF.rules, "value") then return true end
    return (OF.rules.value("interactions") or 0) == FIGHTING
end

powerups.PVP_CAPS = { metal = true, vanish = true, allcaps = true }

local FLAG_INVULNERABLE = 0x00020000

function powerups.ball_may_touch(m)
    if m == nil then return false end
    if not powerups.room_is_fighting() then return false end
    if OF.util.has_flag(m.flags or 0, MARIO_METAL_CAP) then return false end
    if OF.util.has_flag(m.flags or 0, MARIO_VANISH_CAP) then return false end
    if OF.util.has_flag(m.action or 0, FLAG_INVULNERABLE) then return false end
    if (tonumber(m.invincTimer) or 0) ~= 0 then return false end
    return true
end

function powerups.balls_update(m)
    if m == nil or m.pos == nil then return false end
    local bhv = _G[powerups.BALL_BEHAVIOUR]
    if type(bhv) ~= "number" then return false end

    local mine = OF.util.optional("network_global_index_from_local", nil, 0)
    local reach = powerups.BALL_HIT * powerups.BALL_HIT

    local live, landed = {}, 0
    local ball = OF.util.optional("obj_get_first_with_behavior_id", nil, bhv)
    local seen = 0
    while ball ~= nil and seen < 64 do
        seen = seen + 1
        local kind = powerups.BALLS[ball.oBehParams2ndByte or 0]
        if kind ~= nil and ball.activeFlags ~= 0 then

            local thrower = (ball.oBehParams or 0) - 1
            local struck = false
            if mine ~= nil and thrower ~= mine
                and apart(ball, m.pos.x, m.pos.y, m.pos.z) < reach
                and powerups.ball_may_touch(m) then

                if kind.hurts == "burn" then
                    struck = powerups.set_alight(m)
                elseif kind.hurts == "shock" then

                    struck = powerups.zap(m)
                elseif kind.hurts == "sleep" then

                    struck = powerups.send_to_sleep(m)
                elseif kind.hurts == "blow" then

                    struck = powerups.gust(m, ball.oMoveAngleYaw)
                else
                    struck = powerups.freeze(m, powerups.ICE_HOLD)
                end
            end
            if struck then
                spend(ball)
                landed = landed + 1
            else
                table.insert(live, ball)
            end
        end
        ball = OF.util.optional("obj_get_next_with_same_behavior_id", nil, ball)
    end

    if #live > 0 then landed = landed + hit_enemies(live) end
    return landed > 0
end

local function ahead_of(m, distance)
    local yaw = (m.faceAngle ~= nil and tonumber(m.faceAngle.y)) or 0
    return m.pos.x + sins(yaw) * distance, m.pos.z + coss(yaw) * distance
end

function powerups.throw_ball(m, which)
    if m == nil or m.pos == nil then return false end
    local kind = powerups.BALLS[which]
    if kind == nil then return false end
    if spawn_sync_object == nil then return false end
    local bhv, model = _G[powerups.BALL_BEHAVIOUR], _G[kind.model]
    if type(bhv) ~= "number" or type(model) ~= "number" then return false end

    local mine = OF.util.optional("network_global_index_from_local", 0, 0) or 0
    local x, z = ahead_of(m, powerups.BALL_AHEAD)
    local yaw = (m.faceAngle ~= nil and tonumber(m.faceAngle.y)) or 0

    local ball = spawn_sync_object(bhv, model, x, m.pos.y + powerups.BALL_LIFT, z,
        function(o)

            o.oIntangibleTimer = -1
            o.oMoveAngleYaw = yaw
            o.oFaceAngleYaw = yaw

            o.oAction = 1
            o.oTimer = 0

            o.oBehParams = mine + 1
            o.oBehParams2ndByte = which
        end)

    if ball ~= nil then
        OF.sounds.play(SOUND_GENERAL_FLAME_OUT)
    end
    return ball ~= nil
end

powerups.SNOWBALL_MARK = 9
powerups.SNOWBALL_MODEL = "E_MODEL_WHITE_PARTICLE"
powerups.SNOWBALL_WATCH = 360

local MOVE_LANDED = 0x0001
local MOVE_ON_GROUND = 0x0002
local MOVE_UNDER_ON_GROUND = 0x0040

powerups.snowball = powerups.snowball or nil

function powerups.throw_a_snowball(m)
    if m == nil or m.pos == nil then return false end
    if powerups.snowball ~= nil then
        return false, "Their snowball is still in the air."
    end
    if spawn_sync_object == nil then return false end
    local bhv = _G[powerups.BALL_BEHAVIOUR]
    local model = _G[powerups.SNOWBALL_MODEL]
    if type(bhv) ~= "number" or type(model) ~= "number" then return false end

    local mine = OF.util.optional("network_global_index_from_local", 0, 0) or 0
    local x, z = ahead_of(m, powerups.BALL_AHEAD)
    local yaw = (m.faceAngle ~= nil and tonumber(m.faceAngle.y)) or 0
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil

    local thrown = spawn_sync_object(bhv, model,
        x, m.pos.y + powerups.BALL_LIFT, z,
        function(o)

            o.oIntangibleTimer = -1
            o.oMoveAngleYaw = yaw
            o.oFaceAngleYaw = yaw

            o.oAction = 1
            o.oTimer = 0
            o.oBehParams = mine + 1
            o.oBehParams2ndByte = powerups.SNOWBALL_MARK
        end)
    if thrown == nil then return false end

    powerups.snowball = {
        left = powerups.SNOWBALL_WATCH,
        x = x, y = m.pos.y + powerups.BALL_LIFT, z = z,
        level = np ~= nil and np.currLevelNum or nil,
        area = np ~= nil and np.currAreaIndex or nil,
    }
    OF.sounds.play(SOUND_ACTION_THROW)
    return true
end

local function still_the_same_place(watch)
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if np == nil or watch.level == nil then return false end
    return np.currLevelNum == watch.level and np.currAreaIndex == watch.area
end

local function land_the_thrower(watch)
    powerups.snowball = nil
    if not still_the_same_place(watch) then return false end
    return OF.util.place_player(0, watch.x, watch.y, watch.z)
end

function powerups.snowball_update(m)
    local watch = powerups.snowball
    if watch == nil then return false end
    if m == nil or m.pos == nil then return false end

    local bhv = _G[powerups.BALL_BEHAVIOUR]
    if type(bhv) ~= "number" then
        powerups.snowball = nil
        return false
    end
    local mine = OF.util.optional("network_global_index_from_local", nil, 0)

    watch.left = watch.left - 1

    local ball = OF.util.optional("obj_get_first_with_behavior_id", nil, bhv)
    local seen = 0
    while ball ~= nil and seen < 64 do
        seen = seen + 1
        if (tonumber(ball.oBehParams2ndByte) or 0) == powerups.SNOWBALL_MARK
            and mine ~= nil
            and (tonumber(ball.oBehParams) or 0) - 1 == mine
            and ball.activeFlags ~= 0 then

            watch.x = tonumber(ball.oPosX) or watch.x
            watch.y = tonumber(ball.oPosY) or watch.y
            watch.z = tonumber(ball.oPosZ) or watch.z

            local flags = tonumber(ball.oMoveFlags) or 0
            if OF.util.has_flag(flags, MOVE_LANDED)
                or OF.util.has_flag(flags, MOVE_ON_GROUND)
                or OF.util.has_flag(flags, MOVE_UNDER_ON_GROUND) then

                watch.y = tonumber(ball.oFloorHeight) or watch.y

                OF.util.optional("obj_mark_for_deletion", nil, ball)
                return land_the_thrower(watch)
            end
            if watch.left <= 0 then return land_the_thrower(watch) end
            return true
        end
        ball = OF.util.optional("obj_get_next_with_same_behavior_id", nil, ball)
    end

    return land_the_thrower(watch)
end

powerups.PEARL_BEHAVIOUR = "id_bhvBetaHoldableObject"
powerups.PEARL_MODEL = "E_MODEL_METALLIC_BALL"
powerups.PEARL_SCALE = 0.5

powerups.PEARL_MARK = 10

powerups.PEARL_LIFT = 40

powerups.PEARL_SPEED_MIN = 40
powerups.PEARL_SPEED_MAX = 170
powerups.PEARL_LOFT_MIN = 20
powerups.PEARL_LOFT_MAX = 35

powerups.PEARL_CHARGE_FULL = 60

powerups.PEARL_THROW_BUTTON = B_BUTTON

local PEARL_THROW_ACTION = 0x80000588

local PEARL_YAW_SLACK = 0x100

powerups.PEARL_WATCH = 600

local HELD_FREE = 0
local HELD_HELD = 1
local HELD_THROWN = 2
local HELD_DROPPED = 3

powerups.pearl = powerups.pearl or nil

powerups.pearlArmed = powerups.pearlArmed or false

powerups.PEARL_CHORD_HOLD = Z_TRIG

powerups.PEARL_CHORD_PRESS = R_JPAD

local function pad_button_name(button)
    if not OF.util.asks(OF.input, "OPEN_BUTTONS") then return nil end
    for _, entry in ipairs(OF.input.OPEN_BUTTONS) do
        if entry.button == button then return entry.name end
    end
    return nil
end

local function pad_button_taken(button)
    if button == nil then return nil end
    if OF.util.asks(OF.input, "opener") and OF.input.opener() == button then
        return "the menu"
    end
    if OF.util.asks(OF.input, "wheel_button")
        and OF.input.wheel_button() == button then
        return "the emote wheel"
    end
    return nil
end

function powerups.pearl_chord_button()
    local want = powerups.PEARL_CHORD_PRESS
    local taken = pad_button_taken(want)
    if taken == nil then return want, pad_button_name(want) end
    return nil, nil, taken
end

local function pearl_landed(wasVelY, nowVelY)
    if wasVelY == nil then return false end
    return wasVelY < 0 and nowVelY >= 0
end

local function pearl_deflected(wasYaw, nowYaw)
    if wasYaw == nil or nowYaw == nil then return false end
    local turned = math.abs(nowYaw - wasYaw)

    if turned > 0x8000 then turned = 0x10000 - turned end
    return turned > PEARL_YAW_SLACK
end

local function pearl_in_water(ball)
    local level = OF.util.optional("find_water_level", nil,
        tonumber(ball.oPosX) or 0, tonumber(ball.oPosZ) or 0)
    if type(level) ~= "number" then return false end
    return level > (tonumber(ball.oPosY) or 0)
end

function powerups.pearl_owner(m)
    if OF.util.asks(OF.gamemodes, "may_leave_level")
        and OF.gamemodes.may_leave_level() == false then
        return "The round decides where they stand."
    end
    if OF.util.asks(OF.jail, "is_jailed") and OF.jail.is_jailed(0) then
        return "The jail is holding them."
    end

    if not OF.util.can_play(0) then
        return "They are not in the game right now."
    end
    if OF.util.asks(OF.together, "roped_to")
        and OF.together.roped_to(0) ~= nil then
        return "They are on the rope."
    end
    if OF.util.asks(OF.together, "allows") and OF.together.ROPE ~= nil
        and OF.together.allows(OF.together.ROPE) then
        return "They are on the rope."
    end
    if OF.util.asks(OF.together, "holding")
        and OF.together.holding(0) ~= nil then
        return "They are carrying somebody."
    end
    if OF.util.asks(OF.warp, "direction") and OF.warp.direction() ~= nil then
        return "Down is not down in this level."
    end
    return nil
end

local function pearl_same_place(watch)
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if np == nil or watch.level == nil then return false end
    return np.currLevelNum == watch.level and np.currAreaIndex == watch.area
end

local function pearl_taken_back(ball)
    powerups.pearl = nil
    if ball ~= nil then
        OF.util.optional("obj_mark_for_deletion", nil, ball)
    end
    return false
end

local function pearl_port(watch)
    powerups.pearl = nil
    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    if m == nil or m.pos == nil then return false end
    if not pearl_same_place(watch) then return false end

    local owner = powerups.pearl_owner(m)
    if owner ~= nil then
        if OF.util.asks(OF.notify, "show") then
            OF.notify.show(owner, "bad", 4)
        end
        return false
    end

    if not OF.util.asks(OF.net, "snap_to") then return false end
    OF.net.snap_to(watch.x, watch.y, watch.z, nil)
    m.peakHeight = watch.y
    return true
end

function powerups.arm_a_pearl(m)
    if m == nil or m.pos == nil then return false end

    if powerups.pearlArmed then
        powerups.pearlArmed = false
        powerups.pearl = nil
        if OF.util.asks(OF.notify, "show") then
            OF.notify.show("No more boxes to fetch", "warn", 4)
        end
        return true
    end
    powerups.pearlArmed = true

    local _, name, taken = powerups.pearl_chord_button()
    if name == nil then
        if OF.util.asks(OF.notify, "show") then
            OF.notify.show(OF.lang.fill("@ has the button this needs",
                taken or "Something else"), "warn", 6)
        end
        return true
    end

    if OF.util.asks(OF.notify, "show") then
        OF.notify.show("Hold Z and tap @ for a ball to throw", "good", 6, name)
    end
    return true
end

function powerups.give_a_pearl(m)
    if m == nil or m.pos == nil then return false end
    if powerups.pearl ~= nil then
        return false, "Their pearl is still in play."
    end
    if m.heldObj ~= nil then return false, "Their hands are full." end

    if OF.util.has_flag(m.action or 0, ACT_FLAG_AIR)
        or OF.util.has_flag(m.action or 0, ACT_FLAG_SWIMMING) then
        return false, "They have to be standing."
    end
    local owner = powerups.pearl_owner(m)
    if owner ~= nil then return false, owner end
    if spawn_sync_object == nil then return false end

    local bhv = _G[powerups.PEARL_BEHAVIOUR]
    local model = _G[powerups.PEARL_MODEL]
    if type(bhv) ~= "number" or type(model) ~= "number" then
        return false, "This build has nothing to put in their hands."
    end

    local mine = OF.util.optional("network_global_index_from_local", 0, 0) or 0
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil

    local box = spawn_sync_object(bhv, model,
        m.pos.x, m.pos.y + powerups.PEARL_LIFT, m.pos.z,
        function(o)
            o.oBehParams = mine + 1
            o.oBehParams2ndByte = powerups.PEARL_MARK

            o.oInteractType = INTERACT_GRABBABLE

            local holdable = 0x0400
            if not OF.util.has_flag(tonumber(o.oFlags) or 0, holdable) then
                o.oFlags = (tonumber(o.oFlags) or 0) + holdable
            end

            OF.util.optional("obj_scale", nil, o, powerups.PEARL_SCALE)
        end)
    if box == nil then return false end

    m.usedObj = box
    OF.util.optional("mario_grab_used_object", nil, m)
    if m.heldObj == nil then

        OF.util.optional("obj_mark_for_deletion", nil, box)
        return false, "The game would not let them hold it."
    end
    set_mario_action(m, ACT_PICKING_UP, 0)

    powerups.pearl = {
        left = powerups.PEARL_WATCH,
        thrown = false, sped = false,
        x = m.pos.x, y = m.pos.y, z = m.pos.z,
        level = np ~= nil and np.currLevelNum or nil,
        area = np ~= nil and np.currAreaIndex or nil,
    }
    return true
end

function powerups.pearl_frame(m, watch, ball)
    local held = tonumber(ball.oHeldState) or HELD_FREE

    if held == HELD_HELD then
        if watch.left > 0 then return true end

        OF.util.optional("mario_drop_held_object", nil, m)
        return pearl_taken_back(ball)
    end

    if held == HELD_THROWN then
        watch.thrown = true
        return true
    end

    if held == HELD_DROPPED then return pearl_taken_back(ball) end

    if not watch.thrown then return pearl_taken_back(ball) end

    if not watch.sped then
        watch.sped = true
        ball.oForwardVel = watch.speed or powerups.PEARL_SPEED_MIN
        ball.oVelY = watch.loft or powerups.PEARL_LOFT_MIN
    end

    watch.x = tonumber(ball.oPosX) or watch.x
    watch.y = tonumber(ball.oPosY) or watch.y
    watch.z = tonumber(ball.oPosZ) or watch.z

    local velY = tonumber(ball.oVelY) or 0
    local yaw = tonumber(ball.oMoveAngleYaw)
    local landed = pearl_landed(watch.velY, velY)
    local hit = landed
        or pearl_deflected(watch.yaw, yaw)
        or pearl_in_water(ball)
    watch.velY = velY
    watch.yaw = yaw

    if hit or watch.left <= 0 then
        OF.util.optional("obj_mark_for_deletion", nil, ball)
        return pearl_port(watch)
    end
    return true
end

function powerups.pearl_update(m)
    local watch = powerups.pearl
    if watch == nil then return false end
    if m == nil or m.pos == nil then return false end

    local bhv = _G[powerups.PEARL_BEHAVIOUR]
    if type(bhv) ~= "number" then
        powerups.pearl = nil
        return false
    end
    local mine = OF.util.optional("network_global_index_from_local", nil, 0)

    watch.left = watch.left - 1

    local ball = OF.util.optional("obj_get_first_with_behavior_id", nil, bhv)
    local seen = 0
    while ball ~= nil and seen < 64 do
        seen = seen + 1
        if (tonumber(ball.oBehParams2ndByte) or 0) == powerups.PEARL_MARK
            and mine ~= nil
            and (tonumber(ball.oBehParams) or 0) - 1 == mine
            and ball.activeFlags ~= 0 then
            return powerups.pearl_frame(m, watch, ball)
        end
        ball = OF.util.optional("obj_get_next_with_same_behavior_id", nil, ball)
    end

    powerups.pearl = nil
    if not watch.thrown then return false end
    return pearl_port(watch)
end

function powerups.pearl_chord(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    if not powerups.pearlArmed then return false end
    if not OF.util.asks(OF.input, "pressed") then return false end

    local button = powerups.pearl_chord_button()
    if button == nil then return false end

    OF.input.poll(m)
    if not OF.input.pressed(button) then return false end
    if not OF.input.held(powerups.PEARL_CHORD_HOLD) then return false end

    local gave, why = powerups.give_a_pearl(m)
    if gave then
        OF.input.take(m, button)
        return true
    end

    if why ~= nil and OF.util.asks(OF.notify, "show") then
        OF.notify.show(why, "warn", 4)
    end
    return false
end

local function pearl_in_hand(m)
    if m == nil or m.heldObj == nil then return false end
    return (tonumber(m.heldObj.oBehParams2ndByte) or 0) == powerups.PEARL_MARK
end

function powerups.pearl_charge_share()
    local watch = powerups.pearl
    if watch == nil or watch.charge == nil then return nil end
    local full = powerups.PEARL_CHARGE_FULL
    if type(full) ~= "number" or full <= 0 then return nil end
    return OF.util.clamp(watch.charge / full, 0, 1)
end

function powerups.pearl_throw_for(share)
    share = OF.util.clamp(tonumber(share) or 0, 0, 1)
    local speed = powerups.PEARL_SPEED_MIN
        + (powerups.PEARL_SPEED_MAX - powerups.PEARL_SPEED_MIN) * share
    local loft = powerups.PEARL_LOFT_MIN
        + (powerups.PEARL_LOFT_MAX - powerups.PEARL_LOFT_MIN) * share
    return speed, loft
end

function powerups.pearl_charge_step(m)
    local watch = powerups.pearl
    if watch == nil then return false end
    if m == nil or m.playerIndex ~= 0 then return false end
    if not OF.util.asks(OF.input, "held") then return false end

    if watch.speed ~= nil then return false end

    local button = powerups.PEARL_THROW_BUTTON
    if button == nil then return false end

    if not pearl_in_hand(m)
        or OF.util.menu_has_screen()
        or (OF.util.asks(OF.input, "blocked") and OF.input.blocked())
        or OF.util.has_flag(m.action or 0, ACT_FLAG_AIR)
        or OF.util.has_flag(m.action or 0, ACT_FLAG_SWIMMING) then
        watch.charge = nil
        return false
    end

    OF.input.poll(m)

    if OF.input.held(button) then

        OF.input.take(m, button)
        watch.charge = math.min((watch.charge or 0) + 1,
            powerups.PEARL_CHARGE_FULL)
        return true
    end

    local charge = watch.charge
    watch.charge = nil
    if charge == nil then return false end

    local speed, loft = powerups.pearl_throw_for(charge / powerups.PEARL_CHARGE_FULL)
    watch.speed = speed
    watch.loft = loft
    set_mario_action(m, PEARL_THROW_ACTION, 0)
    return true
end

function powerups.pearl_pad(m)
    local charged = powerups.pearl_charge_step(m)
    local chorded = powerups.pearl_chord(m)
    return charged or chorded
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, powerups.pearl_pad)

local PEARL_BAR_WIDTH = 120
local PEARL_BAR_HEIGHT = 8
local PEARL_BAR_DOWN = 0.80
local PEARL_BAR_EMPTY = { r = 40, g = 40, b = 40 }

function powerups.pearl_bar()
    local share = powerups.pearl_charge_share()
    if share == nil then return false end
    if OF.util.menu_has_screen() then return false end
    if djui_hud_get_screen_width == nil then return false end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    local width = djui_hud_get_screen_width()
    local height = djui_hud_get_screen_height()
    local x = width * 0.5 - PEARL_BAR_WIDTH * 0.5
    local y = height * PEARL_BAR_DOWN

    OF.util.plate(x - 5, y - 5, PEARL_BAR_WIDTH + 10, PEARL_BAR_HEIGHT + 10)
    OF.util.meter(x, y, PEARL_BAR_WIDTH, PEARL_BAR_HEIGHT, share,
        OF.util.gold(), PEARL_BAR_EMPTY)
    return true
end

hook_event(HOOK_ON_HUD_RENDER, powerups.pearl_bar)

powerups.COIN_KINDS = {
    "id_bhvYellowCoin", "id_bhvSingleCoinGetsSpawned", "id_bhvRedCoin",
}

powerups.COIN_REACH = 900
powerups.COIN_CLOSE = 60

local coinKinds = nil

function powerups.drift_coins(m, pull)
    if m == nil or m.pos == nil then return 0 end
    if obj_get_first_with_behavior_id == nil then return 0 end
    if type(pull) ~= "number" or pull == 0 then return 0 end

    if coinKinds == nil then coinKinds = numbers_of(powerups.COIN_KINDS) end

    local toward = pull > 0
    local step = pull
    local reach = powerups.COIN_REACH * powerups.COIN_REACH
    local close = powerups.COIN_CLOSE * powerups.COIN_CLOSE
    local moved = 0

    for _, kind in ipairs(coinKinds) do
        local coin = obj_get_first_with_behavior_id(kind)
        while coin ~= nil do
            local dx = m.pos.x - (coin.oPosX or 0)
            local dy = m.pos.y - (coin.oPosY or 0)
            local dz = m.pos.z - (coin.oPosZ or 0)
            local away = dx * dx + dy * dy + dz * dz

            if away < reach and (not toward or away > close) then
                if not toward and away < 1 then

                    dx, dy, dz = -sins(m.faceAngle.y) * 30, 0,
                        -coss(m.faceAngle.y) * 30
                end
                coin.oPosX = (coin.oPosX or 0) + dx * step
                coin.oPosY = (coin.oPosY or 0) + dy * step
                coin.oPosZ = (coin.oPosZ or 0) + dz * step

                coin.oVelY = 0
                moved = moved + 1
            end
            coin = obj_get_next_with_same_behavior_id(coin)
        end
    end

    return moved
end

powerups.MARK_RUNNER = 3
powerups.MARK_SHY = 4

powerups.SHY_NOTICE = 700
powerups.SHY_STEP = 0.12

powerups.RUNNER_PATIENCE = 300

powerups.shy = false

powerups.PRIZE_REACH = 260

function powerups.runaway_prize(m)
    if m == nil or m.pos == nil then return false end
    if spawn_non_sync_object == nil then return false end
    local bhv, model = id_bhv1upRunningAway, E_MODEL_1UP
    if type(bhv) ~= "number" or type(model) ~= "number" then
        return false, "This build has no runaway prize to give."
    end

    local x, z = ahead_of(m, powerups.PRIZE_REACH)

    local prize = spawn_non_sync_object(bhv, model, x, m.pos.y + 60, z,
        function(o) o.oBehParams2ndByte = powerups.MARK_RUNNER end)
    if prize == nil then return false end
    powerups.shy = true
    return true
end

function powerups.shy_update(m)
    if powerups.shy ~= true then return false end
    if m == nil or m.pos == nil then return false end
    if obj_get_first_with_behavior_id == nil then return false end

    local notice = powerups.SHY_NOTICE * powerups.SHY_NOTICE
    local found = 0

    local runner = nil
    if type(id_bhv1upRunningAway) == "number" then
        runner = OF.util.optional("obj_get_first_with_behavior_id", nil,
            id_bhv1upRunningAway)
    end
    while runner ~= nil do
        if runner.oBehParams2ndByte == powerups.MARK_RUNNER
            and runner.activeFlags ~= 0 then
            found = found + 1
            if runner.oAction == 1
                and (runner.oTimer or 0) > powerups.RUNNER_PATIENCE then

                runner.oAction = 2
            end
        end
        runner = OF.util.optional("obj_get_next_with_same_behavior_id", nil,
            runner)
    end

    for _, pick in ipairs(powerups.CAP_BOXES) do
        local kind = _G[pick.bhv]
        local box = nil
        if type(kind) == "number" then
            box = OF.util.optional("obj_get_first_with_behavior_id", nil, kind)
        end
        while box ~= nil do
            if box.oBehParams2ndByte == powerups.MARK_SHY
                and box.activeFlags ~= 0 then
                found = found + 1
                local dx = (box.oPosX or 0) - m.pos.x
                local dz = (box.oPosZ or 0) - m.pos.z
                local away = dx * dx + dz * dz
                if away < notice then
                    if away < 1 then

                        dx, dz = sins(m.faceAngle.y) * 30, coss(m.faceAngle.y) * 30
                    end

                    box.oPosX = (box.oPosX or 0) + dx * powerups.SHY_STEP
                    box.oPosZ = (box.oPosZ or 0) + dz * powerups.SHY_STEP
                end
            end
            box = OF.util.optional("obj_get_next_with_same_behavior_id", nil, box)
        end
    end

    if found == 0 then powerups.shy = false end
    return found > 0
end

powerups.HELD = {
    flatten = {
        on  = function(m, scale) return powerups.flatten(m, scale) end,
        off = function(m) m.squishTimer = 0 return true end,
    },
    freeze = {
        on  = function(m, scale) return powerups.freeze(m, scale) end,
        off = function(m) m.freeze = 0 return true end,
    },
}

powerups.holding = nil

function powerups.hold(m, key)
    local held = powerups.HELD[key]
    if m == nil or held == nil then return false end

    if powerups.holding == key then
        powerups.holding = nil
        held.off(m)
        OF.sounds.play(SOUND_MENU_CAMERA_BUZZ)
        return true
    end

    if powerups.holding ~= nil then
        local was = powerups.HELD[powerups.holding]
        if was ~= nil then was.off(m) end
    end
    powerups.holding = key

    return held.on(m, 1)
end

function powerups.held_update(m)
    if m == nil or powerups.holding == nil then return false end
    local held = powerups.HELD[powerups.holding]
    if held == nil then
        powerups.holding = nil
        return false
    end
    return held.on(m, 1) == true
end

function powerups.worn_update(m)
    if m == nil then return false end

    powerups.carried_update(m)
    powerups.held_update(m)
    if not powerups.any_worn() then return false end

    if (m.capTimer or 0) <= 0 then
        powerups.take_off()
        return false
    end

    if powerups.round_takes_caps() then
        powerups.take_off()
        return false
    end

    local did = false
    for slot, key in pairs(powerups.worn) do
        if powerups.worn_frame(m, slot, key) then did = true end
    end
    return did
end

function powerups.worn_frame(m, slot, key)
    local suit = powerups.SUITS[key]
    if suit == nil then
        powerups.take_off(slot)
        return false
    end

    if suit.ball ~= nil then
        local out = OF.util.has_flag(m.flags or 0, MARIO_PUNCHING)
            or OF.util.has_flag(m.flags or 0, MARIO_KICKING)
        if out and not powerups.swinging then powerups.throw_ball(m, suit.ball) end
        powerups.swinging = out
        return true
    end

    if suit.drift ~= nil then
        powerups.drift_coins(m, powerups.wornPull * suit.drift)
        return true
    end

    if suit.guard then
        if (m.hurtCounter or 0) <= 0 then return false end
        m.hurtCounter = 0

        powerups.set_mine(key, false)
        powerups.drop_carried(slot)
        powerups.take_off(slot)

        if not powerups.any_worn() then m.capTimer = 0 end
        OF.sounds.play(SOUND_MENU_STAR_SOUND)
        return true
    end

    if key == "spring" then

        if ACT_CRAZY_BOX_BOUNCE == nil then return false end
        local group = OF.util.action_group(m.action or 0)
        if group ~= OF.util.action_group(ACT_GROUP_STATIONARY)
            and group ~= OF.util.action_group(ACT_GROUP_MOVING) then
            return false
        end
        if OF.util.has_flag(m.action or 0, ACT_FLAG_SWIMMING) then return false end
        set_mario_action(m, ACT_CRAZY_BOX_BOUNCE, 0)
        return true
    end

    if suit.wing then

        if ACT_FLYING == nil then return false end
        if m.action == ACT_FLYING then return false end
        if not OF.util.has_flag(m.action or 0, ACT_FLAG_AIR) then return false end
        if not OF.util.has_flag(m.input or 0, INPUT_A_PRESSED) then
            return false
        end
        set_mario_action(m, ACT_FLYING, 1)
        return true
    end

    return false
end

local function run_powerup(m, key, scale, amount, quiet, step, hand, forever)

    if key == "nocap" then

        m.capTimer = 0

        powerups.drop_carried()

        powerups.take_off()

        powerups.refuse_all()
        for _, flag in ipairs({ MARIO_WING_CAP, MARIO_METAL_CAP, MARIO_VANISH_CAP }) do
            m.flags = clear_bit(m.flags, flag)
        end
    elseif key == "healfull" then

        m.health = FULL_HEALTH
        m.hurtCounter = 0
        m.healCounter = 0
    elseif key == "life" then
        m.numLives = m.numLives + 1
    elseif key == "lives10" then

        local want = (m.numLives or 0) + amount
        if want > S8_MAX then want = S8_MAX end
        if want == m.numLives then return false end
        m.numLives = want
    elseif key == "coins" then
        m.numCoins = powerups.coins_without_eating_the_star(m, amount)
    elseif key == "moon" then
        powerups.moon(m)
    elseif key == "bubbleput" then
        mario_set_bubbled(m)
    elseif key == "invinc" then
        return powerups.star_power(m, scale, quiet)
    elseif powerups.KEPT[key] ~= nil then

        return powerups.keep(m, key, quiet, hand)
    elseif key == "pop" then
        return powerups.pop_bubble(m)
    elseif key == "lifemax" then
        return powerups.lives_to_the_top(m)
    elseif key == "capoff" then
        return powerups.knock_the_cap_off(m)
    elseif key == "blowcap" then
        return powerups.blow_the_cap_away(m)
    elseif key == "capback" then
        return powerups.cap_back_on(m)
    elseif powerups.HELD[key] ~= nil then

        if forever then return powerups.hold(m, key) end
        return powerups.HELD[key].on(m, scale)
    elseif key == "shock" then
        return powerups.zap(m)
    elseif key == "burn" then
        return powerups.set_alight(m)
    elseif key == "lavatoss" then
        return powerups.lava_launch(m)
    elseif key == "boom" then

        if powerups.clamp_step("boom", step) == powerups.fuse_stop() then
            return powerups.light_the_fuse(m)
        end
        return powerups.blow_up(m)
    elseif key == "wound" then

        return powerups.wound(m, powerups.wedges_asked(step))
    elseif powerups.ENDINGS[key] ~= nil then
        return powerups.end_them(m, key)
    elseif key == "firework" then

        return powerups.firework(m)
    elseif key == "takelife" then
        return powerups.take_a_life(m)
    elseif key == "takecoins" then
        return powerups.empty_pockets(m)
    elseif key == "spillcoins" then
        return powerups.spill_pockets(m)
    elseif key == "heal" then
        return powerups.heal_slowly(m, scale)
    elseif key == "poison" then
        return powerups.poison(m, scale)
    elseif key == "planted" then
        return powerups.plant_in_ground(m)
    elseif powerups.STUCK[key] ~= nil then
        return powerups.stick_them_in(m, key)
    elseif key == "shockbounce" then
        return powerups.shockbounce(m)
    elseif key == "slide" then
        return powerups.send_them_sliding(m)
    elseif key == "sleep" then
        return powerups.send_to_sleep(m)
    elseif key == "dropit" then
        return powerups.drop_everything(m)
    elseif key == "knockup" then
        return powerups.knock_over(m)
    elseif key == "fanfare" then
        return powerups.fanfare()
    elseif key == "surf" then
        return powerups.surf(m)
    elseif key == "capbox" then
        return powerups.toss_a_cap_box(m)
    elseif key == "teasecap" then
        return powerups.toss_a_cap_box(m, powerups.MARK_SHY)
    elseif key == "runaway" then
        return powerups.runaway_prize(m)
    elseif key == "snowball" then
        return powerups.throw_a_snowball(m)
    elseif key == "pearl" then

        return powerups.arm_a_pearl(m)
    elseif powerups.SUITS[key] ~= nil then

        local entry = powerups.find(key)
        if entry ~= nil and entry.carry then
            return powerups.carry(m, key, amount, quiet, step)
        end
        return powerups.wear(m, key, scale, amount, quiet, step)
    elseif key == "coinburst" then
        return powerups.scatter_coins(m)
    elseif key == "ballbounce" then
        return powerups.bounce_them(m)
    elseif powerups.MOVES[key] ~= nil then

        return powerups.make_them_move(m, key)
    elseif key == "cannon" then
        return powerups.cannon(m)
    elseif key == "updraught" then
        return powerups.updraught(m)
    elseif key == "gust" then
        return powerups.gust(m)
    elseif key == "thrown" then
        return powerups.throw_them_forward(m)
    elseif powerups.LAUNCHES[key] ~= nil then
        return powerups.launch_them(m, key)
    elseif key == "spintop" then
        return powerups.twirl(m)
    elseif key == "toss" then
        return powerups.toss(m)
    elseif key == "shakescreen" then
        return powerups.quake()
    elseif key == "sink" then
        return powerups.suck_under(m)
    elseif key == "jackpot" then
        return powerups.jackpot(scale, amount, quiet)
    elseif key == "again" then

        return false, "Nothing to repeat on this machine."
    elseif key == "surprise" then

        local rolled = powerups.roll(powerups.pool)
        if rolled == nil then return false end
        return run_powerup(m, rolled, scale, amount, quiet, step, hand,
            forever)
    else

        return false, "no branch"
    end

    return true
end

function powerups.run(key, scale, amount, quiet)
    local m = gMarioStates[0]
    if m == nil then return false end

    return run_powerup(m, key, scale, amount, quiet, nil, true)
end

function powerups.carried_row(key)
    if key == nil then return false end
    local entry = powerups.find(key)
    if entry == nil or entry.carry ~= true then return false end
    return powerups.SUITS[key] ~= nil
end

function powerups.take_carried(key)

    if key == nil then
        powerups.drop_carried()
        powerups.take_off()

        powerups.forget_mine()

        powerups.pearlArmed = false
        powerups.pearl = nil
        return true
    end
    local slot = powerups.slot_of(key)
    if slot == nil or powerups.carried[slot] ~= key then return false end
    powerups.drop_carried(slot)
    powerups.take_off(slot)

    powerups.set_mine(key, nil)
    return true
end

function powerups.apply(key, opts)
    local m = gMarioStates[0]
    if m == nil then return false end

    if opts ~= nil and opts.off == true then
        return powerups.take_carried(key)
    end

    local scale, amount, forever, step, hand = powerups.settings_from(opts)
    return run_powerup(m, key, scale, amount, false, step, hand, forever)
end

function powerups.give(globalIndex, key, opts, by)

    if key == "surprise" then
        key = powerups.roll(powerups.pool, globalIndex) or key
        if key == "surprise" then return false, "Nothing in that pool." end
    end

    if key == "again" then
        if powerups.lastGiven == nil then
            return false, "Nothing has been handed out yet."
        end
        key = powerups.lastGiven
    end

    local entry = powerups.find(key)
    if entry == nil then return false end

    powerups.lastGiven = key

    opts = opts or powerups.settings(key)

    local function record(who)
        if not OF.util.asks(OF.chatlog, "add_system") then return end
        local note = powerups.given_note(entry, opts)
        if note == nil then return end
        local said = OF.lang.fill("gave @ @", OF.util.plain(who or "?"), note)

        if entry.carry or powerups.staying(entry.key) then
            said = OF.lang.fill("switched @ @", OF.util.plain(who or "?"), note)
        end
        OF.chatlog.add_system(said, by)
    end

    local me = network_global_index_from_local(0)
    if globalIndex == me then
        if not OF.perms.can("powerup_self") then
            return false, "Your rank cannot do that. ("
                .. OF.perms.tier_name(OF.perms.required("powerup_self")) .. "+)"
        end

        if powerups.PVP_CAPS[key] and powerups.room_is_fighting() then
            return false, "Players touching is fighting - not on yourself."
        end
        local gave, why = powerups.apply(key, opts)
        if not gave then

            if why ~= nil and why ~= "no branch" then return false, why end
            return false, "Nothing to do that to."
        end

        if not (tonumber(opts.q) == 1) then
            OF.notify.show(entry.name, entry.kind)
        end

        local np = gNetworkPlayers[0]
        record(np ~= nil and np.name or nil)

        return true, nil, entry
    end

    if not OF.perms.can("powerup_other") then
        return false, "Your rank cannot do that. ("
            .. OF.perms.tier_name(OF.perms.required("powerup_other")) .. "+)"
    end

    if not OF.util.is_host() then

        local settings = powerups.settings(key)
        OF.util.send_to_host({
            ofp = powerups.PACKET_ASK,
            who = globalIndex,
            what = key,
            ln = settings.ln,
            am = settings.am,
            q = settings.q,
            st = settings.st,
        })
        return true, nil, entry
    end

    local li = OF.util.local_from_global(globalIndex)
    if li == nil then return false end

    local ok, why = OF.util.send_to_player(li, {
        ofp = powerups.PACKET,
        what = key,
        ln = opts.ln,
        am = opts.am,

        fv = opts.fv,
        st = opts.st,

        off = opts.off == true or nil,
    })

    if not (tonumber(opts.q) == 1) then
        OF.notify.send_to(globalIndex, "@ from a moderator", entry.kind, nil,
            entry.name)
    end

    local np = gNetworkPlayers[li]
    record(np ~= nil and np.name or nil)
    if not ok then return false, why end
    return true, nil, entry
end

function powerups.take_back_many(globalIndexes, key)
    if type(globalIndexes) ~= "table" then return 0 end

    if not OF.util.is_host() then return 0 end

    local told = 0
    local me = network_global_index_from_local(0)
    for _, globalIndex in ipairs(globalIndexes) do
        if globalIndex == me then

            if powerups.take_carried(key) then told = told + 1 end
        else
            local li = OF.util.local_from_global(globalIndex)
            if li ~= nil then
                OF.util.send_to_player(li, {
                    ofp = powerups.PACKET,
                    what = key,
                    off = true,
                })
                told = told + 1
            end
        end
    end
    return told
end

function powerups.give_many(globalIndexes, key)
    local given, why, last = 0, nil, nil
    for _, globalIndex in ipairs(globalIndexes) do
        local ok, reason, entry = powerups.give(globalIndex, key)
        if ok then
            given = given + 1
            last = entry
        elseif why == nil then
            why = reason
        end
    end

    return given, why, last
end

local function on_packet_receive(data)
    if data == nil then return end

    if data.ofp == powerups.PACKET_ASK then
        if not OF.util.is_host() then return end

        local asker, askerGlobal = OF.util.asked_by(data)
        if asker == nil then return end

        local need = "powerup_other"
        if data.who == askerGlobal then need = "powerup_self" end
        if OF.perms.tier(asker) < OF.perms.required(need) then
            OF.notify.send_to(askerGlobal, "Your rank cannot do that.", "bad", 5)
            return
        end

        local target = OF.util.local_from_global(data.who)

        local may, whyNot = OF.util.may_act_on(asker, target)
        if not may then
            OF.util.tell_asker(askerGlobal, whyNot)
            return
        end

        local np = gNetworkPlayers[asker]
        local gave, whyNotGiven = powerups.give(data.who, data.what, {
            ln = data.ln, am = data.am, q = data.q, st = data.st,
        }, np ~= nil and OF.util.plain(np.name) or nil)
        if not gave then
            OF.util.tell_asker(askerGlobal, whyNotGiven)
            return
        end
        return
    end

    if data.ofp ~= powerups.PACKET then return end

    if not OF.util.from_host_effect(data) then return end

    powerups.apply(data.what, data)
end

hook_event(HOOK_ON_PACKET_RECEIVE, on_packet_receive)

local function coin_worth(o)
    local worth = o ~= nil and o.oDamageOrCoinValue or 1
    if type(worth) ~= "number" or worth < 1 then return 1 end
    if worth > 5 then return 5 end
    return math.floor(worth)
end

local function coin_multiplier()
    local most = 1
    for _, key in pairs(powerups.carried) do
        local suit = powerups.SUITS[key]
        local times = suit ~= nil and suit.coins or nil
        if type(times) == "number" and times > most then most = times end
    end
    return most
end

hook_event(HOOK_ON_INTERACT, function(m, o, interactType)
    if m == nil or m.playerIndex ~= 0 then return end
    if interactType ~= INTERACT_COIN then return end
    local times = coin_multiplier()
    if times <= 1 then return end

    local extra = coin_worth(o) * (times - 1)
    if extra < 1 then return end
    m.numCoins = powerups.coins_without_eating_the_star(m, extra)
end)

hook_event(HOOK_UPDATE, function()
    powerups.cap_round_update()
end)

hook_event(HOOK_MARIO_UPDATE, function(m)

    if m ~= nil then powerups.firework_update(m) end
    if m == nil or m.playerIndex ~= 0 then return end
    powerups.worn_update(m)
    powerups.balls_update(m)
    powerups.shy_update(m)

    powerups.fuse_update(m)
    powerups.snowball_update(m)
    powerups.pearl_update(m)

    powerups.free_flight_watch(m)
end)

hook_event(HOOK_BEFORE_PHYS_STEP, function(m, stepType, stepArg)
    if m == nil or m.playerIndex ~= 0 then return end
    if stepType ~= STEP_TYPE_AIR then return end
    powerups.free_flight_step(m)
end)

hook_event(HOOK_ALLOW_INTERACT, function(m, obj, interactType)
    if interactType ~= INTERACT_CAP then return end
    if m == nil or m.playerIndex ~= 0 then return end
    if obj == nil then return end
    if powerups.cap_grace_left() <= 0 then return end
    if obj ~= loose_cap_of(m) then return end
    return false
end)
