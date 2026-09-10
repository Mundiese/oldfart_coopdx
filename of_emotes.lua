OF = OF or {}
OF.emotes = OF.emotes or {}

local emotes = OF.emotes

local CONTINUE = -1

local function at_load(name)
    local fn = _G[name]
    if type(fn) ~= "function" then
        emotes.missing = emotes.missing or {}
        emotes.missing[name] = true
        return nil
    end
    return fn
end

local setAnimation = at_load("set_character_animation")
local setForwardVel = at_load("mario_set_forward_vel")
local hookAction = at_load("hook_mario_action")

local sayIt = at_load("play_character_sound")

emotes.PLAYS_OVER = { ACT_IDLE, ACT_PANTING, ACT_STANDING_AGAINST_WALL }

local playsOver = {}
for _, action in ipairs(emotes.PLAYS_OVER) do playsOver[action] = true end

function emotes.plays_over(action)
    return playsOver[action] == true
end

local ready = false
function emotes.ready() return ready end

emotes.HOLD_MAX = 1200
emotes.GESTURE = 90

emotes.POSE_TAIL = 90

emotes.GESTURE_MIN = 40

emotes.GAP = 30

local ANIM_WAVE   = 0x1D
local ANIM_PEACE  = 0x27

local ANIM_POINT  = 0x65

local ANIM_SPIN   = 0xB3
local ANIM_SIT    = 0x84
local ANIM_STATUE = 0x0E
local ANIM_CHEER  = 0xCD
local ANIM_SALUTE = 0x22

local ANIM_LOOKUP = 0x1E
local ANIM_YAWN   = 0x83
local ANIM_SHIVER = 0x1B
local ANIM_PUZZLE = 0x82
local ANIM_COUGH  = 0x30
local ANIM_SWEEP  = 0x71
local ANIM_HANDS  = 0x09
local ANIM_NAP    = 0x87

local ANIM_TADA    = 0x9C
local ANIM_UPSIDE  = 0x39
local ANIM_LEAN    = 0x7E
local ANIM_CROUCH  = 0x98
local ANIM_HEAVE   = 0x6C
local ANIM_FLOP    = 0x2C
local ANIM_SNEAK   = 0x92
local ANIM_STRETCH = 0xC8
local ANIM_SHOCK   = 0x7A
local ANIM_CRAWL   = 0x99

local ANIM_WARM    = 0x19
local ANIM_SATIN   = 0x3E
local ANIM_PLANTED = 0x55
local ANIM_CAPON   = 0x36
local ANIM_HEAVY   = 0x7D
local ANIM_KEY     = 0x61

local ANIM_PUNCH   = 0x67
local ANIM_KICK    = 0x66
local ANIM_DOZY    = 0x85
local ANIM_FLAIL   = 0x76
local ANIM_SPARKS  = 0x79
local ANIM_GASP    = 0x2F
local ANIM_ONBACK  = 0x03
local ANIM_HANG    = 0x35
local ANIM_LIMP    = 0x58
local ANIM_TREAD   = 0xB2
local ANIM_VICTORY = 0x25
local ANIM_CAPLESS = 0x5E

local ANIM_POCKET  = 0x63
local ANIM_BOWSER  = 0xB8
local ANIM_WAIST   = 0x77
local ANIM_SIDLE   = 0x7F
local ANIM_SURF    = 0x6D
local ANIM_OWL     = 0x2B
local ANIM_TOSS    = 0x31
local ANIM_HOP     = 0x0A
local ANIM_TOPPLE  = 0x01
local ANIM_LIFT    = 0x59
local ANIM_GETUP   = 0x28

local SAY_HELLO   = 36
local SAY_YAHOO   = 2
local SAY_HERE_GO = 11
local SAY_YIPPEE  = 33
local SAY_HAHA    = 16
local SAY_HRMM    = 4
local SAY_OKEY    = 43
local SAY_LETS_GO = 42
local SAY_YAWN    = 12
local SAY_COLD    = 22
local SAY_DOH     = 34
local SAY_COUGH   = 24
local SAY_PUNCH   = 27
local SAY_WAAAOOOW = 15
local SAY_SNORE   = 13
local SAY_TIRED   = 41
local SAY_WHOA    = 6
local SAY_UH      = 3
local SAY_HOOHOO  = 1
local SAY_MAMA    = 29
local SAY_TWIRL   = 38
local SAY_HAHA2   = 17
local SAY_PANT    = 23
local SAY_EEUH    = 7
local SAY_GAMEOVER = 35
local SAY_HOO     = 28

local SAY_SO_LONG = 40

local DUST_SPARKLE = 1 << 3
local DUST_PLAIN   = 1 << 0
local DUST_BREATH  = 1 << 17
local DUST_MIST    = 1 << 16

