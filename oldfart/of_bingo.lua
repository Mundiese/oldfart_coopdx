OF = OF or {}
OF.bingo = OF.bingo or {}

local bingo = OF.bingo

local SIZE = 5
local CELLS = SIZE * SIZE

local function stream(seed)
    local state = math.floor(seed) % 2147483648
    return function(n)
        state = (1664525 * state + 1013904223) % 4294967296

        return math.floor(state / 65536) % n
    end
end

local function permutation(next_int)
    local list = { 0, 1, 2, 3, 4 }
    for i = SIZE, 2, -1 do
        local j = next_int(i) + 1
        list[i], list[j] = list[j], list[i]
    end
    return list
end

function bingo.square(seed)
    local next_int = stream(seed)
    local five = permutation(next_int)
    local one = permutation(next_int)

    local board = {}
    for y = 0, SIZE - 1 do
        for x = 0, SIZE - 1 do

            board[y * SIZE + x + 1] =
                5 * five[((x + 3 * y) % SIZE) + 1] + one[((3 * x + y) % SIZE) + 1]
        end
    end
    return board
end

bingo.EASY = {
    "Collect 30 coins in one level",
    "Get a star in Bob-omb Battlefield",
    "Get a star in Whomp's Fortress",

    "Ride a Koopa Shell",
    "Get the Wing Cap",
    "Break open a box",
    "Get a Bob-omb Buddy to open a cannon",
    "Collect 8 red coins anywhere",
    "Read three signs in three different places",
    "Get a star in a level before touching a coin",
    "Bounce off three Goombas without landing",

    "Do a triple jump",
    "Do a backflip",
    "Do a long jump",
    "Do a side flip",
    "Dive head first",
    "Do a ground pound",
    "Pick something up",
    "Crawl somewhere",
    "Throw a punch",
    "Grab on to a pole",
    "Collect a red coin",
    "Get a 1-Up",

    "Wall-kick off something",
    "Slide down on your stomach",
    "Get to the top of a pole",
    "Collect 3 red coins anywhere",
    "Visit two different courses",
    "Read a sign",

    "Collect 5 red coins anywhere",
    "Visit three different courses",
    "Read two signs in two different places",
    "Get two stars since this card was dealt",
    "Survive a long fall",
}
bingo.MEDIUM = {
    "Do a slide kick",
    "Bounce off a Spindrift or a Fly Guy",
    "Get blown straight up by a wind",
    "Collect 16 red coins anywhere",
    "Get three stars in one visit to a level",
    "Get a star in Jolly Roger Bay",
    "Get a star in Cool, Cool Mountain",
    "Get 100 coins in one level",
    "Come up out of the water in the Metal Cap",
    "Beat a Boo",
    "Get a star in Hazy Maze Cave",
    "Get two stars in one visit to a level",
    "Get a star in Lethal Lava Land",
    "Get a star in Shifting Sand Land",
    "Win a race against another player to a star",
    "Get the Vanish Cap",
    "Get a star in Dire, Dire Docks",

    "Get the Metal Cap",
    "Climb into a cannon",
    "Get caught in a tornado",
    "Get pulled into a whirlpool",
    "Get blown off your feet",
    "Catch fire",
    "Swim through a water ring",
    "Get picked up and thrown",
    "Collect a blue coin",
    "Collect 50 coins in one level",
    "Visit four different courses",

    "Collect 70 coins in one level",
    "Get three stars since this card was dealt",
    "Visit six different courses",
    "Read five signs in five different places",
    "Swim for fifteen seconds without surfacing",
}
bingo.HARD = {

    "Hang from a ceiling",
    "Die in five different ways",
    "Get ten stars since this card was dealt",
    "Survive a sky-high fall",
    "Swim for a full minute without surfacing",
    "Beat Bowser in the Dark World",
    "Get a star in Tick Tock Clock",
    "Get a star in Rainbow Ride",
    "Get all 8 red coins in one visit to a level",
    "Get a star in Wet-Dry World",
    "Get a star in Snowman's Land",
    "Get a star in Tall, Tall Mountain",
    "Die in three different ways",
    "Get a star in Tiny-Huge Island",
    "Beat Bowser in the Fire Sea",
    "Get 100 coins in a course for the first time",
    "Get a star nobody else in the lobby got tonight",

    "Ride the owl",
    "Wear the Wing Cap, Metal Cap and Vanish Cap",
    "Get five stars since this card was dealt",
    "Walk the sea bed in the Metal Cap",
    "Swim for thirty seconds without surfacing",
    "Survive a big fall",
    "Visit eight different courses",

    "Die in seven different ways",
    "Collect 24 red coins anywhere",
    "Get fifteen stars since this card was dealt",
    "Get four stars in one visit to a level",
    "Survive a huge fall",
    "Swim for ninety seconds without surfacing",
    "Visit twelve different courses",
}

local CLASSES = { bingo.EASY, bingo.MEDIUM, bingo.HARD }

bingo.BY_HAND = {
    ["Bounce off three Goombas without landing"] =
        "the engine reports a stomp exactly as it reports being stomped on",
    ["Come up out of the water in the Metal Cap"] =
        "the cap is a flag, and where the water ends is a judgement about the level",
    ["Beat a Boo"] =
        "the Boo is gone before anything can be asked which enemy it was",
    ["Win a race against another player to a star"] =
        "two machines, and neither one of them saw the other one's star",
    ["Beat Bowser in the Dark World"] =
        "the key is a star to the engine; which Bowser it came off is not",
    ["Beat Bowser in the Fire Sea"] =
        "the same as the floor above: a key is a star, and it says whose nowhere",
    ["Get 100 coins in a course for the first time"] =
        "the save file knows, and reading somebody's save to tick a square is not on",
    ["Get a star nobody else in the lobby got tonight"] =
        "a claim about the lobby, from a machine that only knows about itself",
}

