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
local ANIM_STRETCH = 0xC8
local ANIM_SHOCK   = 0x7A

local ANIM_WARM    = 0x19
local ANIM_CAPON   = 0x36
local ANIM_KEY     = 0x61

local ANIM_PUNCH   = 0x67
local ANIM_KICK    = 0x66
local ANIM_DOZY    = 0x85
local ANIM_ONBACK  = 0x03
local ANIM_VICTORY = 0x25
local ANIM_CAPLESS = 0x5E

local ANIM_TOSS    = 0x31
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
local SAY_EEUH    = 7
local SAY_HOO     = 28

local SAY_COUGH2  = 25
local SAY_COUGH3  = 26
local SAY_SNORE2  = 14
local SAY_OOOF    = 9

local DUST_SPARKLE = 1 << 3
local DUST_PLAIN   = 1 << 0
local DUST_BREATH  = 1 << 17
local DUST_MIST    = 1 << 16

emotes.CATALOGUE = {
    { id = 1,  key = "wave",   name = "Wave",   anim = ANIM_WAVE,
      hold = false, says = "Hello, and goodbye", voice = SAY_HELLO },
    { id = 2,  key = "peace",  name = "Peace",  anim = ANIM_PEACE,
      hold = false, says = "Thanks - all good", voice = SAY_OKEY,
      beats = { { at = 88, voice = SAY_HERE_GO } } },

    { id = 3,  key = "point",  name = "Point",  anim = ANIM_POINT,
      hold = true,  holdFor = emotes.POSE_TAIL,
      says = "Look over here", voice = SAY_HERE_GO },
    { id = 4,  key = "spin",   name = "Spin",   anim = ANIM_SPIN,
      hold = false, says = "Dance", voice = SAY_TWIRL, dust = DUST_SPARKLE },
    { id = 5,  key = "sit",    name = "Sit",    anim = ANIM_SIT,
      hold = true,  says = "I am waiting here", voice = SAY_TIRED },

    { id = 7,  key = "cheer",  name = "Cheer",  anim = ANIM_CHEER,
      hold = false, says = "Well done", voice = SAY_YIPPEE,
      beats = { { at = 42, voice = SAY_HERE_GO } } },
    { id = 8,  key = "salute", name = "Salute", anim = ANIM_SALUTE,
      hold = false, says = "Respect, or sorry", voice = SAY_HOOHOO },
    { id = 9,  key = "lookup", name = "Look up", anim = ANIM_LOOKUP,
      hold = false, says = "It is up there", voice = SAY_WAAAOOOW },
    { id = 10, key = "yawn",   name = "Yawn",   anim = ANIM_YAWN,
      hold = false, says = "This is taking a while", voice = SAY_YAWN },

    { id = 11, key = "shiver", name = "Shiver", anim = ANIM_SHIVER,
      hold = true, says = "It is freezing here", voice = SAY_COLD,
      beats = {
          { at = 9, sfx = "SOUND_ACTION_CLAP_HANDS_COLD" },
          { at = 25, sfx = "SOUND_ACTION_CLAP_HANDS_COLD" },
          { at = 44, sfx = "SOUND_ACTION_CLAP_HANDS_COLD" },
      } },
    { id = 12, key = "puzzle", name = "Puzzled", anim = ANIM_PUZZLE,
      hold = false, says = "No idea at all", voice = SAY_DOH },

    { id = 13, key = "cough",  name = "Clear your throat", anim = ANIM_COUGH,
      hold = false, says = "Ahem - over here", voice = SAY_COUGH,
      beats = {
          { at = 25, voice = SAY_COUGH3 },
          { at = 50, voice = SAY_COUGH2 },
          { at = 71, voice = SAY_COUGH },
      } },

    { id = 14, key = "sweep",  name = "Sweep",  anim = ANIM_SWEEP,
      hold = true,  holdFor = emotes.POSE_TAIL,
      says = "Show off", voice = SAY_PUNCH,
      dust = DUST_PLAIN, dustAt = 0,
      beats = { { at = 0, voice = SAY_HOO } } },
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

    { id = 24, key = "stretch", name = "Stretch",   anim = ANIM_STRETCH,
      hold = false, says = "Right - I am awake", voice = SAY_LETS_GO },

    { id = 25, key = "shock",   name = "Shocked",   anim = ANIM_SHOCK,
      hold = false, says = "You did what?", voice = SAY_WHOA,
      beats = { { at = 0, voice = SAY_WAAAOOOW } } },

    { id = 27, key = "warm",    name = "Warm your hands", anim = ANIM_WARM,
      hold = true,  holdFor = emotes.POSE_TAIL,
      says = "Waiting, and waiting", voice = SAY_COLD,
      dust = DUST_BREATH, dustAt = 49,
      beats = {
          { at = 7, sfx = "SOUND_ACTION_CLAP_HANDS_COLD" },
          { at = 49, voice = SAY_COLD },
          { at = 81, sfx = "SOUND_ACTION_CLAP_HANDS_COLD" },
      } },

    { id = 30, key = "capon",   name = "Cap on",    anim = ANIM_CAPON,
      hold = false, says = "How does it look?", voice = SAY_HERE_GO,
      beats = { { at = 28, voice = SAY_HERE_GO } } },

    { id = 32, key = "key",     name = "Turn a key", anim = ANIM_KEY,
      hold = false, says = "Let me get that", voice = SAY_OKEY,
      beats = {
          { at = 79, sfx = "SOUND_GENERAL_DOOR_INSERT_KEY" },
          { at = 111, sfx = "SOUND_GENERAL_DOOR_TURN_KEY" },
      } },

    { id = 33, key = "punch",   name = "Throw a punch", anim = ANIM_PUNCH,
      hold = false, says = "Come on then", voice = SAY_PUNCH },

    { id = 34, key = "kick",    name = "Kick", anim = ANIM_KICK,
      hold = false, says = "Take that", voice = SAY_HOO },

    { id = 35, key = "dozy",    name = "Asleep on your feet", anim = ANIM_DOZY,
      hold = true,  says = "Still waiting", voice = SAY_SNORE,
      beats = { { at = 2, voice = SAY_SNORE }, { at = 20, voice = SAY_SNORE2 } } },

    { id = 39, key = "onback",  name = "Flat on your back", anim = ANIM_ONBACK,
      hold = true,  says = "Finished, thanks", voice = SAY_TIRED },

    { id = 43, key = "victory", name = "Victory spin", anim = ANIM_VICTORY,
      hold = false, says = "That is the whole game", voice = SAY_YAHOO },

    { id = 44, key = "capless", name = "Where is my cap?", anim = ANIM_CAPLESS,
      hold = false, says = "Has anybody seen it?", voice = SAY_DOH },

    { id = 51, key = "toss",   name = "Toss the key", anim = ANIM_TOSS,
      hold = false, says = "Heads up - catch", voice = SAY_HERE_GO,
      beats = {
          { at = 67, sfx = "SOUND_ACTION_KEY_SWISH" },
          { at = 83, sfx = "SOUND_ACTION_PAT_BACK" },
          { at = 111, voice = SAY_HERE_GO },
      } },

    { id = 53, key = "topple", name = "Topple over", anim = ANIM_TOPPLE,
      hold = true,  says = "Timber", voice = SAY_DOH,
      beats = { { at = 0, voice = SAY_OOOF } } },

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

emotes.DEFAULT_SLOTS = { 1, 2, 3, 4, 5, 17, 7, 8 }

emotes.RETIRED_IDS = { [6] = true, [21] = true, [22] = true, [23] = true,
    [26] = true, [28] = true, [29] = true, [31] = true, [36] = true,
    [37] = true, [38] = true, [40] = true, [41] = true, [42] = true,
    [45] = true, [46] = true, [47] = true, [48] = true, [49] = true,
    [50] = true, [52] = true }

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

function emotes.reset_page()
    emotes.reset_slots()
    emotes.set_voice(emotes.VOICE_ALL)
    return true
end

function emotes.point_of(key)
    load_slots()
    for position, entry in ipairs(emotes.WHEEL) do
        if entry.key == key then return position end
    end
    return nil
end

function emotes.round_is_running(localIndex)
    if not OF.util.asks(OF.lockdown, "menu_stands_down") then return false end
    return OF.lockdown.menu_stands_down(localIndex)
end

function emotes.allowed_here()
    return not emotes.round_is_running()
end

function emotes.allowed_for(localIndex)

    if not emotes.dancing_the_win(localIndex) then
        if not emotes.allowed_here() then return false end

        if emotes.round_is_running(localIndex) then return false end
    end
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
    if OF.util.asks(OF.perms, "can") and not OF.perms.can("fun_self") then
        return false, "Your rank cannot do that.", "fun_self"
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

emotes.WIN_DANCE = "cheer"
local owedWinDance = false

function emotes.owe_win_dance()
    owedWinDance = true
    return true
end

function emotes.crowned(localIndex)
    local modes = OF.gamemodes
    if modes == nil or not OF.util.asks(modes, "is_over") then return false end
    if not modes.is_over() then return false end
    return OF.util.asks(modes, "won") and modes.won(localIndex) == true
end

function emotes.dancing_the_win(localIndex)
    if not emotes.crowned(localIndex) then return false end
    local row = gPlayerSyncTable[localIndex]
    local entry = emotes.BY_KEY[emotes.WIN_DANCE]
    return row ~= nil and entry ~= nil and row.ofEmote == entry.id
end

local wonDanceOn = false

function emotes.pay_win_dance(m)

    if wonDanceOn and not emotes.crowned(0) then
        wonDanceOn = false
        local entry = emotes.BY_KEY[emotes.WIN_DANCE]
        local row = gPlayerSyncTable[0]
        if entry ~= nil and row ~= nil and row.ofEmote == entry.id then emotes.stop() end
    end
    if not owedWinDance then return false end
    if not emotes.crowned(0) then
        owedWinDance = false
        return false
    end
    if not ready or m == nil or not playsOver[m.action] then return false end
    local entry = emotes.BY_KEY[emotes.WIN_DANCE]
    if entry == nil then
        owedWinDance = false
        return false
    end
    owedWinDance = false
    if gPlayerSyncTable[0] ~= nil and (gPlayerSyncTable[0].ofEmote or 0) ~= 0 then
        OF.util.publish_row(0, "ofEmote", 0)
    end
    forget(0)
    OF.util.publish_row(0, "ofEmote", entry.id)
    wonDanceOn = true
    return true
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

function emotes.sound_beat(m, beat)
    if m == nil or type(beat) ~= "table" then return false end
    if beat.voice ~= nil then
        if sayIt == nil then return false end
        sayIt(m, beat.voice)
        return true
    end
    local sound = beat.sfx ~= nil and _G[beat.sfx] or nil
    local play = _G.play_sound
    if type(sound) ~= "number" or type(play) ~= "function" then return false end
    local obj = m.marioObj
    local at = obj ~= nil and obj.header ~= nil and obj.header.gfx ~= nil
        and obj.header.gfx.cameraToObject or nil
    if at == nil then return false end
    play(sound, at)
    return true
end

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

    if entry.beats ~= nil then
        if emotes.hears(index) and not emotes.dancing_the_win(index) then
            for _, beat in ipairs(entry.beats) do
                if beat.at == frames - 1 then emotes.sound_beat(m, beat) end
            end
        end
    elseif not state.voiced then
        state.voiced = true

        if sayIt ~= nil and entry.voice ~= nil and emotes.hears(index)
            and not emotes.dancing_the_win(index) then
            sayIt(m, entry.voice)
        end
    end

    if index == 0 and entry.dust ~= nil
        and (entry.dustAt == nil or entry.dustAt == frames - 1) then

        m.particleFlags = OF.util.add_flag(m.particleFlags, entry.dust)
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

        if aimed ~= nil and aimed ~= emotes.choice and OF.sounds ~= nil then
            OF.sounds.ui("wheel_tick", OF.sounds.MOVE)
        end
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
end, OF.LOCAL_MARIO)

