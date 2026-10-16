OF = OF or {}
OF.cheats = OF.cheats or {}

local cheats = OF.cheats

cheats.PACKET = "chet"
cheats.LIST = {
    { key = "moonjump", name = "Moon jump",       blurb = "hold L in the air - tools that use L take it first" },
    { key = "speed",    name = "Super speed",     blurb = "half again as fast on foot - not in the air, not in water" },

    { key = "lowgrav",  name = "Low gravity",     blurb = "float back down, or come down like a brick",
      levels = {

          { name = "light", fall = 0.72 },
          { name = "floaty", fall = 0.55 },
          { name = "the moon", fall = 0.33 },

          { name = "a little heavy", fall = 1.30 },
          { name = "like lead", fall = 1.80 },

          { name = "a dropped anvil", fall = 2.60 },

          { name = "deep space", fall = 0.17 },
      } },
    { key = "nofall",   name = "No fall damage",  blurb = "land from anywhere" },

    { key = "giant",    name = "Giant",           blurb = "enormous, and there is more than one enormous",
      drawnOn = "shapes",
      levels = {
          { name = "big", scale = 1.8 },
          { name = "huge", scale = 2.6 },
          { name = "absurd", scale = 3.6 },

          { name = "a kaiju", scale = 5.0 },

          { name = "bigger the longer you live",
            scale = 1.0, per = 1.12, every = 30, cap = 3.6 },
      } },
    { key = "tiny",     name = "Tiny",            blurb = "small, and there is smaller than small",
      drawnOn = "shapes",
      levels = {
          { name = "small", scale = 0.45 },
          { name = "tiny", scale = 0.28 },
          { name = "a crumb", scale = 0.15 },

          { name = "a grain of sand", scale = 0.08 },
      } },

    { key = "invisible", name = "Invisible",      blurb = "nobody sees your Mario, its shadow or its name tag",
      drawnOn = "shapes" },
    { key = "rocket",   name = "Rocket",         blurb = "run and jump - speed climbs while your feet are up" },

    { key = "eject",    name = "Eject",          blurb = "leaving a level throws you out with the eject launch",
      levels = {

          { name = "a nudge", boost = 1.0 },
          { name = "a shove", boost = 2.0 },
          { name = "a proper yeet", boost = 4.0 },

          { name = "clear off the map", boost = 8.0 },
      } },
    { key = "godmode",  name = "God mode",       blurb = "nothing can hurt or kill you" },
    { key = "noclip",   name = "Noclip",         blurb = "fly through it all - stick flies, R lifts, L drops, A sprints" },
    { key = "infinitelives", name = "Infinite lives", blurb = "never run out" },
    { key = "blj",      name = "BLJ anywhere",   blurb = "backwards long jumps build speed without stairs; hold Z" },
    { key = "capkeep",  name = "Caps never run out", blurb = "a cap you pick up keeps its time topped up" },
    { key = "drysuit",  name = "Dry suit",       blurb = "deep water never runs your breath out" },
    { key = "surefeet", name = "Sure feet",      blurb = "ice and slopes stop sliding you about" },
    { key = "slick",    name = "Skates",         blurb = "every slope behaves like sheet ice" },

    { key = "bouncy",   name = "Bouncy",         blurb = "every landing throws you back up",
      levels = {

          { name = "a proper bounce", keep = 1.39, cap = 156, floor = 12 },

          { name = "a little", keep = 0.80, cap = 90, floor = 12 },

          { name = "you never stop", keep = 1.39, cap = 156, floor = 0 },
      } },
    { key = "secondchance", name = "Second chance", blurb = "one killing blow a level is survived" },

    { key = "fins",     name = "Faster swim",    blurb = "swim faster than the game allows, faster than on land",
      levels = {

          { name = "fins", swim = 48 },
          { name = "a propeller", swim = 60 },

          { name = "a torpedo", swim = 72 },

          { name = "and you keep it on land", swim = 72, carry = 1.0 },
      } },

    { key = "frog",     name = "Frog swim",      blurb = "a steady glide in water, any way you point - A bursts" },
    { key = "kicks",    name = "Wall kicks never close", blurb = "the window after a bonk stays open" },
    { key = "turn",     name = "Sharp turns",    blurb = "face where the stick points, with no swing",
      levels = {

          { name = "a shade quicker", swing = 0x0800 },
          { name = "sharp", swing = 0x2000 },
          { name = "very sharp", swing = 0x4000 },
          { name = "instant" },
      } },
    { key = "unseen",   name = "Enemies ignore you", blurb = "nothing that chases picks you to chase" },
    { key = "sand",     name = "Light on sand",  blurb = "quicksand never pulls you under" },
    { key = "nowarp",   name = "Warps ignore you", blurb = "pipes and paintings let you walk over them" },
    { key = "nosquish", name = "Never flat",     blurb = "a squash is over the frame it lands" },
    { key = "hover",    name = "Hover",          blurb = "hold R in the air and hang there, still steering",
      levels = {

          { name = "a jump's worth", frames = 30 },
          { name = "a held breath", frames = 60 },
          { name = "a full tank", frames = 120 },

          { name = "no limit at all" },

      } },

    { key = "airhold", name = "Hold A in the air",
      blurb = "hold A while falling and you float, flutter, or hang there",
      levels = {

          { name = "a slow float", fall = -12.0, frames = 60 },

          { name = "a flutter", fall = -12.0, frames = 60, rise = 30 },

          { name = "the full hover" },
      } },
    { key = "magnet",   name = "Coin magnet",    blurb = "coins nearby come to you",
      levels = {

          { name = "across the room", reach = 700.0, pull = 0.22 },
          { name = "the whole hall", reach = 1150.0, pull = 0.28 },

          { name = "the next room too", reach = 1700.0, pull = 0.34 },
          { name = "everything loose in the level", reach = 2600.0, pull = 0.42 },
      } },

    { key = "starmagnet", name = "Star magnet",   blurb = "stars come to you - the standing ones and a boss's",
      levels = {

          { name = "a good jump away", reach = 700.0, pull = 0.22 },
          { name = "the whole hall", reach = 1150.0, pull = 0.28 },
          { name = "the next hall too", reach = 1700.0, pull = 0.34 },
          { name = "everything the level is holding", reach = 2600.0, pull = 0.42 },
      } },
    { key = "backstop", name = "Backstop",       blurb = "walk off the world and you are put back on solid ground" },
    { key = "sealegs",  name = "Sea legs",       blurb = "deep water never pulls you into a swim" },
    { key = "windproof", name = "Windproof",     blurb = "no wind moves you - not the cloud, breath or the gusts" },
    { key = "vow",      name = "Vow of silence", blurb = "your Mario never makes a sound of his own" },

    { key = "sniper",   name = "Sniper rifle",  blurb = "hold L to aim, press B to fire - one shot, one kill",
      levels = {

          { name = "a bolt to work", wait = 90 },
          { name = "a faster hand", wait = 45 },
          { name = "as fast as you can aim", wait = 20 },
      },
      restore = function() return cheats.forget_the_rifle() end },
    { key = "blast",    name = "Blast fists",    blurb = "a punch or a kick sets off a bang where it lands",

      stopOnWire = true,
      levels = {

          { name = "one bang", count = 1, spread = 0 },
          { name = "a wider swing", count = 4, spread = 160 },
          { name = "clear the room", count = 8, spread = 320 },

          { name = "and it throws you back", count = 8, spread = 320, kick = 38 },
      } },
    { key = "coinrun",  name = "Coin runner",    blurb = "every coin you pick up leaves you faster on foot",
      levels = {

          { name = "a nudge a coin", per = 0.4, cap = 48 },
          { name = "a real climb", per = 1.0, cap = 72 },
          { name = "runaway", per = 2.5, cap = 110 },
      } },
    { key = "airjump",  name = "Mid-air jumps",  blurb = "press A again with nothing under you",
      levels = {
          { name = "one more", jumps = 1 },
          { name = "two more", jumps = 2 },
          { name = "three more", jumps = 3 },
          { name = "five more", jumps = 5 },

          { name = "as many as you like", jumps = 99, endless = true },
      } },
    { key = "stroke",   name = "Strong stroke",  blurb = "underwater you face where you point, at once" },
    { key = "coinsize", name = "Coin growth",    blurb = "every coin changes how big you are",
      levels = {

          { name = "grow", per = 1.06, low = 1.0, high = 2.6 },
          { name = "grow fast", per = 1.15, low = 1.0, high = 3.4 },
          { name = "shrink", per = 0.95, low = 0.30, high = 1.0 },
          { name = "shrink fast", per = 0.88, low = 0.12, high = 1.0 },

          { name = "grow on coins, shrink on hits",
            per = 1.06, hit = 0.90, low = 0.30, high = 2.6 },
      } },

    { key = "regen",    name = "Second wind",    blurb = "your health comes back on its own",
      levels = {

          { name = "a wedge a minute", every = 56 },
          { name = "slowly", every = 34 },
          { name = "quickly", every = 6 },

          { name = "quickly, and a wedge per enemy beaten",
            every = 6, beat = 4 },

          { name = "and a wedge for anyone you touch",
            every = 6, beat = 4, touch = 4 },
      } },
    { key = "coininvinc", name = "A coin buys a moment", blurb = "picking one up leaves you briefly untouchable",
      levels = {

          { name = "half a second", frames = 15 },
          { name = "a second", frames = 30 },
          { name = "two seconds", frames = 60 },
          { name = "four seconds", frames = 120 },

          { name = "eight seconds for a blue coin", per = 48 },
      } },
    { key = "nolava",   name = "Lava never burns", blurb = "the fire floor and the fire walls take nothing off you" },
    { key = "noflame",  name = "Fireproof",      blurb = "nothing sets you alight" },
    { key = "noshock",  name = "Shockproof",     blurb = "nothing electric makes you drop what you are doing" },
    { key = "notwister", name = "Twister-proof", blurb = "the tornado and the whirlpool cannot take you" },
    { key = "nokb",     name = "Nothing knocks you back", blurb = "a hit hurts and it leaves you the stick" },
    { key = "nobite",   name = "Nothing swallows you", blurb = "the clam and the big fish let you past" },
    { key = "still",    name = "Never dozes off", blurb = "standing about never puts you to sleep" },
    { key = "capstay",  name = "Your cap stays on", blurb = "nothing takes it off your head and keeps it" },
    { key = "poundcut", name = "Pound cancel",   blurb = "press A during a ground pound and you jump out of it" },
    { key = "twirl",    name = "Twirl down",     blurb = "press A while falling and you spin down - hold for slower" },
    { key = "triples",  name = "Every jump is the third one", blurb = "the triple jump's height and its somersault, from standing" },
    { key = "ledgeup",  name = "Quick ledge climbs", blurb = "you never do the slow haul over an edge" },
    { key = "nodialog", name = "Skip the talking", blurb = "signs and speeches never open a box in front of you" },
    { key = "nofade",   name = "No fades",       blurb = "warps and level changes land without the wipe" },
    { key = "keepcam",  name = "Keep your camera", blurb = "going under water never takes the camera off you" },

    { key = "airsteer",  name = "Air steering",     blurb = "turn to face the stick while your feet are off the ground",
      levels = {

          { name = "a shade", turn = 0x0400 },
          { name = "quickly", turn = 0x1000 },

          { name = "at once" },
      } },
    { key = "revup",    name = "Off the mark",     blurb = "your top speed on foot arrives on the first frame you ask" },
    { key = "wallbounce", name = "Walls give it back", blurb = "a bonk stops costing you everything you were carrying",
      levels = {

          { name = "you keep your speed", keep = 1.0, lift = 0 },
          { name = "it throws you off", keep = 1.0, lift = 30 },
          { name = "it throws you right off", keep = 1.6, lift = 55 },

          { name = "and you keep going up", keep = 1.6, climb = 14 },
      } },
    { key = "heavy",    name = "Heavy",            blurb = "you fall like you weigh something, and jump shorter for it",
      levels = {

          { name = "half again", pull = 2.0 },
          { name = "twice as heavy", pull = 4.0 },
          { name = "like a stone", pull = 8.0 },
      } },
    { key = "coinheal", name = "A coin patches you up", blurb = "picking one up mends more of you than it does",
      levels = {

          { name = "twice over", per = 4 },
          { name = "four times over", per = 12 },

          { name = "the whole meter", full = true },
      } },
    { key = "coinpop",  name = "A coin springs you", blurb = "every coin you take throws you into the air",
      levels = {

          { name = "a hop", lift = 22 },
          { name = "a jump", lift = 52 },
          { name = "over the roof", lift = 90 },
      } },
    { key = "nodance",  name = "Stars never stop you", blurb = "no dance, no fanfare, and the course keeps you in" },

    { key = "enemycoins", name = "What you beat leaves a coin", blurb = "coins only you can see, and only you can take",
      levels = {
          { name = "one", coins = 1 },
          { name = "three", coins = 3 },
          { name = "a handful", coins = 5 },
      } },
    { key = "tough",    name = "Enemies hurt you less", blurb = "a hit still lands and it costs you a fraction of what it did",
      levels = {

          { name = "half as much", keep = 0.5 },
          { name = "a quarter", keep = 0.25 },
          { name = "a scratch", keep = 0.1 },

          { name = "not at all, and they still shove you", keep = 0 },
      } },

    { key = "reach",    name = "Longer reach",   blurb = "you touch the world further off, and it reaches you as far",
      levels = {

          { name = "as wide as everything else", wide = 1.35 },
          { name = "twice as far", wide = 2.0 },
          { name = "three times as far", wide = 3.0 },
      } },
    { key = "stompchain", name = "Stomps chain", blurb = "land on enemy after enemy and each throws you higher",
      levels = {

          { name = "a little more each time", add = 12 },
          { name = "a jump more each time", add = 22 },
          { name = "higher every time", add = 34 },

          { name = "higher, and each one heals you", add = 34, heal = 1 },
      } },
    { key = "stompguard", name = "A stomp buys a moment", blurb = "landing on something leaves you briefly untouchable",
      levels = {

          { name = "half a second", frames = 15 },
          { name = "a second", frames = 30 },
          { name = "two seconds", frames = 60 },
      } },

    { key = "cough",    name = "Catching cough", blurb = "caught off anybody near; a full meter shakes it off",
      levels = {

          { name = "a tickle",       every = 150, catch = 1, clear = 600 },
          { name = "a bad chest",    every = 90,  catch = 2, clear = 450 },
          { name = "the full thing", every = 45,  catch = 3, clear = 300 },
      } },
    { key = "speedo",   name = "Speedometer",    blurb = "how fast you are going, and your best this run",
      shows = true },
    { key = "timer",    name = "Stopwatch",      blurb = "how long you have been in this level",
      shows = true },
    { key = "facing",   name = "Facing",         blurb = "which way you point, and the slope under you",
      shows = true },
    { key = "coords",   name = "Coords",         blurb = "where you are standing, in the corner",
      shows = true },
    { key = "height",   name = "Altimeter",      blurb = "how far above the floor, and how far you have fallen",
      shows = true },
    { key = "inputs",   name = "Inputs",         blurb = "the buttons and sticks you are pressing",
      shows = true, deep = true },

    { key = "hitbox",   name = "Show player hitboxes",
      blurb = "both cylinders the game tests, red while a swing lands",
      shows = true, deep = true, advantage = true },

    { key = "hitboxobj", name = "Show object hitboxes",
      blurb = "the same cylinder round everything that reacts to touch",
      shows = true, deep = true, advantage = true },
    { key = "cost",     name = "Frame cost",     blurb = "which of this mod's hooks spent longest on one frame",
      shows = true, deep = true },

    { key = "act",      name = "Action",         blurb = "which action you are in, how long, and the one before it",
      shows = true },
    { key = "meter",    name = "Health wheel",   blurb = "the game's own dial, always on and as big as you like",
      shows = true,
      levels = {

          { name = "small", size = 44 },
          { name = "the size the game draws it", size = 64 },
          { name = "big", size = 96 },
          { name = "across the corner", size = 144 },
      } },

    { key = "vitals",   name = "Vitals",         blurb = "your health to the wedge, and what it is about to do",
      shows = true, deep = true },
    { key = "clocks",   name = "Timers",         blurb = "every counter the engine is running down on you",
      shows = true, deep = true },
    { key = "surface",  name = "The floor under you", blurb = "what you stand on, how steep it is, whether it grips",
      shows = true, deep = true },
    { key = "load",     name = "Object count",   blurb = "how many objects this level runs, and how many near",
      shows = true, deep = true },
}

cheats.HOVER_BUTTON = R_TRIG

cheats.MOONJUMP_BUTTON = L_TRIG

function cheats.hover_takes(button)
    if button == nil then return false end
    return button == cheats.HOVER_BUTTON and cheats.is_on("hover")
end

cheats.MOON_BONKS = { "ACT_SOFT_BONK", "ACT_BACKWARD_AIR_KB", "ACT_FORWARD_AIR_KB",
    "ACT_HARD_BACKWARD_AIR_KB", "ACT_HARD_FORWARD_AIR_KB" }
function cheats.moon_out_of_bonk(m)
    if m == nil then return false end
    for _, name in ipairs(cheats.MOON_BONKS) do
        local act = _G[name]
        if type(act) == "number" and m.action == act then
            if (m.forwardVel or 0) < 0 then m.forwardVel = 0 end
            set_mario_action(m, ACT_FREEFALL, 0)
            return true
        end
    end
    return false
end

function cheats.moonjump_stands_down()
    local _, name = OF.util.hands_on()
    return name
end

local FRAMES_A_SECOND = 30

local HOVER_WATER_SECONDS = 1

local HOVER_GROUND_SLOWER = 10

local HOVER_RESTART = 0.25

local HOVER_FLOOR_BAND = 20

cheats.hoverTank = cheats.hoverTank or 1
cheats.hoverLatched = false

cheats.hoverPeak = nil

function cheats.hover_wet(m)
    if m == nil or m.waterLevel == nil then return false end
    return m.pos.y < m.waterLevel
end

function cheats.hover_footed(m)
    if m == nil then return true end
    return m.pos.y <= m.floorHeight + HOVER_FLOOR_BAND
end

function cheats.hover_size()
    if cheats.is_on("hover") then
        return cheats.setting("hover", "frames", nil)
    end
    local entry = cheats.find("hover")
    local first = entry ~= nil and (entry.levels or {})[1] or nil
    return first ~= nil and first.frames or nil
end

function cheats.hover_tick(m, holding)
    if m == nil then return false end

    local size = cheats.hover_size()
    local wet = cheats.hover_wet(m)
    local footed = cheats.hover_footed(m)
    local tank = cheats.hoverTank or 1

    local full = FRAMES_A_SECOND * HOVER_WATER_SECONDS
    if wet then
        tank = math.min(1, tank + 1 / full)
    elseif footed then
        tank = math.min(1, tank + 1 / (full * HOVER_GROUND_SLOWER))
    end

    if not holding and tank >= HOVER_RESTART then
        cheats.hoverLatched = false
    end

    local lift = holding and not wet and not footed and m.vel.y < 0

    if size == nil then
        cheats.hoverTank = 1
        cheats.hoverLatched = false
        if not lift then cheats.hoverPeak = nil end
        return lift
    end

    if not lift or cheats.hoverLatched then
        cheats.hoverTank = tank
        cheats.hoverPeak = nil
        return false
    end

    tank = tank - 1 / size
    if tank * size < 1 then
        tank = 0

        cheats.hoverLatched = true
    end
    cheats.hoverTank = tank
    return true
end

function cheats.hover_on_a()
    if not cheats.is_on("airhold") then return false end
    return cheats.setting("airhold", "fall", nil) == nil
end

cheats.airHeld = 0

function cheats.air_hold_floor(m, holding)
    if m == nil or m.vel == nil then return nil end
    if not cheats.is_on("airhold") then
        cheats.airHeld = 0
        return nil
    end

    local fall = cheats.setting("airhold", "fall", nil)

    if fall == nil then
        cheats.airHeld = 0
        return nil
    end

    if not holding or cheats.hover_wet(m) or cheats.hover_footed(m)
        or m.vel.y >= 0 then
        cheats.airHeld = 0
        return nil
    end

    local allowance = cheats.setting("airhold", "frames", 0)
    if cheats.airHeld >= allowance then return nil end
    cheats.airHeld = cheats.airHeld + 1

    local rise = cheats.setting("airhold", "rise", nil)
    if rise == nil or rise <= 0 then return fall end
    local gone = cheats.airHeld / rise
    if gone >= 1 then return 0.0 end
    return fall * (1 - gone)
end

cheats.GRANTED = {

    gasmask = {
        levels = {
            { name = "the gas" },
            { name = "the gas and the water", water = true },
            { name = "everything, including lava", water = true, lava = true },
        },
    },

    grip    = {
        levels = {
            { name = "a slow slide", rise = -12.0 },
            { name = "you stick to it", rise = 0.0 },
            { name = "you climb it", rise = 8.0 },
        },
    },
    springs = {

        levels = {
            { name = "spring heels", lift = 1.4, cap = 100 },
            { name = "a pogo stick", lift = 1.8, cap = 130 },
            { name = "a launchpad", lift = 2.4, cap = 175 },

            { name = "the moon and back", lift = 3.2, cap = 240 },
        },
    },
    float = {

        levels = {
            { name = "a little slower", fall = -30.0 },
            { name = "like a leaf", fall = -16.0 },
            { name = "like a feather", fall = -8.0 },

            { name = "barely at all", fall = -3.0 },
        },
    },
}

function cheats.is_instrument(key)
    local entry = cheats.find(key)
    return entry ~= nil and entry.shows == true and entry.advantage ~= true
end