emotes.CATALOGUE = {
    { id = 1,  key = "wave",   name = "Wave",   anim = ANIM_WAVE,
      hold = false, says = "Hello, and goodbye", voice = SAY_HELLO },
    { id = 2,  key = "peace",  name = "Peace",  anim = ANIM_PEACE,
      hold = false, says = "Thanks - all good", voice = SAY_OKEY },

    { id = 3,  key = "point",  name = "Point",  anim = ANIM_POINT,
      hold = true,  holdFor = emotes.POSE_TAIL,
      says = "Look over here", voice = SAY_HERE_GO },
    { id = 4,  key = "spin",   name = "Spin",   anim = ANIM_SPIN,
      hold = false, says = "Dance", voice = SAY_TWIRL, dust = DUST_SPARKLE },
    { id = 5,  key = "sit",    name = "Sit",    anim = ANIM_SIT,
      hold = true,  says = "I am waiting here", voice = SAY_TIRED },

    { id = 6,  key = "statue", name = "Statue", anim = ANIM_STATUE,
      hold = true,  says = "Stand perfectly still", voice = SAY_HRMM },

    { id = 7,  key = "cheer",  name = "Cheer",  anim = ANIM_CHEER,
      hold = false, says = "Well done", voice = SAY_YIPPEE },
    { id = 8,  key = "salute", name = "Salute", anim = ANIM_SALUTE,
      hold = false, says = "Respect, or sorry", voice = SAY_HOOHOO },
    { id = 9,  key = "lookup", name = "Look up", anim = ANIM_LOOKUP,
      hold = false, says = "It is up there", voice = SAY_WAAAOOOW },
    { id = 10, key = "yawn",   name = "Yawn",   anim = ANIM_YAWN,
      hold = false, says = "This is taking a while", voice = SAY_YAWN },

    { id = 11, key = "shiver", name = "Shiver", anim = ANIM_SHIVER,
      hold = true, says = "It is freezing here", voice = SAY_COLD },
    { id = 12, key = "puzzle", name = "Puzzled", anim = ANIM_PUZZLE,
      hold = false, says = "No idea at all", voice = SAY_DOH },

    { id = 13, key = "cough",  name = "Clear your throat", anim = ANIM_COUGH,
      hold = false, says = "Ahem - over here", voice = SAY_COUGH },

    { id = 14, key = "sweep",  name = "Sweep",  anim = ANIM_SWEEP,
      hold = true,  holdFor = emotes.POSE_TAIL,
      says = "Show off", voice = SAY_PUNCH,
      dust = DUST_PLAIN, dustAt = 0 },
    { id = 15, key = "stand",  name = "Handstand", anim = ANIM_HANDS,
      hold = true,  says = "Upside down on purpose", voice = SAY_HOO },
    { id = 16, key = "nap",    name = "Nap",    anim = ANIM_NAP,
      hold = true,  says = "Wake me when it starts", voice = SAY_SNORE },

    { id = 17, key = "tada",    name = "Ta-da",     anim = ANIM_TADA,
      hold = false, says = "Look what I did", voice = SAY_YAHOO,
      dust = DUST_SPARKLE },

    { id = 18, key = "upside",  name = "Upside down", anim = ANIM_UPSIDE,
      hold = true,  says = "Nothing to see here", voice = SAY_MAMA,
      dust = DUST_MIST, dustAt = 0 },

    { id = 19, key = "lean",    name = "Lean",      anim = ANIM_LEAN,
      hold = true,  says = "Any time you are ready", voice = SAY_HAHA },

    { id = 20, key = "crouch",  name = "Crouch",    anim = ANIM_CROUCH,
      hold = true,  says = "Down at the front", voice = SAY_UH },

    { id = 21, key = "heave",   name = "Heave",     anim = ANIM_HEAVE,
      hold = true,  says = "Out of the way", voice = SAY_EEUH },

    { id = 22, key = "flop",    name = "Face down", anim = ANIM_FLOP,
      hold = true,  says = "I am done", voice = SAY_GAMEOVER },

    { id = 23, key = "sneak",   name = "Tiptoe",    anim = ANIM_SNEAK,
      hold = true,  says = "Quietly, now", voice = SAY_HAHA2 },

    { id = 24, key = "stretch", name = "Stretch",   anim = ANIM_STRETCH,
      hold = false, says = "Right - I am awake", voice = SAY_LETS_GO },

    { id = 25, key = "shock",   name = "Shocked",   anim = ANIM_SHOCK,
      hold = false, says = "You did what?", voice = SAY_WHOA },

    { id = 26, key = "crawl",   name = "Crawl",     anim = ANIM_CRAWL,
      hold = true,  says = "Do not mind me", voice = SAY_PANT },

    { id = 27, key = "warm",    name = "Warm your hands", anim = ANIM_WARM,
      hold = true,  holdFor = emotes.POSE_TAIL,
      says = "Waiting, and waiting", voice = SAY_COLD,
      dust = DUST_BREATH, dustAt = 49 },

    { id = 28, key = "satin",   name = "Sat in the floor", anim = ANIM_SATIN,
      hold = true,  says = "I live here now", voice = SAY_DOH,
      dust = DUST_PLAIN, dustAt = 0 },

    { id = 29, key = "planted", name = "Planted",   anim = ANIM_PLANTED,
      hold = true,  says = "Stuck, and not in a good way", voice = SAY_HRMM },

    { id = 30, key = "capon",   name = "Cap on",    anim = ANIM_CAPON,
      hold = false, says = "How does it look?", voice = SAY_HERE_GO },

    { id = 31, key = "heavy",   name = "Carrying nothing", anim = ANIM_HEAVY,
      hold = true,  says = "This is heavier than it looks", voice = SAY_EEUH },

    { id = 32, key = "key",     name = "Turn a key", anim = ANIM_KEY,
      hold = false, says = "Let me get that", voice = SAY_OKEY },

    { id = 33, key = "punch",   name = "Throw a punch", anim = ANIM_PUNCH,
      hold = false, says = "Come on then", voice = SAY_PUNCH },

    { id = 34, key = "kick",    name = "Kick", anim = ANIM_KICK,
      hold = false, says = "Take that", voice = SAY_HOO },

    { id = 35, key = "dozy",    name = "Asleep on your feet", anim = ANIM_DOZY,
      hold = true,  says = "Still waiting", voice = SAY_SNORE },

    { id = 36, key = "flail",   name = "Going under", anim = ANIM_FLAIL,
      hold = true,  says = "Help, I am sinking", voice = SAY_WHOA,
      dust = DUST_PLAIN, dustAt = 0 },

    { id = 37, key = "sparks",  name = "Zapped", anim = ANIM_SPARKS,
      hold = true,  says = "Do not touch that", voice = SAY_WHOA },

    { id = 38, key = "gasp",    name = "Out of air", anim = ANIM_GASP,
      hold = true,  says = "I cannot breathe in here", voice = SAY_PANT },

    { id = 39, key = "onback",  name = "Flat on your back", anim = ANIM_ONBACK,
      hold = true,  says = "Finished, thanks", voice = SAY_TIRED },

    { id = 40, key = "hang",    name = "Hanging on", anim = ANIM_HANG,
      hold = true,  says = "Not letting go", voice = SAY_HOOHOO },

    { id = 41, key = "limp",    name = "Carry me", anim = ANIM_LIMP,
      hold = true,  says = "You will have to carry me", voice = SAY_UH },

    { id = 42, key = "tread",   name = "Swim on dry land", anim = ANIM_TREAD,
      hold = true,  says = "The floor is water now", voice = SAY_HAHA2 },

    { id = 43, key = "victory", name = "Victory spin", anim = ANIM_VICTORY,
      hold = false, says = "That is the whole game", voice = SAY_YAHOO },

    { id = 44, key = "capless", name = "Where is my cap?", anim = ANIM_CAPLESS,
      hold = false, says = "Has anybody seen it?", voice = SAY_DOH },

    { id = 45, key = "pocket", name = "Search your pockets", anim = ANIM_POCKET,
      hold = true,  says = "Hold on - it is in here somewhere", voice = SAY_HRMM },

    { id = 46, key = "bowser", name = "Bowser by the tail", anim = ANIM_BOWSER,
      hold = true,  says = "Look what I have got", voice = SAY_SO_LONG },

    { id = 47, key = "waist",  name = "Sunk to the waist", anim = ANIM_WAIST,
      hold = true,  says = "The floor has got me", voice = SAY_MAMA },

    { id = 48, key = "sidle",  name = "Sidle away", anim = ANIM_SIDLE,
      hold = true,  says = "Edging out of here", voice = SAY_HAHA2 },

    { id = 49, key = "surf",   name = "Riding the shell", anim = ANIM_SURF,
      hold = true,  says = "Surfing on nothing", voice = SAY_LETS_GO },

    { id = 50, key = "owl",    name = "Hanging off the owl", anim = ANIM_OWL,
      hold = true,  says = "Fly me up there", voice = SAY_HOOHOO },

    { id = 51, key = "toss",   name = "Toss the key", anim = ANIM_TOSS,
      hold = false, says = "Heads up - catch", voice = SAY_HERE_GO },

    { id = 52, key = "hop",    name = "Handstand hop", anim = ANIM_HOP,
      hold = false, says = "Watch this one", voice = SAY_YAHOO },

    { id = 53, key = "topple", name = "Topple over", anim = ANIM_TOPPLE,
      hold = true,  says = "Timber", voice = SAY_DOH },

    { id = 54, key = "lift",   name = "Lift with your knees", anim = ANIM_LIFT,
      hold = false, says = "Give me a hand with this", voice = SAY_EEUH },

    { id = 55, key = "getup",  name = "Pick yourself up", anim = ANIM_GETUP,
      hold = false, says = "I am fine, I am fine", voice = SAY_UH },
}