hook_event(HOOK_MARIO_UPDATE, function(m)
    if m == nil or (m.playerIndex or 0) ~= 0 then return end
    emotes.pay_win_dance(m)
    keep_honest(m)
end, OF.LOCAL_MARIO)

hook_event(HOOK_ON_LEVEL_INIT, function()
    worn = {}
    emotes.close_wheel()
    emotes.stop()
end)

local RING_OF_SCREEN = 0.30

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

local function ink_middle(text, scale, face)
    local hud = OF.hud
    local w, h = OF.util.text_size(text, scale)
    local dx, dy = w / 2, h / 2
    if hud ~= nil and type(hud.ink_at) == "function" then
        local l, r = hud.ink_at(text, face, scale)
        if l ~= nil and r ~= nil then dx = (l + r) / 2 end
    end
    if hud ~= nil and type(hud.cap) == "function" and face == _G["FONT_MENU"] then
        local top, base = hud.cap({ face = "title", scale = scale }, 1, text)
        if top ~= nil and base ~= nil then dy = (top + base) / 2 end
    end
    return dx, dy, w, h
end
emotes.ink_middle = ink_middle

local function name_geometry(position, lit, layout)
    local grown = lit / LIT_FRAMES
    local angle = (position - 1) * layout.slice
    local reach = layout.radius + LIFT * layout.unit * grown
    local scale = layout.textUnit
        * (NAME_SCALE + (NAME_LIT_SCALE - NAME_SCALE) * grown)
    local text = layout.names[position]
    local dx, dy = ink_middle(text, scale, layout.face)
    return layout.cx + math.sin(angle) * reach - dx,
        layout.cy - math.cos(angle) * reach - dy,
        scale