bingo.MODES = {
    { key = "mixed",   name = "Mixed",
      blurb = "the usual card" },
    { key = "gentle",  name = "Gentle",
      blurb = "nothing on it takes a whole session" },
    { key = "hard",    name = "Hard",
      blurb = "every square is a job" },
    { key = "watched", name = "Watched",
      blurb = "only squares the mod ticks for you" },
}

bingo.MODE_KEY = "ofBingoMode"
function bingo.mode()
    local value = gGlobalSyncTable[bingo.MODE_KEY]
    if type(value) ~= "string" then return "mixed" end
    for _, entry in ipairs(bingo.MODES) do
        if entry.key == value then return value end
    end

    return "mixed"
end

function bingo.mode_entry(key)
    for _, entry in ipairs(bingo.MODES) do
        if entry.key == (key or bingo.mode()) then return entry end
    end
    return bingo.MODES[1]
end

local function classes_for(mode)
    if mode == "gentle" then
        return { bingo.EASY, bingo.EASY, bingo.MEDIUM }
    end
    if mode == "hard" then
        return { bingo.MEDIUM, bingo.HARD, bingo.HARD }
    end
    if mode == "watched" then

        local out = { {}, {}, {} }
        for index, pool in ipairs(CLASSES) do
            local into = out[index]
            local n = 0
            for _, text in ipairs(pool) do
                if bingo.watched(text) then
                    n = n + 1
                    into[n] = text
                end
            end
        end

        local total = #out[1] + #out[2] + #out[3]
        if total < CELLS then return CLASSES end
        return out
    end
    return CLASSES
end

bingo.classes_for = classes_for

function bingo.class_of(value)
    if value < 8 then return 1 end
    if value < 17 then return 2 end
    return 3
end

local dealtSeed, dealtMode, dealtCard = nil, nil, nil

bingo.CAP_GOALS = {
    ["Get the Wing Cap"] = true,
    ["Get the Metal Cap"] = true,
    ["Get the Vanish Cap"] = true,
    ["Wear the Wing Cap, Metal Cap and Vanish Cap"] = true,
    ["Come up out of the water in the Metal Cap"] = true,
    ["Walk the sea bed in the Metal Cap"] = true,
}