emotes.BY_KEY = {}
emotes.BY_ID = {}
for _, entry in ipairs(emotes.CATALOGUE) do
    emotes.BY_KEY[entry.key] = entry
    emotes.BY_ID[entry.id] = entry
end

emotes.DEFAULT_SLOTS = { 1, 2, 3, 4, 5, 6, 7, 8 }

emotes.SLOTS = #emotes.DEFAULT_SLOTS

emotes.POINTS = {
    "Up", "Up and right", "Right", "Down and right",
    "Down", "Down and left", "Left", "Up and left",
}

emotes.WHEEL = {}
for position, id in ipairs(emotes.DEFAULT_SLOTS) do
    emotes.WHEEL[position] = emotes.BY_ID[id]
end

function emotes.count() return #emotes.WHEEL end

function emotes.catalogue_count() return #emotes.CATALOGUE end

function emotes.catalogue() return emotes.CATALOGUE end

function emotes.entry_of(key)
    if type(key) ~= "string" then return nil end
    return emotes.BY_KEY[key]
end

local VOICE_KEY = "ofEmoteVoice"
emotes.VOICE_OFF = 0
emotes.VOICE_MINE = 1
emotes.VOICE_ALL = 2

emotes.VOICE_STOPS = {
    [0] = "Silent",
    [1] = "Only mine",
    [2] = "Everybody",
}