end

local function render()

    if OF.util.asks(OF.spray, "draw_wheel") then OF.spray.draw_wheel() end
    if not ready then return end
    if not emotes.showing() then return end

    if OF.util.menu_has_screen() then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)

    local face = OF.util.hud_face("A")
    djui_hud_set_font(face or FONT_NORMAL)

    step_lit()

    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()
    local short = math.min(screenWidth, screenHeight)

    local unit = short / DESIGNED_FOR
    local layout = {
        cx = screenWidth / 2,
        cy = screenHeight / 2,
        unit = unit,
        textUnit = unit * (face ~= nil and 0.5 or 1),
        radius = short * RING_OF_SCREEN,
        slice = 2 * math.pi / #emotes.WHEEL,
        names = {},
        face = face or FONT_NORMAL,
    }
    for position, entry in ipairs(emotes.WHEEL) do
        layout.names[position] = OF.lang.t(entry.name)
    end

    local big = layout.textUnit * NAME_LIT_SCALE
    local room = LIFT * layout.unit
    local widest = 0
    for _, name in ipairs(layout.names) do
        widest = math.max(widest, OF.util.width(name, big))
    end
    local boxW = widest + PAD * 4 + room * 2
    local boxH = OF.util.line_height(big) + PAD * 2 + room * 2

    local fade = emotes.appearance(emotes.phase)
    local function faded(value) return math.floor(value * fade) end

    local look = OF.util.asks(OF.theme, "active") and OF.theme.active() or nil
    local accent = look ~= nil and look.accent or { r = 255, g = 205, b = 60 }
    local accentRGB = { accent.r, accent.g, accent.b }
    local hud = OF.hud

    if hud ~= nil then

        hud.wheel_chrome({ cx = layout.cx, cy = layout.cy, rx = layout.radius, ry = layout.radius,
            count = #emotes.WHEEL, selected = emotes.choice, fade = fade, open = 1,
            accent = accentRGB, hubRadius = 60 * unit, wash = emotes.open == true })
    else
        OF.util.rect(0, 0, screenWidth, screenHeight, 0, 0, 0, faded(96))
    end

    for position, entry in ipairs(emotes.WHEEL) do
        local lit = emotes.choice == position

        local angle = (position - 1) * layout.slice
        local midX = layout.cx + math.sin(angle) * layout.radius
        local midY = layout.cy - math.cos(angle) * layout.radius

        if hud ~= nil then
            hud.wheel_slot(midX, midY, boxW, boxH, (litNow[position] or 0) / LIT_FRAMES,
                fade, accentRGB)
        else
            OF.util.plate(midX - boxW / 2, midY - boxH / 2, boxW, boxH, {
                alpha = faded(lit and 250 or 190), accent = lit and accent or nil })
        end

        local x, y, scale = name_geometry(position, litNow[position] or 0, layout)
        local fx, fy, fs = name_geometry(position, litWas[position] or 0, layout)
        local shade = lit and 255 or 190
        OF.util.text(layout.names[position], x, y, scale,
            lit and accent.r or shade, lit and accent.g or shade, lit and accent.b or shade,
            faded(lit and 255 or 215),
            { x = fx, y = fy, scale = fs })
    end

    local aimed = emotes.choice ~= nil and emotes.WHEEL[emotes.choice] or nil
    local repeatable = emotes.BY_ID[emotes.last] or emotes.WHEEL[1]
    local title = OF.lang.t(aimed ~= nil and aimed.name or repeatable.name)
    local under = aimed ~= nil and OF.lang.t(aimed.says)
        or OF.lang.t("Let go to play this again")

    local titleScale = layout.textUnit * HUB_SCALE
    local saysScale = layout.textUnit * SAYS_SCALE
    local titleDx, titleDy, titleW, titleH = ink_middle(title, titleScale, layout.face)
    local underDx, underDy, underW, underH = ink_middle(under, saysScale, layout.face)
    local hubW = math.max(titleW, underW) + PAD * 4
    local hubH = titleH + underH + PAD * 3

    local hubTop = layout.cy - hubH / 2
    local titleMid = hubTop + PAD + titleH / 2
    local underMid = hubTop + PAD * 2 + titleH + underH / 2

    if hud ~= nil then
        hud.wheel_hub(layout.cx, layout.cy, hubW, hubH, fade, aimed ~= nil, accentRGB)
    else
        OF.util.plate(layout.cx - hubW / 2, layout.cy - hubH / 2, hubW, hubH, {
            alpha = faded(240), accent = aimed ~= nil and accent or nil })
    end

    OF.util.text(title, layout.cx - titleDx, titleMid - titleDy, titleScale,
        accent.r, accent.g, accent.b, faded(255))
    OF.util.text(under, layout.cx - underDx, underMid - underDy, saysScale,
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
    end

    rows[#rows + 1] = panel.with_help(panel.row(
        OF.lang.t("Reset this page"), 220, 210, 190,
        function() emotes.reset_page() end),
        OF.lang.t("the eight and whose gestures you hear, back to how they ship - not the wheel button"))

    if button ~= nil then
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

    rows[#rows + 1] = panel.with_help(
        panel.with_right(
            panel.row(OF.lang.t("Gestures you hear"), 255, 255, 255,
                function() emotes.step_voice() end),
            OF.lang.t(emotes.voice_name())),
        OF.lang.t("every emote has a voice - this is whose reaches your speakers"))

    local join = panel.with_help(
        panel.gated_row("fun_self", OF.lang.t("Do what they are doing"),
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