cheats.GROUPS = {

    { name = "How you move", help = "how fast you go, and what is no longer in the way",
      keys = { "speed", "blj", "noclip",

               "frog" } },

    { name = "Once your feet leave the ground", help = "how you get up there, how long you stay, and where you can steer",
      keys = { "moonjump", "rocket", "eject", "hover", "airhold",
               "airsteer" } },

    { name = "What the ground does", help = "what happens to you when you touch a floor, a wall or something you land on",
      keys = { "bouncy", "kicks", "turn", "slick", "surefeet", "revup",
               "wallbounce", "stompchain" } },

    { name = "Nothing can kill you", help = "everything that would end your run, and no longer does",
      keys = { "godmode", "nofall", "infinitelives", "secondchance",
               "nosquish", "backstop", "regen", "stompguard" } },

    { name = "The level can't touch you", help = "the course itself - its water, its wind, its sand and its fire",
      keys = { "drysuit", "sand", "nowarp", "sealegs", "windproof",
               "nolava" } },

    { name = "The creatures can't get to you", help = "what lives in the level and has its own idea about you",
      keys = { "unseen", "noflame", "noshock", "notwister", "nokb",
               "nobite", "tough" } },

    { name = "Your body", help = "what you are: how big, how heavy, how loud, how far you reach - and what you have caught",
      keys = { "giant", "tiny", "lowgrav", "fins", "vow", "heavy",
               "reach", "cough" } },

    { name = "Your cap", help = "the cap you are wearing: its clock, and keeping it on your head",
      keys = { "capkeep", "capstay" } },

    { name = "Moves nobody taught you", help = "moves the game does not have, rather than its own numbers turned up",
      keys = { "blast", "sniper", "airjump", "stroke", "poundcut", "twirl",
               "triples", "ledgeup" } },

    { name = "What a coin is worth", help = "what picking a coin up does to you, and where the coins come from",
      keys = { "magnet", "starmagnet", "coinrun", "coinsize", "coininvinc",
               "coinheal", "coinpop", "enemycoins" } },

    { name = "Nothing interrupts you", help = "text boxes, screen wipes, naps and dances that cost you seconds",
      keys = { "nodialog", "nofade", "keepcam", "nodance", "still" } },

    { name = "On the dashboard", instruments = true,
      help = "read-outs about your own run - a round puts these away until it ends" },
    { name = "Under the bonnet", instruments = "deep",
      help = "read-outs about the machine underneath your run" },
}
cheats.UNGROUPED = "Everything else"
function cheats.grouped(part)
    local where = {}
    for index, group in ipairs(cheats.GROUPS) do
        for _, key in ipairs(group.keys or {}) do where[key] = index end
    end

    local instrumentsAt, deepAt = nil, nil
    for index, group in ipairs(cheats.GROUPS) do
        if group.instruments == "deep" then deepAt = index
        elseif group.instruments then instrumentsAt = index end
    end

    local buckets = {}
    for index = 1, #cheats.GROUPS do buckets[index] = {} end
    local rest = {}

    for _, entry in ipairs(cheats.LIST) do
        local index = where[entry.key]

        if entry.drawnOn ~= nil then
            index = false
        elseif index == nil and entry.shows == true then
            index = entry.deep == true and (deepAt or instrumentsAt)
                or instrumentsAt
        end
        if index == nil then
            table.insert(rest, entry)
        elseif index ~= false then
            table.insert(buckets[index], entry)
        end
    end

    local out = {}
    for index, group in ipairs(cheats.GROUPS) do
        local wanted = part == nil
            or (part == "readouts") == (group.instruments ~= nil
                and group.instruments ~= false)
        if #buckets[index] > 0 and wanted then
            table.insert(out, { name = group.name, help = group.help,
                                entries = buckets[index] })
        end
    end
    if #rest > 0 and part ~= "readouts" then

        table.insert(out, { name = cheats.UNGROUPED,
                            help = OF.lang.t("cheats no heading has claimed yet"),
                            entries = rest })
    end
    return out
end

cheats.active = cheats.active or {}

local BLJ_GAIN = 1.5
local BLJ_ENTRY_CAP = 48.0
local BLJ_LIMIT = -30000

local BLJ_SLAM = -30

local BLJ_BACKWARDS = -15

local SPEED_FACTOR = 1.6
local SPEED_CAP = 72

local WALK_TARGET_MAX = 32

local ROOM_SPEED_CAP = 160

local function frame_now()
    return OF.util.optional("get_global_timer", nil)
end

local function set_bit(value, bit)
    if bit == nil or bit == 0 then return value end
    if OF.util.has_flag(value, bit) then return value end
    return value + bit
end

local function clear_bit(value, bit)
    if bit == nil or bit == 0 then return value end
    if not OF.util.has_flag(value, bit) then return value end
    return value - bit
end

local CAP_HELD_AT = 1200

local BOUNCE_KEEP = 1.39
local BOUNCE_CAP = 156
local BOUNCE_FLOOR = 12

local ONE_WEDGE = 0x100
local FULL_HEALTH = 0x880

local SWIM_CLAMP = 28

local FINS_CAP = 48

local WALK_CLAMP = 48

local WALK_SHED = 1.0

local HEAL_WEDGE = 4

local HEAL_OWED_CAP = 8 * HEAL_WEDGE

local SPRING_LIFT = 1.4
local SPRING_CAP = 100

local function angle_gap(to, from)
    local gap = (to - from) % 0x10000
    if gap >= 0x8000 then gap = gap - 0x10000 end
    return gap
end

local SPRING_JUMPS = {}
local SPRING_ACTIONS = { ACT_JUMP, ACT_DOUBLE_JUMP, ACT_TRIPLE_JUMP,
                         ACT_BACKFLIP, ACT_SIDE_FLIP, ACT_WALL_KICK_AIR }
for i = 1, 6 do
    if SPRING_ACTIONS[i] ~= nil then SPRING_JUMPS[SPRING_ACTIONS[i]] = true end
end

local KNOCKBACK_ACTIONS = {}
do
    local list = {
        ACT_SOFT_FORWARD_GROUND_KB, ACT_FORWARD_GROUND_KB,
        ACT_HARD_FORWARD_GROUND_KB, ACT_SOFT_BACKWARD_GROUND_KB,
        ACT_BACKWARD_GROUND_KB, ACT_HARD_BACKWARD_GROUND_KB,
        ACT_FORWARD_AIR_KB, ACT_HARD_FORWARD_AIR_KB,
        ACT_BACKWARD_AIR_KB, ACT_HARD_BACKWARD_AIR_KB,
        ACT_FORWARD_WATER_KB, ACT_BACKWARD_WATER_KB,
    }
    for i = 1, 12 do
        if list[i] ~= nil then KNOCKBACK_ACTIONS[list[i]] = true end
    end
end

function cheats.is_knockback(action)
    if action == nil then return false end
    return KNOCKBACK_ACTIONS[action] == true
end

local BONK_ACTIONS = {}
local BONK_ANY = { ACT_AIR_HIT_WALL, ACT_SOFT_BONK, ACT_BACKWARD_AIR_KB }
for i = 1, 3 do
    if BONK_ANY[i] ~= nil then BONK_ACTIONS[BONK_ANY[i]] = true end
end

cheats.WALL_KICK_HOLDS = {}
for action in pairs(BONK_ACTIONS) do cheats.WALL_KICK_HOLDS[action] = true end
if ACT_WALL_KICK_AIR ~= nil then
    cheats.WALL_KICK_HOLDS[ACT_WALL_KICK_AIR] = true
end

function cheats.wall_kick_holds(action)
    if action == nil then return false end
    return cheats.WALL_KICK_HOLDS[action] == true
end

local STOMP_TYPES = {}
local STOMP_ANY = { INTERACT_BOUNCE_TOP, INTERACT_BOUNCE_TOP2, INTERACT_KOOPA }
for i = 1, 3 do
    if STOMP_ANY[i] ~= nil then STOMP_TYPES[STOMP_ANY[i]] = true end
end
local STOMP_ATTACK = ATTACK_FROM_ABOVE or 3
local ATTACK_MASK = 256

local BOUNCE_OFF_OBJECT = 30
local STOMP_LIFT_CAP = 240

local function was_a_stomp(o, interactType)
    if not STOMP_TYPES[interactType] then return false end
    local status = tonumber(o ~= nil and o.oInteractStatus or nil) or 0
    return math.floor(status) % ATTACK_MASK == STOMP_ATTACK
end

local STAR_DANCES = {}
local STAR_DANCE_ANY = { ACT_STAR_DANCE_EXIT, ACT_STAR_DANCE_NO_EXIT,
                         ACT_STAR_DANCE_WATER, ACT_FALL_AFTER_STAR_GRAB }
for i = 1, 4 do
    if STAR_DANCE_ANY[i] ~= nil then STAR_DANCES[STAR_DANCE_ANY[i]] = true end
end

local BLAST_ACTIONS = {}
local BLAST_ANY = { ACT_PUNCHING, ACT_MOVE_PUNCHING, ACT_JUMP_KICK,
                    ACT_DIVE, ACT_SLIDE_KICK }
for i = 1, 5 do
    if BLAST_ANY[i] ~= nil then BLAST_ACTIONS[BLAST_ANY[i]] = true end
end

local WARP_SKIP_HOLD = 2

local NUMBERS = {

    gripSlide = 12.0,

    gripHold = 5,

    magnetReach = 700.0,
    magnetPull = 0.22,

    magnetClose = 60.0,

    starReach = 700.0,
    starPull = 0.22,

    starWireMatch = 500.0,

    starClose = 90.0,
}

local byKey, byKeyAt = nil, -1

function cheats.find(key)
    if byKey == nil or byKeyAt ~= #cheats.LIST then
        byKey, byKeyAt = {}, #cheats.LIST
        for _, entry in ipairs(cheats.LIST) do byKey[entry.key] = entry end
    end
    return byKey[key]
end

function cheats.stops_of(key)
    local entry = cheats.find(key)
    if entry ~= nil then return entry end
    return cheats.GRANTED[key]
end

function cheats.is_on(key)
    return (cheats.in_force(key)) > 0
end

function cheats.round_grants(key)
    if not OF.util.asks(OF.gamemodes, "current") then return nil end

    local mode = OF.gamemodes.current()
    if mode == nil or type(mode.cheatsGiven) ~= "table" then return nil end
    if mode.cheatsGiven[key] == nil then return nil end
    if not OF.util.asks(OF.gamemodes, "is_running") then return nil end

    if not (OF.gamemodes.is_running()
        or (OF.util.asks(OF.gamemodes, "is_waiting") and OF.gamemodes.is_waiting())) then
        return nil
    end

    if OF.util.asks(OF.roundscope, "inside") and not OF.roundscope.inside(0) then
        return nil
    end
    local rung = mode.cheatsGiven[key]

    if type(rung) == "function" then rung = rung() end
    if type(rung) ~= "number" or rung < 1 then return nil end
    return math.floor(rung)
end

function cheats.granted(key)
    local given = nil
    if OF.util.asks(OF.powerups, "granting") then
        given = OF.powerups.granting(key)
    end
    local round = cheats.round_grants(key)
    if round ~= nil and (given == nil or round > given) then given = round end

    if OF.util.asks(OF.speedrun, "grants") then
        local run = OF.speedrun.grants(key)
        if run ~= nil and (given == nil or run > given) then given = run end
    end
    return given
end

function cheats.page_count(part)
    local n = 0
    for _, group in ipairs(cheats.grouped(part or "cheats")) do
        for _, entry in ipairs(group.entries) do
            if cheats.is_on(entry.key) then n = n + 1 end
        end
    end
    return n
end

function cheats.any_on()
    for _, entry in ipairs(cheats.LIST) do
        if cheats.is_on(entry.key) then return true end
    end
    return false
end

cheats.dialled = cheats.dialled or {}

local WIRE_CHUNK = 190

local WIRE_KEYS = { "ofRoomCheats", "ofRoomCheats2", "ofRoomCheats3",
                    "ofRoomCheats4", "ofRoomCheats5" }

cheats.WIRE_CHUNK = WIRE_CHUNK
cheats.WIRE_KEYS = WIRE_KEYS

local MINE_CHUNK = 190
local MINE_KEYS = { "ofCheats", "ofCheats2", "ofCheats3",
                    "ofCheats4", "ofCheats5" }

cheats.MINE_CHUNK = MINE_CHUNK
cheats.MINE_KEYS = MINE_KEYS

local roomAt, roomSet = nil, nil

function cheats.room_text()
    return OF.util.joined(WIRE_KEYS)
end

local function room_piece(piece)
    local key, level = string.match(piece, "^([^=]+)=(%d+)$")
    if key == nil then key, level = piece, 1 end
    local entry = cheats.find(key)
    if entry == nil then return nil end
    return key, OF.util.clamp(math.floor(tonumber(level) or 1), 1,
        cheats.step_count(entry))
end

function cheats.room_parse(packed)
    local set = {}
    if packed == nil or packed == "" then return set end
    for piece in string.gmatch(packed, "[^,]+") do
        local key, level = room_piece(piece)
        if key ~= nil then set[key] = level end
    end
    return set
end

function cheats.room()
    local text = cheats.room_text()
    if roomSet == nil or roomAt ~= text then
        roomAt = text
        roomSet = cheats.room_parse(text)
    end
    return roomSet
end

function cheats.room_level(key)
    return cheats.room()[key]
end

function cheats.room_on(key)
    return cheats.room()[key] ~= nil
end

function cheats.room_any()
    return next(cheats.room()) ~= nil
end

local function room_parts(set)
    local parts = {}
    for _, entry in ipairs(cheats.LIST) do
        local level = set[entry.key]
        if level ~= nil then
            local piece = entry.key
            if level > 1 then piece = piece .. "=" .. tostring(level) end
            table.insert(parts, piece .. ",")
        end
    end
    return parts
end

cheats.room_parts = room_parts

local function publish_room(set)
    local chunks = OF.util.chunk_parts(room_parts(set), WIRE_CHUNK)
    if chunks == nil or #chunks > #WIRE_KEYS then

        return false
    end
    local ok = true
    for index, wireKey in ipairs(WIRE_KEYS) do
        if not OF.util.publish(wireKey, chunks[index] or "") then ok = false end
    end

    if cheats.publish_mine ~= nil then cheats.publish_mine() end
    return ok
end

local registered = false

local function register_requests()
    if registered then return end
    if not OF.util.asks(OF.net, "register_action") then return end
    registered = true

    OF.net.register_action("roomcheat", "cheats_lobby",
        function(_, key, level)
            if not OF.util.is_host() then return false, "Only the host." end

            local at = math.floor(tonumber(level) or 0)
            return cheats.write_room(tostring(key), at > 0, at > 0 and at or nil)
        end)

    OF.net.register_action("roomcheatclear", "cheats_lobby", function()
        if not OF.util.is_host() then return false, "Only the host." end
        return cheats.write_room_set({})
    end)
end

function cheats.set_room(key, value, level)
    local entry = cheats.find(key)
    if entry == nil then return false, "No such cheat." end
    if not OF.perms.can("cheats_lobby") then
        return false, "Your rank cannot set the lobby's cheats. ("
            .. OF.perms.tier_name(OF.perms.required("cheats_lobby")) .. "+)"
    end

    local roundSaysNo = cheats.round_refusal(key, value)
    if roundSaysNo ~= nil then return false, roundSaysNo end

    register_requests()
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does("roomcheat", key,
            value and math.floor(level or 1) or 0)
    end

    if not OF.util.is_host() then
        return false, "No host to ask yet - try again in a second."
    end
    return cheats.write_room(key, value, level)
end

function cheats.write_room(key, value, level)
    local entry = cheats.find(key)
    if entry == nil then return false, "No such cheat." end
    local roundSaysNo = cheats.round_refusal(key, value)
    if roundSaysNo ~= nil then return false, roundSaysNo end
    local set = cheats.room_parse(cheats.room_text())
    if value then
        set[key] = OF.util.clamp(
            math.floor(type(level) == "number" and level or 1),
            1, cheats.step_count(entry))

        local opposite = cheats.OPPOSITES[key]
        if opposite ~= nil then set[opposite] = nil end
    else
        set[key] = nil
    end
    return cheats.write_room_set(set)
end

function cheats.write_room_set(set)
    if not publish_room(set) then
        return false, "Too many cheats for the lobby to carry at once."
    end
    return true
end

function cheats.set_room_level(key, level)
    local entry = cheats.find(key)
    if entry == nil then return false, "No such cheat." end
    if type(level) ~= "number" then return false, "That is not a setting." end
    level = math.floor(level)
    if level <= 0 then return cheats.set_room(key, false) end
    if level > cheats.step_count(entry) then
        return false, "That cheat only has " .. cheats.step_count(entry)
            .. " setting(s)."
    end
    return cheats.set_room(key, true, level)
end

function cheats.clear_room()
    if not OF.perms.can("cheats_lobby") then
        return false, "Your rank cannot set the lobby's cheats. ("
            .. OF.perms.tier_name(OF.perms.required("cheats_lobby")) .. "+)"
    end
    register_requests()
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does("roomcheatclear")
    end
    if not OF.util.is_host() then
        return false, "No host to ask yet - try again in a second."
    end
    return cheats.write_room_set({})
end

cheats.OPPOSITES = {
    giant = "tiny", tiny = "giant",
    slick = "surefeet", surefeet = "slick",
    lowgrav = "heavy", heavy = "lowgrav",
}

function cheats.in_force(key, ignoreRound)

    if cheats.active[key] == nil and cheats.room_level(key) == nil then
        local given = cheats.granted(key)
        if given ~= nil then
            return OF.util.clamp(given, 1,
                cheats.step_count(cheats.stops_of(key))), false
        end
        return 0, false
    end
    local holds = (not ignoreRound) and cheats.round_holds(key)

    local state = nil
    if not holds then state = cheats.mine_state(key) end
    if state == true then
        local wanted = cheats.dialled[key] or 1
        return OF.util.clamp(wanted, 1, cheats.step_count(cheats.find(key))),
            true
    end

    if state == false then return 0, true end
    local opposite = cheats.OPPOSITES[key]

    if not holds
        and (opposite == nil or cheats.mine_state(opposite) ~= true) then
        local level = cheats.room_level(key)
        if level ~= nil then return level, false end
    end
    local given = cheats.granted(key)
    if given ~= nil then
        return OF.util.clamp(given, 1,
            cheats.step_count(cheats.stops_of(key))), false
    end
    return 0, false
end

function cheats.step_count(entry)
    if entry == nil or entry.levels == nil then return 1 end
    return #entry.levels
end

function cheats.level(key)
    return (cheats.in_force(key))
end

function cheats.level_is_yours(key)
    local _, mine = cheats.in_force(key)
    return mine
end

function cheats.setting(key, field, fallback)
    local entry = cheats.stops_of(key)
    if entry == nil then return fallback end
    local level = cheats.level(key)
    if level <= 0 then return fallback end
    local step = (entry.levels or {})[level]
    if step == nil or step[field] == nil then return fallback end
    return step[field]
end

function cheats.owe_a_wedge(units)
    if type(units) ~= "number" or units <= 0 then return end
    local owed = (cheats.healOwed or 0) + units
    if owed > HEAL_OWED_CAP then owed = HEAL_OWED_CAP end
    cheats.healOwed = owed
end

do

    local REACH = 120
    local OVER = 200
    local UNDER = 100

    function cheats.coughing(localIndex)
        if localIndex == 0 then return cheats.level("cough") end

        local shared = cheats.room_level("cough")
        local worn = cheats.worn_set(localIndex)
        local wears = worn ~= nil and worn.cough or nil
        if shared == nil and wears == nil and cheats.round_grants("cough") == nil then
            return nil
        end
        if cheats.round_holds("cough") then
            return cheats.round_grants("cough")
        end
        if shared ~= nil then return shared end
        return wears
    end

    local function caught_from(m)
        local me = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
        if me == nil or m == nil or m.pos == nil then return nil end
        if not OF.util.asks(OF.util, "connected_players") then return nil end

        for _, other in ipairs(OF.util.connected_players()) do
            local np = other.np

            if other.localIndex ~= 0 and np ~= nil
                and OF.util.same_world(other.localIndex) then
                local theirs = cheats.coughing(other.localIndex)
                local om = theirs ~= nil and gMarioStates[other.localIndex]
                    or nil
                if om ~= nil and om.pos ~= nil then
                    local dy = (tonumber(m.pos.y) or 0)
                        - (tonumber(om.pos.y) or 0)
                    if dy <= OVER and dy >= -UNDER then
                        local dx = (tonumber(m.pos.x) or 0)
                            - (tonumber(om.pos.x) or 0)
                        local dz = (tonumber(m.pos.z) or 0)
                            - (tonumber(om.pos.z) or 0)
                        if dx * dx + dz * dz < REACH * REACH then
                            return theirs
                        end
                    end
                end
            end
        end
        return nil
    end

    cheats.caught_from = caught_from

    local function take_a_wedge(m, wedges)
        if m == nil or wedges == nil or wedges <= 0 then return end
        m.hurtCounter = math.min(255,
            (tonumber(m.hurtCounter) or 0) + wedges * 4)
    end

    local function say_so()
        if not OF.util.asks(OF.notify, "show") then return end
        OF.notify.show("You have caught it - fill your meter to shake it off.",
            "warn", 5)
    end

    local function cough_now(m)
        if ACT_COUGHING == nil or ACT_IDLE == nil then return end
        if m.action ~= ACT_IDLE then return end
        OF.util.optional("set_mario_action", nil, m, ACT_COUGHING, 0)
    end

    function cheats.cough_tick(m)
        if m == nil then return end

        if (cheats.coughClear or 0) > 0 then
            cheats.coughClear = cheats.coughClear - 1
            if cheats.coughClear <= 0 then cheats.coughClear = nil end
        end

        local level = cheats.level("cough")

        if level <= 0 then
            cheats.coughWait = nil
            if (cheats.coughClear or 0) <= 0 then
                local theirs = caught_from(m)
                if theirs ~= nil and theirs > 0 then
                    local ok = cheats.set_level("cough", theirs)
                    if ok then
                        take_a_wedge(m, cheats.setting("cough", "catch", 1))
                        say_so()
                    end
                end
            end
            return
        end

        if (tonumber(m.health) or 0) >= FULL_HEALTH
            and (tonumber(m.hurtCounter) or 0) == 0 then
            if cheats.set_level("cough", 0) then
                cheats.coughClear = cheats.setting("cough", "clear", 450)
                cheats.coughWait = nil
            end
            return
        end

        cheats.coughWait = (cheats.coughWait or 0) + 1
        if cheats.coughWait >= cheats.setting("cough", "every", 90) then
            cheats.coughWait = 0
            take_a_wedge(m, 1)
            cough_now(m)
        end
    end
end

function cheats.stop_name_at(key, level)
    local entry = cheats.stops_of(key)
    if entry == nil then return nil end
    if type(level) ~= "number" or level <= 0 then return nil end
    local step = (entry.levels or {})[level]
    if step == nil then return nil end
    return step.name
end

function cheats.step_name(key)
    return cheats.stop_name_at(key, cheats.level(key))
end

local function publish()

    local set = {}
    for _, entry in ipairs(cheats.LIST) do
        if cheats.active[entry.key] then

            local stop = 1
            if entry.stopOnWire then
                stop = math.max(1, math.floor(cheats.dialled[entry.key] or 1))
            end
            set[entry.key] = stop
        end
    end
    local chunks = OF.util.chunk_parts(room_parts(set), MINE_CHUNK)

    if chunks == nil or #chunks > #MINE_KEYS then return end

    for index, mineKey in ipairs(MINE_KEYS) do
        OF.util.publish_row(0, mineKey, chunks[index] or "")
    end

    OF.util.publish_row(0, "ofUnseen", cheats.is_on("unseen") == true)

    local own = cheats.active.invisible
    local said = 0
    if own == false then said = -1 elseif own ~= nil then said = 1 end
    OF.util.publish_row(0, "ofInvisible", said)
end

cheats.publish_mine = publish