function bingo.goals(seed, mode, withoutCaps)
    local wanted = mode or bingo.mode()

    local dealtAs = wanted .. (withoutCaps == true and " without caps" or "")
    if dealtCard ~= nil and dealtSeed == seed and dealtMode == dealtAs then
        return dealtCard
    end

    local square = bingo.square(seed)
    local next_int = stream(seed + 7919)
    local used = {}
    local out = {}
    local classes = classes_for(wanted)

    for cell = 1, CELLS do
        local class = bingo.class_of(square[cell])
        local picked = nil

        for _, order in ipairs({ class, 1, 2, 3 }) do
            local pool = classes[order]
            local start = next_int(#pool)
            for step = 0, #pool - 1 do
                local text = pool[((start + step) % #pool) + 1]
                if not used[text]
                    and not (withoutCaps == true and bingo.CAP_GOALS[text]) then
                    picked = text
                    break
                end
            end
            if picked ~= nil then break end
        end

        if picked == nil then
            for _, pool in ipairs(classes) do
                if pool[1] ~= nil then picked = pool[1] break end
            end
        end
        if picked == nil then picked = bingo.EASY[1] end
        used[picked] = true
        out[cell] = picked
    end

    dealtSeed, dealtMode, dealtCard = seed, dealtAs, out
    return out
end

local function forget_card()
    dealtSeed, dealtMode, dealtCard = nil, nil, nil
end

local CAUSES = {
    fall      = { ACT_DEATH_ON_STOMACH, ACT_DEATH_ON_BACK },
    drowned   = { ACT_DROWNING, ACT_WATER_DEATH },
    crushed   = { ACT_SUFFOCATION },
    quicksand = { ACT_QUICKSAND_DEATH },
    shocked   = { ACT_ELECTROCUTION },
    eaten     = { ACT_EATEN_BY_BUBBA },
    enemy     = { ACT_STANDING_DEATH },
}

local CAUSE_OF = {}
for name, actions in pairs(CAUSES) do
    for _, action in ipairs(actions) do
        if action ~= nil then CAUSE_OF[action] = name end
    end
end

function bingo.death_cause(action)
    if type(action) ~= "number" then return nil end
    return CAUSE_OF[action] or "the void"
end

local seenCauses = {}

local starsIn = {}
local capsSeen = {}
local mostCoins = 0

local function fresh_tally()
    return {

        actions = {},

        touched = {},

        signs = {},

        courses = {},
        red = 0, redHere = 0, blue = 0,
        stars = 0, starsHere = 0, coinsHere = 0,
        lives = nil, gotLife = false,
        level = nil,
        airTop = nil, fall = 0,
        swim = 0, swimBest = 0,
    }
end

local tally = fresh_tally()

function bingo.stands_down()
    return OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() == true
end

local function tallying()
    return bingo.running() and not bingo.stands_down()
end

function bingo.cause_count()
    local count = 0
    for _ in pairs(seenCauses) do count = count + 1 end
    return count
end

function bingo.tally()
    return tally
end

local function count_of(set)
    local n = 0
    for _ in pairs(set or {}) do n = n + 1 end
    return n
end

bingo.count_of = count_of

function bingo.forget_causes()
    seenCauses = {}
    starsIn = {}
    capsSeen = {}
    mostCoins = 0
    tally = fresh_tally()
    forget_card()
end

hook_event(HOOK_ON_DEATH, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if not tallying() then return end
    local cause = bingo.death_cause(m.action)
    if cause ~= nil then seenCauses[cause] = true end
end)

local CAPS = {
    ["Get the Wing Cap"]   = MARIO_WING_CAP,
    ["Get the Vanish Cap"] = MARIO_VANISH_CAP,

    ["Get the Metal Cap"]  = MARIO_METAL_CAP,
}

local MOVES = {
    ["Do a triple jump"]           = { ACT_TRIPLE_JUMP },
    ["Do a backflip"]              = { ACT_BACKFLIP },
    ["Do a long jump"]             = { ACT_LONG_JUMP },
    ["Do a side flip"]             = { ACT_SIDE_FLIP },
    ["Dive head first"]            = { ACT_DIVE },

    ["Do a ground pound"]          = { ACT_GROUND_POUND },
    ["Crawl somewhere"]            = { ACT_CRAWLING },

    ["Throw a punch"]              = { ACT_PUNCHING, ACT_MOVE_PUNCHING,
                                       ACT_WATER_PUNCH },

    ["Pick something up"]          = { ACT_PICKING_UP },
    ["Grab on to a pole"]          = { ACT_HOLDING_POLE },
    ["Ride a Koopa Shell"]         = { ACT_RIDING_SHELL_GROUND, ACT_RIDING_SHELL_FALL },
    ["Walk the sea bed in the Metal Cap"] = { ACT_METAL_WATER_WALKING },

    ["Get picked up and thrown"]   = { ACT_THROWN_FORWARD, ACT_THROWN_BACKWARD },

    ["Wall-kick off something"]    = { ACT_WALL_KICK_AIR },
    ["Slide down on your stomach"] = { ACT_STOMACH_SLIDE },
    ["Do a slide kick"]            = { ACT_SLIDE_KICK },

    ["Bounce off a Spindrift or a Fly Guy"] = { ACT_TWIRLING },
    ["Get to the top of a pole"]   = { ACT_TOP_OF_POLE },
    ["Hang from a ceiling"]        = { ACT_HANGING },

    ["Get blown straight up by a wind"] = { ACT_VERTICAL_WIND },
}

local NEEDS_OK = {

    ["Break open a box"]            = INTERACT_BREAKABLE,
    ["Climb into a cannon"]         = INTERACT_CANNON_BASE,
    ["Get caught in a tornado"]     = INTERACT_TORNADO,
    ["Get pulled into a whirlpool"] = INTERACT_WHIRLPOOL,
    ["Get blown off your feet"]     = INTERACT_STRONG_WIND,
    ["Catch fire"]                  = INTERACT_FLAME,
    ["Ride the owl"]                = INTERACT_HOOT,
}

local TOUCHES = {
    ["Swim through a water ring"]   = INTERACT_WATER_RING,
}

function bingo.most_coins()
    return mostCoins
end

function bingo.stars_in(courseNum)
    return starsIn[courseNum] == true
end

local function sign_place(o)
    local np = gNetworkPlayers[0]
    local level = np ~= nil and np.currLevelNum or 0
    if o == nil or type(o.oPosX) ~= "number" or type(o.oPosZ) ~= "number" then
        return string.format("%.0f:n%.0f", level, count_of(tally.signs) + 1)
    end
    return string.format("%.0f:%.0f:%.0f", level,
        math.floor(o.oPosX / 50), math.floor(o.oPosZ / 50))
end

local NPC_SUBTYPE = INT_SUBTYPE_NPC

local function is_person(o)
    if o == nil or NPC_SUBTYPE == nil then return false end
    return OF.util.has_flag(o.oInteractionSubtype, NPC_SUBTYPE)
end

local function opens_a_cannon(o)
    if o == nil then return false end
    return OF.util.optional("obj_has_behavior_id", 0, o,
        id_bhvBobombBuddyOpensCannon) ~= 0
end

hook_event(HOOK_ON_INTERACT, function(m, o, interactType, ok)
    if m == nil or m.playerIndex ~= 0 then return end
    if not tallying() then return end

    if interactType == INTERACT_STAR_OR_KEY and ok ~= false then
        tally.stars = tally.stars + 1
        tally.starsHere = tally.starsHere + 1

        if tally.coinsHere == 0 then tally.touched["cleanstar"] = true end

        local np = gNetworkPlayers[0]
        if np == nil then return end
        local course = OF.util.course_of_level(np.currLevelNum)
        if course ~= nil and course > 0 then starsIn[course] = true end
        return
    end

    if interactType == INTERACT_COIN then

        tally.coinsHere = tally.coinsHere + 1
        local worth = o ~= nil and o.oDamageOrCoinValue or 1
        if type(worth) ~= "number" then worth = 1 end
        if worth == 2 then
            tally.red = tally.red + 1
            tally.redHere = tally.redHere + 1
        elseif worth >= 5 then
            tally.blue = tally.blue + 1
        end
        return
    end

    if interactType == INTERACT_TEXT and ok ~= false then

        if opens_a_cannon(o) then
            tally.touched["cannon"] = true
            return
        end
        if is_person(o) then return end
        tally.signs[sign_place(o)] = true
        return
    end

    for _, want in pairs(NEEDS_OK) do
        if interactType == want and ok ~= false then tally.touched[want] = true end
    end
    for _, want in pairs(TOUCHES) do
        if interactType == want then tally.touched[want] = true end
    end
end)

hook_event(HOOK_ON_SET_MARIO_ACTION, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if not tallying() then return end
    if type(m.action) ~= "number" then return end
    tally.actions[m.action] = true
end)

hook_event(HOOK_UPDATE, function()
    if not tallying() then return end
    local m = gMarioStates[0]
    if m == nil then return end

    if type(m.numCoins) == "number" and m.numCoins > mostCoins then
        mostCoins = m.numCoins
    end

    for text, flag in pairs(CAPS) do
        if flag ~= nil and OF.util.has_flag(m.flags, flag)
            and not OF.util.intangible_borrowed(flag) then
            capsSeen[text] = true
        end
    end

    local np = gNetworkPlayers[0]
    local level = np ~= nil and np.currLevelNum or nil
    if level ~= nil and level ~= tally.level then
        tally.level = level
        tally.starsHere = 0
        tally.coinsHere = 0
        tally.redHere = 0
        local course = OF.util.course_of_level(level)
        if course ~= nil and course > 0 then tally.courses[course] = true end
    end

    if type(m.numLives) == "number" then
        if tally.lives == nil or m.numLives < tally.lives then
            tally.lives = m.numLives
        elseif m.numLives > tally.lives then
            tally.lives = m.numLives
            tally.gotLife = true
        end
    end

    local airborne = OF.util.has_flag(m.action, ACT_FLAG_AIR)
    local y = m.pos ~= nil and m.pos.y or nil
    if type(y) == "number" then
        if airborne then
            if tally.airTop == nil or y > tally.airTop then tally.airTop = y end
        elseif tally.airTop ~= nil then
            local drop = tally.airTop - y
            if drop > tally.fall then tally.fall = drop end
            tally.airTop = nil
        end
    end

    if OF.util.has_flag(m.action, ACT_FLAG_SWIMMING) then
        tally.swim = tally.swim + 1
        if tally.swim > tally.swimBest then tally.swimBest = tally.swim end
    else
        tally.swim = 0
    end
end)

bingo.AUTO = {
    ["Die in three different ways"] = function() return bingo.cause_count() >= 3 end,
    ["Collect 30 coins in one level"] = function() return mostCoins >= 30 end,
    ["Collect 50 coins in one level"] = function() return mostCoins >= 50 end,
    ["Get 100 coins in one level"] = function() return mostCoins >= 100 end,

    ["Collect a red coin"] = function() return tally.red >= 1 end,
    ["Collect a blue coin"] = function() return tally.blue >= 1 end,
    ["Collect 8 red coins anywhere"] = function() return tally.red >= 8 end,

    ["Get all 8 red coins in one visit to a level"] = function() return tally.redHere >= 8 end,
    ["Get a 1-Up"] = function() return tally.gotLife end,
    ["Get five stars since this card was dealt"] = function() return tally.stars >= 5 end,
    ["Get two stars in one visit to a level"] = function() return tally.starsHere >= 2 end,
    ["Get a star in a level before touching a coin"] =
        function() return tally.touched["cleanstar"] == true end,

    ["Get a Bob-omb Buddy to open a cannon"] =
        function() return tally.touched["cannon"] == true end,
    ["Read three signs in three different places"] =
        function() return count_of(tally.signs) >= 3 end,
    ["Visit four different courses"] = function() return count_of(tally.courses) >= 4 end,
    ["Visit eight different courses"] = function() return count_of(tally.courses) >= 8 end,

    ["Wear the Wing Cap, Metal Cap and Vanish Cap"] = function() return count_of(capsSeen) >= 3 end,

    ["Survive a big fall"] = function() return tally.fall >= 4000 end,

    ["Swim for thirty seconds without surfacing"] =
        function() return tally.swimBest >= 900 end,

    ["Collect 3 red coins anywhere"] = function() return tally.red >= 3 end,
    ["Collect 16 red coins anywhere"] = function() return tally.red >= 16 end,
    ["Visit two different courses"] = function() return count_of(tally.courses) >= 2 end,
    ["Read a sign"] = function() return count_of(tally.signs) >= 1 end,
    ["Get three stars in one visit to a level"] =
        function() return tally.starsHere >= 3 end,
    ["Get ten stars since this card was dealt"] = function() return tally.stars >= 10 end,
    ["Die in five different ways"] = function() return bingo.cause_count() >= 5 end,

    ["Survive a sky-high fall"] = function() return tally.fall >= 8000 end,

    ["Swim for a full minute without surfacing"] =
        function() return tally.swimBest >= 1800 end,

    ["Collect 5 red coins anywhere"] = function() return tally.red >= 5 end,
    ["Collect 24 red coins anywhere"] = function() return tally.red >= 24 end,
    ["Visit three different courses"] = function() return count_of(tally.courses) >= 3 end,
    ["Visit six different courses"] = function() return count_of(tally.courses) >= 6 end,
    ["Visit twelve different courses"] = function() return count_of(tally.courses) >= 12 end,
    ["Read two signs in two different places"] =
        function() return count_of(tally.signs) >= 2 end,
    ["Read five signs in five different places"] =
        function() return count_of(tally.signs) >= 5 end,

    ["Get two stars since this card was dealt"] = function() return tally.stars >= 2 end,
    ["Get three stars since this card was dealt"] = function() return tally.stars >= 3 end,
    ["Get fifteen stars since this card was dealt"] = function() return tally.stars >= 15 end,
    ["Get four stars in one visit to a level"] =
        function() return tally.starsHere >= 4 end,
    ["Collect 70 coins in one level"] = function() return mostCoins >= 70 end,

    ["Survive a long fall"] = function() return tally.fall >= 2000 end,
    ["Survive a huge fall"] = function() return tally.fall >= 6000 end,

    ["Swim for fifteen seconds without surfacing"] =
        function() return tally.swimBest >= 450 end,
    ["Swim for ninety seconds without surfacing"] =
        function() return tally.swimBest >= 2700 end,

    ["Die in seven different ways"] = function() return bingo.cause_count() >= 7 end,
}

for text, flag in pairs(CAPS) do
    bingo.AUTO[text] = function() return capsSeen[text] == true end
end

for text, actions in pairs(MOVES) do
    local wanted = actions
    bingo.AUTO[text] = function()
        for _, action in ipairs(wanted) do
            if action ~= nil and tally.actions[action] == true then return true end
        end
        return false
    end
end

for text, interactType in pairs(NEEDS_OK) do
    local want = interactType
    bingo.AUTO[text] = function() return tally.touched[want] == true end
end
for text, interactType in pairs(TOUCHES) do
    local want = interactType
    bingo.AUTO[text] = function() return tally.touched[want] == true end
end

local madeWatcher = {}

function bingo.watcher_for(text)
    if type(text) ~= "string" then return nil end
    local direct = bingo.AUTO[text]
    if direct ~= nil then return direct end

    local kept = madeWatcher[text]
    if kept ~= nil then return kept end

    local course = string.match(text, "^Get a star in (.+)$")
    if course == nil then return nil end
    for _, entry in ipairs(OF.COURSES or {}) do
        if entry.name == course then
            local num = entry.num
            local made = function() return bingo.stars_in(num) end
            madeWatcher[text] = made
            return made
        end
    end
    return nil
end

function bingo.watched(text)
    return bingo.watcher_for(text) ~= nil
end

local function bit_of(cell)
    return 2 ^ (cell - 1)
end

function bingo.marks(localIndex)
    local row = gPlayerSyncTable[localIndex or 0]
    local value = row ~= nil and row.ofBingoMarks or 0
    if type(value) ~= "number" or value < 0 then return 0 end
    return math.floor(value)
end

function bingo.marked(cell, localIndex)
    if type(cell) ~= "number" or cell < 1 or cell > CELLS then return false end
    return math.floor(bingo.marks(localIndex) / bit_of(cell)) % 2 == 1
end

function bingo.mark(cell)
    if not bingo.running() then return false, "No card - ask the host for one." end
    if type(cell) ~= "number" or cell < 1 or cell > CELLS then return false end
    local marks = bingo.marks(0)
    if bingo.marked(cell, 0) then
        local watcher = bingo.watcher_for(bingo.goals(bingo.seed())[cell])
        if watcher ~= nil and watcher() then
            return false, "The mod watched you do that one - it stays ticked."
        end
        marks = marks - bit_of(cell)
    else
        marks = marks + bit_of(cell)
    end
    OF.util.publish_row(0, "ofBingoMarks", marks)
    OF.sounds.play(OF.sounds.PICK)
    return true
end

local LINES = (function()
    local lines = {}
    for y = 0, SIZE - 1 do
        local row, col = {}, {}
        for x = 0, SIZE - 1 do
            row[x + 1] = y * SIZE + x + 1
            col[x + 1] = x * SIZE + y + 1
        end
        lines[y * 2 + 1] = row
        lines[y * 2 + 2] = col
    end
    local down, up = {}, {}
    for i = 0, SIZE - 1 do
        down[i + 1] = i * SIZE + i + 1
        up[i + 1] = i * SIZE + (SIZE - 1 - i) + 1
    end
    lines[SIZE * 2 + 1] = down
    lines[SIZE * 2 + 2] = up
    return lines
end)()

bingo.LINES = LINES

function bingo.line_count()
    return #LINES
end

function bingo.line_of(localIndex)
    for _, line in ipairs(LINES) do
        local all = true
        for _, cell in ipairs(line) do
            if not bingo.marked(cell, localIndex) then
                all = false
                break
            end
        end
        if all then return line end
    end
    return nil
end

function bingo.seed()
    local value = gGlobalSyncTable.ofBingoSeed
    if type(value) ~= "number" or value <= 0 then return nil end
    return value
end

function bingo.running()
    return bingo.seed() ~= nil
end

local function clear_my_marks()
    if bingo.marks(0) ~= 0 then
        OF.util.publish_row(0, "ofBingoMarks", nil)
    end

    bingo.forget_causes()

    bingo.forget_flashes()
end

bingo.clear_my_marks = clear_my_marks

hook_on_sync_table_change(gGlobalSyncTable, "ofBingoSeed", 0, function()
    if OF.util.asks(OF.guard, "repair") and OF.guard.repair("ofBingoSeed") then
        return
    end
    clear_my_marks()
end)

hook_on_sync_table_change(gGlobalSyncTable, bingo.MODE_KEY, "mixed", function()
    if OF.util.asks(OF.guard, "repair") and OF.guard.repair(bingo.MODE_KEY) then
        return
    end
    clear_my_marks()
end)

bingo.DECK_ACTION = "bingodeck"
bingo.DEAL_ACTION = "bingodeal"
bingo.STOP_ACTION = "bingostop"
function bingo.can_ask_host()
    if OF.util.is_host() then return true end
    if not OF.util.asks(OF.net, "host_does") then return false end
    local seat = OF.util.local_from_global(0)
    return seat ~= nil and seat > 0
end

function bingo.set_mode(key, askerLocal)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    local entry = nil
    for _, candidate in ipairs(bingo.MODES) do
        if candidate.key == key then entry = candidate end
    end
    if entry == nil then return false, "No such deck." end

    if not OF.util.is_host() then
        if OF.util.asks(OF.net, "host_does") then
            return OF.net.host_does(bingo.DECK_ACTION, entry.key)
        end
        return false, "No host to ask yet - try again in a second."
    end

    OF.util.publish(bingo.MODE_KEY, entry.key)

    OF.notify.send_all("The bingo deck is now @", "info", 4, entry.name)

    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit") then
        OF.notify.credit(askerLocal,
            OF.lang.fill("bingo deck: @", OF.lang.t(entry.name)))
    end
    OF.actionlog.by_hand(OF.util.presser(askerLocal),
        OF.lang.fill("set the bingo deck: @", OF.lang.t(entry.name)))
    return true
end

function bingo.cycle_mode(askerLocal)
    local current = bingo.mode()
    local at = 1
    for i, entry in ipairs(bingo.MODES) do
        if entry.key == current then at = i end
    end
    at = at + 1
    if at > #bingo.MODES then at = 1 end
    return bingo.set_mode(bingo.MODES[at].key, askerLocal)
end

function bingo.start(askerLocal)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end

    if not OF.util.is_host() then
        if OF.util.asks(OF.net, "host_does") then
            return OF.net.host_does(bingo.DEAL_ACTION)
        end
        return false, "No host to ask yet - try again in a second."
    end

    local now = OF.util.optional("get_global_timer", 1) or 1
    OF.util.publish("ofBingoSeed", math.floor(now) % 2147483647 + 1)

    OF.notify.send_all("A new bingo card is dealt", "good", 5)

    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
        OF.notify.credit_named(askerLocal, OF.lang.t("dealt a bingo card"))
    end
    OF.actionlog.by_hand(OF.util.presser(askerLocal),
        OF.lang.t("dealt a new bingo card"))
    return true
end

function bingo.stop()
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    if not OF.util.is_host() then
        if OF.util.asks(OF.net, "host_does") then
            return OF.net.host_does(bingo.STOP_ACTION)
        end
        return false, "No host to ask yet - try again in a second."
    end
    OF.util.publish("ofBingoSeed", nil)
    return true
end

hook_event(HOOK_ON_MODS_LOADED, function()
    if OF.net == nil or OF.net.register_action == nil then return end

    OF.net.register_action(bingo.DECK_ACTION, "speedrun", function(asker, key)
        if not OF.util.is_host() then return false, "Only the host." end
        return bingo.set_mode(tostring(key or ""), asker)
    end)

    OF.net.register_action(bingo.DEAL_ACTION, "speedrun", function(asker)
        if not OF.util.is_host() then return false, "Only the host." end
        return bingo.start(asker)
    end)

    OF.net.register_action(bingo.STOP_ACTION, "speedrun", function()
        if not OF.util.is_host() then return false, "Only the host." end
        return bingo.stop()
    end)
end)

function bingo.build_page(panel)
    local rows = {}

    local function deck_row()
        local entry = bingo.mode_entry()
        local row = panel.with_help(panel.gated_row("speedrun",
            OF.lang.t("Deck"), 255, 255, 255,

            function() OF.util.report(bingo.cycle_mode(0)) end),
            OF.lang.t(entry.blurb))
        row.right = OF.lang.t(entry.name)
        return panel.with_key(row, "bingo:deck")
    end

    local function waiting_row()
        return panel.label_row(
            OF.lang.t("Waiting for the host - these are the host's to run."))
    end

    if not bingo.running() then
        table.insert(rows, panel.label_row(
            OF.lang.t("No card. One board for the lobby, twenty-five things to do.")))
        if not bingo.can_ask_host() then table.insert(rows, waiting_row()) end
        table.insert(rows, deck_row())
        table.insert(rows, panel.with_help(panel.gated_row("speedrun",
            OF.lang.t("Deal a card"), 255, 255, 255,

            function() OF.util.report(bingo.start(0)) end),
            "deals the lobby twenty-five goals out of the deck chosen above"))
        table.insert(rows, panel.back_row("fun"))
        return rows
    end

    local goals = bingo.goals(bingo.seed())
    local line = bingo.line_of(0)
    if line ~= nil then
        table.insert(rows, panel.label_row(OF.lang.t("You have a line.")))
    end

    table.insert(rows, panel.label_row(OF.lang.t(
        "(watched) ticks itself. (yours) is yours to tick.")))

    for y = 0, SIZE - 1 do
        table.insert(rows, panel.header_row(
            OF.lang.fill("Row @", tostring(y + 1))))
        for x = 0, SIZE - 1 do
            local cell = y * SIZE + x + 1
            local done = bingo.marked(cell, 0)
            local r, g, b = 255, 255, 255
            if done then
                local gold = OF.util.gold()
                r, g, b = gold.r, gold.g, gold.b
            end

            local text = OF.lang.fill("@. @", tostring(cell),
                OF.lang.t(goals[cell]))

            if bingo.watched(goals[cell]) then
                text = text .. "  " .. OF.lang.t("(watched)")
            else
                text = text .. "  " .. OF.lang.t("(yours)")
            end

            local built = panel.row(
                panel.tick(done, text),
                r, g, b, function() OF.util.report(bingo.mark(cell)) end)
            local why = bingo.BY_HAND[goals[cell]]
            if why ~= nil then built = panel.with_help(built, why) end
            table.insert(rows, panel.with_key(built, "bingo:" .. cell))
        end
    end

    table.insert(rows, panel.header_row(OF.lang.t("The card itself")))

    table.insert(rows, panel.with_key(panel.with_help(panel.row(
        panel.tick(not bingo.hud_hidden(), OF.lang.t("Card on screen")),
        255, 255, 255,
        function() OF.util.report(bingo.set_hud_hidden(not bingo.hud_hidden())) end),
        "the small card in the corner while you play - yours alone, nobody else's"),
        "bingo:hud"))

    table.insert(rows, panel.with_key(panel.with_help(panel.row(
        panel.tick(bingo.board_open(),
            OF.lang.t("The whole card, with the goals on it")), 255, 255, 255,
        function() OF.util.report(bingo.toggle_board()) end),
        OF.lang.t("close the menu to read it - every square, and who has taken it")),
        "bingo:board"))

    if not bingo.can_ask_host() then table.insert(rows, waiting_row()) end
    table.insert(rows, deck_row())
    table.insert(rows, panel.with_help(panel.gated_row("speedrun",
        OF.lang.t("Deal a new card"), 255, 255, 255,

        function() OF.util.report(bingo.start(0)) end),
        "throws the card away and deals the lobby twenty-five fresh goals"))
    table.insert(rows, panel.with_help(panel.gated_row("speedrun",
        OF.lang.t("Put the card away"), 255, 140, 90,
        function() OF.util.report(bingo.stop()) end),
        "ends it for the whole lobby - nothing about the card is kept"))
    table.insert(rows, panel.back_row("fun"))
    return rows
end

local CELL = 26
local CELL_GAP = 3

local HIDE_KEY = "of_bingo_hud"
local hidden = nil

function bingo.hud_hidden()
    if hidden == nil then
        hidden = OF.util.stored(HIDE_KEY, "") == "1"
    end
    return hidden
end

function bingo.set_hud_hidden(value)
    hidden = value == true
    OF.util.store(HIDE_KEY, hidden and "1" or "0")
    return true
end

local boardOpen = false

function bingo.board_open()
    return boardOpen
end

function bingo.set_board_open(value)
    boardOpen = value == true and bingo.running()
    return true
end

function bingo.toggle_board()
    if not bingo.running() then
        return false, "No card - ask the host for one."
    end
    boardOpen = not boardOpen
    OF.sounds.play(OF.sounds.PICK)
    return true
end

function bingo.holders(cell)
    local list = {}
    if not bingo.running() then return list end
    for _, entry in ipairs(OF.util.connected_players()) do
        if bingo.marked(cell, entry.localIndex) then
            table.insert(list, entry)
        end
    end
    return list
end

function bingo.score_of(localIndex)
    local n = 0
    for cell = 1, CELLS do
        if bingo.marked(cell, localIndex) then n = n + 1 end
    end
    return n
end

local function wrap(text, scale, room, most)
    local lines = {}
    if type(text) ~= "string" or text == "" then return lines end
    local count = 0
    local line = nil
    for word in string.gmatch(text, "%S+") do
        local candidate = line == nil and word or (line .. " " .. word)
        if line ~= nil and OF.util.width(candidate, scale) > room then
            count = count + 1
            lines[count] = line
            if count >= most then

                lines[count] = OF.util.fit(line .. " " .. word, scale, room)
                return lines
            end
            line = word
        else
            line = candidate
        end
    end
    if line ~= nil and count < most then
        count = count + 1
        lines[count] = line
    end
    return lines
end

local FLASH_FRAMES = 45
local flashing = {}

function bingo.flash_left(cell)
    return flashing[cell] or 0
end

local function flash(cell)
    flashing[cell] = FLASH_FRAMES
end

local function fade_flashes()
    for cell, left in pairs(flashing) do
        if left <= 1 then
            flashing[cell] = nil
        else
            flashing[cell] = left - 1
        end
    end
end

function bingo.forget_flashes()
    flashing = {}
end

local BOARD_SPAN_W = 0.80
local BOARD_SPAN_H = 0.72
local BOARD_GAP = 0.055
local BOARD_TEXT = 0.0043
local BOARD_LINES = 4

bingo.CARD_LINES = BOARD_LINES

local function board_cell()
    local span = math.min(djui_hud_get_screen_width() * BOARD_SPAN_W,
        djui_hud_get_screen_height() * BOARD_SPAN_H)
    local cell = span / (SIZE + (SIZE - 1) * BOARD_GAP)
    return span, cell, cell * BOARD_GAP, cell * 0.09, cell * BOARD_TEXT
end

function bingo.card_lines(text)
    local _, cell, _, pad, scale = board_cell()
    return OF.util.in_font(FONT_NORMAL, function()
        return wrap(OF.lang.t(text), scale, cell - pad * 2, BOARD_LINES)
    end)
end

local function render_board()
    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()

    local span, cell, gap, pad, scale = board_cell()
    local lineHeight = 20 * scale

    local titleGap = cell * 0.34
    local legendGap = cell * 0.30

    local roster = OF.util.connected_players()
    local legendScale = scale * 0.95
    local legendLine = 22 * legendScale
    local legendHeight = legendGap + legendLine * #roster

    local left = (screenWidth - span) * 0.5
    local top = (screenHeight - span - titleGap - legendHeight) * 0.5

    OF.util.plate(left - pad * 2, top - pad * 2,
        span + pad * 4, span + titleGap + legendHeight + pad * 4,
        { accent = OF.util.gold() })

    local gold = OF.util.gold()
    OF.util.text(OF.lang.t("BINGO"), left, top, scale * 1.5,
        gold.r, gold.g, gold.b, 255)

    local deck = bingo.mode_entry()
    local heading = OF.lang.fill("@   -   @ of 25", OF.lang.t(deck.name),
        string.format("%.0f", bingo.score_of(0)))
    OF.util.text(heading, left + span - OF.util.width(heading, scale),
        top + lineHeight * 0.35, scale, 210, 210, 210, 220)
    top = top + titleGap

    local line = bingo.line_of(0)
    local inLine = {}
    if line ~= nil then
        for _, at in ipairs(line) do inLine[at] = true end
    end

    local goals = bingo.goals(bingo.seed())

    for y = 0, SIZE - 1 do
        for x = 0, SIZE - 1 do
            local at = y * SIZE + x + 1
            local cx = left + x * (cell + gap)
            local cy = top + y * (cell + gap)
            local holders = bingo.holders(at)
            local mine = bingo.marked(at, 0)

            local r, g, b, a = 255, 255, 255, 26
            if mine then
                r, g, b, a = gold.r, gold.g, gold.b, 200
            elseif #holders > 0 then
                r, g, b, a = 150, 160, 185, 90
            end
            if inLine[at] then r, g, b, a = 255, 255, 255, 235 end
            OF.util.rect(cx, cy, cell, cell, r, g, b, a)

            local fading = bingo.flash_left(at)
            if fading > 0 then
                OF.util.rect(cx - pad * 0.4, cy - pad * 0.4,
                    cell + pad * 0.8, cell + pad * 0.8, 255, 255, 255,
                    math.floor(255 * fading / FLASH_FRAMES))
            end

            local dark = a > 150
            local label = string.format("%.0f", at)
            local numberScale = scale * 0.85
            if dark then
                OF.util.text(label, cx + pad, cy + pad * 0.6, numberScale,
                    20, 18, 10, 255)
            else
                OF.util.text(label, cx + pad, cy + pad * 0.6, numberScale,
                    200, 200, 200, 190)
            end

            local room = cell - pad * 2
            local textTop = cy + pad * 0.6 + lineHeight * 1.05
            local wrapped = wrap(OF.lang.t(goals[at]), scale, room, BOARD_LINES)
            for index = 1, #wrapped do
                if dark then
                    OF.util.text(wrapped[index], cx + pad,
                        textTop + (index - 1) * lineHeight, scale, 26, 22, 12, 255)
                else
                    OF.util.text(wrapped[index], cx + pad,
                        textTop + (index - 1) * lineHeight, scale, 240, 240, 240, 225)
                end
            end

            if #holders > 0 then
                local pipGap = pad * 0.25
                local pipWidth = (cell - pad * 2 - pipGap * (#holders - 1)) / #holders
                for index, entry in ipairs(holders) do

                    local pr, pg, pb = OF.util.player_color(entry.localIndex)
                    OF.util.rect(cx + pad + (index - 1) * (pipWidth + pipGap),
                        cy + cell - pad * 0.9, pipWidth, pad * 0.5,
                        pr, pg, pb, 235)
                end
            end

            if #holders == 0 and bingo.watched(goals[at]) then
                OF.util.rect(cx + pad, cy + cell - pad * 0.9,
                    cell - pad * 2, pad * 0.3, gold.r, gold.g, gold.b, 150)
            end
        end
    end

    local legendTop = top + span + legendGap
    for index, entry in ipairs(roster) do
        local ly = legendTop + (index - 1) * legendLine
        local pr, pg, pb = OF.util.player_color(entry.localIndex)
        OF.util.rect(left, ly + legendLine * 0.12,
            legendLine * 0.5, legendLine * 0.5, pr, pg, pb, 235)
        local nameLeft = left + legendLine * 0.85
        OF.util.text_raw(OF.util.fit_name(gNetworkPlayers[entry.localIndex].name,
            legendScale, span * 0.5), nameLeft, ly, legendScale,
            255, 255, 255, 235)
        local score = OF.lang.fill("@ of 25",
            string.format("%.0f", bingo.score_of(entry.localIndex)))
        OF.util.text(score, left + span - OF.util.width(score, legendScale), ly,
            legendScale, 200, 200, 200, 210)
    end
end

local function render()
    if not bingo.running() or bingo.stands_down() then

        boardOpen = false
        return
    end

    if OF.util.menu_has_screen() then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    if boardOpen then
        render_board()
        return
    end

    if bingo.hud_hidden() then return end

    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()

    local span = SIZE * CELL + (SIZE - 1) * CELL_GAP
    local left = screenWidth - span - 18
    local titleGap = 20

    local footGap = 14
    local top = (screenHeight - span - titleGap - footGap) * 0.5

    OF.util.plate(left - 8, top - 8, span + 16,
        span + titleGap + footGap + 16)

    local gold = OF.util.gold()
    OF.util.text(OF.lang.t("BINGO"), left, top, 0.7, gold.r, gold.g, gold.b, 255)

    local deck = bingo.mode_entry()
    if deck.key ~= "mixed" then
        local name = OF.lang.t(deck.name)
        OF.util.text(name, left + span - OF.util.width(name, 0.5), top + 4,
            0.5, 200, 200, 200, 200)
    end
    top = top + titleGap

    local line = bingo.line_of(0)
    local inLine = {}
    if line ~= nil then
        for _, cell in ipairs(line) do inLine[cell] = true end
    end

    local goals = bingo.goals(bingo.seed())

    for y = 0, SIZE - 1 do
        for x = 0, SIZE - 1 do
            local cell = y * SIZE + x + 1
            local cx = left + x * (CELL + CELL_GAP)
            local cy = top + y * (CELL + CELL_GAP)

            local fading = bingo.flash_left(cell)
            if fading > 0 then
                local glow = math.floor(255 * fading / FLASH_FRAMES)
                OF.util.rect(cx - 3, cy - 3, CELL + 6, CELL + 6,
                    255, 255, 255, glow)
            end

            local r, g, b, a = 255, 255, 255, 40
            if bingo.marked(cell, 0) then
                r, g, b, a = gold.r, gold.g, gold.b, 210
            end
            if inLine[cell] then r, g, b, a = 255, 255, 255, 235 end
            OF.util.rect(cx, cy, CELL, CELL, r, g, b, a)

            if not bingo.marked(cell, 0) and bingo.watched(goals[cell]) then
                OF.util.rect(cx + 4, cy + CELL - 4, CELL - 8, 2,
                    gold.r, gold.g, gold.b, 150)
            end

            local label = string.format("%.0f", cell)
            local scale = 0.5
            local tx = cx + (CELL - OF.util.width(label, scale)) * 0.5
            local ty = cy + 6
            if a > 150 then
                OF.util.text(label, tx, ty, scale, 20, 18, 10, 255)
            else
                OF.util.text(label, tx, ty, scale, 235, 235, 235, 200)
            end

            if not bingo.marked(cell, 0) and #bingo.holders(cell) > 0 then
                OF.util.rect(cx + CELL - 6, cy + 3, 3, 3, 160, 172, 200, 220)
            end
        end
    end

    OF.util.text(OF.lang.t("Modes tab - Bingo"), left, top + span + 3, 0.45,
        180, 180, 180, 190)
end

hook_event(HOOK_ON_HUD_RENDER, render)

local hadLine = false

function bingo.forget_line()
    hadLine = false
end

local function tick_watched()
    local goals = bingo.goals(bingo.seed())
    local marks = bingo.marks(0)
    local went, count = {}, 0
    local last = nil

    for cell = 1, CELLS do
        local watcher = bingo.watcher_for(goals[cell])
        if watcher ~= nil and not bingo.marked(cell, 0) and watcher() then

            marks = marks + bit_of(cell)
            count = count + 1

            went[count] = string.format("%.0f", cell)
            last = goals[cell]
            flash(cell)
        end
    end

    if count == 0 then return end

    OF.util.publish_row(0, "ofBingoMarks", marks)
    OF.sounds.play(OF.sounds.PICK)

    if count == 1 then
        OF.notify.show("Bingo - @", "good", 5, last)
    else
        OF.notify.show("Bingo - squares @ went", "good", 5,
            table.concat(went, ", "))
    end
end

hook_event(HOOK_UPDATE, function()
    if not bingo.running() then
        hadLine = false
        return
    end

    fade_flashes()
    tick_watched()
    local line = bingo.line_of(0)
    if line == nil then

        hadLine = false
        return
    end
    if hadLine then return end
    hadLine = true

    local np = gNetworkPlayers[0]
    OF.notify.show("@ has a bingo line!", "good", 5,
        OF.util.plain(np ~= nil and np.name or "Somebody"))
end)