local voice = nil

function emotes.voice()
    if voice == nil then

        local stored = mod_storage_load_integer(VOICE_KEY, emotes.VOICE_ALL)
        stored = math.floor(tonumber(stored) or emotes.VOICE_ALL)
        if stored < 0 or stored > emotes.VOICE_ALL then
            stored = emotes.VOICE_ALL
        end
        voice = stored
    end
    return voice
end

function emotes.voice_name()
    return emotes.VOICE_STOPS[emotes.voice()] or "?"
end

function emotes.set_voice(stop)
    stop = math.floor(tonumber(stop) or emotes.VOICE_ALL)
    if stop < 0 or stop > emotes.VOICE_ALL then
        return false, "That is not one of the three."
    end
    voice = stop
    OF.util.store_integer(VOICE_KEY, stop)
    return true
end

function emotes.step_voice()
    return emotes.set_voice((emotes.voice() + 1) % (emotes.VOICE_ALL + 1))
end

function emotes.hears(localIndex)
    local stop = emotes.voice()
    if stop == emotes.VOICE_OFF then return false end
    if stop == emotes.VOICE_MINE then return (localIndex or 0) == 0 end
    return true
end

local SLOTS_KEY = "ofEmoteSlots"
local slotsLoaded = false

local function parse_slots(text)
    local wanted = {}
    if type(text) ~= "string" then return nil end
    for piece in string.gmatch(text, "[^,]+") do
        local id = math.floor(tonumber(piece) or 0)

        if emotes.BY_ID[id] ~= nil then wanted[#wanted + 1] = id end
    end
    if #wanted == 0 then return nil end
    return wanted
end

local function apply_slots(wanted)
    local taken, out = {}, {}
    for _, id in ipairs(wanted or {}) do
        if not taken[id] and #out < emotes.SLOTS then
            taken[id] = true
            out[#out + 1] = id
        end
    end
    for _, id in ipairs(emotes.DEFAULT_SLOTS) do
        if #out >= emotes.SLOTS then break end
        if not taken[id] then
            taken[id] = true
            out[#out + 1] = id
        end
    end

    for _, entry in ipairs(emotes.CATALOGUE) do
        if #out >= emotes.SLOTS then break end
        if not taken[entry.id] then
            taken[entry.id] = true
            out[#out + 1] = entry.id
        end
    end
    for position = 1, emotes.SLOTS do
        emotes.WHEEL[position] = emotes.BY_ID[out[position]]
    end
    return out
end

local function load_slots()
    if slotsLoaded then return end
    slotsLoaded = true
    apply_slots(parse_slots(mod_storage_load(SLOTS_KEY, "")))
end

function emotes.ensure_slots()
    load_slots()
end

function emotes.forget_slots()
    slotsLoaded = false
end

function emotes.slots()
    load_slots()
    local out = {}
    for position, entry in ipairs(emotes.WHEEL) do out[position] = entry.id end
    return out
end

local function save_slots()
    local pieces = {}
    for position, entry in ipairs(emotes.WHEEL) do
        pieces[position] = tostring(entry.id)
    end
    OF.util.store(SLOTS_KEY, table.concat(pieces, ","))
end

function emotes.set_slot(position, id)
    load_slots()
    position = math.floor(tonumber(position) or 0)
    if position < 1 or position > emotes.SLOTS then return false end
    local entry = emotes.BY_ID[math.floor(tonumber(id) or 0)]
    if entry == nil then return false end
    for at, on in ipairs(emotes.WHEEL) do
        if on.id == entry.id then return at == position end
    end
    emotes.WHEEL[position] = entry
    save_slots()
    return true
end

function emotes.step_slot(position)
    load_slots()
    position = math.floor(tonumber(position) or 0)
    local here = emotes.WHEEL[position]
    if here == nil then return false end

    local on = {}
    for at, entry in ipairs(emotes.WHEEL) do
        if at ~= position then on[entry.id] = true end
    end

    local at = 0
    for index, entry in ipairs(emotes.CATALOGUE) do
        if entry.id == here.id then at = index break end
    end
    for step = 1, #emotes.CATALOGUE do
        local entry = emotes.CATALOGUE[((at - 1 + step) % #emotes.CATALOGUE) + 1]
        if not on[entry.id] then
            emotes.WHEEL[position] = entry
            save_slots()
            return true
        end
    end
    return false
end

function emotes.reset_slots()
    load_slots()
    apply_slots(emotes.DEFAULT_SLOTS)
    save_slots()
    return true
end

function emotes.point_of(key)
    load_slots()
    for position, entry in ipairs(emotes.WHEEL) do
        if entry.key == key then return position end
    end
    return nil
end

function emotes.round_is_running()
    if not OF.util.asks(OF.lockdown, "menu_stands_down") then return false end
    return OF.lockdown.menu_stands_down()
end

function emotes.allowed_here()
    return not emotes.round_is_running()
end

function emotes.allowed_for(localIndex)
    if not emotes.allowed_here() then return false end
    if OF.util.asks(OF.jail, "is_jailed") and OF.jail.is_jailed(localIndex) then
        return false
    end

    if OF.util.asks(OF.possess, "hides_from_world")
        and OF.possess.hides_from_world(localIndex) then
        return false
    end

    if OF.util.asks(OF.spectate, "is_spectating")
        and OF.spectate.is_spectating(localIndex) then
        return false
    end
    return true
end

function emotes.may()
    if not ready then
        return false, "This build cannot play emotes."
    end
    if emotes.round_is_running() then
        return false, "Not while a round is running."
    end
    if OF.util.asks(OF.perms, "can") and not OF.perms.can("chat") then
        return false, "Your rank cannot do that.", "chat"
    end

    if OF.util.asks(OF.mute, "is_muted") and OF.mute.is_muted(0) then
        return false, "You are muted."
    end
    if OF.util.asks(OF.jail, "is_jailed") and OF.jail.is_jailed(0) then
        return false, "Not from in there."
    end

    if OF.util.asks(OF.possess, "hides_from_world")
        and OF.possess.hides_from_world(0) then
        return false, "Not while you are a thing."
    end

    if OF.util.asks(OF.spectate, "is_spectating")
        and OF.spectate.is_spectating(0) then
        return false, "Not while you are watching."
    end
    return true
end

local worn = {}

local lastStart = -10000

local ticks = 0
function emotes.clock()
    local timer = OF.util.optional("get_global_timer", nil)
    if type(timer) == "number" then return timer end
    return ticks
end

local function published(localIndex)
    local row = gPlayerSyncTable[localIndex]
    if row == nil then return nil end

    return emotes.BY_ID[row.ofEmote or 0]
end

function emotes.current(localIndex)
    local entry = published(localIndex)
    if entry == nil then return nil end
    local m = gMarioStates[localIndex]
    if m == nil or not playsOver[m.action] then return nil end
    return entry.key
end

function emotes.name_of(localIndex)
    local key = emotes.current(localIndex)
    if key == nil then return nil end
    return emotes.BY_KEY[key].name
end

function emotes.frames_held(localIndex)
    local state = worn[localIndex]
    if state == nil then return 0 end
    return state.frames
end

local function forget(localIndex)
    worn[localIndex] = nil
end

function emotes.stop()
    local row = gPlayerSyncTable[0]
    if row == nil or (row.ofEmote or 0) == 0 then return false end
    forget(0)
    OF.util.publish_row(0, "ofEmote", 0)
    return true
end

function emotes.play(key)
    local entry = emotes.BY_KEY[key]
    if entry == nil then return false, "There is no emote by that name." end

    local may, why, feature = emotes.may()
    if not may then return false, why, feature end

    local m = gMarioStates[0]
    if m == nil then return false, "Not in a level." end

    if not playsOver[m.action] then
        return false, "Stand still on the ground first."
    end

    local now = emotes.clock()
    if now - lastStart < emotes.GAP then return false, "One at a time." end
    lastStart = now

    if gPlayerSyncTable[0] ~= nil and (gPlayerSyncTable[0].ofEmote or 0) ~= 0 then
        OF.util.publish_row(0, "ofEmote", 0)
    end
    forget(0)
    OF.util.publish_row(0, "ofEmote", entry.id)
    return true
end

emotes.COPY_REACH = 1200

function emotes.nearest_emoting()
    local me = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    local mine = gMarioStates ~= nil and gMarioStates[0] or nil
    if me == nil or mine == nil or mine.pos == nil then return nil end
    if not OF.util.asks(OF.util, "connected_players") then return nil end

    local best, bestSquare = nil, emotes.COPY_REACH * emotes.COPY_REACH
    for _, other in ipairs(OF.util.connected_players()) do
        local np = other.np
        if other.localIndex ~= 0 and np ~= nil
            and np.currLevelNum == me.currLevelNum
            and np.currAreaIndex == me.currAreaIndex then
            local key = emotes.current(other.localIndex)
            local om = key ~= nil and gMarioStates[other.localIndex] or nil
            if om ~= nil and om.pos ~= nil then
                local dx = (tonumber(om.pos.x) or 0) - (tonumber(mine.pos.x) or 0)
                local dy = (tonumber(om.pos.y) or 0) - (tonumber(mine.pos.y) or 0)
                local dz = (tonumber(om.pos.z) or 0) - (tonumber(mine.pos.z) or 0)
                local square = dx * dx + dy * dy + dz * dz
                if square < bestSquare then best, bestSquare = key, square end
            end
        end
    end
    return best
end

function emotes.copy_nearby()
    local key = emotes.nearest_emoting()
    if key == nil then
        return false, "Nobody near you is doing anything to join in with."
    end
    return emotes.play(key)
end

function emotes.gesture_frames(loop, flags, startFrame)
    local loopEnd = math.floor(tonumber(loop) or 0)
    flags = math.floor(tonumber(flags) or 0)
    startFrame = math.floor(tonumber(startFrame) or 0)

    if (flags & 1) ~= 0 and startFrame >= 0 and loopEnd > startFrame then
        local once = loopEnd - startFrame
        if once > emotes.HOLD_MAX then return emotes.HOLD_MAX end
        return once
    end

    loop = loopEnd - 1
    if loop < 1 then return emotes.GESTURE end

    local frames = loop
    while frames < emotes.GESTURE_MIN do frames = frames + loop end

    if frames > emotes.HOLD_MAX then return emotes.HOLD_MAX end
    return frames
end

function emotes.pose_frames(loop, flags, startFrame, holdFor)
    holdFor = tonumber(holdFor)
    if holdFor == nil or holdFor < 0 then return emotes.HOLD_MAX end
    local loopEnd = math.floor(tonumber(loop) or 0)
    flags = math.floor(tonumber(flags) or 0)
    startFrame = math.floor(tonumber(startFrame) or 0)

    if (flags & 1) == 0 or startFrame < 0 or loopEnd <= startFrame then
        return emotes.HOLD_MAX
    end

    local total = (loopEnd - startFrame) + math.floor(holdFor)
    if total > emotes.HOLD_MAX then return emotes.HOLD_MAX end
    return total
end

local function anim_loop(m)
    if m == nil then return nil end
    local obj = m.marioObj
    if obj == nil or obj.header == nil then return nil end
    local gfx = obj.header.gfx
    if gfx == nil or gfx.animInfo == nil then return nil end
    local anim = gfx.animInfo.curAnim
    if anim == nil then return nil end
    local loop = anim.loopEnd
    if type(loop) ~= "number" then return nil end

    local flags = anim.flags
    local start = anim.startFrame
    return loop,
        type(flags) == "number" and flags or nil,
        type(start) == "number" and start or nil
end

local WALK_OUT = 20

local function should_end(m, index, entry, frames, state)
    if not emotes.allowed_for(index) then return "room" end
    local loop = state ~= nil and state.loop or nil
    local flags = state ~= nil and state.flags or nil
    local start = state ~= nil and state.start or nil
    local cap
    if entry.hold then
        cap = emotes.pose_frames(loop, flags, start, entry.holdFor)
    else
        cap = emotes.gesture_frames(loop, flags, start)
    end
    if frames > cap then

        if entry.hold and cap >= emotes.HOLD_MAX then return "capped" end
        return "done"
    end
    if index ~= 0 then return nil end
    local c = m.controller
    if c ~= nil then
        local pressed = c.buttonPressed or 0
        local mag = c.stickMag or 0

        if state ~= nil and not state.armed then
            if mag <= WALK_OUT then state.armed = true end
        elseif mag > WALK_OUT then
            return "moved"
        end
        if pressed ~= 0 then return "moved" end
    end
    return nil
end

emotes.should_end = should_end

local function act_emote(m)
    if m == nil then return CONTINUE end
    local index = m.playerIndex or 0

    local entry = published(index)
    if entry == nil then
        forget(index)
        return CONTINUE
    end

    local state = worn[index]
    if state == nil or state.id ~= entry.id then

        state = { id = entry.id, frames = 0, done = false, armed = false,
                  voiced = false }
        worn[index] = state
    end
    if state.done then return CONTINUE end

    local frames = state.frames + 1
    state.frames = frames

    local over = should_end(m, index, entry, frames, state)
    if over ~= nil then
        state.done = true
        state.frames = 0

        if index == 0 then emotes.stop() end
        return CONTINUE
    end

    if not state.voiced then
        state.voiced = true
        if sayIt ~= nil and entry.voice ~= nil and emotes.hears(index) then
            sayIt(m, entry.voice)
        end
    end

    if index == 0 and entry.dust ~= nil
        and (entry.dustAt == nil or entry.dustAt == frames - 1) then
        m.particleFlags = (m.particleFlags or 0) | entry.dust
    end

    setAnimation(m, entry.anim)

    if state.loop == nil then
        state.loop, state.flags, state.start = anim_loop(m)
    end

    setForwardVel(m, 0)

    return
end

emotes.act_emote = act_emote

if setAnimation ~= nil and setForwardVel ~= nil and hookAction ~= nil then
    ready = true
    for _, action in ipairs(emotes.PLAYS_OVER) do
        if not pcall(hookAction, action, { every_frame = act_emote }) then
            ready = false
        end
    end
end

emotes.open = false
emotes.choice = 1
emotes.last = 1

emotes.OPEN_FRAMES = 6

emotes.phase = 0

function emotes.appearance(phase)
    phase = math.floor(tonumber(phase) or 0)
    if phase <= 0 then return 0 end
    if phase >= emotes.OPEN_FRAMES then return 1 end
    return phase / emotes.OPEN_FRAMES
end

function emotes.showing()
    return emotes.phase > 0
end

local function step_phase()
    if emotes.open then
        if emotes.phase < emotes.OPEN_FRAMES then
            emotes.phase = emotes.phase + 1
        end
    elseif emotes.phase > 0 then
        emotes.phase = emotes.phase - 1
    end
end

local STICK_DEAD = 30

function emotes.sector(stickX, stickY)
    local x, y = stickX or 0, stickY or 0
    if (x * x + y * y) < (STICK_DEAD * STICK_DEAD) then return nil end

    local angle = math.atan(x, y)
    local slice = 2 * math.pi / #emotes.WHEEL
    local index = math.floor((angle + slice / 2) / slice)
    index = index % #emotes.WHEEL
    return index + 1
end

function emotes.close_wheel()
    emotes.open = false
    emotes.phase = 0
end

local function pad_frame(m)
    emotes.ensure_slots()

    local busy = OF.input.blocked()
        or OF.util.menu_has_screen()
        or (OF.util.asks(OF.forge, "open") and OF.forge.open == true)
    if busy or not emotes.may() then
        emotes.close_wheel()
        return
    end

    local button = OF.input.wheel_button()
    if button == nil then
        emotes.close_wheel()
        return
    end

    local down = OF.util.has_flag(m.controller.buttonDown or 0, button)

    if down and not emotes.open then
        emotes.open = true
        emotes.choice = nil
    end

    if not emotes.open then return end

    if down then
        local aimed = emotes.sector(m.controller.stickX, m.controller.stickY)
        if aimed ~= nil then emotes.choice = aimed end

        local onFoot = not OF.util.has_flag(m.action or 0, ACT_FLAG_AIR)
            and not OF.util.has_flag(m.action or 0, ACT_FLAG_SWIMMING)
        OF.input.claim(m, { button }, onFoot and "dead" or true)
        return
    end

    emotes.open = false

    local entry = (emotes.choice ~= nil and emotes.WHEEL[emotes.choice])
        or emotes.BY_ID[emotes.last] or emotes.WHEEL[1]
    emotes.last = entry.id

    local ok, why = emotes.play(entry.key)
    if not ok and why ~= nil and OF.util.asks(OF.notify, "show") then
        OF.notify.show(why, "bad", 3)

        emotes.close_wheel()
    end
end

local function drive(m)
    if m == nil or m.controller == nil then return end
    if not ready then return end

    ticks = ticks + 1
    pad_frame(m)
    step_phase()
end

local function keep_honest(m)
    local row = gPlayerSyncTable[0]
    if row == nil or (row.ofEmote or 0) == 0 then return end
    if playsOver[m.action] and emotes.allowed_for(0) then return end
    forget(0)
    emotes.stop()
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, function(m)
    if m == nil or (m.playerIndex or 0) ~= 0 then return end
    drive(m)
end)

hook_event(HOOK_MARIO_UPDATE, function(m)
    if m == nil or (m.playerIndex or 0) ~= 0 then return end
    keep_honest(m)
end)

hook_event(HOOK_ON_LEVEL_INIT, function()
    worn = {}
    emotes.close_wheel()
    emotes.stop()
end)

local RING_OF_SCREEN = 0.26

local DESIGNED_FOR = 720

local NAME_SCALE = 0.52
local NAME_LIT_SCALE = 0.70
local HUB_SCALE = 0.80
local SAYS_SCALE = 0.44
local PAD = 9

local LIFT = 6

local LIT_FRAMES = 4

local litNow = {}
local litWas = {}

local function step_lit()
    for position = 1, #emotes.WHEEL do
        local at = litNow[position] or 0
        litWas[position] = at
        if emotes.choice == position then
            if at < LIT_FRAMES then at = at + 1 end
        elseif at > 0 then
            at = at - 1
        end
        litNow[position] = at
    end
end

function emotes.forget_lit()
    litNow = {}
    litWas = {}
end

local function name_geometry(position, lit, layout)
    local grown = lit / LIT_FRAMES
    local angle = (position - 1) * layout.slice
    local reach = layout.radius + LIFT * layout.unit * grown
    local scale = layout.unit
        * (NAME_SCALE + (NAME_LIT_SCALE - NAME_SCALE) * grown)
    local text = layout.names[position]
    local w, h = OF.util.text_size(text, scale)
    return layout.cx + math.sin(angle) * reach - w / 2,
        layout.cy - math.cos(angle) * reach - h / 2,
        scale
end

local function render()
    if not ready then return end
    if not emotes.showing() then return end

    if OF.util.menu_has_screen() then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    step_lit()

    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()
    local short = math.min(screenWidth, screenHeight)

    local layout = {
        cx = screenWidth / 2,
        cy = screenHeight / 2,
        unit = short / DESIGNED_FOR,
        radius = short * RING_OF_SCREEN,
        slice = 2 * math.pi / #emotes.WHEEL,
        names = {},
    }
    for position, entry in ipairs(emotes.WHEEL) do
        layout.names[position] = OF.lang.t(entry.name)
    end

    local fade = emotes.appearance(emotes.phase)
    local function faded(value) return math.floor(value * fade) end

    OF.util.rect(0, 0, screenWidth, screenHeight, 0, 0, 0, faded(96))

    local look = OF.util.asks(OF.theme, "active") and OF.theme.active() or nil
    local accent = look ~= nil and look.accent or { r = 255, g = 205, b = 60 }

    for position, entry in ipairs(emotes.WHEEL) do
        local lit = emotes.choice == position

        local big = layout.unit * NAME_LIT_SCALE
        local room = LIFT * layout.unit
        local boxW = OF.util.width(layout.names[position], big)
            + PAD * 4 + room * 2
        local boxH = OF.util.line_height(big) + PAD * 2 + room * 2
        local angle = (position - 1) * layout.slice
        local bx = layout.cx + math.sin(angle) * layout.radius - boxW / 2
        local by = layout.cy - math.cos(angle) * layout.radius - boxH / 2

        OF.util.plate(bx, by, boxW, boxH, {
            alpha = faded(lit and 250 or 190),
            accent = lit and accent or nil,
        })

        local x, y, scale = name_geometry(position, litNow[position] or 0, layout)
        local fx, fy, fs = name_geometry(position, litWas[position] or 0, layout)
        local shade = lit and 255 or 178
        OF.util.text(layout.names[position], x, y, scale,
            shade, shade, shade, faded(lit and 255 or 205),
            { x = fx, y = fy, scale = fs })
    end

    local aimed = emotes.choice ~= nil and emotes.WHEEL[emotes.choice] or nil
    local repeatable = emotes.BY_ID[emotes.last] or emotes.WHEEL[1]
    local title = OF.lang.t(aimed ~= nil and aimed.name or repeatable.name)
    local under = aimed ~= nil and OF.lang.t(aimed.says)
        or OF.lang.t("Let go to play this again")

    local titleScale = layout.unit * HUB_SCALE
    local saysScale = layout.unit * SAYS_SCALE
    local titleW, titleH = OF.util.text_size(title, titleScale)
    local underW, underH = OF.util.text_size(under, saysScale)
    local hubW = math.max(titleW, underW) + PAD * 4
    local hubH = titleH + underH + PAD * 3

    OF.util.plate(layout.cx - hubW / 2, layout.cy - hubH / 2, hubW, hubH, {
        alpha = faded(240),
        accent = aimed ~= nil and accent or nil,
    })

    OF.util.text(title, layout.cx - titleW / 2,
        layout.cy - hubH / 2 + PAD, titleScale,
        accent.r, accent.g, accent.b, faded(255))
    OF.util.text(under, layout.cx - underW / 2,
        layout.cy - hubH / 2 + PAD * 2 + titleH, saysScale,
        215, 215, 215, faded(230))
end

hook_event(HOOK_ON_HUD_RENDER, render)

function emotes.build_page(panel)
    local rows = {}
    emotes.ensure_slots()

    local may, why = emotes.may()
    if not may then
        rows[#rows + 1] = panel.label_row(OF.lang.t(why or "Not right now."))
    end

    local button = OF.util.asks(OF.input, "wheel_button_name")
        and OF.input.wheel_button_name() or nil
    if button == nil then
        rows[#rows + 1] = panel.label_row(OF.lang.t(
            "Every button this wheel could sit on is taken. Change which one "
            .. "opens the mod menu and one comes free."))
    else
        rows[#rows + 1] = panel.label_row(OF.lang.fill(
            "Hold @ and push the stick. Let go to play it; let go without "
            .. "pushing to repeat the last one.", OF.lang.t(button)))
        rows[#rows + 1] = panel.label_row(OF.lang.fill(
            "@ emotes, and the eight below are the ones your stick reaches.",
            emotes.catalogue_count()))
        rows[#rows + 1] = panel.with_help(panel.with_right(
            panel.row(OF.lang.t("Wheel button"), 255, 255, 255,
                function() OF.input.step_wheel() end),
            OF.lang.fill("@ (@)", OF.lang.t(button),
                OF.lang.t(OF.input.wheel_button_key() or "?"))),
            OF.lang.t("which button holds the wheel open - yours alone"))
    end

    for position, entry in ipairs(emotes.WHEEL) do
        rows[#rows + 1] = panel.with_help(panel.with_right(
            panel.row(OF.lang.t(emotes.POINTS[position] or "?"),
                255, 255, 255,
                function() emotes.step_slot(position) end),
            OF.lang.t(entry.name)),
            OF.lang.t("steps this push of the stick to the next unused gesture"))
    end
    rows[#rows + 1] = panel.with_help(panel.row(
        OF.lang.t("Put the eight it ships with back"), 220, 210, 190,
        function() emotes.reset_slots() end),
        OF.lang.t("the wheel goes back to the eight it shipped with"))

    rows[#rows + 1] = panel.with_help(
        panel.with_right(
            panel.row(OF.lang.t("Gestures you hear"), 255, 255, 255,
                function() emotes.step_voice() end),
            OF.lang.t(emotes.voice_name())),
        OF.lang.t("every emote has a voice - this is whose reaches your speakers"))

    local said, held = {}, {}
    for _, entry in ipairs(emotes.CATALOGUE) do
        local into = entry.hold and held or said
        into[#into + 1] = entry
    end

    for _, section in ipairs({
        { name = "Things to say", list = said },
        { name = "Poses to hold", list = held },
    }) do
        rows[#rows + 1] = panel.header_row(OF.lang.t(section.name))
        for _, entry in ipairs(section.list) do

            rows[#rows + 1] = panel.with_help(panel.with_right(
                panel.gated_row("chat", OF.lang.t(entry.name), 255, 255, 255,
                    function() emotes.play(entry.key) end),
                OF.lang.t(entry.says)),
                entry.hold
                    and OF.lang.t("held where you stand until you move")
                    or OF.lang.t("plays out once, wherever you are standing"))
        end
    end

    local join = panel.with_help(
        panel.gated_row("chat", OF.lang.t("Do what they are doing"),
            255, 255, 255, function()
                OF.util.report(emotes.copy_nearby())
            end),
        OF.lang.t("plays whatever the nearest person in this level is playing"))
    join.outside = true
    rows[#rows + 1] = join

    local stop = panel.with_help(
        panel.row(OF.lang.t("Stop the emote you are playing"),
            220, 200, 200, function() emotes.stop() end),
        OF.lang.t("ends a held pose - walking away ends one too"))
    stop.outside = true
    rows[#rows + 1] = stop

    rows[#rows + 1] = panel.back_row("players")
    return rows
end