function cheats.cheats_of(localIndex)
    local packed = OF.util.joined_row(localIndex, MINE_KEYS)
    if packed == "" then return "" end

    local names, known = {}, false
    for piece in string.gmatch(packed, "[^,]+") do
        local key = string.match(piece, "^([^=]+)=%d+$") or piece
        local entry = cheats.find(key)
        if entry ~= nil then
            known = true
            table.insert(names, entry.name)
        end
    end

    if not known then return packed end
    return table.concat(names, ", ")
end

do
    local wornAt, wornSet = {}, {}

    function cheats.worn_set(localIndex)
        local text = OF.util.joined_row(localIndex, MINE_KEYS)
        if wornSet[localIndex] == nil or wornAt[localIndex] ~= text then
            wornAt[localIndex] = text
            wornSet[localIndex] = cheats.room_parse(text)
        end
        return wornSet[localIndex]
    end
end

function cheats.eject_start()
    local m = gMarioStates[0]
    if m == nil then return false end
    local kept = { health = m.health, lives = m.numLives }
    set_mario_action(m, ACT_SPECIAL_DEATH_EXIT, 0)

    cheats.ejectKept = kept
    cheats.ejecting = true
    cheats.ejectLiftOwed = true
    return true
end

cheats.EJECT_EXITS = {}
for _, name in ipairs({ "ACT_DEATH_EXIT", "ACT_FALLING_DEATH_EXIT",
        "ACT_UNUSED_DEATH_EXIT", "ACT_SPECIAL_DEATH_EXIT" }) do
    local id = rawget(_G, name)
    if id ~= nil then cheats.EJECT_EXITS[id] = ACT_SPECIAL_DEATH_EXIT end
end
for _, name in ipairs({ "ACT_EXIT_AIRBORNE", "ACT_FALLING_EXIT_AIRBORNE",
        "ACT_SPECIAL_EXIT_AIRBORNE" }) do
    local id = rawget(_G, name)
    if id ~= nil and ACT_SPECIAL_EXIT_AIRBORNE ~= nil then
        cheats.EJECT_EXITS[id] = ACT_SPECIAL_EXIT_AIRBORNE
    end
end

function cheats.eject_flight(action)
    return action ~= nil and (action == ACT_SPECIAL_DEATH_EXIT
        or (ACT_SPECIAL_EXIT_AIRBORNE ~= nil and action == ACT_SPECIAL_EXIT_AIRBORNE))
end

function cheats.eject_exit(m, action)
    if m == nil or m.playerIndex ~= 0 then return nil end
    local becomes = cheats.EJECT_EXITS[action]
    if becomes == nil then return nil end
    if cheats.is_on("eject") ~= true then return nil end
    if OF.util.asks(OF.lockdown, "menu_stands_down")
            and OF.lockdown.menu_stands_down() then
        return nil
    end

    cheats.ejectKept = nil
    cheats.ejecting = true
    cheats.ejectLiftOwed = true
    return becomes
end

local function apply_local(key, value, level)

    if value and type(level) == "number" and level >= 1 then
        cheats.dialled[key] = math.floor(level)
    end

    if value and key == "giant" then cheats.active.tiny = nil end
    if value and key == "tiny" then cheats.active.giant = nil end

    if value and key == "slick" then cheats.active.surefeet = nil end
    if value and key == "surefeet" then cheats.active.slick = nil end

    if value and key == "lowgrav" then cheats.active.heavy = nil end
    if value and key == "heavy" then cheats.active.lowgrav = nil end

    if key == "noclip" then
        local was = cheats.is_on("noclip")
        local willBe = value or cheats.room_on("noclip")
        if willBe and not was then
            local mayHave, why = OF.util.enter_mode("noclip")
            if not mayHave then return false, why end
        elseif was and not willBe then
            cheats.active[key] = nil
            OF.util.leave_mode("noclip")
        end
    end

    cheats.active[key] = value and true or false

    if key == "giant" or key == "tiny" then cheats.apply_scale() end

    if key == "secondchance" and value then cheats.chanceSpent = false end

    if not value then
        if key == "coinsize" then

            cheats.coinScale = nil
            cheats.apply_scale()
        elseif key == "coinrun" then

            cheats.coinSpeed = nil
        elseif key == "stompchain" then

            cheats.stompChain = nil

            cheats.healOwed = nil
        elseif key == "regen" then

            cheats.regenWait = nil

            cheats.healOwed = nil
            cheats.touchWait = nil
        end
    end

    publish()
    return true
end

function cheats.round_holds(key)
    if OF.lockdown == nil or OF.lockdown.menu_stands_down == nil then
        return false
    end
    return OF.lockdown.menu_stands_down() == true
end

local function round_refuses(key, value)
    if not value then return false end
    return cheats.round_holds(key)
end

function cheats.suspended(key)
    if not cheats.round_holds(key) then return false end

    return (cheats.in_force(key, true)) > 0 and (cheats.in_force(key)) == 0
end

function cheats.round_refusal(key, value)
    if not round_refuses(key, value) then return nil end
    return "A round is on - cheats are put away until it ends."
end

function cheats.set_local(key, value, level)
    local entry = cheats.find(key)
    if entry == nil then

        if cheats.GRANTED[key] ~= nil then
            return false, "That is a powerup now - hand it over from Powerups."
        end
        return false, "No such cheat."
    end
    local roundSaysNo = cheats.round_refusal(key, value)
    if roundSaysNo ~= nil then return false, roundSaysNo end
    return apply_local(key, value, level)
end

function cheats.set_level(key, level)
    local entry = cheats.find(key)
    if entry == nil then return false, "No such cheat." end
    if type(level) ~= "number" then return false, "That is not a setting." end
    level = math.floor(level)

    if level <= 0 then return cheats.set_mine(key, false) end
    if level > cheats.step_count(entry) then
        return false, "That cheat only has " .. cheats.step_count(entry)
            .. " setting(s)."
    end
    local ok, why = cheats.set_local(key, true, level)

    if ok then
        cheats.settle_mine(key)
        cheats.publish_mine()
    end
    return ok, why
end

function cheats.cycle_local(key)
    local entry = cheats.find(key)
    if entry == nil then return false, "No such cheat." end
    local next = cheats.level(key) + 1
    if next > cheats.step_count(entry) then next = 0 end
    return cheats.set_level(key, next)
end

function cheats.put_back(key)
    if cheats.find(key) == nil then return false end
    return apply_local(key, true)
end

function cheats.toggle_local(key)
    return cheats.set_local(key, not cheats.is_on(key))
end

function cheats.mine_state(key)
    local held = cheats.active[key]
    if held == nil then return nil end
    local roomLevel = cheats.room_level(key)
    if held == false then

        if roomLevel == nil then return nil end
        return false
    end

    local steps = cheats.step_count(cheats.find(key))
    if roomLevel ~= nil and steps <= 1 then
        local mine = OF.util.clamp(cheats.dialled[key] or 1, 1, steps)
        if mine == roomLevel then return nil end
    end
    return true
end

function cheats.settle_mine(key)
    if cheats.mine_state(key) == nil then cheats.active[key] = nil end
end

function cheats.set_mine(key, state)
    if cheats.find(key) == nil then return false, "No such cheat." end

    if key == "inputs" and OF.util.asks(OF.tas, "pad_follows") then
        OF.tas.pad_follows(state == true)
    end
    if state == nil then
        cheats.active[key] = nil

        if key == "giant" or key == "tiny" then cheats.apply_scale() end
        if key == "noclip" and not cheats.is_on("noclip") then
            OF.util.leave_mode("noclip")
        end
        cheats.publish_mine()
        return true
    end
    local ok, why = cheats.set_local(key, state == true)
    if ok then
        cheats.settle_mine(key)
        cheats.publish_mine()
    end
    return ok, why
end

function cheats.clear_local()
    cheats.active = {}

    cheats.forget_swings()

    cheats.dialled = {}

    cheats.coinScale = nil
    cheats.coinSpeed = nil

    cheats.aliveSince = nil
    cheats.aliveDeaths = nil

    cheats.timedSize = nil

    cheats.bonkSpeed = nil

    cheats.stompChain = nil

    cheats.regenWait = nil

    cheats.healOwed = nil
    cheats.touchWait = nil

    cheats.finsBank = nil
    cheats.apply_scale()
    publish()
end

cheats.coinScale = cheats.coinScale or nil

cheats.aliveSince = cheats.aliveSince or nil

cheats.aliveDeaths = cheats.aliveDeaths or nil

function cheats.alive_scale()
    local per = cheats.setting("giant", "per", nil)
    local since = cheats.aliveSince
    if type(per) ~= "number" or type(since) ~= "number" then return 1.0 end
    local now = OF.util.optional("get_global_timer", nil)

    if type(now) ~= "number" or now <= since then return 1.0 end
    local every = (cheats.setting("giant", "every", 30) or 30) * FRAMES_A_SECOND
    if every < 1 then return 1.0 end
    local steps = math.floor((now - since) / every)
    if steps < 1 then return 1.0 end

    if steps > 64 then steps = 64 end
    local grown = per ^ steps
    local cap = cheats.setting("giant", "cap", 3.6) or 3.6
    if grown > cap then grown = cap end
    return grown
end

function cheats.alive_clock(m)
    if m == nil or m.playerIndex ~= 0 then return end

    if type(cheats.setting("giant", "per", nil)) ~= "number" then
        cheats.aliveSince, cheats.aliveDeaths = nil, nil
        return
    end
    local now = OF.util.optional("get_global_timer", nil)
    if type(now) ~= "number" then return end
    local deaths = nil
    if OF.util.asks(OF.modifiers, "deaths_here") then
        deaths = OF.modifiers.deaths_here()
    end
    if cheats.aliveSince == nil or deaths ~= cheats.aliveDeaths then
        cheats.aliveSince, cheats.aliveDeaths = now, deaths
    end
end

cheats.timedSize = cheats.timedSize or nil

function cheats.timed_size(scale, frames, owner)
    scale, frames = tonumber(scale), tonumber(frames)
    if scale == nil or frames == nil or scale <= 0 or frames <= 0 then return false end
    cheats.timedSize = { scale = scale, left = math.floor(frames), owner = owner or "row" }
    cheats.apply_scale()
    return true
end

function cheats.timed_size_left()
    local t = cheats.timedSize
    return t ~= nil and t.left or 0
end

function cheats.end_timed_size()
    if cheats.timedSize == nil then return false end
    cheats.timedSize = nil
    cheats.apply_scale()
    return true
end

function cheats.timed_scale()
    local t = cheats.timedSize
    if t == nil or t.left <= 0 then return nil end
    if t.owner ~= "mode" and cheats.round_holds("timedsize") then return nil end
    return t.scale
end

function cheats.timed_size_tick()
    local t = cheats.timedSize
    if t == nil then return false end
    if t.owner ~= "mode" and cheats.round_holds("timedsize") then return false end
    t.left = t.left - 1
    if t.left <= 0 then
        cheats.timedSize = nil
        cheats.apply_scale()
        return true
    end
    return false
end

local function personal_scale()
    local timed = cheats.timed_scale()
    if timed ~= nil then return timed end
    local grown = cheats.coinScale or 1.0

    if cheats.round_holds("coinsize") then grown = 1.0 end
    if cheats.is_on("giant") then

        return cheats.setting("giant", "scale", 1.8) * cheats.alive_scale() * grown
    end
    if cheats.is_on("tiny") then
        return cheats.setting("tiny", "scale", 0.45) * grown
    end
    return grown
end

function cheats.publish_scale()
    OF.util.publish_row(0, "ofScale", personal_scale())
end

function cheats.wanted_scale_for(localIndex)
    if OF.modifiers ~= nil then
        if OF.modifiers.is_on("giant") then
            return OF.modifiers.setting("giant", "scale", 1.8)
        end
        if OF.modifiers.is_on("tiny") then
            return OF.modifiers.setting("tiny", "scale", 0.45)
        end
    end
    return cheats.row_scale(localIndex)
end

function cheats.row_scale(localIndex)
    local row = gPlayerSyncTable[localIndex]
    local own = row ~= nil and row.ofScale or nil
    if not (type(own) == "number" and own > 0) or own == 1.0 then
        return 1.0
    end
    if localIndex ~= 0 and OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down(localIndex) then

        local mode = nil
        if OF.util.asks(OF.gamemodes, "current") then mode = OF.gamemodes.current() end
        if mode ~= nil and type(mode.sized_by_round) == "function"
            and mode.sized_by_round(localIndex) == true then
            return own
        end
        return 1.0
    end
    return own
end

function cheats.wanted_scale()
    return cheats.wanted_scale_for(0)
end

function cheats.apply_scale()

    cheats.forget_room_scale()
    cheats.publish_scale()
    for i = 0, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[i]
        if np ~= nil and np.connected then
            cheats.draw_scale(gMarioStates[i])
        end
    end
end

local BASE_HITBOX_RADIUS = 37

local BASE_HITBOX_HEIGHT = 160
local BASE_HITBOX_CROUCH = 100

local SHORT_HITBOX = ACT_FLAG_SHORT_HITBOX or 0x00008000

local squished = {}

local roomStamp = nil
local roomScale = nil

local function room_now()
    if get_global_timer == nil then return nil end
    return get_global_timer()
end

local function room_answers()
    local stamp = room_now()
    if stamp ~= nil and stamp == roomStamp then return end

    roomScale = false
    if OF.modifiers ~= nil then
        if OF.modifiers.is_on("giant") then
            roomScale = OF.modifiers.setting("giant", "scale", 1.8)
        elseif OF.modifiers.is_on("tiny") then
            roomScale = OF.modifiers.setting("tiny", "scale", 0.45)
        end
    end

    roomStamp = stamp
end

local function shape_of(localIndex)
    if not OF.util.asks(OF.theme, "drawn_shape") then return 1, 1, 1 end
    return OF.theme.drawn_shape(localIndex)
end

function cheats.forget_room_scale()
    roomStamp = nil
end

function cheats.draw_scale(m)
    if m == nil or m.marioObj == nil then return end

    local squishing = (m.squishTimer or 0) ~= 0 or (m.bounceSquishTimer or 0) ~= 0
    local engineOwns = (m.squishTimer or 0) == 0xFF
        and (m.bounceSquishTimer or 0) == 0
    local localIndex = m.playerIndex
    if squishing and engineOwns then
        squished[localIndex] = nil
        return
    end

    room_answers()

    local wanted = roomScale
    if not wanted then
        wanted = cheats.row_scale(localIndex)
    end
    local scale = m.marioObj.header.gfx.scale

    if squishing then
        local was = squished[localIndex]
        if was == nil or scale.x ~= was.x or scale.y ~= was.y
            or scale.z ~= was.z then
            local sqx = (scale.x or 1) * wanted
            local sqy = (scale.y or 1) * wanted
            local sqz = (scale.z or 1) * wanted
            scale.x, scale.y, scale.z = sqx, sqy, sqz
            squished[localIndex] = { x = sqx, y = sqy, z = sqz }
        end

    end
    if not squishing then squished[localIndex] = nil end

    if not squishing then
        local shx, shy, shz = shape_of(localIndex)

        if OF.util.asks(OF.powerups, "balloon_shape") then
            local bx, by, bz = OF.powerups.balloon_shape(m)
            shx, shy, shz = shx * bx, shy * by, shz * bz
        end
        local sx = wanted * shx
        local sy = wanted * shy
        local sz = wanted * shz

        if scale.x ~= sx or scale.y ~= sy or scale.z ~= sz then
            scale.x = sx
            scale.y = sy
            scale.z = sz
        end
    end

    local marioObj = m.marioObj
    local reach = 1.0
    if m.playerIndex == 0 and cheats.is_on("reach") then
        reach = cheats.setting("reach", "wide", 1.35)
    end

    local radius = BASE_HITBOX_RADIUS * wanted * reach
    local base = OF.util.has_flag(m.action or 0, SHORT_HITBOX)
        and BASE_HITBOX_CROUCH or BASE_HITBOX_HEIGHT
    local height = base * wanted

    if marioObj.hitboxRadius ~= radius then marioObj.hitboxRadius = radius end
    if marioObj.hitboxHeight ~= height then marioObj.hitboxHeight = height end
end

local HEAD_ABOVE_FEET = FIRST_PERSON_MARIO_HEAD_POS or 120
local HEAD_CROUCHED = FIRST_PERSON_MARIO_HEAD_POS_SHORT or 60

cheats.HEAD_ABOVE_FEET = HEAD_ABOVE_FEET
cheats.HEAD_CROUCHED = HEAD_CROUCHED

function cheats.drawn_height(localIndex)
    room_answers()
    local wanted = roomScale
    if not wanted then
        wanted = cheats.row_scale(localIndex or 0)
    end
    local _, shy = shape_of(localIndex or 0)
    return wanted * (shy or 1)
end

function cheats.eye_height(localIndex, crouch)
    local down = tonumber(crouch) or 0
    if down < 0 then down = 0 end
    local drop = HEAD_ABOVE_FEET - HEAD_CROUCHED
    if down > drop then down = drop end
    return (HEAD_ABOVE_FEET - down) * cheats.drawn_height(localIndex)
end

function cheats.eye_offset(localIndex, crouch)
    local down = tonumber(crouch) or 0
    if down < 0 then down = 0 end
    local drop = HEAD_ABOVE_FEET - HEAD_CROUCHED
    if down > drop then down = drop end
    return cheats.eye_height(localIndex, down) - (HEAD_ABOVE_FEET - down)
end

function cheats.wants_unseen(localIndex)
    if OF.util.asks(OF.spectate, "is_spectating")
        and OF.spectate.is_spectating(localIndex) then
        return false
    end
    if OF.util.asks(OF.possess, "hides_from_world")
        and OF.possess.hides_from_world(localIndex) then
        return true
    end
    local row = gPlayerSyncTable[localIndex]
    return row ~= nil and row.ofUnseen == true
end

function cheats.apply_unseen(m)
    if m == nil then return end
    if cheats.wants_unseen(m.playerIndex) then m.visibleToObjects = false end
end

do
local INVISIBLE = GRAPH_RENDER_INVISIBLE or 16

function cheats.flying(localIndex)

    if localIndex == 0 then return cheats.is_on("noclip") end

    local worn = cheats.worn_set(localIndex)
    local wears = worn ~= nil and worn.noclip ~= nil
    if not wears and not cheats.room_on("noclip")
        and cheats.round_grants("noclip") == nil then
        return false
    end

    if cheats.round_holds("noclip") then
        return cheats.round_grants("noclip") ~= nil
    end

    if cheats.room_on("noclip") then return true end

    return wears
end

function cheats.drawn_invisible(localIndex)
    if localIndex == 0 then return cheats.is_on("invisible") end
    local row = gPlayerSyncTable[localIndex]
    local said = row ~= nil and row.ofInvisible or 0
    local on
    if said == 1 then on = true
    elseif said == -1 then on = false
    else on = cheats.room_on("invisible") end
    if not on then return false end
    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down(localIndex) then
        return false
    end
    return true
end

function cheats.apply_invisible(m)
    if m == nil or m.marioObj == nil then return end
    if not cheats.drawn_invisible(m.playerIndex) then return end
    local node = m.marioObj.header.gfx.node
    if OF.util.has_flag(node.flags, INVISIBLE) then return end
    node.flags = node.flags + INVISIBLE
end

function cheats.apply_flier(m)
    if m == nil then return end

    if m.playerIndex == 0 then return end
    if not cheats.flying(m.playerIndex) then return end
    local obj = m.marioObj
    if obj == nil then return end
    local node = obj.header.gfx.node

    if OF.util.has_flag(node.flags, INVISIBLE) then return end
    node.flags = node.flags + INVISIBLE
end
end

local INTENDED_MAG_FULL = 32

local parked = false

function cheats.owns_step(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    if cheats.is_on("noclip") then return true end
    return parked and OF.util.hands_on() ~= nil
end

local function noclip_holds(m)
    if cheats.owns_step(m) then return true end
    parked = false
    return false
end

local function noclip_step(m, stepType, stepArg)
    if not noclip_holds(m) then return nil end
    if not cheats.is_on("noclip") then

        m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
        m.forwardVel = 0
        if m.marioObj ~= nil then
            vec3f_copy(m.marioObj.header.gfx.pos, m.pos)
        end
        if stepType == STEP_TYPE_GROUND then return GROUND_STEP_NONE end
        return AIR_STEP_NONE
    end

    local down = m.controller.buttonDown or 0
    local mag = OF.util.clamp((m.intendedMag or 0) / INTENDED_MAG_FULL, 0, 1)
    local speed = OF.util.fly_speed(down) * mag

    if mag > 0 then
        m.pos.x = m.pos.x + speed * sins(m.intendedYaw)
        m.pos.z = m.pos.z + speed * coss(m.intendedYaw)
    end
    m.pos.y = m.pos.y + OF.util.fly_lift(down)

    m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
    m.forwardVel = 0

    if m.marioObj ~= nil then
        vec3f_copy(m.marioObj.header.gfx.pos, m.pos)
    end

    if stepType == STEP_TYPE_GROUND then return GROUND_STEP_NONE end
    return AIR_STEP_NONE
end

hook_event(HOOK_BEFORE_PHYS_STEP, noclip_step)

function cheats.keep_warp_floor(m)
    if m == nil or m.pos == nil or find_floor == nil then return false end
    local _, floor = find_floor(m.pos.x, m.pos.y, m.pos.z)
    if floor == nil then return false end
    m.floor = floor
    return true
end

hook_event(HOOK_MARIO_OVERRIDE_GEOMETRY_INPUTS, function(m)
    if not noclip_holds(m) then return end
    cheats.keep_warp_floor(m)
    return false
end)

function cheats.noclip_hints()
    if not cheats.is_on("noclip") then return false end
    if OF.util.asks(OF.camera, "active") and OF.camera.active() then return false end
    if OF.util.asks(OF.camera, "controls_shown") and not OF.camera.controls_shown() then return false end
    local H = OF.hud
    if H == nil or type(H.hints) ~= "function" or OF.camera.FLY_HINTS == nil then return false end

    return H.hints(OF.camera.FLY_HINTS, { y = OF.hud.corner_hint_y() }) > 0
end
hook_event(HOOK_ON_HUD_RENDER, function()
    cheats.noclip_hints()

    if OF.util.asks(OF.ball, "ride_hints") then OF.ball.ride_hints() end
end)

function cheats.mode_live()
    return cheats.is_on("noclip")
end

function cheats.mode_suspend()
    if not cheats.is_on("noclip") then return false end
    if cheats.set_local("noclip", false) ~= true then return false end
    parked = true
    return true
end

function cheats.mode_resume()
    parked = false
    if cheats.is_on("noclip") then return true end

    return cheats.set_local("noclip", true) == true
end

local HAZARD_HURTS = {
    [HAZARD_TYPE_LAVA_FLOOR] = true,
    [HAZARD_TYPE_LAVA_WALL] = true,
    [HAZARD_TYPE_QUICKSAND] = true,
}

hook_event(HOOK_ALLOW_HAZARD_SURFACE, function(m, hazardType)
    if m == nil or m.playerIndex ~= 0 then return end

    if hazardType == HAZARD_TYPE_HORIZONTAL_WIND
        or hazardType == HAZARD_TYPE_VERTICAL_WIND then

        if cheats.is_on("windproof") then return false end
        return
    end

    if (cheats.is_on("nolava")
        or cheats.setting("gasmask", "lava", false) == true)
        and (hazardType == HAZARD_TYPE_LAVA_FLOOR
             or hazardType == HAZARD_TYPE_LAVA_WALL) then
        return false
    end
    if cheats.is_on("godmode") or cheats.is_on("noclip") then return false end
end)

local INTERACT_REFUSALS = {}
do

    local pairsList = {
        { INTERACT_FLAME, "noflame" },
        { INTERACT_SHOCK, "noshock" },
        { INTERACT_TORNADO, "notwister" },

        { INTERACT_WHIRLPOOL, "notwister" },

        { INTERACT_STRONG_WIND, "windproof" },
        { INTERACT_CLAM_OR_BUBBA, "nobite" },
    }
    for i = 1, 6 do
        local one = pairsList[i]
        if one ~= nil and one[1] ~= nil then INTERACT_REFUSALS[one[1]] = one[2] end
    end
end

hook_event(HOOK_ALLOW_INTERACT, function(m, obj, interactType)
    if m == nil or m.playerIndex ~= 0 then return end
    local key = INTERACT_REFUSALS[interactType]
    if key ~= nil and cheats.is_on(key) then return false end
end)

do

local BOX_KEY = "ofNoBoxes"
cheats.BOX_KEY = BOX_KEY

local MAX_SUPPRESSED = 16

cheats.lastDialogSeen = cheats.lastDialogSeen or nil

local function suppressed_list()
    local text = gGlobalSyncTable[BOX_KEY]
    if type(text) ~= "string" or text == "" then return {} end
    local list = {}
    for piece in string.gmatch(text, "[^,]+") do
        local id = tonumber(piece)
        if id ~= nil then table.insert(list, math.floor(id)) end
    end
    return list
end

cheats.suppressed_boxes = suppressed_list

function cheats.box_is_suppressed(dialogId)
    if type(dialogId) ~= "number" then return false end

    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() then
        return false
    end
    for _, id in ipairs(suppressed_list()) do
        if id == dialogId then return true end
    end
    return false
end

function cheats.box_preview(dialogId)
    if type(dialogId) ~= "number" then return nil end
    local entry = OF.util.optional("smlua_text_utils_dialog_get", nil, dialogId)
    local text = entry ~= nil and entry.text or nil
    if type(text) ~= "string" or text == "" then return nil end

    text = text:gsub("[\n\r]", " ")
    return OF.util.shorten(text, 40)
end

local function publish_boxes(list)
    table.sort(list)
    local parts = {}
    for _, id in ipairs(list) do table.insert(parts, tostring(id)) end
    return OF.util.publish(BOX_KEY, table.concat(parts, ","))
end

hook_on_sync_table_change(gGlobalSyncTable, BOX_KEY, BOX_KEY, function()
    if OF.util.asks(OF.guard, "repair") and OF.guard.repair(BOX_KEY) then
        return
    end
end)

local registered = false
local function register_box_requests()
    if registered then return end
    if not OF.util.asks(OF.net, "register_action") then return end
    registered = true
    OF.net.register_action("noboxadd", "cheats_lobby", function(_, id)
        if not OF.util.is_host() then return false, "Only the host." end
        return cheats.suppress_box(id)
    end)
    OF.net.register_action("noboxdel", "cheats_lobby", function(_, id)
        if not OF.util.is_host() then return false, "Only the host." end
        return cheats.unsuppress_box(id)
    end)
end

function cheats.suppress_box(dialogId)
    dialogId = math.floor(tonumber(dialogId) or -1)
    if dialogId < 0 then return false, "That is not a box." end
    if not OF.perms.can("cheats_lobby") then
        return false, "Your rank cannot change this lobby's boxes. ("
            .. OF.perms.tier_name(OF.perms.required("cheats_lobby")) .. "+)"
    end
    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() then
        return false, "A round is on - try again when it ends."
    end
    register_box_requests()
    if not OF.util.is_host() then
        if OF.util.asks(OF.net, "host_does") then
            return OF.net.host_does("noboxadd", dialogId)
        end
        return false, "No host to ask yet - try again in a second."
    end
    local list = suppressed_list()
    for _, id in ipairs(list) do
        if id == dialogId then return true end
    end
    if #list >= MAX_SUPPRESSED then
        return false, "This lobby already has " .. MAX_SUPPRESSED
            .. " boxes suppressed - take one off first."
    end
    table.insert(list, dialogId)
    return publish_boxes(list)
end

function cheats.unsuppress_box(dialogId)
    dialogId = math.floor(tonumber(dialogId) or -1)
    if not OF.perms.can("cheats_lobby") then
        return false, "Your rank cannot change this lobby's boxes. ("
            .. OF.perms.tier_name(OF.perms.required("cheats_lobby")) .. "+)"
    end
    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() then
        return false, "A round is on - try again when it ends."
    end
    register_box_requests()
    if not OF.util.is_host() then
        if OF.util.asks(OF.net, "host_does") then
            return OF.net.host_does("noboxdel", dialogId)
        end
        return false, "No host to ask yet - try again in a second."
    end
    local list = suppressed_list()
    local kept = {}
    for _, id in ipairs(list) do
        if id ~= dialogId then table.insert(kept, id) end
    end
    return publish_boxes(kept)
end

end

hook_event(HOOK_ON_DIALOG, function(dialogId)
    cheats.lastDialogSeen = dialogId
    local blanket = cheats.is_on("nodialog")
    local named = cheats.box_is_suppressed(dialogId)
    if not blanket and not named then return end
    if OF.util.asks(OF.lockdown, "dialog_is_a_response")
        and OF.lockdown.dialog_is_a_response(dialogId) then
        return
    end
    return false
end)

function cheats.build_box_page(panel)
    local rows = {}
    table.insert(rows, panel.label_row(OF.lang.t(
        "Specific boxes this lobby never shows - everything else still opens.")))

    local last = cheats.lastDialogSeen
    if last == nil then
        table.insert(rows, panel.label_row(OF.lang.t(
            "Walk up to the box you want gone - the last one you see is what this remembers.")))
    elseif cheats.box_is_suppressed(last) then
        table.insert(rows, panel.label_row(OF.lang.t(
            "The last box you saw is already on this list.")))
    else
        local preview = cheats.box_preview(last)
            or OF.lang.fill("box #@", tostring(last))
        table.insert(rows, panel.host_row("cheats_lobby",
            OF.lang.t("Suppress the last box you saw") .. ": " .. preview,
            255, 255, 255, function()
                OF.util.report(cheats.suppress_box(last))
            end, panel.ask_host(cheats.BOX_ON_ACTION, last)))
    end

    local list = cheats.suppressed_boxes()
    if #list == 0 then
        table.insert(rows, panel.label_row(OF.lang.t("Nothing on the list yet.")))
    else
        table.insert(rows, panel.sub_header_row(OF.lang.t("On the list")))

        for _, id in ipairs(list) do
            local preview = cheats.box_preview(id)
                or OF.lang.fill("box #@", tostring(id))
            table.insert(rows, panel.host_row("cheats_lobby",
                OF.lang.t("Remove") .. ": " .. preview, 255, 255, 255,
                function() OF.util.report(cheats.unsuppress_box(id)) end,
                panel.ask_host(cheats.BOX_OFF_ACTION, id)))
        end
    end

    table.insert(rows, panel.back_row())
    return rows
end

cheats.BOX_ON_ACTION = "boxon"
cheats.BOX_OFF_ACTION = "boxoff"
hook_event(HOOK_ON_MODS_LOADED, function()
    if OF.util.asks(OF.net, "register_cohost_action") then
        OF.net.register_cohost_action(cheats.BOX_ON_ACTION, "cheats_lobby", function(_, x)
            local id = tonumber(x)
            if id == nil then return false, "No box to put on the list." end
            return cheats.suppress_box(id)
        end)
        OF.net.register_cohost_action(cheats.BOX_OFF_ACTION, "cheats_lobby", function(_, x)
            local id = tonumber(x)
            if id == nil then return false, "No box to take off the list." end
            return cheats.unsuppress_box(id)
        end)
    end
    local panel = OF.panel
    if panel == nil or type(panel.PAGES) ~= "table" then return end
    if panel.PAGES.cheatboxes == nil then
        panel.PAGES.cheatboxes = {
            title = "Boxes this lobby never shows", tab = "room", up = "cheats",
            build = function() return cheats.build_box_page(panel) end,
        }
    end
end)

hook_event(HOOK_ON_SCREEN_TRANSITION, function()
    if cheats.is_on("nofade") then return false end
end)

local WATER_CAMERA_MODES = {}
do
    local list = { CAMERA_MODE_CLOSE, CAMERA_MODE_BEHIND_MARIO,
                   CAMERA_MODE_WATER_SURFACE }
    for i = 1, 3 do
        if list[i] ~= nil then WATER_CAMERA_MODES[list[i]] = true end
    end
end

hook_event(HOOK_ON_SET_CAMERA_MODE, function(c, mode)
    if not cheats.is_on("keepcam") then return end

    local m = gMarioStates[0]
    if m == nil then return end
    local wet = OF.util.has_flag(m.action, ACT_FLAG_SWIMMING)
        or OF.util.has_flag(m.action, ACT_FLAG_METAL_WATER)
    if not wet then return end
    if WATER_CAMERA_MODES[mode] then return false end
end)

hook_event(HOOK_MARIO_OVERRIDE_FLOOR_CLASS, function(m, floorClass)
    if m == nil or m.playerIndex ~= 0 then return end
    local sure = cheats.is_on("surefeet")
    local slick = cheats.is_on("slick")
    if not sure and not slick then return end
    if OF.util.asks(OF.modifiers, "is_on") and OF.modifiers.is_on("floor") then return end
    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() then return end

    if sure then return SURFACE_CLASS_NOT_SLIPPERY end
    return SURFACE_CLASS_VERY_SLIPPERY
end)

hook_event(HOOK_ON_DEATH, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if cheats.is_on("godmode") or cheats.is_on("noclip") then return false end
    if cheats.catch_the_drop(m) then return false end
end)

hook_event(HOOK_ALLOW_FORCE_WATER_ACTION, function(m, isInWaterAction)
    if m == nil or m.playerIndex ~= 0 then return end
    if isInWaterAction then return end
    if cheats.is_on("sealegs") then return false end
end)

hook_event(HOOK_CHARACTER_SOUND, function(m)
    if m == nil then return end

    if m.playerIndex ~= 0 then
        if OF.util.asks(OF.roundscope, "mutes_voice") and OF.roundscope.mutes_voice(m) then
            return 0
        end
        return
    end
    if not cheats.is_on("vow") then return end
    return 0
end)

local COIN_KINDS = {}
do
    local pairsList = { id_bhvYellowCoin, id_bhvSingleCoinGetsSpawned,
        id_bhvRedCoin, id_bhvHiddenBlueCoin, id_bhvBlueCoinSliding,
        id_bhvBlueCoinJumping, id_bhvMovingYellowCoin, id_bhvMovingBlueCoin }
    for i = 1, 8 do
        local one = pairsList[i]
        if one ~= nil then COIN_KINDS[#COIN_KINDS + 1] = one end
    end
end

function cheats.pull_coins(m)
    if not cheats.is_on("magnet") then return false end
    if m == nil or m.pos == nil then return false end
    if obj_get_first_with_behavior_id == nil then return false end

    local far = cheats.setting("magnet", "reach", NUMBERS.magnetReach)
    local reach = far * far
    local close = NUMBERS.magnetClose * NUMBERS.magnetClose
    local pull = cheats.setting("magnet", "pull", NUMBERS.magnetPull)
    local moved = 0

    for _, kind in ipairs(COIN_KINDS) do
        local coin = obj_get_first_with_behavior_id(kind)
        while coin ~= nil do
            local dx = m.pos.x - (coin.oPosX or 0)
            local dy = m.pos.y - (coin.oPosY or 0)
            local dz = m.pos.z - (coin.oPosZ or 0)
            local away = dx * dx + dy * dy + dz * dz
            if away < reach and away > close then
                coin.oPosX = (coin.oPosX or 0) + dx * pull
                coin.oPosY = (coin.oPosY or 0) + dy * pull
                coin.oPosZ = (coin.oPosZ or 0) + dz * pull

                coin.oVelY = 0
                moved = moved + 1
            end
            coin = obj_get_next_with_same_behavior_id(coin)
        end
    end

    return moved > 0
end

cheats.starHomes = cheats.starHomes or {}

local function star_key(star)
    if star == nil then return nil end
    local params = tonumber(star.oBehParams)
    if params == nil then return nil end
    return tostring(math.floor(params))
end

function cheats.forget_star_homes()
    cheats.starHomes = {}
    return true
end

function cheats.star_home(star)
    local key = star_key(star)
    if key == nil then return nil end
    return cheats.starHomes[key]
end

function cheats.wire_match()
    return NUMBERS.starWireMatch
end

function cheats.pull_venue_stars(m, on, reach, close, pull)
    local venues = OF.venues
    local list = venues ~= nil and venues.starObjects or nil
    if type(list) ~= "table" or next(list) == nil then return false end
    local moved = 0
    for _, star in pairs(list) do
        if star ~= nil and OF.util.alive(star) and star.activeFlags ~= 0 then
            local hx = (star.oHomeX or star.oPosX or 0)
            local hy = (star.oHomeY or star.oPosY or 0)
            local hz = (star.oHomeZ or star.oPosZ or 0)
            local ax, ay, az = m.pos.x - hx, m.pos.y - hy, m.pos.z - hz
            if on and ax * ax + ay * ay + az * az < reach then
                local dx = m.pos.x - (star.oPosX or 0)
                local dy = m.pos.y - (star.oPosY or 0)
                local dz = m.pos.z - (star.oPosZ or 0)
                if dx * dx + dy * dy + dz * dz > close then
                    star.oPosX = (star.oPosX or 0) + dx * pull
                    star.oPosY = (star.oPosY or 0) + dy * pull
                    star.oPosZ = (star.oPosZ or 0) + dz * pull
                    moved = moved + 1
                end
            elseif star.oPosX ~= hx or star.oPosY ~= hy or star.oPosZ ~= hz then
                star.oPosX, star.oPosY, star.oPosZ = hx, hy, hz
                moved = moved + 1
            end
        end
    end
    return moved > 0
end

function cheats.pull_stars(m)
    if m == nil or m.pos == nil then return false end

    local venueOn = cheats.is_on("starmagnet")
    local venueFar = cheats.setting("starmagnet", "reach", NUMBERS.starReach)
    local venueMoved = cheats.pull_venue_stars(m, venueOn, venueFar * venueFar,
        NUMBERS.starClose * NUMBERS.starClose,
        cheats.setting("starmagnet", "pull", NUMBERS.starPull))

    if obj_get_first_with_behavior_id == nil then return venueMoved end
    if id_bhvStar == nil then return venueMoved end

    local on = venueOn
    if not on and next(cheats.starHomes) == nil then return venueMoved end

    local far = cheats.setting("starmagnet", "reach", NUMBERS.starReach)
    local reach = far * far
    local close = NUMBERS.starClose * NUMBERS.starClose
    local pull = cheats.setting("starmagnet", "pull", NUMBERS.starPull)
    local moved = 0
    local holding = false

    local star = obj_get_first_with_behavior_id(id_bhvStar)
    while star ~= nil do
        local key = star_key(star)
        local home = key ~= nil and cheats.starHomes[key] or nil

        if on and home == nil and key ~= nil then
            home = { x = star.oPosX or 0, y = star.oPosY or 0, z = star.oPosZ or 0 }
            cheats.starHomes[key] = home
        end

        if home ~= nil then

            local hx = m.pos.x - home.x
            local hy = m.pos.y - home.y
            local hz = m.pos.z - home.z
            if on and hx * hx + hy * hy + hz * hz < reach then

                holding = true

                local dx = m.pos.x - (star.oPosX or 0)
                local dy = m.pos.y - (star.oPosY or 0)
                local dz = m.pos.z - (star.oPosZ or 0)
                if dx * dx + dy * dy + dz * dz > close then

                    star.oPosX = (star.oPosX or 0) + dx * pull
                    star.oPosY = (star.oPosY or 0) + dy * pull
                    star.oPosZ = (star.oPosZ or 0) + dz * pull
                    moved = moved + 1
                end
            elseif star.oPosX ~= home.x or star.oPosY ~= home.y
                or star.oPosZ ~= home.z then

                star.oPosX, star.oPosY, star.oPosZ = home.x, home.y, home.z
                moved = moved + 1
            end
        end

        star = obj_get_next_with_same_behavior_id(star)
    end

    if not holding then cheats.starHomes = {} end

    if not on then return moved > 0 or venueMoved end
    return cheats.pull_dropped_stars(m, reach, close, pull) or moved > 0 or venueMoved
end

local starSent = nil

function cheats.star_back_from_the_wire()
    local one = starSent
    starSent = nil
    if one == nil or one.obj == nil then return false end
    if one.obj.oPosX ~= one.homeX or one.obj.oPosY ~= one.homeY
        or one.obj.oPosZ ~= one.homeZ then return false end
    one.obj.oPosX, one.obj.oPosY, one.obj.oPosZ = one.x, one.y, one.z
    return true
end

function cheats.star_to_the_wire(m, obj, interactType)
    cheats.star_back_from_the_wire()
    if interactType ~= INTERACT_STAR_OR_KEY then return end

    if m == nil or m.playerIndex ~= 0 then return end
    if obj == nil or id_bhvStar == nil then return end

    if OF.util.optional("obj_has_behavior_id", 0, obj, id_bhvStar) == 0 then return end
    local home = cheats.star_home(obj)
    if home == nil then return end
    if obj.oPosX == home.x and obj.oPosY == home.y and obj.oPosZ == home.z then return end
    starSent = { obj = obj, x = obj.oPosX, y = obj.oPosY, z = obj.oPosZ,
                 homeX = home.x, homeY = home.y, homeZ = home.z }
    obj.oPosX, obj.oPosY, obj.oPosZ = home.x, home.y, home.z
end

hook_event(HOOK_ALLOW_INTERACT, cheats.star_to_the_wire)
hook_event(HOOK_ON_INTERACT, cheats.star_back_from_the_wire)

local DROPPED_STAR_KINDS = {}
do
    local pairsList = { id_bhvStarSpawnCoordinates, id_bhvSpawnedStar,
        id_bhvGrandStar, id_bhvSpawnedStarNoLevelExit }
    for i = 1, 4 do
        local one = pairsList[i]
        if one ~= nil then DROPPED_STAR_KINDS[#DROPPED_STAR_KINDS + 1] = one end
    end
end

function cheats.pull_dropped_stars(m, reach, close, pull)
    local moved = 0
    for _, kind in ipairs(DROPPED_STAR_KINDS) do
        local star = obj_get_first_with_behavior_id(kind)
        while star ~= nil do

            local mine = OF.util.optional("sync_object_is_owned_locally", false,
                star.oSyncID or 0) == true
            if mine then

                local dx = m.pos.x - (star.oPosX or 0)
                local dy = m.pos.y - (star.oPosY or 0)
                local dz = m.pos.z - (star.oPosZ or 0)
                local away = dx * dx + dy * dy + dz * dz
                if away < reach and away > close then
                    star.oPosX = (star.oPosX or 0) + dx * pull
                    star.oPosY = (star.oPosY or 0) + dy * pull
                    star.oPosZ = (star.oPosZ or 0) + dz * pull
                    moved = moved + 1
                end
            end
            star = obj_get_next_with_same_behavior_id(star)
        end
    end

    return moved > 0
end

cheats.footing = nil
cheats.fell = false

local function is_a_killing_floor(kind)
    if kind == nil then return false end
    return kind == SURFACE_DEATH_PLANE or kind == SURFACE_VERTICAL_WIND
end

function cheats.remember_footing(m)
    if not cheats.is_on("backstop") then
        cheats.footing = nil
        return false
    end
    if m == nil or m.pos == nil then return false end
    if m.floor == nil then return false end
    if OF.util.has_flag(m.action or 0, ACT_FLAG_AIR) then return false end
    if OF.util.has_flag(m.action or 0, ACT_FLAG_SWIMMING) then return false end
    if m.pos.y > (m.floorHeight or 0) + 40 then return false end

    if is_a_killing_floor(m.floor.type) then return false end

    cheats.footing = { x = m.pos.x, y = m.pos.y, z = m.pos.z }
    return true
end

function cheats.catch_them(m)
    if not cheats.fell then
        cheats.remember_footing(m)
        return false
    end
    cheats.fell = false

    local back = cheats.footing
    if not cheats.is_on("backstop") or back == nil then return false end
    if m == nil or m.pos == nil then return false end

    m.pos.x, m.pos.y, m.pos.z = back.x, back.y, back.z
    m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
    m.forwardVel = 0

    m.peakHeight = back.y

    local obj = m.marioObj
    if obj ~= nil then
        obj.oPosX, obj.oPosY, obj.oPosZ = back.x, back.y, back.z
        obj.oVelX, obj.oVelY, obj.oVelZ = 0, 0, 0
        if obj.header ~= nil and obj.header.gfx ~= nil
            and obj.header.gfx.pos ~= nil then
            obj.header.gfx.pos.x = back.x
            obj.header.gfx.pos.y = back.y
            obj.header.gfx.pos.z = back.z
        end

        OF.util.skip_interpolation(obj)
    end
    return true
end

function cheats.note_the_edge(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if not cheats.is_on("backstop") then return end
    cheats.fell = true
end

hook_event(HOOK_ON_COLLIDE_LEVEL_BOUNDS, cheats.note_the_edge)

function cheats.catch_the_drop(m)
    if not cheats.is_on("backstop") then return false end
    if m == nil or m.playerIndex ~= 0 then return false end
    if m.floor == nil then return false end
    if not is_a_killing_floor(m.floor.type) then return false end
    if cheats.footing == nil then return false end
    cheats.fell = true
    return true
end

cheats.BLAST_MARK = 6220

local BLAST_SEATS = 100

function cheats.blast_stamp(seat)
    return cheats.BLAST_MARK * BLAST_SEATS + (seat or 0) + 1
end

function cheats.blast_seat_of(obj)
    if obj == nil then return nil end
    local stamp = obj.oBehParams2ndByte
    if type(stamp) ~= "number" then return nil end
    if math.floor(stamp / BLAST_SEATS) ~= cheats.BLAST_MARK then return nil end
    return (stamp % BLAST_SEATS) - 1
end

function cheats.blast_stop_for(m)
    if m == nil then return nil end

    local function blast_step(level)
        if type(level) ~= "number" or level <= 0 then return nil end
        local entry = cheats.stops_of("blast")
        local step = entry ~= nil and (entry.levels or {})[level] or nil
        if step == nil then return nil end
        return step.count or 1, step.spread or 0
    end

    local seat = m.playerIndex or 0
    if seat == 0 then
        if not cheats.is_on("blast") then return nil end
        return cheats.setting("blast", "count", 1),
            cheats.setting("blast", "spread", 0)
    end

    if cheats.round_holds("blast") then
        return blast_step(cheats.round_grants("blast"))
    end

    local level = nil
    if OF.util.asks(cheats, "worn_set") then
        level = (cheats.worn_set(seat) or {})["blast"]
    end
    if level == nil then level = cheats.room_level("blast") end
    return blast_step(level)
end

local blastWas = {}

function cheats.watch_the_swing(m)
    if m == nil then return false end
    local seat = m.playerIndex or 0
    local was = blastWas[seat]
    blastWas[seat] = m.action

    if BLAST_ACTIONS[m.action] ~= true then return false end
    if was == m.action then return false end

    local count, spread = cheats.blast_stop_for(m)
    if count == nil then return false end
    return cheats.blow_up_around(m, count, spread) ~= false
end

function cheats.forget_swings()
    for key in pairs(blastWas) do blastWas[key] = nil end
    return true
end

cheats.SNIPER_REACH = 20000

cheats.MARIO_RADIUS = 37
cheats.SNIPER_ASSIST = 33

local rifleReadyAt = -9999
local rifleAiming = false

function cheats.forget_the_rifle()
    rifleReadyAt = -9999
    rifleAiming = false
    return true
end

function cheats.rifle_is_aimed()
    return rifleAiming
end

function cheats.rifle_cooldown()
    local now = OF.util.optional("get_global_timer", 0) or 0
    local left = rifleReadyAt - now
    if left < 0 then return 0 end
    return left
end

function cheats.rifle_target(ex, ey, ez, dx, dy, dz)
    if type(ex) ~= "number" or type(dx) ~= "number" then return nil end

    local ownAlong = nil
    local own = gMarioStates[0]
    if own ~= nil and own.pos ~= nil then
        ownAlong = (own.pos.x - ex) * dx + (own.pos.y - ey) * dy
            + (own.pos.z - ez) * dz
    end

    local best, bestAt = nil, nil
    for _, entry in ipairs(OF.util.connected_players()) do
        local seat = entry.localIndex
        if seat ~= 0 then
            local o = gMarioStates[seat]
            local live = OF.util.optional("is_player_active", 0, o)

            if o ~= nil and o.pos ~= nil and live ~= 0
                and OF.util.can_play(seat) then
                local px = o.pos.x - ex
                local py = o.pos.y - ey
                local pz = o.pos.z - ez
                local along = px * dx + py * dy + pz * dz
                if along > 0 and along <= cheats.SNIPER_REACH
                    and (ownAlong == nil or along >= ownAlong) then

                    local cx = px - dx * along
                    local cz = pz - dz * along
                    local off = math.sqrt(cx * cx + cz * cz)

                    local cy = ey + along * dy
                    if off <= (cheats.MARIO_RADIUS + cheats.SNIPER_ASSIST)
                        and cy >= o.pos.y - 10 and cy <= o.pos.y + 170
                        and (bestAt == nil or along < bestAt) then
                        best, bestAt = entry, along
                    end
                end
            end
        end
    end
    if best == nil then return nil end

    local wall = OF.util.optional("collision_find_surface_on_ray", nil,
        ex, ey, ez, dx * bestAt, dy * bestAt, dz * bestAt)
    if wall ~= nil and wall.surface ~= nil and wall.hitPos ~= nil then
        local hx = wall.hitPos.x - ex
        local hy = wall.hitPos.y - ey
        local hz = wall.hitPos.z - ez
        local toWall = math.sqrt(hx * hx + hy * hy + hz * hz)
        if toWall < bestAt - 1 then return nil end
    end
    return best, bestAt
end

function cheats.muzzle_of(m, ex, ey, ez)
    if m == nil then return ex, ey, ez end
    local hx = OF.util.optional("get_hand_foot_pos_x", nil, m, 0)
    local hy = OF.util.optional("get_hand_foot_pos_y", nil, m, 0)
    local hz = OF.util.optional("get_hand_foot_pos_z", nil, m, 0)
    if type(hx) ~= "number" or type(hy) ~= "number"
        or type(hz) ~= "number" then
        return ex, ey, ez
    end
    return hx, hy, hz
end

function cheats.shot_reaches(ex, ey, ez, dx, dy, dz, along)
    if type(along) == "number" and along > 0 then return along end

    local wall = OF.util.optional("collision_find_surface_on_ray", nil,
        ex, ey, ez, dx * cheats.SNIPER_REACH, dy * cheats.SNIPER_REACH,
        dz * cheats.SNIPER_REACH)
    if wall ~= nil and wall.surface ~= nil and wall.hitPos ~= nil then
        local hx = wall.hitPos.x - ex
        local hy = wall.hitPos.y - ey
        local hz = wall.hitPos.z - ez
        local toWall = math.sqrt(hx * hx + hy * hy + hz * hz)

        if toWall > 1 then return toWall end
    end
    return cheats.SNIPER_REACH
end

function cheats.fire_the_rifle(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    local wait = cheats.setting("sniper", "wait", nil)
    if wait == nil then return false end
    if cheats.rifle_cooldown() > 0 then return false end

    if OF.util.asks(OF.shooter, "rifle_stands_down")
        and OF.shooter.rifle_stands_down() then
        return false
    end

    if not OF.util.asks(OF.util, "view_axis") then return false end
    local ex, ey, ez, dx, dy, dz = OF.util.view_axis()
    if ex == nil then return false end

    local now = OF.util.optional("get_global_timer", 0) or 0
    rifleReadyAt = now + wait

    local hit, along = cheats.rifle_target(ex, ey, ez, dx, dy, dz)

    if OF.util.asks(cheats, "show_a_shot") then

        local mx, my, muzzleZ = cheats.muzzle_of(m, ex, ey, ez)
        local reach = cheats.shot_reaches(ex, ey, ez, dx, dy, dz, along)
        cheats.show_a_shot(mx, my, muzzleZ,
            ex + dx * reach, ey + dy * reach, ez + dz * reach)
    end

    if hit == nil and OF.util.asks(OF.logic, "shot") then
        OF.logic.shot(ex, ey, ez, dx, dy, dz,
            cheats.shot_reaches(ex, ey, ez, dx, dy, dz, along))
    end

    if hit == nil then return true end

    if OF.util.asks(OF.shooter, "put_down")
        and OF.shooter.put_down(hit.np.globalIndex)
        and OF.util.asks(OF.shooter, "credit_a_kill") then
        OF.shooter.credit_a_kill()
    end
    return true
end

local rifleHeldB = false

function cheats.work_the_rifle(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    if not cheats.is_on("sniper") then
        if rifleAiming then rifleAiming = false end
        return false
    end
    local pad = m.controller
    if pad == nil then return false end

    rifleAiming = OF.util.has_flag(pad.buttonDown, L_TRIG)

    local nowB
    if OF.util.asks(OF.input, "aim_held") then
        nowB = OF.input.aim_held(m, B_BUTTON)
    else
        nowB = OF.util.has_flag(pad.buttonDown, B_BUTTON)
    end
    local pressed = nowB and not rifleHeldB
    rifleHeldB = nowB
    if not rifleAiming or not pressed then return false end
    return cheats.fire_the_rifle(m)
end

do

local TRACER_FRAMES = 4
local TRACER_TAIL = 900

local TRACER_FAR = cheats.SNIPER_REACH

local TRACER_WIDTH = 3
local TRACER_MINE_R, TRACER_MINE_G, TRACER_MINE_B = 255, 236, 140
local TRACER_THEIRS_R, TRACER_THEIRS_G, TRACER_THEIRS_B = 130, 200, 255

local TRACER_PACKET = "shot"
local live = {}

local tailAt = { x = 0, y = 0, z = 0 }
local headAt = { x = 0, y = 0, z = 0 }

local function tracer_frame()
    return OF.util.optional("get_global_timer", 0) or 0
end

local function shot_belongs_here(globalIndex)
    local me = gNetworkPlayers[0]
    if me == nil then return false end
    if globalIndex == network_global_index_from_local(0) then return true end
    local li = OF.util.local_from_global(globalIndex)
    if li == nil then return false end
    local np = gNetworkPlayers[li]
    if np == nil then return false end

    return np.currLevelNum == me.currLevelNum
        and np.currAreaIndex == me.currAreaIndex
        and (np.currActNum or 0) == (me.currActNum or 0)
end

local function remember_a_shot(globalIndex, ax, ay, az, bx, by, bz)
    if type(globalIndex) ~= "number" then return false end
    if type(ax) ~= "number" or type(ay) ~= "number" or type(az) ~= "number"
        or type(bx) ~= "number" or type(by) ~= "number"
        or type(bz) ~= "number" then
        return false
    end

    local dx, dy, dz = bx - ax, by - ay, bz - az
    local length = math.sqrt(dx * dx + dy * dy + dz * dz)

    if not (length > 1) then return false end
    if not (length <= TRACER_FAR) then return false end
    if not shot_belongs_here(globalIndex) then return false end

    live[globalIndex] = {
        x = ax, y = ay, z = az,
        ux = dx / length, uy = dy / length, uz = dz / length,
        length = length, at = tracer_frame(),
    }
    return true
end

cheats.tracerDrawn = 0

function cheats.tracer_lines()
    return cheats.tracerDrawn
end

local MARK_FRAMES = 12
local MARK_REACH = 14
local MARK_GAP = 5
local markedAt = -9999

function cheats.mark_a_hit()
    markedAt = tracer_frame()
    return true
end

function cheats.hit_marked()
    if markedAt <= -9999 then return false end
    return (tracer_frame() - markedAt) < MARK_FRAMES
end

function cheats.forget_the_tracers()
    for key in pairs(live) do live[key] = nil end
    markedAt = -9999
    cheats.tracerDrawn = 0
    return true
end

function cheats.show_a_shot(ax, ay, az, bx, by, bz)
    local mine = network_global_index_from_local(0)
    local kept = remember_a_shot(mine, ax, ay, az, bx, by, bz)
    if not kept then return false end

    local wire = { ofp = TRACER_PACKET, gi = mine,
        ax = ax, ay = ay, az = az, bx = bx, by = by, bz = bz }
    if OF.util.is_host() then
        OF.util.tell_all(wire)
    else
        OF.util.send_to_host(wire)
    end
    return true
end

local function on_a_shot(data)
    if data == nil or data.ofp ~= TRACER_PACKET then return end

    local function play_shot_sound(globalIndex)
        if type(globalIndex) ~= "number" then return end
        if globalIndex == network_global_index_from_local(0) then return end
        if not shot_belongs_here(globalIndex) then return end
        local li = OF.util.local_from_global(globalIndex)
        if li == nil then return end
        local m = gMarioStates[li]
        if m == nil or m.marioObj == nil then return end
        play_sound(SOUND_OBJ_SNUFIT_SHOOT,
            m.marioObj.header.gfx.cameraToObject)
    end

    if OF.util.is_host() then
        if not OF.util.asks(OF.pass, "owner") then return end
        local globalIndex = OF.pass.owner(data.pk)
        if globalIndex == nil then return end
        remember_a_shot(globalIndex, data.ax, data.ay, data.az,
            data.bx, data.by, data.bz)
        play_shot_sound(globalIndex)
        OF.util.tell_all({ ofp = TRACER_PACKET, gi = globalIndex,
            ax = data.ax, ay = data.ay, az = data.az,
            bx = data.bx, by = data.by, bz = data.bz })
        return
    end

    if not OF.util.from_host_effect(data) then return end

    if data.gi == network_global_index_from_local(0) then return end
    remember_a_shot(data.gi, data.ax, data.ay, data.az,
        data.bx, data.by, data.bz)
    play_shot_sound(data.gi)
end

hook_event(HOOK_ON_PACKET_RECEIVE, on_a_shot)

local function render_tracers()
    cheats.tracerDrawn = 0

    if OF.util.menu_has_screen() then return end
    if not OF.util.asks(OF.util, "world_line") then return end
    local mine = gMarioStates[0]
    if mine == nil or mine.pos == nil then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)

    local now = tracer_frame()
    local drawn = 0
    for globalIndex, shot in pairs(live) do
        local age = now - shot.at
        if age < 0 or age >= TRACER_FRAMES then
            live[globalIndex] = nil
        else
            local head = shot.length * (age + 1) / TRACER_FRAMES
            local tail = head - TRACER_TAIL
            if tail < 0 then tail = 0 end

            tailAt.x = shot.x + shot.ux * tail
            tailAt.y = shot.y + shot.uy * tail
            tailAt.z = shot.z + shot.uz * tail
            headAt.x = shot.x + shot.ux * head
            headAt.y = shot.y + shot.uy * head
            headAt.z = shot.z + shot.uz * head

            local dx = tailAt.x - mine.pos.x
            local dz = tailAt.z - mine.pos.z
            local near = dx * dx + dz * dz
            dx = headAt.x - mine.pos.x
            dz = headAt.z - mine.pos.z
            local far = dx * dx + dz * dz
            if far < near then near = far end

            if near <= TRACER_FAR * TRACER_FAR then
                local own = globalIndex == network_global_index_from_local(0)
                local r, g, b = TRACER_THEIRS_R, TRACER_THEIRS_G,
                    TRACER_THEIRS_B
                if own then
                    r, g, b = TRACER_MINE_R, TRACER_MINE_G, TRACER_MINE_B
                end

                local alpha = math.floor(255 - 150 * (age / TRACER_FRAMES))
                if OF.util.world_line(tailAt, headAt, TRACER_WIDTH,
                    r, g, b, alpha) then
                    drawn = drawn + 1
                end
            end
        end
    end
    cheats.tracerDrawn = drawn
end

local function render_hitmark()
    if not cheats.hit_marked() then return end
    if OF.util.menu_has_screen() then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    local midX = djui_hud_get_screen_width() / 2
    local midY = djui_hud_get_screen_height() / 2
    local age = tracer_frame() - markedAt
    local alpha = math.floor(255 - 200 * (age / MARK_FRAMES))
    djui_hud_set_color(255, 255, 255, OF.util.byte(alpha))

    for _, turn in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
        local fromX = midX + turn[1] * MARK_GAP
        local fromY = midY + turn[2] * MARK_GAP
        djui_hud_render_line(fromX, fromY,
            fromX + turn[1] * MARK_REACH, fromY + turn[2] * MARK_REACH, 2)
    end
    djui_hud_set_rotation(0, 0, 0)
end

local function render_shot_feedback()
    render_tracers()
    render_hitmark()
end

hook_event(HOOK_ON_HUD_RENDER, render_shot_feedback)

hook_event(HOOK_ON_LEVEL_INIT, cheats.forget_the_tracers)

end

function cheats.blow_up_around(m, count, spread)
    if m == nil then return false end

    if count == nil then
        count = cheats.setting("blast", "count", 1)
        spread = cheats.setting("blast", "spread", 0)
    end
    if spread == nil then spread = 0 end
    local made = 0
    for index = 0, count - 1 do
        local angle = index * 2 * math.pi / count

        local blast = OF.util.optional("spawn_non_sync_object", nil,
            id_bhvExplosion, E_MODEL_EXPLOSION,
            m.pos.x + math.sin(angle) * spread,
            m.pos.y + 60,
            m.pos.z + math.cos(angle) * spread,
            nil)
        if blast ~= nil then

            blast.oBehParams2ndByte = cheats.blast_stamp(m.playerIndex or 0)
            made = made + 1
        end
    end

    local kick = cheats.setting("blast", "kick", nil)
    if kick ~= nil and made > 0 and m.vel ~= nil then
        local punch = m.action == ACT_PUNCHING or m.action == ACT_MOVE_PUNCHING
        if punch then
            if (m.vel.y or 0) < kick then m.vel.y = kick end
            m.forwardVel = -kick
        elseif m.action == ACT_JUMP_KICK then
            if (m.vel.y or 0) < kick then m.vel.y = kick end
        end
    end
    return made > 0
end

function cheats.own_blast_stands_down(m, obj, interactType)
    if m == nil or m.playerIndex ~= 0 then return end
    if interactType ~= INTERACT_DAMAGE then return end
    if obj == nil then return end

    if cheats.blast_seat_of(obj) ~= (m.playerIndex or 0) then return end
    return false
end

hook_event(HOOK_ALLOW_INTERACT, cheats.own_blast_stands_down)

local function coin_worth(o)
    local worth = o ~= nil and o.oDamageOrCoinValue or 1
    if type(worth) ~= "number" or worth < 1 then return 1 end
    if worth > 5 then return 5 end
    return math.floor(worth)
end

hook_event(HOOK_ON_INTERACT, function(m, o, interactType)
    if m == nil or m.playerIndex ~= 0 then return end
    if interactType ~= INTERACT_COIN then return end

    local worth = coin_worth(o)

    if cheats.is_on("coinrun") then
        local per = cheats.setting("coinrun", "per", 0.4)

        local room = cheats.setting("coinrun", "cap", SPEED_CAP) - WALK_TARGET_MAX
        cheats.coinSpeed = math.min((cheats.coinSpeed or 0) + per * worth,
            math.max(room, 0))
    end

    if cheats.is_on("coinsize") then
        local per = cheats.setting("coinsize", "per", 1.0)
        local low = cheats.setting("coinsize", "low", 0.15)
        local high = cheats.setting("coinsize", "high", 3.0)

        local grown = cheats.coinScale or 1.0
        for _ = 1, worth do grown = grown * per end
        cheats.coinScale = OF.util.clamp(grown, low, high)
        cheats.apply_scale()
    end

    if cheats.is_on("coininvinc") then

        local per = cheats.setting("coininvinc", "per", nil)
        local frames = per ~= nil and (per * worth)
            or cheats.setting("coininvinc", "frames", 30)
        if (m.invincTimer or 0) < frames then m.invincTimer = frames end
    end

    if cheats.is_on("coinheal") then
        local add
        if cheats.setting("coinheal", "full", false) then
            add = math.floor(math.max(0x880 - (tonumber(m.health) or 0), 0) / 0x40)
        else
            add = cheats.setting("coinheal", "per", 4) * worth
        end
        if add > 0 then
            m.healCounter = math.min(255, (m.healCounter or 0) + add)
        end
    end

    if cheats.is_on("coinpop") and not cheats.is_on("noclip") then
        local lift = cheats.setting("coinpop", "lift", 22)
        if (m.vel.y or 0) < lift then m.vel.y = lift end
    end
end)

hook_event(HOOK_ON_INTERACT, function(m, o, interactType)
    if m == nil or m.playerIndex ~= 0 then return end

    local shrink = cheats.setting("coinsize", "hit", nil)
    if shrink ~= nil then
        local now = tonumber(m.hurtCounter) or 0
        local rise = now - (tonumber(cheats.sizeMark) or now)
        cheats.sizeMark = now

        local wedges = math.floor(rise / 4)
        if wedges > 0 then

            local grown = cheats.coinScale or 1.0
            for _ = 1, wedges do grown = grown * shrink end
            cheats.coinScale = OF.util.clamp(grown,
                cheats.setting("coinsize", "low", 0.15),
                cheats.setting("coinsize", "high", 3.0))
            cheats.apply_scale()
        end
    end

    if cheats.is_on("tough") then
        local now = tonumber(m.hurtCounter) or 0
        local mark = tonumber(cheats.hurtMark) or now
        local rise = now - mark
        if rise > 0 then
            local keep = cheats.setting("tough", "keep", 0.5)
            local back = math.floor(rise * (1 - keep))
            if back > 0 then m.hurtCounter = math.max(0, now - back) end
        end
        cheats.hurtMark = tonumber(m.hurtCounter) or 0
    end

    if not was_a_stomp(o, interactType) then return end

    if cheats.is_on("stompchain") then
        cheats.stompChain = (tonumber(cheats.stompChain) or 0) + 1
        local add = cheats.setting("stompchain", "add", 12)
        local lift = math.min(BOUNCE_OFF_OBJECT + add * (cheats.stompChain - 1),
            STOMP_LIFT_CAP)
        if (m.vel.y or 0) < lift then m.vel.y = lift end

        local heal = cheats.setting("stompchain", "heal", nil)
        if heal ~= nil and cheats.stompChain > 1 then
            cheats.owe_a_wedge(heal)
        end
    end

    if cheats.is_on("stompguard") then
        local frames = cheats.setting("stompguard", "frames", 15)
        if (m.invincTimer or 0) < frames then m.invincTimer = frames end
    end
end)

hook_event(HOOK_ON_ATTACK_OBJECT, function(m, o)
    if m == nil or m.playerIndex ~= 0 then return end
    if not cheats.is_on("regen") then return end
    cheats.owe_a_wedge(cheats.setting("regen", "beat", nil))
end)

local TOUCH_COOLDOWN = 30

hook_event(HOOK_ON_INTERACT, function(m, o, interactType)
    if m == nil or m.playerIndex ~= 0 then return end
    if interactType ~= INTERACT_PLAYER then return end
    if not cheats.is_on("regen") then return end
    local pay = cheats.setting("regen", "touch", nil)
    if pay == nil then return end
    if (cheats.touchWait or 0) > 0 then return end
    cheats.touchWait = TOUCH_COOLDOWN
    cheats.owe_a_wedge(pay)
end)

hook_event(HOOK_ON_ATTACK_OBJECT, function(m, o)
    if m == nil or m.playerIndex ~= 0 then return end
    if o == nil or o.oPosX == nil then return end
    if not cheats.is_on("enemycoins") then return end
    local bhv, model = id_bhvSingleCoinGetsSpawned, E_MODEL_YELLOW_COIN
    if type(bhv) ~= "number" or type(model) ~= "number" then return end

    local many = cheats.setting("enemycoins", "coins", 1)
    for _ = 1, many do

        OF.slots.spawn_non_sync(
            bhv, model, o.oPosX, o.oPosY + 60, o.oPosZ, nil)
    end
end)

local FINS_IDLE_ACTIONS = {
    [ACT_WATER_IDLE] = true,
    [ACT_HOLD_WATER_IDLE] = true,
    [ACT_WATER_ACTION_END] = true,
    [ACT_HOLD_WATER_ACTION_END] = true,
}

local function fins_swims_here(m)
    if not OF.util.has_flag(m.action, ACT_FLAG_SWIMMING) then return false end
    if OF.util.has_flag(m.action, ACT_FLAG_MOVING) then return true end
    return FINS_IDLE_ACTIONS[m.action] == true
end

cheats.finsBank = nil

local function fins_land_step(m)
    local bank = cheats.finsBank
    if bank == nil then return nil end

    local shed = cheats.setting("fins", "carry", nil)
    if shed == nil or not cheats.is_on("fins") or m.vel == nil then
        cheats.finsBank = nil
        return nil
    end

    bank = bank - shed
    if bank <= WALK_CLAMP then
        cheats.finsBank = nil
        return nil
    end
    cheats.finsBank = bank

    local speed = m.forwardVel or 0
    if speed <= 1 or speed >= bank then return nil end
    local scale = bank / speed
    m.vel.x = m.vel.x * scale
    m.vel.z = m.vel.z * scale
    return nil
end

local function fins_water_step(m, stepType, stepArg)
    if m == nil or m.playerIndex ~= 0 then return nil end
    if stepType == STEP_TYPE_GROUND then return fins_land_step(m) end
    if stepType ~= STEP_TYPE_WATER then return nil end
    if m.vel == nil or m.faceAngle == nil then return nil end
    if not cheats.is_on("fins") then return nil end
    if cheats.is_on("speed") then return nil end
    if OF.util.asks(OF.modifiers, "is_on") and OF.modifiers.is_on("quick") then
        return nil
    end
    if not fins_swims_here(m) then return nil end

    local speed = m.forwardVel or 0
    if speed <= 1 or speed > SWIM_CLAMP then return nil end

    local swim = cheats.setting("fins", "swim", FINS_CAP)
    local scale = swim / SWIM_CLAMP
    if scale <= 1 then return nil end

    local climb = speed * sins(m.faceAngle.x)
    m.vel.x = m.vel.x * scale
    m.vel.z = m.vel.z * scale
    m.vel.y = m.vel.y + climb * (scale - 1)

    if cheats.setting("fins", "carry", nil) ~= nil then
        local held = speed * scale
        if held > (cheats.finsBank or 0) then cheats.finsBank = held end
    end
    return nil
end

hook_event(HOOK_BEFORE_PHYS_STEP, fins_water_step)

function cheats.eject_step(m, stepType)
    if m == nil or m.playerIndex ~= 0 then return end
    if stepType ~= nil and stepType ~= STEP_TYPE_AIR then return end
    if not cheats.ejecting then return end
    if not cheats.eject_flight(m.action) then return end
    if m.vel == nil then return end

    if cheats.ejectLiftOwed then
        cheats.ejectLiftOwed = false
        m.vel.y = m.vel.y * cheats.eject_lift()
    end
    local boost = cheats.setting("eject", "boost", 1.0)
    if boost == 1.0 then return end
    m.vel.x = m.vel.x * boost
    m.vel.z = m.vel.z * boost
end

function cheats.eject_lift()
    local warp = OF.warp

    if warp ~= nil and type(warp.exit_lift) == "function" then return 1.0 end
    if warp == nil or type(warp.land_height_factor) ~= "function" then return 1.0 end
    local fy = tonumber(warp.land_height_factor()) or 1.0
    if fy <= 0 then return 1.0 end
    return math.sqrt(fy)
end

hook_event(HOOK_BEFORE_PHYS_STEP, cheats.eject_step)

cheats.GOD_INVINC = 2

local function update_mario(m)

    cheats.draw_scale(m)

    cheats.watch_the_swing(m)

    cheats.apply_flier(m)

    cheats.apply_invisible(m)

    if m.playerIndex ~= 0 then return end

    cheats.capBeforeStar = m.capTimer

    cheats.work_the_rifle(m)

    local kept = cheats.ejectKept
    if cheats.ejecting and kept ~= nil then

        if type(kept.health) == "number" then m.health = kept.health end
        if type(kept.lives) == "number" and (m.numLives or 0) < kept.lives then
            m.numLives = kept.lives
        end
    end
    if cheats.ejecting and not cheats.eject_flight(m.action) then

        cheats.ejecting = false
        cheats.ejectKept = nil
    end

    if cheats.is_on("moonjump") and not cheats.moonjump_stands_down() then

        if OF.util.has_flag(m.controller.buttonDown, cheats.MOONJUMP_BUTTON)
            and m.pos.y > m.floorHeight + HOVER_FLOOR_BAND then
            if m.vel.y < 30 then m.vel.y = 30 end
            cheats.moon_out_of_bonk(m)
        end
    end

    local onA = cheats.hover_on_a()
    if (cheats.is_on("hover") or onA) and not cheats.is_on("noclip") then

        local holding = (cheats.is_on("hover")
                and OF.util.has_flag(m.controller.buttonDown,
                    cheats.HOVER_BUTTON))
            or (onA and OF.util.has_flag(m.controller.buttonDown, A_BUTTON))
        if cheats.hover_tick(m, holding) then
            m.vel.y = 0
            local peak = cheats.hoverPeak
            if peak == nil or m.peakHeight > peak then peak = m.peakHeight end
            cheats.hoverPeak = peak
            m.peakHeight = peak

            if ACT_GROUND_POUND ~= nil and m.action == ACT_GROUND_POUND then
                set_mario_action(m, ACT_FREEFALL, 0)
            end
        end
    end

    if not cheats.is_on("noclip") then
        local floor = cheats.air_hold_floor(m,
            OF.util.has_flag(m.controller.buttonDown, A_BUTTON))
        if floor ~= nil and m.vel.y < floor then m.vel.y = floor end
    end

    if cheats.is_on("float") and not cheats.is_on("noclip") then
        local floor = cheats.setting("float", "fall", -30.0)
        if OF.util.has_flag(m.action, ACT_FLAG_AIR) and m.vel.y < floor then
            m.vel.y = floor
        end
    end

    if cheats.is_on("grip") then
        local held = cheats.gripFrames or 0

        local bonked = BONK_ACTIONS[m.action] == true
            and (m.action == ACT_AIR_HIT_WALL or held > 0)

        if m.wall ~= nil or bonked then
            cheats.gripFrames = NUMBERS.gripHold

            if bonked and cheats.wasAction ~= m.action
                and cheats.wasYaw ~= nil and m.faceAngle ~= nil then
                m.faceAngle.y = cheats.wasYaw

                if (m.forwardVel or 0) < 0 then m.forwardVel = 0 end
            end
        elseif held > 0 then
            cheats.gripFrames = held - 1
        end

        if (cheats.gripFrames or 0) > 0 and m.pos.y > m.floorHeight + 20 then

            if BONK_ACTIONS[m.action] == true then
                set_mario_action(m, ACT_FREEFALL, 0)
            end

            if OF.util.has_flag(m.input or 0, INPUT_A_PRESSED) then
                if m.faceAngle ~= nil then
                    m.faceAngle.y = ((m.faceAngle.y + 0x10000) % 0x10000) - 0x8000
                end
                set_mario_action(m, ACT_WALL_KICK_AIR, 0)

                cheats.gripFrames = 0
            else

                local rise = cheats.setting("grip", "rise", -NUMBERS.gripSlide)
                if m.vel.y < rise then m.vel.y = rise end
            end
        end
    elseif (cheats.gripFrames or 0) > 0 then

        cheats.gripFrames = 0
    end

    cheats.pull_coins(m)
    cheats.pull_stars(m)
    cheats.catch_them(m)

    if cheats.is_on("capkeep") and m.capTimer > 0 then
        m.capTimer = CAP_HELD_AT
    end

    if cheats.is_on("capstay")
        and OF.util.optional("does_mario_have_normal_cap_on_head", 1, m) == 0

        and not OF.util.has_flag(m.flags, MARIO_WING_CAP)
        and not OF.util.has_flag(m.flags, MARIO_METAL_CAP)
        and not OF.util.has_flag(m.flags, MARIO_VANISH_CAP) then
        m.flags = set_bit(set_bit(m.flags, MARIO_NORMAL_CAP), MARIO_CAP_ON_HEAD)

        m.cap = clear_bit(clear_bit(clear_bit(m.cap,
            SAVE_FLAG_CAP_ON_KLEPTO), SAVE_FLAG_CAP_ON_UKIKI),
            SAVE_FLAG_CAP_ON_MR_BLIZZARD)
    end

    local faster = nil
    if OF.util.asks(OF.modifiers, "quick_speed") then
        faster = OF.modifiers.quick_speed(m)
    end
    if faster == nil and cheats.is_on("speed") then
        faster = SPEED_FACTOR
    end

    local boosting = faster
    if boosting ~= nil and boosting > 1
        and OF.util.optional("analog_stick_held_back", 0, m) ~= 0 then
        boosting = nil
    end
    local boosted = false
    if boosting ~= nil then
        local want = math.min(m.intendedMag or 0, WALK_TARGET_MAX) * boosting

        local top = SPEED_CAP
        if OF.util.asks(OF.modifiers, "is_on") and OF.modifiers.is_on("quick") then
            top = ROOM_SPEED_CAP
        end
        if want > top then want = top end
        if boosting < 1 then

            if m.forwardVel > want then m.forwardVel = want end
        elseif m.forwardVel > 1 then

            boosted = OF.util.speed_up(m, math.min(m.forwardVel * boosting, want))
        end
    end

    local thisFrame = frame_now()
    if faster ~= nil and not boosted
        and not OF.util.has_flag(m.action, ACT_FLAG_AIR)
        and not OF.util.has_flag(m.action, ACT_FLAG_SWIMMING)
        and thisFrame ~= nil and cheats.wasVelFrame == thisFrame
        and cheats.wasVel ~= nil and m.forwardVel > 0
        and cheats.wasVel > m.forwardVel

        and cheats.wasVel > WALK_TARGET_MAX then
        local took = cheats.wasVel - m.forwardVel
        local extra = took * (faster * faster - 1)
        if m.forwardVel - extra < 0 then
            m.forwardVel = 0
        else
            m.forwardVel = m.forwardVel - extra
        end
    end

    if cheats.is_on("stroke")
        and OF.util.has_flag(m.action, ACT_FLAG_SWIMMING)
        and m.faceAngle ~= nil and m.angleVel ~= nil
        and m.controller ~= nil then
        m.faceAngle.y = m.intendedYaw
        m.angleVel.y = 0

        local wantPitch = -252 * (m.controller.stickY or 0)
        if wantPitch >= 0 then
            m.faceAngle.x = math.floor(wantPitch)
        else
            m.faceAngle.x = -math.floor(-wantPitch)
        end
    end

    local onFoot = not OF.util.has_flag(m.action, ACT_FLAG_AIR)
        and not OF.util.has_flag(m.action, ACT_FLAG_SWIMMING)

    local ceiling = 0
    if cheats.is_on("coinrun") then

        local want = math.min(WALK_TARGET_MAX + (cheats.coinSpeed or 0),
            cheats.setting("coinrun", "cap", SPEED_CAP))
        if want > ceiling then ceiling = want end
    end

    if ceiling > WALK_TARGET_MAX and onFoot
        and not cheats.is_on("speed")
        and not (OF.util.asks(OF.modifiers, "is_on") and OF.modifiers.is_on("quick"))
        and (m.intendedMag or 0) > 8
        and (m.forwardVel or 0) > 1 then
        OF.util.speed_up(m, ceiling)
    end

    if cheats.is_on("revup") and onFoot
        and not cheats.is_on("speed")
        and (m.intendedMag or 0) > 8 then
        OF.util.speed_up(m, math.min(m.intendedMag or 0, WALK_TARGET_MAX), true)
    end

    if cheats.is_on("nowarp")
        and (m.skipWarpInteractionsTimer or 0) < WARP_SKIP_HOLD then
        m.skipWarpInteractionsTimer = WARP_SKIP_HOLD
    end

    if cheats.is_on("turn") and m.faceAngle ~= nil
        and (m.action == ACT_WALKING or m.action == ACT_HOLD_WALKING) then

        local swing = cheats.setting("turn", "swing", nil)
        if swing == nil then
            m.faceAngle.y = m.intendedYaw
        else

            local gap = angle_gap(m.intendedYaw, m.faceAngle.y)
            if gap > swing then gap = swing elseif gap < -swing then gap = -swing end

            m.faceAngle.y = ((m.faceAngle.y + gap + 0x8000) % 0x10000) - 0x8000
        end
    end

    if cheats.is_on("airsteer") and m.faceAngle ~= nil
        and not cheats.is_on("noclip")
        and not cheats.wall_kick_holds(m.action)
        and OF.util.has_flag(m.action or 0, ACT_FLAG_AIR)
        and (m.intendedMag or 0) > 8 then
        local turn = cheats.setting("airsteer", "turn", nil)
        if turn == nil then
            m.faceAngle.y = m.intendedYaw
        else
            local gap = angle_gap(m.intendedYaw, m.faceAngle.y)
            if gap > turn then gap = turn elseif gap < -turn then gap = -turn end
            m.faceAngle.y = ((m.faceAngle.y + gap + 0x8000) % 0x10000) - 0x8000
        end
    end

    if cheats.is_on("heavy") and not cheats.is_on("noclip")
        and OF.util.has_flag(m.action or 0, ACT_FLAG_AIR) then
        local pull = cheats.setting("heavy", "pull", 2.0)
        m.vel.y = math.max(m.vel.y - pull, -75.0)
    end

    do
        local bonking = BONK_ACTIONS[m.action] == true
        local entered = bonking and cheats.wasBonk ~= true
        cheats.wasBonk = bonking
        if not bonking then
            cheats.bonkSpeed = nil
        elseif entered then
            local stamp = frame_now()
            if cheats.wasVelFrame ~= nil and cheats.wasVelFrame == stamp then
                cheats.bonkSpeed = math.abs(tonumber(cheats.wasVel) or 0)
            else
                cheats.bonkSpeed = nil
            end
        end
        if bonking and cheats.bonkSpeed ~= nil and cheats.is_on("wallbounce")
            and not cheats.is_on("noclip") then
            local keep = cheats.setting("wallbounce", "keep", 1.0)
            m.forwardVel = cheats.bonkSpeed * keep
            if entered then
                local lift = cheats.setting("wallbounce", "lift", 0)
                if lift > 0 and m.vel.y < lift then m.vel.y = lift end
            end

            local climb = cheats.setting("wallbounce", "climb", nil)
            if climb ~= nil then m.vel.y = (m.vel.y or 0) + climb end
        end
    end

    if not OF.util.has_flag(m.action or 0, ACT_FLAG_AIR) then
        cheats.stompChain = nil
    end

    if cheats.is_on("sand") and (m.quicksandDepth or 0) > 0 then
        m.quicksandDepth = 0
    end

    local landing = m.action == ACT_LONG_JUMP_LAND
    if cheats.is_on("blj") and landing then

        if cheats.bljHeld == nil then
            cheats.bljHeld = math.min(cheats.bljCarried or 0, m.forwardVel)
        end
        if m.forwardVel < cheats.bljHeld then cheats.bljHeld = m.forwardVel end
        if cheats.bljHeld >= 0 then

            cheats.bljHeld = nil
            cheats.bljCarried = nil
        else
            m.forwardVel = math.max(cheats.bljHeld, BLJ_LIMIT)

            if OF.util.has_flag(m.controller.buttonDown, A_BUTTON)
                and m.forwardVel > BLJ_LIMIT then
                set_mario_action(m, ACT_LONG_JUMP, 0)
                cheats.bljHeld = nil
            end
        end
    elseif not landing then
        cheats.bljHeld = nil
    end

    if cheats.is_on("rocket") and m.forwardVel > 1 then
        OF.util.speed_up(m, m.forwardVel * 1.6, true)
    end

    local fall = nil
    if OF.util.asks(OF.modifiers, "is_on") and OF.modifiers.is_on("lowgrav") then
        fall = OF.modifiers.setting("lowgrav", "fall", 0.72)
    elseif cheats.is_on("lowgrav") then

        fall = cheats.setting("lowgrav", "fall", 0.72)
    end
    if fall ~= nil then

        if m.vel.y < 0 then m.vel.y = m.vel.y * fall end
    end

    if (cheats.wasSquish or 0) == 0 and (m.squishTimer or 0) ~= 0 then
        local theirs = OF.util.asks(OF.powerups, "is_their_flatten")
            and OF.powerups.is_their_flatten(m.squishTimer)
        cheats.squishIsTheirs = theirs == true
    elseif (m.squishTimer or 0) == 0 then
        cheats.squishIsTheirs = false
    end
    if cheats.is_on("nosquish") and cheats.squishIsTheirs ~= true then
        if (m.squishTimer or 0) ~= 0 then m.squishTimer = 0 end
        if (m.bounceSquishTimer or 0) ~= 0 then m.bounceSquishTimer = 0 end
    end

    if cheats.is_on("springs") and SPRING_JUMPS[m.action] == true
        and cheats.wasAction ~= m.action and m.vel.y > 0 then

        m.vel.y = math.min(m.vel.y * cheats.setting("springs", "lift", SPRING_LIFT),
            cheats.setting("springs", "cap", SPRING_CAP))
    end

    local group = OF.util.action_group(m.action)
    local landedNow = cheats.wasAir == true
        and not OF.util.has_flag(m.action, ACT_FLAG_AIR)
        and (group == OF.util.action_group(ACT_GROUP_MOVING)
            or group == OF.util.action_group(ACT_GROUP_STATIONARY))

    local bounceFloor = cheats.setting("bouncy", "floor", BOUNCE_FLOOR)
    if cheats.is_on("bouncy") and landedNow
        and (cheats.wasFall or 0) < -bounceFloor then
        local up = math.min(-(cheats.wasFall) * cheats.setting("bouncy", "keep", BOUNCE_KEEP),
            cheats.setting("bouncy", "cap", BOUNCE_CAP))

        set_mario_action(m, ACT_JUMP, 0)
        m.vel.y = up

        if MARIO_UNKNOWN_08 ~= nil and type(m.flags) == "number" then
            m.flags = m.flags & ~MARIO_UNKNOWN_08
        end
    end

    if not OF.util.has_flag(m.action, ACT_FLAG_AIR) then
        cheats.airJumps = 0
    elseif cheats.is_on("airjump")
        and OF.util.has_flag(m.input or 0, INPUT_A_PRESSED)
        and (cheats.setting("airjump", "endless", false) == true
            or (cheats.airJumps or 0) < cheats.setting("airjump", "jumps", 1))

        and cheats.wasAction == m.action then
        cheats.airJumps = (cheats.airJumps or 0) + 1

        if m.heldObj ~= nil
            and OF.util.has_flag(m.heldObj.oInteractionSubtype or 0,
                INT_SUBTYPE_GRABS_MARIO) then
            OF.util.optional("mario_drop_held_object", nil, m)
            set_mario_action(m, ACT_JUMP, 0)
        else
            set_mario_action(m, m.heldObj ~= nil and ACT_HOLD_JUMP or ACT_JUMP, 0)
        end

        cheats.spentA = true
    end

    if cheats.is_on("poundcut") and m.action == ACT_GROUND_POUND
        and OF.util.has_flag(m.input or 0, INPUT_A_PRESSED) then
        set_mario_action(m, ACT_JUMP, 0)
        cheats.spentA = true
    end

    if cheats.is_on("twirl") and not cheats.spentA
        and OF.util.has_flag(m.action, ACT_FLAG_AIR)
        and m.action ~= ACT_TWIRLING
        and m.vel.y < 0
        and OF.util.has_flag(m.input or 0, INPUT_A_PRESSED)
        and cheats.wasAction == m.action then
        set_mario_action(m, ACT_TWIRLING, 0)
        cheats.spentA = true
    end

    if cheats.is_on("triples") and m.action == ACT_JUMP
        and cheats.wasAction ~= m.action
        and cheats.wasAir ~= true
        and not (OF.util.asks(OF.rules, "denied_move")
                 and OF.rules.denied_move(m, ACT_TRIPLE_JUMP) ~= nil) then
        set_mario_action(m, ACT_TRIPLE_JUMP, 0)
    end

    if cheats.is_on("ledgeup")
        and (m.action == ACT_LEDGE_CLIMB_SLOW_1
             or m.action == ACT_LEDGE_CLIMB_SLOW_2) then
        set_mario_action(m, ACT_LEDGE_CLIMB_FAST, 0)
    end

    if cheats.is_on("still")
        and (m.action == ACT_START_SLEEPING or m.action == ACT_SLEEPING
             or m.action == ACT_WAKING_UP) then
        set_mario_action(m, ACT_IDLE, 0)
    end

    if cheats.is_on("nokb") and KNOCKBACK_ACTIONS[m.action] == true then
        if OF.util.has_flag(m.action, ACT_FLAG_SWIMMING) then
            set_mario_action(m, ACT_WATER_IDLE, 0)
        elseif OF.util.has_flag(m.action, ACT_FLAG_AIR) then
            set_mario_action(m, ACT_FREEFALL, 0)
        else
            set_mario_action(m, ACT_IDLE, 0)
        end
    end

    if cheats.is_on("nofall")
        or (OF.util.asks(OF.modifiers, "softland_clears_the_fall")
            and OF.modifiers.softland_clears_the_fall()) then
        m.peakHeight = m.pos.y
    end

    if cheats.is_on("godmode") then

        m.invincTimer = cheats.GOD_INVINC
        m.hurtCounter = 0
        if m.health < 0x880 then m.health = 0x880 end
        m.peakHeight = m.pos.y
    end

    if cheats.is_on("infinitelives") then
        if m.numLives < 99 then m.numLives = 99 end
    end

    if (cheats.is_on("drysuit")
        or cheats.setting("gasmask", "water", false) == true)
        and OF.util.has_flag(m.action, ACT_FLAG_SWIMMING)
        and not OF.util.has_flag(m.input, INPUT_IN_POISON_GAS)
        and (cheats.wasHurt or 0) == 0
        and cheats.wasHealth ~= nil and m.health < cheats.wasHealth then
        m.health = cheats.wasHealth
    end

    if cheats.is_on("gasmask")
        and OF.util.has_flag(m.input, INPUT_IN_POISON_GAS)
        and (cheats.wasHurt or 0) == 0
        and cheats.wasHealth ~= nil and m.health < cheats.wasHealth then
        m.health = cheats.wasHealth
    end

    if cheats.is_on("secondchance") and cheats.chanceSpent ~= true
        and m.health < ONE_WEDGE then
        cheats.chanceSpent = true
        m.health = FULL_HEALTH
        m.hurtCounter = 0
        if m.invincTimer < 60 then m.invincTimer = 60 end
        OF.notify.show("Second chance used - that is the one for this level",
            "warn", 4)
    end

    if (cheats.touchWait or 0) > 0 then
        cheats.touchWait = cheats.touchWait - 1
        if cheats.touchWait <= 0 then cheats.touchWait = nil end
    end

    if cheats.is_on("regen") and m.health >= ONE_WEDGE and m.health < FULL_HEALTH
        and (m.hurtCounter or 0) == 0 and (m.healCounter or 0) == 0 then
        cheats.regenWait = (cheats.regenWait or 0) + 1
        if cheats.regenWait >= cheats.setting("regen", "every", 30) then
            cheats.regenWait = 0

            cheats.owe_a_wedge(HEAL_WEDGE)
        end
    else

        cheats.regenWait = 0
    end

    if (cheats.healOwed or 0) > 0 and m.health >= ONE_WEDGE
        and m.health < FULL_HEALTH and (m.hurtCounter or 0) == 0
        and (m.healCounter or 0) == 0 then

        local bite = cheats.healOwed
        if bite > HEAL_WEDGE then bite = HEAL_WEDGE end
        cheats.healOwed = cheats.healOwed - bite
        if cheats.healOwed <= 0 then cheats.healOwed = nil end
        m.healCounter = bite
    end

    cheats.cough_tick(m)

    cheats.alive_clock(m)

    cheats.timed_size_tick()

    if cheats.wanted_scale() ~= 1.0 then cheats.apply_scale() end

    local row = gPlayerSyncTable[0]
    local said = row ~= nil and tonumber(row.ofScale) or nil
    if said ~= personal_scale() then cheats.apply_scale() end
end

local function on_packet_receive(data)
    if data == nil then return end

    if data.ofp ~= cheats.PACKET then return end
    if not OF.util.from_host(data) then return end

    if data.what == "clear" then
        cheats.clear_local()
        OF.notify.show("The host turned your cheats off", "info", 4)
        return
    end

end

cheats.peak = cheats.peak or 0

local function speed_now(m)
    if m == nil then return 0, 0 end

    local k = OF.util.asks(OF.util, "stride_now") and OF.util.stride_now(m) or nil
    k = k or 1.0
    local ground = math.sqrt(m.vel.x * m.vel.x + m.vel.z * m.vel.z) * k

    local speed = OF.util.asks(OF.util, "ground_speed") and OF.util.ground_speed(m)
        or (m.forwardVel or 0) * k
    return speed, ground
end

function cheats.reset_peak()
    cheats.peak = 0
    return true
end

hook_event(HOOK_ON_LEVEL_INIT, function()
    cheats.peak = 0
    cheats.chanceSpent = false

    cheats.levelFrames = 0

    cheats.footing = nil
    cheats.fell = false

    cheats.regenWait = 0

    cheats.healOwed = nil
    cheats.touchWait = nil

    cheats.finsBank = nil

    cheats.spentA = false

    cheats.hoverTank = 1
    cheats.hoverLatched = false
    cheats.hoverPeak = nil

    cheats.airHeld = 0

    cheats.forget_star_homes()
end)

local SIGN_GAP = { ["+"] = 6, ["-"] = 2 }

local SPEEDO_BOTTOM = 52

local function render_speedometer()
    if not cheats.is_on("speedo") then return end
    local m = gMarioStates[0]
    if m == nil then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    local forward, ground = speed_now(m)
    local size = math.abs(forward)
    if size > cheats.peak then cheats.peak = size end

    if OF.util.menu_has_screen() then return end

    local sign = forward < 0 and "-" or "+"
    local digits = string.format("%.0f", math.abs(forward))

    djui_hud_set_font(FONT_HUD)

    local scale = 2.3
    local gap = SIGN_GAP[sign] * scale
    local signWidth = djui_hud_measure_text(sign) * scale
    local width = signWidth + gap + djui_hud_measure_text(digits) * scale
    local x = (djui_hud_get_screen_width() - width) / 2
    local y = djui_hud_get_screen_height() - SPEEDO_BOTTOM

    local r, g, b = 255, 255, 255
    if forward < -1 then r, g, b = 255, 140, 140 end

    local numberAt = x + signWidth + gap

    local shadow = 2 * scale / 1.15
    djui_hud_set_color(0, 0, 0, 160)
    djui_hud_print_text(sign, x + shadow, y + shadow, scale)
    djui_hud_print_text(digits, numberAt + shadow, y + shadow, scale)
    djui_hud_set_color(r, g, b, 255)
    djui_hud_print_text(sign, x, y, scale)
    djui_hud_print_text(digits, numberAt, y, scale)

    djui_hud_set_font(FONT_NORMAL)
end

local TANK_WIDTH = 96
local TANK_HEIGHT = 6

local TANK_LIFT = 16

local TANK_SPENT = { r = 255, g = 90, b = 90 }

local TANK_EMPTY = { r = 40, g = 40, b = 40 }

local function render_hover_tank()

    if not cheats.is_on("hover") and not cheats.hover_on_a() then return end

    if cheats.hover_size() == nil then return end

    if cheats.is_on("noclip") then return end
    if OF.util.menu_has_screen() then return end

    local left = OF.util.clamp(cheats.hoverTank or 1, 0, 1)
    if left >= 1 and not cheats.hoverLatched then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)

    local x = (djui_hud_get_screen_width() - TANK_WIDTH) / 2
    local y = djui_hud_get_screen_height() - SPEEDO_BOTTOM - TANK_LIFT

    local fill = cheats.hoverLatched and TANK_SPENT or OF.util.gold()
    OF.util.meter(x, y, TANK_WIDTH, TANK_HEIGHT, left, fill, TANK_EMPTY)
end

local function render_bottom_middle()
    render_speedometer()
    render_hover_tank()
end

hook_event(HOOK_ON_HUD_RENDER, render_bottom_middle)

local function render_the_crosshair()
    if not OF.util.asks(cheats, "rifle_is_aimed") then return end
    if not cheats.rifle_is_aimed() then return end
    local width = OF.util.optional("djui_hud_get_screen_width", nil)
    local height = OF.util.optional("djui_hud_get_screen_height", nil)
    if width == nil or height == nil then return end

    local cold = cheats.rifle_cooldown() > 0
    if cold then
        djui_hud_set_color(230, 90, 70, 200)
    else
        djui_hud_set_color(255, 255, 255, 220)
    end

    local cx, cy = width / 2, height / 2
    local arm, gap, thick = 9, 5, 2
    djui_hud_render_rect(cx - gap - arm, cy - thick / 2, arm, thick)
    djui_hud_render_rect(cx + gap,       cy - thick / 2, arm, thick)
    djui_hud_render_rect(cx - thick / 2, cy - gap - arm, thick, arm)
    djui_hud_render_rect(cx - thick / 2, cy + gap,       thick, arm)
end

hook_event(HOOK_ON_HUD_RENDER, render_the_crosshair)

local READOUT_SCALE = 0.62
local READOUT_LEFT = 14
local READOUT_BOTTOM = 18
local READOUT_GAP = 3

local function coords_line(m)
    return string.format("X %.0f   Y %.0f   Z %.0f", m.pos.x, m.pos.y, m.pos.z)
end

local BUTTONS = {
    { name = "A",     flag = A_BUTTON },
    { name = "B",     flag = B_BUTTON },
    { name = "Z",     flag = Z_TRIG },
    { name = "L",     flag = L_TRIG },
    { name = "R",     flag = R_TRIG },
    { name = "START", flag = START_BUTTON },
    { name = "C-up",    flag = U_CBUTTONS },
    { name = "C-down",  flag = D_CBUTTONS },
    { name = "C-left",  flag = L_CBUTTONS },
    { name = "C-right", flag = R_CBUTTONS },
    { name = "D-up",    flag = U_JPAD },
    { name = "D-down",  flag = D_JPAD },
    { name = "D-left",  flag = L_JPAD },
    { name = "D-right", flag = R_JPAD },
}

local ASK_RECENT = 60

local ASK_BUTTONS = { { "A", "framesSinceA" }, { "B", "framesSinceB" } }

cheats.PAD_DRAWS = { A = true, B = true, Z = true, L = true, R = true, START = true,
    ["C-up"] = true, ["C-down"] = true, ["C-left"] = true, ["C-right"] = true }

local function inputs_line(m, padded)
    local c = m.controller
    if c == nil then return nil end

    local held = {}
    for _, button in ipairs(BUTTONS) do
        if OF.util.has_flag(c.buttonDown, button.flag)
            and not (padded and cheats.PAD_DRAWS[button.name]) then
            table.insert(held, button.name)
        end
    end

    local line = string.format("%.0f, %.0f", c.stickX or 0, c.stickY or 0)
    local rx, ry = c.extStickX or 0, c.extStickY or 0
    if rx ~= 0 or ry ~= 0 then
        line = line .. string.format("   R %.0f, %.0f", rx, ry)
    end
    if #held > 0 then line = line .. "   " .. table.concat(held, " ") end

    for _, ask in ipairs(ASK_BUTTONS) do
        local since = m[ask[2]]
        if type(since) == "number" and since >= 0 and since < ASK_RECENT then
            line = line .. string.format("   %s %.0ff ago", ask[1], since)
        end
    end
    return line
end

local ACTION_WORDS = {}
do
    local named = {
        { ACT_IDLE, "standing" },
        { ACT_WALKING, "walking" },
        { ACT_BRAKING, "braking" },
        { ACT_TURNING_AROUND, "turning" },
        { ACT_FINISH_TURNING_AROUND, "turning" },
        { ACT_CROUCHING, "crouching" },
        { ACT_CRAWLING, "crawling" },
        { ACT_START_CRAWLING, "crawling" },
        { ACT_BUTT_SLIDE, "butt slide" },
        { ACT_CROUCH_SLIDE, "crouch slide" },
        { ACT_DIVE_SLIDE, "dive slide" },
        { ACT_SLIDE_KICK_SLIDE, "slide kick" },
        { ACT_JUMP, "jump" },
        { ACT_DOUBLE_JUMP, "double jump" },
        { ACT_TRIPLE_JUMP, "triple jump" },
        { ACT_SPECIAL_TRIPLE_JUMP, "special triple" },
        { ACT_BACKFLIP, "backflip" },
        { ACT_SIDE_FLIP, "side flip" },
        { ACT_LONG_JUMP, "long jump" },
        { ACT_WALL_KICK_AIR, "wall kick" },
        { ACT_AIR_HIT_WALL, "bonk" },
        { ACT_FREEFALL, "falling" },
        { ACT_DIVE, "dive" },
        { ACT_GROUND_POUND, "ground pound" },
        { ACT_TWIRLING, "twirling" },
        { ACT_FLYING, "flying" },
        { ACT_SHOT_FROM_CANNON, "cannon" },
        { ACT_LAVA_BOOST, "lava boost" },
        { ACT_BURNING_JUMP, "on fire" },
        { ACT_BURNING_FALL, "on fire" },
        { ACT_SHOCKED, "shocked" },
        { ACT_SQUISHED, "squished" },
        { ACT_LEDGE_GRAB, "ledge grab" },
        { ACT_LEDGE_CLIMB_FAST, "quick climb" },
        { ACT_LEDGE_CLIMB_SLOW_1, "slow climb" },
        { ACT_LEDGE_CLIMB_SLOW_2, "slow climb" },
        { ACT_WATER_IDLE, "treading" },
        { ACT_BREASTSTROKE, "swimming" },
        { ACT_FLUTTER_KICK, "flutter kick" },
        { ACT_WATER_PLUNGE, "plunging" },
        { ACT_WATER_JUMP, "out of the water" },
        { ACT_DROWNING, "drowning" },
        { ACT_CLIMBING_POLE, "on a pole" },
        { ACT_HANGING, "hanging" },
        { ACT_START_SLEEPING, "dozing off" },
        { ACT_SLEEPING, "asleep" },
        { ACT_BUBBLED, "bubbled" },
    }
    for i = 1, 96 do
        local one = named[i]
        if one ~= nil and one[1] ~= nil then ACTION_WORDS[one[1]] = one[2] end
    end
end

local ACTION_FAMILIES = { [0] = "uninitialised", "standing", "moving",
                          "airborne", "in water", "cutscene", "automatic",
                          "on an object" }

function cheats.inputs_detail(m)
    if m == nil then return nil end
    return inputs_line(m, true)
end

local function action_word(action)
    if action == nil then return "-" end
    local word = ACTION_WORDS[action]
    if word ~= nil then return word end

    if OF.util.asks(OF.moves, "custom_word") then
        local ours = OF.moves.custom_word(action)
        if ours ~= nil then return ours end
    end
    local family = ACTION_FAMILIES[OF.util.action_group(action) or -1] or "action"
    if OF.util.asks(OF.moves, "is_custom") and OF.moves.is_custom(action) then
        family = string.format("%s, a mod's own", family)
    end
    return string.format("%s %s", family,
        string.format("0x%08X", action))
end

local function action_line(m)

    return string.format("%s   %.0ff   was %s",
        action_word(m.action), m.actionTimer or 0, action_word(m.prevAction))
end

local function vitals_line(m)
    local wedges = (m.health or 0) / 0x100
    local line = string.format("Health %.2f/8.5", wedges)
    local hurt = m.hurtCounter or 0
    local heal = m.healCounter or 0
    if hurt > 0 then line = line .. string.format("   -%.0f", hurt) end
    if heal > 0 then line = line .. string.format("   +%.0f", heal) end
    line = line .. string.format("   %.0f lives   %.0f coins", m.numLives or 0,
        m.numCoins or 0)
    return line
end

local TIMER_FIELDS = {
    { "invinc", "invincTimer" },
    { "cap", "capTimer" },
    { "squish", "squishTimer" },
    { "bounce", "bounceSquishTimer" },
    { "knockback", "knockbackTimer" },
    { "wallkick", "wallKickTimer" },
    { "jumpchain", "doubleJumpTimer" },
    { "nowarp", "skipWarpInteractionsTimer" },
}

local function clocks_line(m)
    local parts = {}
    for _, field in ipairs(TIMER_FIELDS) do
        local value = m[field[2]]

        if type(value) == "number" and value ~= 0 then
            table.insert(parts, string.format("%s %.0f", field[1], value))
        end
    end
    if #parts == 0 then return OF.lang.t("Timers: none running") end
    return "Timers: " .. table.concat(parts, "  ")
end

local SURFACE_GRIP = {}
do
    local named = {
        { SURFACE_CLASS_VERY_SLIPPERY, "sheet ice" },
        { SURFACE_CLASS_SLIPPERY, "slippery" },
        { SURFACE_CLASS_NOT_SLIPPERY, "grippy" },
        { SURFACE_CLASS_DEFAULT, "normal" },
    }
    for i = 1, 4 do
        local one = named[i]
        if one ~= nil and one[1] ~= nil then SURFACE_GRIP[one[1]] = one[2] end
    end
end

local SURFACE_WORDS = {}
do
    local named = {
        { SURFACE_DEFAULT, "plain" },
        { SURFACE_BURNING, "lava" },
        { SURFACE_HANGABLE, "hangable" },
        { SURFACE_SLOW, "slow" },
        { SURFACE_DEATH_PLANE, "death plane" },
        { SURFACE_WATER, "water" },
        { SURFACE_FLOWING_WATER, "flowing water" },
        { SURFACE_INTANGIBLE, "intangible" },
        { SURFACE_VERY_SLIPPERY, "very slippery" },
        { SURFACE_SLIPPERY, "slippery" },
        { SURFACE_NOT_SLIPPERY, "not slippery" },
        { SURFACE_ICE, "ice" },
        { SURFACE_HARD, "hard" },
        { SURFACE_SHALLOW_QUICKSAND, "shallow quicksand" },
        { SURFACE_DEEP_QUICKSAND, "deep quicksand" },
        { SURFACE_INSTANT_QUICKSAND, "instant quicksand" },
        { SURFACE_QUICKSAND, "quicksand" },
        { SURFACE_HORIZONTAL_WIND, "side wind" },
        { SURFACE_VERTICAL_WIND, "updraft" },
        { SURFACE_WARP, "warp" },
        { SURFACE_TIMER_START, "timer start" },
        { SURFACE_TIMER_END, "timer end" },
        { SURFACE_VANISH_CAP_WALLS, "vanish walls" },
    }

    for i = 1, 48 do
        local one = named[i]
        if one ~= nil and one[1] ~= nil then SURFACE_WORDS[one[1]] = one[2] end
    end
end

local function surface_line(m)
    local floor = m.floor
    if floor == nil or not OF.util.alive(floor) then
        return OF.lang.t("Floor: none - you are over nothing")
    end
    local kind = SURFACE_WORDS[floor.type]
        or string.format("type %.0f", floor.type or 0)
    local grip = SURFACE_GRIP[OF.util.optional("mario_get_floor_class", -1, m)]
        or "?"
    local up = 1.0
    if floor.normal ~= nil and floor.normal.y ~= nil then up = floor.normal.y end
    if up > 1.0 then up = 1.0 end
    if up < -1.0 then up = -1.0 end
    local steep = math.deg(math.acos(up))
    return string.format("Floor: %s   %s   %.0f deg", kind, grip, steep)
end

local OBJECT_LISTS = {}
do
    local list = { OBJ_LIST_PLAYER, OBJ_LIST_DESTRUCTIVE, OBJ_LIST_GENACTOR,
                   OBJ_LIST_PUSHABLE, OBJ_LIST_LEVEL, OBJ_LIST_DEFAULT,
                   OBJ_LIST_SURFACE, OBJ_LIST_POLELIKE, OBJ_LIST_SPAWNER,
                   OBJ_LIST_UNIMPORTANT }
    for i = 1, 10 do
        if list[i] ~= nil then table.insert(OBJECT_LISTS, list[i]) end
    end
end

local LOAD_EVERY = 30
local LOAD_NEAR = 1500.0

local function count_objects(m)
    if obj_get_first == nil or obj_get_next == nil then return nil, nil end
    local total, near = 0, 0
    local reach = LOAD_NEAR * LOAD_NEAR
    for _, which in ipairs(OBJECT_LISTS) do
        local o = obj_get_first(which)
        while o ~= nil do
            total = total + 1
            if m ~= nil and m.pos ~= nil then
                local dx = m.pos.x - (o.oPosX or 0)
                local dy = m.pos.y - (o.oPosY or 0)
                local dz = m.pos.z - (o.oPosZ or 0)
                if dx * dx + dy * dy + dz * dz < reach then near = near + 1 end
            end
            o = obj_get_next(o)
        end
    end
    return total, near
end

local function load_line(m)
    cheats.loadWait = (cheats.loadWait or 0) + 1
    if cheats.loadTotal == nil or cheats.loadWait >= LOAD_EVERY then
        cheats.loadWait = 0
        cheats.loadTotal, cheats.loadNear = count_objects(m)
    end
    if cheats.loadTotal == nil then return nil end
    return string.format("Objects %.0f   near you %.0f", cheats.loadTotal,
        cheats.loadNear or 0)
end

local function stopwatch_line()
    if OF.util.asks(OF.speedrun, "is_running") and OF.speedrun.is_running() then
        return nil
    end
    local frames = cheats.levelFrames or 0
    if OF.util.asks(OF.speedrun, "format_time") then
        return OF.lang.fill("In this level @", OF.speedrun.format_time(frames))
    end
    return OF.lang.fill("In this level @s", math.floor(frames / 30))
end

local function degrees(angle)
    return math.floor(((angle or 0) * 360 / 65536) % 360)
end

local function facing_line(m)
    return string.format("Facing %.0f   Floor %.0f",
        degrees(m.faceAngle.y), degrees(m.floorAngle))
end

local function height_line(m)
    if m.pos == nil then return nil end
    local y = tonumber(m.pos.y) or 0
    local up = y - (tonumber(m.floorHeight) or 0)
    if up < 0 then up = 0 end
    local fallen = (tonumber(m.peakHeight) or 0) - y
    if fallen < 0 then fallen = 0 end
    return string.format("Up %.0f   Fallen %.0f", up, fallen)
end

do
local HITBOX_SEGMENTS = 20
local HITBOX_LINE = 2

local HITBOX_PVP_SCALE = 1.75

local function hitbox_base(m)
    local obj = m.marioObj
    if obj == nil then return nil end
    local body = m.marioBodyState
    local torso = body ~= nil and body.torsoPos or nil
    if torso == nil or torso.y == nil then return nil end
    return { x = torso.x, y = torso.y - (obj.hitboxDownOffset or 0), z = torso.z }
end

local function hitbox_feet(m)
    local obj = m.marioObj
    if obj == nil then return nil end
    local y = tonumber(obj.oPosY)
    if y == nil then return nil end
    return { x = tonumber(obj.oPosX) or 0,
             y = y - (tonumber(obj.hitboxDownOffset) or 0),
             z = tonumber(obj.oPosZ) or 0 }
end

do
local ATTACK_ARC_HAND = 0x2AAA
local ATTACK_ARC_TRIP = 0x4000

local ATTACK_ARC_WATER = 0x25C8
local ATTACK_FAST = 26.0

local function attack_arc(m)
    local action = tonumber(m.action) or 0
    if action == ACT_WATER_PUNCH then return ATTACK_ARC_WATER end
    if not OF.util.has_flag(action, ACT_FLAG_ATTACKING) then return nil end

    local flags = tonumber(m.flags) or 0
    if OF.util.has_flag(flags, MARIO_PUNCHING)
        or OF.util.has_flag(flags, MARIO_KICKING) then
        return ATTACK_ARC_HAND
    end
    if OF.util.has_flag(flags, MARIO_TRIPPING) then return ATTACK_ARC_TRIP end

    local down = (m.vel ~= nil and (tonumber(m.vel.y) or 0) or 0) < 0
    if down and (action == ACT_GROUND_POUND or action == ACT_TWIRLING) then
        return 0
    end
    if down and (tonumber(m.actionState) or 0) == 0
        and (action == ACT_GROUND_POUND_LAND or action == ACT_TWIRL_LAND) then
        return 0
    end
    if action == ACT_SLIDE_KICK or action == ACT_SLIDE_KICK_SLIDE then return 0 end
    if OF.util.has_flag(action, ACT_FLAG_RIDING_SHELL) then return 0 end

    if action ~= ACT_PUNCHING and action ~= ACT_MOVE_PUNCHING
        and action ~= ACT_JUMP_KICK then
        local speed = tonumber(m.forwardVel) or 0
        if speed <= -ATTACK_FAST or speed >= ATTACK_FAST then return 0 end
    end
    return nil
end

cheats.attack_arc = attack_arc
end

local HITBOX_FAR = 8000

local HITBOX_NEAR = 1500
local HITBOX_SEGMENTS_FAR = 10
local HITBOX_UPRIGHTS = 6
local HITBOX_UPRIGHTS_FAR = 4

local function detail_at(flatDist)
    if flatDist <= HITBOX_NEAR then return 1.0 end
    local span = HITBOX_FAR - HITBOX_NEAR
    if span <= 0 then return 0.0 end
    local far = (flatDist - HITBOX_NEAR) / span
    if far > 1 then far = 1 end
    return 1.0 - far
end

local HITBOX_FOOT_R, HITBOX_FOOT_G, HITBOX_FOOT_B = 150, 235, 150
local HITBOX_HURT_R, HITBOX_HURT_G, HITBOX_HURT_B = 255, 70, 70

local HITBOX_ALPHA_FAR = 110
local HITBOX_ALPHA_NEAR = 255

local function draw_one_hitbox(m, mine, r, g, b, detail)
    local obj = m.marioObj
    if obj == nil then return 0 end
    local base = hitbox_base(m)
    if base == nil then return 0 end
    local radius = tonumber(obj.hitboxRadius) or 0
    local height = tonumber(obj.hitboxHeight) or 0
    if radius <= 0 or height <= 0 then return 0 end

    detail = detail or 1.0
    local segments = math.floor(HITBOX_SEGMENTS_FAR
        + (HITBOX_SEGMENTS - HITBOX_SEGMENTS_FAR) * detail)
    local uprights = math.floor(HITBOX_UPRIGHTS_FAR
        + (HITBOX_UPRIGHTS - HITBOX_UPRIGHTS_FAR) * detail)

    local alpha = math.floor(HITBOX_ALPHA_FAR
        + (HITBOX_ALPHA_NEAR - HITBOX_ALPHA_FAR) * detail)

    local arc = cheats.attack_arc(m)
    if arc ~= nil then
        local gold = OF.util.gold()
        local dr = HITBOX_HURT_R - (tonumber(gold.r) or 0)
        local dg = HITBOX_HURT_G - (tonumber(gold.g) or 0)
        local db = HITBOX_HURT_B - (tonumber(gold.b) or 0)
        if dr * dr + dg * dg + db * db < 3000 then
            r, g, b = 255, 235, 40
        else
            r, g, b = HITBOX_HURT_R, HITBOX_HURT_G, HITBOX_HURT_B
        end
    end

    local drawn = 0
    local feet = hitbox_feet(m)
    if feet ~= nil then
        local fr, fg, fb = HITBOX_FOOT_R, HITBOX_FOOT_G, HITBOX_FOOT_B
        if arc ~= nil then fr, fg, fb = r, g, b end
        drawn = drawn + (OF.util.world_column(feet, radius, height, segments,
            HITBOX_LINE, uprights, fr, fg, fb, alpha) or 0)
    end

    drawn = drawn + (OF.util.world_column(base, radius, height, segments,
        HITBOX_LINE, uprights, r, g, b, alpha) or 0)

    if arc ~= nil and feet ~= nil then
        drawn = drawn + (OF.util.world_wedge(feet,
            radius * 2 * HITBOX_PVP_SCALE, tonumber(m.faceAngle.y) or 0, arc,
            segments, HITBOX_LINE, r, g, b, alpha) or 0)
    elseif mine and feet ~= nil then

        drawn = drawn + (OF.util.world_ring(feet, radius * 2 * HITBOX_PVP_SCALE,
            segments, 1, r, g, b, math.floor(alpha * 0.45)) or 0)
    end
    return drawn
end

local HITBOX_OBJ_LISTS = {
    OBJ_LIST_GENACTOR, OBJ_LIST_PUSHABLE, OBJ_LIST_DESTRUCTIVE,
    OBJ_LIST_POLELIKE, OBJ_LIST_LEVEL, OBJ_LIST_SURFACE, OBJ_LIST_DEFAULT,
}

local HITBOX_OBJ_MAX = 12
local HITBOX_OBJ_GUARD = 512

local function draw_object_hitboxes(here, mine, detail_at)
    if not cheats.is_on("hitboxobj") then return 0 end
    if OF.util.binding("obj_get_first") == nil then return 0 end

    local near = {}
    for _, list in ipairs(HITBOX_OBJ_LISTS) do
        local object = obj_get_first(list)
        local guard = 0
        while object ~= nil and guard < HITBOX_OBJ_GUARD do
            guard = guard + 1
            if object.activeFlags ~= 0
                and (tonumber(object.oInteractType) or 0) ~= 0
                and (tonumber(object.hitboxRadius) or 0) > 0
                and (tonumber(object.hitboxHeight) or 0) > 0 then
                local dx = (tonumber(object.oPosX) or 0) - mine.pos.x
                local dz = (tonumber(object.oPosZ) or 0) - mine.pos.z
                local flat = math.sqrt(dx * dx + dz * dz)
                if flat <= HITBOX_FAR then
                    near[#near + 1] = { object = object, flat = flat }
                end
            end
            object = obj_get_next(object)
        end
    end

    table.sort(near, function(a, b) return a.flat < b.flat end)

    local drawn = 0
    for index = 1, math.min(#near, HITBOX_OBJ_MAX) do
        local one = near[index]
        local object = one.object
        local detail = detail_at(one.flat)
        local segments = math.floor(HITBOX_SEGMENTS_FAR
            + (HITBOX_SEGMENTS - HITBOX_SEGMENTS_FAR) * detail)
        local uprights = math.floor(HITBOX_UPRIGHTS_FAR
            + (HITBOX_UPRIGHTS - HITBOX_UPRIGHTS_FAR) * detail)
        local alpha = math.floor(60 + 110 * detail)
        local base = {
            x = tonumber(object.oPosX) or 0,
            y = (tonumber(object.oPosY) or 0)
                - (tonumber(object.hitboxDownOffset) or 0),
            z = tonumber(object.oPosZ) or 0,
        }

        drawn = drawn + (OF.util.world_column(base,
            tonumber(object.hitboxRadius) or 0,
            tonumber(object.hitboxHeight) or 0,
            segments, HITBOX_LINE, uprights,
            HITBOX_FOOT_R, HITBOX_FOOT_G, HITBOX_FOOT_B, alpha) or 0)
    end
    return drawn
end

cheats.hitboxDrawn = 0

function cheats.hitbox_lines()
    return cheats.hitboxDrawn
end

local function render_hitboxes()
    cheats.hitboxDrawn = 0
    if not cheats.is_on("hitbox") and not cheats.is_on("hitboxobj") then
        return
    end

    if OF.util.menu_has_screen() then return end
    if not OF.util.asks(OF.util, "world_ring") then return end
    local me = gNetworkPlayers[0]
    if me == nil then return end
    local mine = gMarioStates[0]
    if mine == nil or mine.pos == nil then return end

    local gold = OF.util.gold()
    local drawn = draw_object_hitboxes(me, mine, detail_at)
    if not cheats.is_on("hitbox") then
        cheats.hitboxDrawn = drawn
        return
    end
    for _, entry in ipairs(OF.util.connected_players()) do
        local m = gMarioStates[entry.localIndex]
        local np = entry.np

        local here = entry.localIndex == 0
            or (OF.util.same_world(entry.localIndex)
                and not (OF.util.asks(OF.roundscope, "hides_body")
                    and OF.roundscope.hides_body(entry.localIndex)))
        if m ~= nil and m.pos ~= nil and np ~= nil and here then
            local own = entry.localIndex == 0
            local dx = m.pos.x - mine.pos.x
            local dz = m.pos.z - mine.pos.z
            if own or dx * dx + dz * dz <= HITBOX_FAR * HITBOX_FAR then

                local r, g, b = 130, 200, 255
                if own then r, g, b = gold.r, gold.g, gold.b end

                local detail = own and 1.0
                    or detail_at(math.sqrt(dx * dx + dz * dz))
                drawn = drawn + draw_one_hitbox(m, own, r, g, b, detail)
            end
        end
    end
    cheats.hitboxDrawn = drawn
end

hook_event(HOOK_ON_HUD_RENDER, render_hitboxes)
end

local COST_ROWS = 6

local costRowWas = nil

local function render_cost()
    local wanted = cheats.is_on("cost")

    if wanted ~= costRowWas then
        costRowWas = wanted
        if OF.util.asks(OF, "watch_cost") then
            if wanted then
                OF.watch_cost(true)
            elseif not OF.wireWatch then
                OF.watch_cost(false)
            end
        end
    end
    if not wanted then return end

    if OF.util.menu_has_screen() then return end
    if not OF.util.asks(OF, "hook_costs") then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    local worst = OF.hook_costs(COST_ROWS)
    if #worst == 0 then
        OF.util.text(OF.lang.t("Frame cost: nothing measured yet"),
            16, 220, 0.6, 200, 200, 200, 220)
        return
    end

    OF.util.text(OF.lang.t("Worst frame since this was switched on"),
        16, 220, 0.6, OF.util.gold().r, OF.util.gold().g, OF.util.gold().b, 230)
    for index, entry in ipairs(worst) do

        local ms = entry.seconds * 1000
        local r, g, b = 220, 220, 220
        if ms >= 16 then r, g, b = 255, 80, 80 end
        OF.util.text(string.format("%s   %.1f ms", entry.name, ms),
            16, 220 + index * 14, 0.55, r, g, b, 220)
    end
end

hook_event(HOOK_ON_HUD_RENDER, render_cost)

local METER_MARGIN = 20

local function render_meter()

    if OF.util.round_meter_render() then return end
    if not cheats.is_on("meter") then return end
    if OF.util.menu_has_screen() then return end

    if OF.util.game_hud_hidden() then return end
    local m = gMarioStates[0]
    if m == nil then return end
    if hud_render_power_meter == nil then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_color(255, 255, 255, 255)

    local size = cheats.setting("meter", "size", 64)
    local x = djui_hud_get_screen_width() - METER_MARGIN - size
    local y = djui_hud_get_screen_height() - METER_MARGIN - size
    hud_render_power_meter(m.health or 0, x, y, size, size)
end

hook_event(HOOK_ON_HUD_RENDER, render_meter)

local function render_readouts()
    if OF.util.menu_has_screen() then return end
    local m = gMarioStates[0]
    if m == nil then return end

    local lines = nil

    if cheats.is_on("timer") then
        local said = stopwatch_line()
        if said ~= nil then lines = lines or {}; lines[#lines + 1] = said end
    end
    if cheats.is_on("coords") then lines = lines or {}; lines[#lines + 1] = coords_line(m) end
    if cheats.is_on("facing") then lines = lines or {}; lines[#lines + 1] = facing_line(m) end
    if cheats.is_on("height") then
        local said = height_line(m)
        if said ~= nil then lines = lines or {}; lines[#lines + 1] = said end
    end
    if cheats.is_on("act") then lines = lines or {}; lines[#lines + 1] = action_line(m) end
    if cheats.is_on("vitals") then lines = lines or {}; lines[#lines + 1] = vitals_line(m) end
    if cheats.is_on("surface") then lines = lines or {}; lines[#lines + 1] = surface_line(m) end
    if cheats.is_on("clocks") then lines = lines or {}; lines[#lines + 1] = clocks_line(m) end
    if cheats.is_on("load") then
        local said = load_line(m)
        if said ~= nil then lines = lines or {}; lines[#lines + 1] = said end
    end

    if lines == nil or #lines == 0 then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    local height = OF.util.line_height(READOUT_SCALE)
    local bottom = djui_hud_get_screen_height() - READOUT_BOTTOM

    if OF.util.asks(OF.tas, "pad_rect") then
        local _, padTop = OF.tas.pad_rect()
        if padTop ~= nil then bottom = math.min(bottom, padTop - READOUT_GAP) end
    end
    local y = bottom - #lines * (height + READOUT_GAP)

    for _, line in ipairs(lines) do
        OF.util.text(line, READOUT_LEFT, y, READOUT_SCALE, 255, 255, 255, 255)
        y = y + height + READOUT_GAP
    end

    djui_hud_set_font(FONT_NORMAL)
end

hook_event(HOOK_ON_HUD_RENDER, render_readouts)

hook_event(HOOK_ON_PACKET_RECEIVE, on_packet_receive)

local flying = false

local function room_changed()
    cheats.apply_scale()

    local wants = cheats.is_on("noclip")
    if wants ~= flying then
        flying = wants
        if wants then
            OF.util.enter_mode("noclip")
        else
            OF.util.leave_mode("noclip")
        end
    end
end

cheats.room_changed = room_changed

for _, wireKey in ipairs(cheats.WIRE_KEYS) do
    hook_on_sync_table_change(gGlobalSyncTable, wireKey, wireKey, function()

        if OF.util.asks(OF.guard, "repair") and OF.guard.repair(wireKey) then
            return
        end
        room_changed()
    end)
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, function(m)
    if m == nil then return end

    cheats.apply_unseen(m)

    if m.playerIndex ~= 0 then return end

    cheats.levelFrames = (cheats.levelFrames or 0) + 1

    cheats.spentA = false

    cheats.wasHealth = m.health
    cheats.wasHurt = m.hurtCounter
    cheats.wasAir = OF.util.has_flag(m.action, ACT_FLAG_AIR)
    cheats.wasFall = m.vel.y

    cheats.wasAction = m.action
    cheats.wasSquish = m.squishTimer

    cheats.wasYaw = m.faceAngle ~= nil and m.faceAngle.y or nil

    cheats.wasVel = m.forwardVel
    cheats.wasVelFrame = frame_now()

    cheats.hurtMark = m.hurtCounter

    cheats.sizeMark = m.hurtCounter

    if not cheats.is_on("blj") then
        cheats.bljCarried = nil
        return
    end

    if m.action == ACT_LONG_JUMP and (m.forwardVel or 0) < 0 then
        cheats.bljCarried = m.forwardVel
    elseif m.action ~= ACT_LONG_JUMP_LAND then
        cheats.bljCarried = nil
    end

    if m.action == ACT_LONG_JUMP
        and (m.forwardVel or 0) < BLJ_BACKWARDS
        and OF.util.has_flag(m.controller.buttonDown, Z_TRIG) then
        m.vel.y = BLJ_SLAM
    end
end)

hook_event(HOOK_MARIO_UPDATE, update_mario)

function cheats.after_star(m)
    if m == nil then return ACT_FREEFALL end
    local now = m.action
    if OF.util.has_flag(m.flags, MARIO_WING_CAP)
        and (now == ACT_FLYING or now == ACT_FLYING_TRIPLE_JUMP
            or now == ACT_SHOT_FROM_CANNON) then
        return ACT_FLYING
    end
    if OF.util.action_group(now) == OF.util.action_group(ACT_GROUP_SUBMERGED) then
        local metalFall = rawget(_G, "ACT_METAL_WATER_FALLING")
        if OF.util.has_flag(now, ACT_FLAG_METAL_WATER) and metalFall ~= nil then
            return metalFall
        end
        return ACT_WATER_IDLE
    end
    return ACT_FREEFALL
end

function cheats.keep_cap_after_star(m)
    if m == nil then return end
    local had = cheats.capBeforeStar
    if type(had) ~= "number" or had <= 1 then return end
    if m.capTimer == 1 then m.capTimer = had end
end

function cheats.round_keeps_the_dance()
    local modes = OF.gamemodes
    if modes == nil or modes.state == nil or modes.state() == modes.OFF then
        return false
    end

    local current = OF.util.asks(modes, "current") and modes.current() or nil
    local given = current ~= nil and type(current.cheatsGiven) == "table"
        and current.cheatsGiven.nodance or nil
    if given ~= nil and given ~= 0 and given ~= false then return false end
    if not OF.util.asks(OF.roundscope, "inside") then return true end
    return OF.roundscope.inside(0) == true
end

hook_event(HOOK_BEFORE_SET_MARIO_ACTION, function(m, action, actionArg)
    if m == nil or m.playerIndex ~= 0 then return end

    local ejected = cheats.eject_exit(m, action)
    if ejected ~= nil then return ejected end

    if STAR_DANCES[action] == true and cheats.is_on("nodance")
        and not cheats.round_keeps_the_dance() then
        if (tonumber(actionArg) or 0) % 2 == 0
            and OF.util.asks(OF.music, "owe_restart_after_star") then
            OF.music.owe_restart_after_star()
        end
        cheats.keep_cap_after_star(m)
        return cheats.after_star(m)
    end

    if action ~= ACT_LONG_JUMP then return end
    if not cheats.is_on("blj") then return end

    if (m.forwardVel or 0) <= 0 then return end

    if (m.intendedMag or 0) <= 8 then return end
    if OF.util.optional("analog_stick_held_back", 0, m) == 0 then return end

    if OF.util.asks(OF.rules, "denied_move")
        and OF.rules.denied_move(m, action) ~= nil then return end

    m.forwardVel = -m.forwardVel
end)

cheats.ALSO_LOBBY = {
    nofall  = "softland",
    speed   = "quick",
    lowgrav = "lowgrav",
    giant   = "giant",
    tiny    = "tiny",
}

function cheats.lobby_already(key)
    local mod = cheats.ALSO_LOBBY[key]
    if mod == nil then return nil end
    if not (OF.util.asks(OF.modifiers, "is_on") and OF.modifiers.is_on(mod)) then
        return nil
    end
    if OF.util.asks(OF.modifiers, "covers_cheat")
        and not OF.modifiers.covers_cheat(mod) then
        return nil
    end
    local entry = OF.modifiers.BY_KEY[mod]
    return OF.lang.fill("The lobby has this already - @, for everybody",
        entry ~= nil and entry.name or mod)
end

function cheats.entry_row(panel, entry, heldByRound)
    local key = entry.key
    local steps = cheats.step_count(entry)

    local room = cheats.room_on(key)
    local mine = cheats.mine_state(key)

    local level, yours = cheats.in_force(key)
    local on = level > 0

    local r, g, b = 255, 255, 255
    if on then r, g, b = 120, 255, 140 end

    if heldByRound then
        r, g, b = 130, 130, 130
    end

    local help = cheats.lobby_already(key) or entry.blurb

    if cheats.suspended(key) then
        help = OF.lang.t(
            "put away until the round ends - your setting is kept")
    end

    local function step_after(from)
        if steps <= 1 then return from > 0 and 0 or 1 end
        local next = from + 1
        if next > steps then next = 0 end
        return next
    end

    local built = panel.with_help(panel.two_box({
        lobbyOn = room,

        mineBox = panel.mine_shown(mine, room),
        name = OF.lang.t(entry.name),
        lobbyNeed = "cheats_lobby",
        mineNeed = "cheats_self",
        r = r, g = g, b = b,
        onLobby = function()
            OF.util.report(cheats.set_room_level(key,
                step_after(cheats.room_level(key) or 0)))
        end,

        onMine = function()

            local mineAt = cheats.in_force(key, true)
            local want = panel.next_mine_level(mine, mineAt, steps,
                cheats.room_level(key) or 0)
            if want == nil then
                OF.util.report(cheats.set_mine(key, nil))
                return
            end
            OF.util.report(cheats.set_level(key, want))
        end,

    }), OF.util.say_buttons(help ~= nil and OF.lang.t(help) or nil, true))

    local stop = nil
    if steps > 1 and on then
        stop = cheats.stop_name_at(key, level)
        if stop ~= nil then stop = OF.lang.t(stop) end
    end

    local column = panel.two_box_level(stop, yours)
    if mine == false then

        column = panel.two_box_level(OF.lang.t("off"), true)
    end

    local youPart = nil
    if steps > 1 then
        local roomAt = cheats.room_level(key)
        local roomStop = roomAt ~= nil and cheats.stop_name_at(key, roomAt) or nil
        if roomStop ~= nil then roomStop = OF.lang.t(roomStop) end
        local mineStop = nil
        if mine == false then mineStop = OF.lang.t("off")
        elseif mine == true then
            mineStop = cheats.stop_name_at(key, level)
            if mineStop ~= nil then mineStop = OF.lang.t(mineStop) end
        end
        column, youPart = panel.two_box_column(roomStop, mineStop, mine ~= nil)
    end
    built = panel.level_right(built, on or column ~= nil, column)
    built.rightMine = youPart

    if steps > 1 then

        local roomAt = cheats.room_level(key) or 0
        local mineAt = nil
        if mine == false then mineAt = 0 elseif mine == true then mineAt = level end
        local function name_at(stopAt)
            if stopAt == nil then return OF.lang.t("follow lobby") end
            if stopAt <= 0 then return OF.lang.t("off") end
            local said = cheats.stop_name_at(key, stopAt)
            return said ~= nil and OF.lang.t(said) or tostring(stopAt)
        end
        built = panel.two_slider(built, {
            steps = steps, room = roomAt, mine = mineAt,
            mayRoom = panel.may("cheats_lobby"), mayMine = panel.may("cheats_self"),
            setRoom = function(wanted)
                OF.util.report(cheats.set_room_level(key, wanted))
            end,

            setMine = function(wanted)
                OF.util.report(cheats.set_level(key, wanted))
            end,
            clearMine = function()
                OF.util.report(cheats.set_mine(key, nil))
            end,
            roomNext = name_at(step_after(roomAt)),
            mineNext = name_at(panel.next_mine_level(mine,
                cheats.in_force(key, true), steps, roomAt)),
        })
    end

    built.catalogue = "cheat"
    return built
end

function cheats.page_rows(panel, page)
    local rows = {}
    local heldByRound = OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down()
    for _, entry in ipairs(cheats.LIST) do
        if entry.drawnOn == page then
            table.insert(rows, cheats.entry_row(panel, entry, heldByRound))
        end
    end
    return rows
end

function cheats.group_rows(panel, part, heldByRound)
    local rows = {}
    for _, group in ipairs(cheats.grouped(part)) do

        table.insert(rows, panel.with_help(
            panel.sub_header_row(OF.lang.t(group.name)),
            group.help ~= nil and OF.lang.t(group.help) or nil))
        for _, entry in ipairs(group.entries) do
            table.insert(rows, cheats.entry_row(panel, entry, heldByRound))
        end

        if group.name == "Nothing interrupts you" then
            table.insert(rows, panel.with_help(
                panel.row(OF.lang.t("Boxes this lobby never shows"),
                    255, 255, 255, function() panel.go("cheatboxes") end),
                OF.lang.t("a short, named list of specific text boxes that stay closed - not the blanket switch above")))
        end
    end

    return rows
end

function cheats.build_rows(panel, part)
    local rows = {}
    part = part or "cheats"
    table.insert(rows, panel.label_row(OF.lang.t(
        "A ticks the lobby's box, Z yours - and yours wins.")))

    if part == "readouts" then
        local readoutsHeld = OF.util.asks(OF.lockdown, "menu_stands_down")
            and OF.lockdown.menu_stands_down()
        if readoutsHeld then
            table.insert(rows, panel.label_row(
                OF.lang.t("A round is on - these come back when it ends.")))
        end
        for _, row in ipairs(cheats.group_rows(panel, "readouts",
                readoutsHeld)) do
            table.insert(rows, row)
        end
        return rows
    end

    local heldByRound = OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down()
    if heldByRound then
        table.insert(rows, panel.label_row(
            OF.lang.t("A round is on - these come back when it ends.")))
    end

    table.insert(rows, panel.with_help(
        panel.gated_row("cheats_lobby",
            OF.lang.t("Reset this page"), 255, 200, 120,
            function()

                OF.util.report(cheats.clear_room())
            end),
        OF.lang.t("every cheat in the lobby's boxes, for everybody at once")))

    table.insert(rows, panel.with_help(
        panel.row(OF.lang.t("Reset this page, your own boxes only"), 255, 200, 120,
            function()
                cheats.clear_local()
            end),
        OF.lang.t("every box of your own emptied, so the lobby's apply again")))

    for _, row in ipairs(cheats.group_rows(panel, "cheats", heldByRound)) do
        table.insert(rows, row)
    end

    return rows
end
