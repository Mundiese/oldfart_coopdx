OF = OF or {}
OF.music = OF.music or {}

local music = OF.music

local PRIORITY = 4
local FADE_IN = 60

music.SILENCE = -1

music.VANILLA = 0

music.VOLUME_KEY = "ofMusicVol"
music.ROUNDS_KEY = "ofRoundMusic"
music.COURSES = "Courses"
music.BOSSES  = "Bosses and races"
music.SCREENS = "Menus and cutscenes"
music.OTHER   = "From other games"
local IMPORTED = {

    { file = "b64_blue_resort",  bank = 37, name = "BM64 Blue Resort",
      about = "Bomberman 64's Blue Resort, by cpuHacka101" },
    { file = "cvhod_vampire_killer", bank = 37,
      name = "Castlevania Vampire Killer",
      about = "Vampire Killer, from Castlevania: Harmony of Dissonance, "
          .. "by mosky2000" },
    { file = "dkc2_stickerbrush", bank = 37,
      name = "DKC2 Stickerbrush Symphony",
      about = "Donkey Kong Country 2's Stickerbrush Symphony, "
          .. "by ShrooboidBrat" },
    { file = "kdl_green_greens", bank = 12, name = "Kirby Green Greens",
      about = "Green Greens, from Kirby's Dream Land, by Stanley "
          .. "Jamie/Cackletta and MrGreenThunder" },
    { file = "nsmb_athletic",    bank = 37, name = "NSMB Athletic",
      about = "the athletic theme of New Super Mario Bros., by ShrooboidBrat" },
    { file = "nsmb_overworld",   bank = 37, name = "NSMB Overworld",
      about = "the overworld theme of New Super Mario Bros., "
          .. "by ShrooboidBrat" },
    { file = "smb3_athletic",    bank = 17, name = "SMB3 Athletic",
      about = "the athletic theme of Super Mario Bros. 3, by ShrooboidBrat" },
    { file = "smb3_overworld",   bank = 37, name = "SMB3 Overworld",
      about = "the overworld theme of Super Mario Bros. 3, by ShrooboidBrat" },
    { file = "smg_gusty_garden", bank = 26, name = "SMG Gusty Garden Galaxy",
      about = "Super Mario Galaxy's Gusty Garden Galaxy, by pieordie1" },
    { file = "smk_beach",        bank = 17, name = "SMK Beach",
      about = "the beach theme of Super Mario Kart, by EDARK 900" },
    { file = "smw_athletic",     bank = 17, name = "SMW Athletic",
      about = "the athletic theme of Super Mario World, by Skelux" },
    { file = "smw_overworld",    bank = 37, name = "SMW Overworld",
      about = "the overworld theme of Super Mario World, by ShrooboidBrat" },
    { file = "smw2_athletic",    bank = 17, name = "SMW2 Athletic",
      about = "the athletic theme of Yoshi's Island, by Jesse" },
    { file = "smw2_cave",        bank = 37, name = "SMW2 Crystal Caves",
      about = "Yoshi's Island's Crystal Caves, by EDARK 900" },
    { file = "smw2_flower_garden", bank = 37, name = "SMW2 Flower Garden",
      about = "Yoshi's Island's Flower Garden, by ShrooboidBrat" },
    { file = "smw2_fuzzy_dizzy", bank = 17,
      name = "SMW2 Touch Fuzzy, Get Dizzy",
      about = "Yoshi's Island's Touch Fuzzy, Get Dizzy, by ShrooboidBrat" },
    { file = "sth_green_hill_zone", bank = 37, name = "Sonic Green Hill Zone",
      about = "Green Hill Zone, from Sonic the Hedgehog, by ShrooboidBrat" },
    { file = "ssb_meta_crystal_brawl", bank = 26, name = "SSB Meta Crystal",
      about = "Super Smash Bros.' Meta Crystal, in its Brawl arrangement, "
          .. "by King Meteor and Sanji02" },
}

local MAX_SEQUENCE = 128

local function bring_in(entry)
    if type(smlua_audio_utils_allocate_sequence) ~= "function" then return nil end
    if type(smlua_audio_utils_replace_sequence) ~= "function" then return nil end
    if type(mod_file_exists) ~= "function" then return nil end
    if not mod_file_exists("sound/" .. entry.file .. ".m64") then return nil end

    local seq = smlua_audio_utils_allocate_sequence()
    if type(seq) ~= "number" or seq <= 0 or seq >= MAX_SEQUENCE then return nil end
    smlua_audio_utils_replace_sequence(seq, entry.bank, entry.volume or 75,
        entry.file)
    return seq
end

music.TRACKS = {
    { seq = SEQ_LEVEL_GRASS,            name = "Bob-omb Battlefield",  group = music.COURSES,
      about = "the theme the game's outdoor courses play" },
    { seq = SEQ_LEVEL_INSIDE_CASTLE,    name = "Inside the Castle",    group = music.COURSES,
      about = "the castle's own halls" },
    { seq = SEQ_LEVEL_WATER,            name = "Dire, Dire Docks",     group = music.COURSES,
      about = "the theme the water courses play" },
    { seq = SEQ_LEVEL_HOT,              name = "Lethal Lava Land",     group = music.COURSES,
      about = "the theme the fire and desert courses play" },
    { seq = SEQ_LEVEL_SNOW,             name = "Cool, Cool Mountain",  group = music.COURSES,
      about = "the theme the snow courses play" },
    { seq = SEQ_LEVEL_SLIDE,            name = "Slider",               group = music.COURSES,
      about = "the slides, and the race down them" },
    { seq = SEQ_LEVEL_SPOOKY,           name = "Big Boo's Haunt",      group = music.COURSES,
      about = "the haunted house" },
    { seq = SEQ_LEVEL_UNDERGROUND,      name = "Hazy Maze Cave",       group = music.COURSES,
      about = "the caves under the castle" },
    { seq = SEQ_EVENT_MERRY_GO_ROUND,   name = "Merry-Go-Round",       group = music.COURSES,
      about = "the carousel in the haunted house" },
    { seq = SEQ_EVENT_PIRANHA_PLANT,    name = "Piranha Plant's Lullaby", group = music.COURSES,
      about = "the sleeping plants in the garden" },
    { seq = SEQ_EVENT_ENDLESS_STAIRS,   name = "Endless Stairs",       group = music.COURSES,
      about = "the staircase that goes nowhere" },

    { seq = SEQ_LEVEL_KOOPA_ROAD,       name = "Bowser's Road",        group = music.BOSSES,
      about = "the climb up to each Bowser" },
    { seq = SEQ_LEVEL_BOSS_KOOPA,       name = "Bowser Battle",        group = music.BOSSES,
      about = "the first two fights with Bowser" },
    { seq = SEQ_LEVEL_BOSS_KOOPA_FINAL, name = "Final Bowser",         group = music.BOSSES,
      about = "the last fight, on the roof" },
    { seq = SEQ_EVENT_BOSS,             name = "Boss Fight",           group = music.BOSSES,
      about = "a course's own boss" },

    { seq = SEQ_EVENT_POWERUP,          name = "Powerful Mario",       group = music.BOSSES,
      about = "what plays while a cap is on you" },

    { seq = SEQ_EVENT_METAL_CAP,        name = "Metal Cap Theme",      group = music.BOSSES,
      about = "what plays while the metal cap is on you" },

    { seq = SEQ_MENU_TITLE_SCREEN,      name = "Title Theme",          group = music.SCREENS,
      about = "the game's title screen" },
    { seq = SEQ_MENU_FILE_SELECT,       name = "File Select",          group = music.SCREENS,
      about = "the file select screen" },
    { seq = SEQ_MENU_STAR_SELECT,       name = "Star Select",          group = music.SCREENS,
      about = "the act picker inside a painting" },
    { seq = SEQ_EVENT_CUTSCENE_INTRO,   name = "Peach's Letter",       group = music.SCREENS,
      about = "the letter the game opens on" },
    { seq = SEQ_EVENT_CUTSCENE_VICTORY, name = "Victory",              group = music.SCREENS,
      about = "the cutscene after a key is won" },
    { seq = SEQ_EVENT_CUTSCENE_ENDING,  name = "Ending",               group = music.SCREENS,
      about = "the cutscene after the last star" },
    { seq = SEQ_EVENT_CUTSCENE_CREDITS, name = "Credits",              group = music.SCREENS,
      about = "the flight over the castle at the end" },
}

local imported = {}

function music.import_tracks()

function music.restore_banks()
    if type(smlua_audio_utils_replace_sequence) ~= "function" then return 0 end
    local put = 0
    for _, entry in ipairs(IMPORTED) do
        local seq = imported[entry.file]
        if type(seq) == "number" then
            smlua_audio_utils_replace_sequence(seq, entry.bank,
                entry.volume or 75, entry.file)
            put = put + 1
        end
    end
    return put
end
    local added = 0
    for _, entry in ipairs(IMPORTED) do
        if not imported[entry.file] then
            local seq = bring_in(entry)
            if seq ~= nil then
                imported[entry.file] = seq
                table.insert(music.TRACKS, {

                    seq = seq, key = entry.file,
                    name = entry.name, group = music.OTHER,
                    about = entry.about,
                })
                added = added + 1
            end
        end
    end
    return added
end

music.import_tracks()

music.IMPORT_MARK = "of:"
local function marked(wire)
    if type(wire) ~= "string" then return nil end
    local mark = music.IMPORT_MARK
    if string.sub(wire, 1, #mark) ~= mark then return nil end
    local key = string.sub(wire, #mark + 1)
    if key == "" then return nil end
    return key
end

function music.wire_for(seq)
    seq = tonumber(seq)
    if seq == nil then return nil end
    for _, entry in ipairs(music.TRACKS) do
        if entry.seq == seq and entry.key ~= nil then
            return music.IMPORT_MARK .. entry.key
        end
    end
    return seq
end

function music.seq_for(wire)
    local key = marked(wire)
    if key == nil then return tonumber(wire) end
    for _, entry in ipairs(music.TRACKS) do
        if entry.key == key then return entry.seq end
    end
    return nil
end

function music.lobby_missing()
    local wire = gGlobalSyncTable.ofMusic
    if marked(wire) == nil then return nil end
    if music.seq_for(wire) ~= nil then return nil end
    return wire
end

local wornBank = nil

local bankOwed = false

function music.worn_bank()
    return wornBank
end

function music.wear_bank(bank)
    if type(bank) ~= "number" or bank <= 0 then bank = nil end
    wornBank = bank

    OF.util.optional("set_sound_bank_override", nil, -1)
    return true
end

hook_event(HOOK_ON_SEQ_LOAD, function(seqPlayer)
    if wornBank == nil then return end
    if seqPlayer == SEQ_PLAYER_LEVEL then
        OF.util.optional("set_sound_bank_override", nil, wornBank)
        bankOwed = true
    else
        OF.util.optional("set_sound_bank_override", nil, -1)
    end
end)

function music.free_the_voice()
    if OF.util.binding("play_music") == nil then return false end
    play_music(SEQ_PLAYER_SFX, SEQ_SOUND_PLAYER, 0)
    return true
end

function music.track_name(seq)
    if seq == nil or seq == 0 then return "the level's own music" end
    if seq == music.SILENCE then return "silence" end
    for _, entry in ipairs(music.TRACKS) do
        if entry.seq == seq then return entry.name end
    end
    return "track " .. tostring(seq)
end

function music.by_name(word)
    word = string.lower(OF.util.plain(tostring(word or "")))
    if word == "" then return nil, nil end

    local best, bestAt = nil, nil
    for pass = 1, 3 do
        for index, entry in ipairs(music.TRACKS) do
            local name = string.lower(entry.name)
            local hit = false
            if pass == 1 then hit = (name == word)
            elseif pass == 2 then hit = (string.sub(name, 1, #word) == word)
            else hit = (string.find(name, word, 1, true) ~= nil) end
            if hit then return entry, index end
        end
    end

    for _, entry in ipairs(music.TRACKS) do
        local name = string.lower(entry.name)
        local score, at = 0, 1
        for i = 1, #word do
            local found = string.find(name, string.sub(word, i, i), at, true)
            if found ~= nil then score = score + 1 at = found + 1 end
        end
        if bestAt == nil or score > bestAt then best, bestAt = entry, score end
    end

    if best ~= nil and bestAt >= math.max(2, math.ceil(#word / 2)) then
        return nil, best.name
    end
    return nil, nil
end

local function offers(seq)
    seq = tonumber(seq)
    if seq == nil then return false end

    if seq == 0 then return true end

    if seq == music.SILENCE then return true end
    for _, entry in ipairs(music.TRACKS) do
        if entry.seq == seq then return true end
    end
    return false
end

function music.lobby_track()
    return music.seq_for(gGlobalSyncTable.ofMusic) or 0
end

local wanted = nil
local playing = nil

local orphan = nil

local EMPTY_QUEUE = 65535

local function queue_head()
    local head = get_current_background_music()
    if head == nil or head == EMPTY_QUEUE or head < 0 then return nil end
    return head
end

local function level_track()
    local m = gMarioStates[0]
    if m == nil then return nil end
    local area = m.area
    if area == nil then return nil end
    local args = area.musicParam2
    if args == nil or args == 0 then return nil end
    return args
end

local function same_seq(a, b)
    if a == nil or b == nil then return false end
    return a % 256 == b % 256
end

local function ours_at_head()
    return same_seq(queue_head(), wanted)
end

local function sweep_orphan()
    if orphan == nil then return false end
    if same_seq(wanted, orphan) or same_seq(level_track(), orphan) then
        orphan = nil
        return false
    end
    local head = queue_head()
    if not same_seq(head, orphan) then return false end
    stop_background_music(head)
    orphan = nil
    return true
end

local silent = false
local hushed = false

local function quiet()
    return silent or hushed
end

local QUIET_FADE = 30

local function hold_quiet()
    seq_player_fade_out(SEQ_PLAYER_LEVEL, QUIET_FADE)
end

function music.volume()
    local value = tonumber(gGlobalSyncTable[music.VOLUME_KEY])
    if value == nil then return 100 end
    return OF.util.clamp(math.floor(value), 0, 100)
end

local volumeTouched = false

local duckTo = 100

local function apply_volume()

    local percent = music.in_force("volume") * duckTo / 100
    if percent >= 100 and not volumeTouched then

        return
    end
    volumeTouched = true
    fade_volume_scale(SEQ_PLAYER_LEVEL,
        math.floor(127 * percent / 100), QUIET_FADE)
end

local function hold_under(percent)
    percent = OF.util.clamp(math.floor(tonumber(percent) or 100), 0, 100)
    if duckTo == percent then return false end
    duckTo = percent
    apply_volume()
    return true
end

local function pop_ours()
    if playing == nil then return end
    stop_background_music(playing)
    playing = nil
    if queue_head() == nil then
        local args = level_track()
        if args ~= nil then play_music(SEQ_PLAYER_LEVEL, args, FADE_IN) end
    end

    apply_volume()
    if quiet() then hold_quiet() end
end

local function act_selector_up()
    if OF.util.binding("obj_get_first_with_behavior_id") == nil then
        return false
    end
    if id_bhvActSelector == nil then return false end
    return obj_get_first_with_behavior_id(id_bhvActSelector) ~= nil
end

local function push()
    if wanted == nil then return end

    if act_selector_up() then return end

    if not ours_at_head() then
        play_music(SEQ_PLAYER_LEVEL, wanted, FADE_IN)
    end

    if ours_at_head() then playing = wanted end

    apply_volume()
    if quiet() then hold_quiet() end
end

local function lift_quiet()
    if wanted ~= nil then

        play_music(SEQ_PLAYER_LEVEL, wanted, FADE_IN)
        if ours_at_head() then playing = wanted end
    else
        local args = level_track()
        if args ~= nil then play_music(SEQ_PLAYER_LEVEL, args, FADE_IN) end
    end
    apply_volume()
end

function music.hush(on)
    on = on and true or false
    if hushed == on then return false end
    hushed = on
    if quiet() then hold_quiet() else lift_quiet() end
    return true
end

function music.is_quiet()
    return quiet()
end

local overlay = nil

local mineTrack = nil

local mineVolume = nil

local roundHeard = nil

function music.in_force(what)
    if what == "volume" then

        if mineVolume ~= nil then return mineVolume end
        return music.volume()
    end

    local round = music.round_wants()
    if round ~= nil then return round end

    if mineTrack ~= nil then return mineTrack end

    if overlay ~= nil then return overlay end
    return music.lobby_track()
end

local function start(seq)

    if playing == nil and wanted ~= nil then orphan = wanted % 256 end

    pop_ours()

    if seq == music.SILENCE then
        wanted = nil
        silent = true
        hold_quiet()
        return
    end
    local wasSilent = silent
    silent = false
    if seq == nil or seq == 0 then
        wanted = nil
        if wasSilent and not quiet() then lift_quiet() end
        return
    end
    wanted = PRIORITY * 256 + seq

    if wasSilent and not quiet() then lift_quiet() end
    push()
end

function music.refresh()
    local seq = music.in_force()
    if seq == 0 then
        wanted, playing = nil, nil

        silent = false
        if quiet() then hold_quiet() else apply_volume() end
        return
    end
    start(seq)
end

function music.set_lobby_here(asker, seq)
    if not OF.util.is_host() then return false, "Only the host sets these." end
    if asker == nil then return false, "Who asked?" end
    if OF.perms.tier(asker) < OF.perms.required("music") then
        return false, "Your rank cannot do that."
    end

    return music.apply_lobby(seq, asker)
end

function music.apply_lobby(seq, askerLocal)

    seq = music.seq_for(seq)
    if seq == nil then
        return false, "This lobby has not got that track."
    end
    if not offers(seq) then return false, "That is not one of the tracks." end

    OF.util.publish("ofMusic", music.wire_for(seq))

    OF.notify.send_all("Now playing: @", "info", nil, music.track_name(seq))

    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit") then
        OF.notify.credit(askerLocal,
            OF.lang.fill("music: @", music.track_name(seq)))
    end
    if OF.util.asks(OF.chatlog, "add_system") then
        OF.chatlog.add_system(OF.lang.fill("music: @", music.track_name(seq)),
            OF.util.presser(askerLocal))
    end
    return true
end

function music.set_volume_here(asker, percent)
    if not OF.util.is_host() then return false, "Only the host sets these." end
    if asker == nil then return false, "Who asked?" end
    if OF.perms.tier(asker) < OF.perms.required("music") then
        return false, "Your rank cannot do that."
    end

    return music.apply_volume_lobby(percent, asker)
end

function music.apply_volume_lobby(percent, askerLocal)
    percent = tonumber(percent)
    if percent == nil then return false, "Say a number from 0 to 100." end
    percent = OF.util.clamp(math.floor(percent), 0, 100)
    OF.util.publish(music.VOLUME_KEY, percent)
    OF.notify.send_all("Music volume: @%", "quiet", 3, tostring(percent))

    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit") then
        OF.notify.credit(askerLocal,
            OF.lang.fill("music volume: @%", tostring(percent)))
    end
    if OF.util.asks(OF.chatlog, "add_system") then
        OF.chatlog.add_system(OF.lang.fill("music volume: @%", tostring(percent)),
            OF.util.presser(askerLocal))
    end
    return true
end

function music.set_volume(percent)
    if not OF.perms.can("music") then return false, "Your rank cannot do that.", "music" end
    if OF.util.is_host() then

        return music.apply_volume_lobby(percent, 0)
    end
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does("musicvol", percent)
    end
    return false, "No host to ask yet - try again in a second."
end

music.POLICIES = { "", "vanilla", "lobby", "under", "silence" }

music.CUES = {
    { key = "warmup",   name = "Warm-up",
      when = "While people arrive, before the first round." },
    { key = "last",     name = "Last stretch",
      when = "The last thirty seconds of a round that has a clock." },
    { key = "breather", name = "Breather",
      when = "The pause in the middle of a session." },
    { key = "board",    name = "Closing board",
      when = "The table at the end, once the last round is over." },
}

music.CUE_BY_KEY = {}
for _, entry in ipairs(music.CUES) do music.CUE_BY_KEY[entry.key] = entry end

local CUE_FIELD = ";"
local function parse_evening(packed)
    local policy, cues = nil, {}
    for piece in string.gmatch(tostring(packed or "") .. CUE_FIELD,
        "([^" .. CUE_FIELD .. "]*)" .. CUE_FIELD) do
        if policy == nil then
            policy = piece
        else

            local key, answer = string.match(piece, "^(%a+)=(%-?%d+)$")
            if key ~= nil then cues[key] = tonumber(answer) end
        end
    end
    return policy or "", cues
end

local function pack_evening(policy, cues)
    local parts = { tostring(policy or "") }
    for _, entry in ipairs(music.CUES) do
        local answer = cues[entry.key]
        if answer ~= nil then
            table.insert(parts, entry.key .. "=" .. tostring(math.floor(answer)))
        end
    end
    return table.concat(parts, CUE_FIELD)
end

function music.rounds_policy()
    local policy = parse_evening(gGlobalSyncTable[music.ROUNDS_KEY])
    return policy
end

function music.cue(key)
    local _, cues = parse_evening(gGlobalSyncTable[music.ROUNDS_KEY])
    local answer = cues[key]
    if answer == nil or not offers(answer) then return nil end
    return answer
end

function music.cue_name(key)
    local answer = music.cue(key)
    if answer == nil then return "whatever the lobby is on" end
    return music.track_name(answer)
end

function music.rounds_choice(seq)
    local policy = music.rounds_policy()
    if policy == "" then return seq end

    if policy == "vanilla" then return music.VANILLA end
    if policy == "lobby" then return nil end

    if policy == "under" then return nil end
    if policy == "silence" then return music.SILENCE end
    local wanted = tonumber(policy)
    if wanted ~= nil and offers(wanted) then return wanted end

    return seq
end

function music.round_wants()
    if not music.round_hides() then return nil end

    local policy = music.rounds_policy()

    if policy == "lobby" or policy == "under" then return nil end

    local asked = nil
    if OF.util.asks(OF.gamemodes, "current") then
        local mode = OF.gamemodes.current()
        if mode ~= nil then asked = mode.music end
    end

    local picked = music.rounds_choice(asked)

    if picked == nil then return music.VANILLA end
    return picked
end

function music.rounds_name()
    local policy = music.rounds_policy()
    if policy == "" then return "the mode's own choice" end
    if policy == "vanilla" then return "the game's own music" end
    if policy == "lobby" then return "the lobby's track, always" end
    if policy == "under" then return "the lobby's track, ducked under the round" end
    if policy == "silence" then return "silence" end
    local wanted = tonumber(policy)
    if wanted ~= nil and offers(wanted) then return music.track_name(wanted) end
    return "the mode's own choice"
end

function music.set_rounds_here(asker, policy)
    if not OF.util.is_host() then return false, "Only the host sets these." end
    if asker == nil then return false, "Who asked?" end
    if OF.perms.tier(asker) < OF.perms.required("music") then
        return false, "Your rank cannot do that."
    end

    return music.apply_rounds(policy, asker)
end

function music.apply_rounds(value, askerLocal)
    local policy, cues = parse_evening(value)
    if policy ~= "" and policy ~= "vanilla" and policy ~= "lobby"
        and policy ~= "under" and policy ~= "silence" then
        local wanted = tonumber(policy)
        if wanted == nil or not offers(wanted) then
            return false, "Say mode, vanilla, lobby, under, silence or a track."
        end

        policy = tostring(math.floor(wanted))
    end

    local kept = {}
    for _, entry in ipairs(music.CUES) do
        local answer = cues[entry.key]
        if answer ~= nil and offers(answer) then
            kept[entry.key] = math.floor(tonumber(answer))
        end
    end

    local wasPolicy, wasCues = parse_evening(gGlobalSyncTable[music.ROUNDS_KEY])
    OF.util.publish(music.ROUNDS_KEY, pack_evening(policy, kept))

    if policy ~= wasPolicy then
        OF.notify.send_all("Rounds play: @", "quiet", 3, music.rounds_name())

        if askerLocal ~= nil and OF.util.asks(OF.notify, "credit") then
            OF.notify.credit(askerLocal,
                OF.lang.fill("rounds play: @",
                    OF.lang.t(music.rounds_name())))
        end
        OF.actionlog.by_hand(OF.util.presser(askerLocal),
            OF.lang.fill("set what rounds play: @",
                OF.lang.t(music.rounds_name())))
        return true
    end
    for _, entry in ipairs(music.CUES) do
        if kept[entry.key] ~= wasCues[entry.key] then
            OF.notify.send_all("@ plays @", "quiet", 3,
                OF.lang.t(entry.name), music.cue_name(entry.key))

            local said = OF.lang.t(entry.name) .. ": "
                .. OF.lang.t(music.cue_name(entry.key))
            if askerLocal ~= nil and OF.util.asks(OF.notify, "credit") then
                OF.notify.credit(askerLocal, said)
            end
            OF.actionlog.by_hand(OF.util.presser(askerLocal),
                OF.lang.fill("set a round cue: @", said))
            return true
        end
    end

    return true
end

function music.set_policy(policy)
    local _, cues = parse_evening(gGlobalSyncTable[music.ROUNDS_KEY])
    return music.set_rounds(pack_evening(tostring(policy or ""), cues))
end

function music.rounds_text()
    return music.rounds_policy()
end

function music.put_rounds(policy)
    if not OF.util.is_host() then return false end
    policy = tostring(policy or "")
    if music.rounds_policy() == policy then return false end
    local _, cues = parse_evening(gGlobalSyncTable[music.ROUNDS_KEY])
    OF.util.publish(music.ROUNDS_KEY, pack_evening(policy, cues))
    return true
end

function music.set_cue(key, answer)
    if music.CUE_BY_KEY[key] == nil then
        return false, "Say warmup, last, breather or board."
    end
    if answer ~= nil and not offers(answer) then
        return false, "That is not one of the tracks."
    end
    local policy, cues = parse_evening(gGlobalSyncTable[music.ROUNDS_KEY])
    cues[key] = answer ~= nil and math.floor(tonumber(answer)) or nil
    return music.set_rounds(pack_evening(policy, cues))
end

function music.set_rounds(policy)
    if not OF.perms.can("music") then return false, "Your rank cannot do that.", "music" end

    if OF.util.is_host() then return music.apply_rounds(policy, 0) end
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does("musicround", policy)
    end
    return false, "No host to ask yet - try again in a second."
end

local REQUEST_GAP = 60 * 30
local askedAt = {}

function music.may_request(localIndex)
    local at = askedAt[localIndex]

    return at == nil or (get_global_timer() - at) >= REQUEST_GAP
end

function music.request_here(asker, seq)
    if not OF.util.is_host() then return false, "Only the host sets these." end
    if asker == nil then return false, "Who asked?" end

    seq = music.seq_for(seq)
    if seq == nil then return false, "This lobby has not got that track." end
    if not offers(seq) then return false, "That is not one of the tracks." end
    if seq == 0 or seq == music.SILENCE then
        return false, "Ask for a track, not for the music to stop."
    end
    if not music.may_request(asker) then
        return false, "You have already asked - give it a minute."
    end
    askedAt[asker] = get_global_timer()

    local np = gNetworkPlayers[asker]
    local who = OF.util.plain(np ~= nil and np.name or "Somebody")

    OF.notify.show("@ asks for @", "info", 6, who, music.track_name(seq))
    if OF.util.asks(OF.chatlog, "add_system") then
        OF.chatlog.add_system(OF.lang.fill("@ asked for @", who,
            music.track_name(seq)))
    end

    OF.util.chat("\\#808080\\" .. OF.lang.fill("Put it on from Fun, Music: @",
        music.track_name(seq)))
    return true
end

function music.request(seq)
    if not offers(seq) then return false, "That is not one of the tracks." end
    if OF.util.is_host() then return music.set_lobby(seq) end
    if OF.util.asks(OF.net, "host_does") then

        local ok, why = OF.net.host_does("musicask", music.wire_for(seq))
        if ok then return true, "Asked the host." end
        return ok, why
    end
    return false, "No host to ask yet - try again in a second."
end

function music.set_lobby(seq)
    if not OF.perms.can("music") then return false, "Your rank cannot do that.", "music" end

    if OF.util.is_host() then return music.apply_lobby(seq, 0) end
    if OF.util.asks(OF.net, "host_does") then

        return OF.net.host_does("music", music.wire_for(seq))
    end
    return false, "No host to ask yet - try again in a second."
end

function music.put_lobby(seq)
    if not OF.util.is_host() then return false end

    seq = music.seq_for(seq) or 0
    if not offers(seq) then return false end
    if music.lobby_track() == seq then return false end
    OF.util.publish("ofMusic", music.wire_for(seq))
    return true
end

function music.take_over(seq)
    if not OF.util.is_host() then return false end
    local asked = seq
    seq = music.rounds_choice(seq)
    if seq ~= asked then
        OF.notify.send_all("The round's own music is off - the lobby is set to @",
            "info", 5, music.rounds_name())
    end
    if seq == nil then return false end
    if not offers(seq) then
        if OF.util.asks(OF.chatlog, "add_system") then
            OF.chatlog.add_system("round music refused: " .. tostring(seq))
        end
        return false
    end
    return true
end

local LAST_SECONDS = 30

local UNDER_PERCENT = 40

local function evening_set()
    local value = gGlobalSyncTable[music.ROUNDS_KEY]
    return value ~= nil and value ~= ""
end

local function round_state()
    if not OF.util.asks(OF.gamemodes, "state") then return nil end
    return OF.gamemodes.state()
end

local function room_cue()
    local state = round_state()
    if state ~= nil and state ~= OF.gamemodes.OFF then

        if state == OF.gamemodes.ACTIVE then
            local left = OF.gamemodes.time_left()
            if left ~= nil and left <= LAST_SECONDS then
                return music.cue("last")
            end
        end
        return nil
    end
    if not OF.util.asks(OF.night, "state") then return nil end
    local phase = OF.night.state()
    if phase == OF.night.WARMUP then return music.cue("warmup") end
    if phase == OF.night.BREAK then return music.cue("breather") end
    if phase == OF.night.BOARD then return music.cue("board") end
    return nil
end

local function room_duck()
    if music.rounds_policy() ~= "under" then return 100 end
    local state = round_state()

    if state == nil then return 100 end
    if state == OF.gamemodes.COUNTDOWN or state == OF.gamemodes.ACTIVE then
        return UNDER_PERCENT
    end
    return 100
end

function music.follow_the_room()
    local cue, dip = nil, 100
    if evening_set() then

        if music.mine_track() == nil then cue = room_cue() end
        dip = room_duck()
    end

    local round = music.round_wants()

    local moved = false
    if cue ~= overlay or round ~= roundHeard then
        overlay = cue
        roundHeard = round
        start(music.in_force())
        moved = true
    end
    if hold_under(dip) then moved = true end
    return moved
end

function music.round_hides()
    if not OF.util.asks(OF.lockdown, "menu_stands_down") then return false end
    return OF.lockdown.menu_stands_down() == true
end

function music.mine_track()
    return mineTrack
end

function music.mine_volume()
    return mineVolume
end

function music.mine_state(what, seq)
    if what == "volume" then
        if mineVolume == nil then return nil end
        if mineVolume == music.volume() then return nil end
        return mineVolume > 0
    end
    if mineTrack == nil then return nil end
    local room = music.lobby_track()
    if mineTrack == room then return nil end
    if mineTrack == seq then return true end
    if room == seq then return false end
    return nil
end

function music.set_mine_track(seq)
    if seq ~= nil then
        if not offers(seq) then return false, "That is not one of the tracks." end
        seq = tonumber(seq)

        if seq == music.lobby_track() then seq = nil end
    end
    mineTrack = seq

    overlay = nil
    if mineTrack == nil and evening_set() then overlay = room_cue() end
    start(music.in_force())
    return true
end

function music.set_mine_volume(percent)
    if percent ~= nil then
        percent = tonumber(percent)
        if percent == nil then return false, "Say a number from 0 to 100." end
        percent = OF.util.clamp(math.floor(percent), 0, 100)
        if percent == music.volume() then percent = nil end
    end
    mineVolume = percent
    apply_volume()
    return true
end

function music.forget_mine()

    local dial = music.set_mine_volume(nil)
    return music.set_mine_track(nil) == true and dial == true
end

function music.anyone_chose()
    return mineTrack ~= nil or mineVolume ~= nil
end

music.PACKET_CLEAR = "musicclear"
hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil or data.ofp ~= music.PACKET_CLEAR then return end

    if not OF.util.from_host(data) then return end

    music.forget_mine()
end)

music.FANFARES = {
    win    = "play_star_fanfare",
    start  = "play_race_fanfare",
    finish = "play_course_clear",
    asked  = "play_toads_jingle",
    notice = "play_puzzle_jingle",
}

local FANFARE_GAP = 90
local lastFanfare = nil

function music.fanfares_on()
    return OF.settings == nil or OF.settings.fanfares ~= false
end

function music.fanfare(kind)
    if not music.fanfares_on() then return false end
    local name = music.FANFARES[kind]
    if name == nil then return false end

    local now = get_global_timer()
    if lastFanfare ~= nil and now - lastFanfare < FANFARE_GAP then return false end

    local play = OF.util.binding(name)
    if play == nil then return false end

    lastFanfare = now
    play()
    return true
end

function music.set_fanfares(value)
    if OF.settings == nil then return false end
    OF.settings.set_fanfares(value)

    OF.notify.show("Fanfares: @", "info", 4, value and "on" or "off")
    return true
end

local NEVER_LOOKED = {}
local signPacked = NEVER_LOOKED
local signUp = nil

function music.watch_the_sign()
    local packed = gGlobalSyncTable.ofSign
    if packed == signPacked then return false end
    signPacked = packed

    local up = OF.util.asks(OF.sign, "on")
        and OF.util.asks(OF.sign, "has_content")
        and OF.sign.on() and OF.sign.has_content()
    local was = signUp
    signUp = up
    if was == nil then return false end
    if up and not was then return music.fanfare("notice") end
    return false
end

hook_on_sync_table_change(gGlobalSyncTable, "ofMusic", 0, function(tag, oldVal, newVal)

    if OF.util.asks(OF.guard, "repair") and OF.guard.repair("ofMusic") then return end

    local missing = music.lobby_missing()
    if missing ~= nil and OF.util.asks(OF.notify, "show") then
        OF.notify.show("This copy has not got @ - the level's own music instead",
            "warn", 6, missing)
    end
    start(music.in_force())
end)

hook_on_sync_table_change(gGlobalSyncTable, music.VOLUME_KEY, 100, function()
    if OF.util.asks(OF.guard, "repair")
        and OF.guard.repair(music.VOLUME_KEY) then return end
    apply_volume()
end)

local function arrived()

    playing = nil
    wanted = nil

    orphan = nil
    music.refresh()
end

hook_event(HOOK_ON_LEVEL_INIT, arrived)

hook_event(HOOK_ON_WARP, arrived)

local CHECK_FRAMES = 30
local sinceCheck = 0

local STILL_FRAMES = 3
local lastAcc, stillFor = nil, 0

local function level_player_stalled()
    if sequence_player_get_tempo_acc == nil then return false end

    if OF.util.optional("is_game_paused", false) then
        lastAcc, stillFor = nil, 0
        return false
    end

    if OF.util.optional("sequence_player_get_fade_volume", 1.0,
        SEQ_PLAYER_LEVEL) <= 0 then
        lastAcc, stillFor = nil, 0
        return false
    end

    local acc = sequence_player_get_tempo_acc(SEQ_PLAYER_LEVEL)
    if acc ~= lastAcc then
        lastAcc, stillFor = acc, 0
        return false
    end
    stillFor = stillFor + 1
    return stillFor >= STILL_FRAMES
end

function music.play_again()
    if wanted == nil then return false end
    if quiet() then return false end
    if not ours_at_head() then return false end
    play_music(SEQ_PLAYER_LEVEL, wanted, FADE_IN)
    apply_volume()
    return true
end

local function play_it_again()
    if wanted == nil then return false end
    if quiet() then return false end
    if not ours_at_head() then return false end
    if not level_player_stalled() then return false end

    play_music(SEQ_PLAYER_LEVEL, wanted, FADE_IN)

    apply_volume()
    lastAcc, stillFor = nil, 0
    return true
end

function music.keep_playing()

    sinceCheck = sinceCheck + 1
    if sinceCheck < CHECK_FRAMES then return false end
    sinceCheck = 0

    if sweep_orphan() then return true end

    apply_volume()

    if quiet() then
        hold_quiet()
        return true
    end
    if wanted == nil then return false end
    if ours_at_head() then
        playing = wanted
        return false
    end
    push()
    return true
end

hook_event(HOOK_UPDATE, function()

    if wornBank ~= nil then
        OF.util.optional("set_sound_bank_override", nil, -1)

        if bankOwed then
            bankOwed = false
            music.free_the_voice()
        end
    end

    music.follow_the_room()
    music.watch_the_sign()
    music.keep_playing()

    play_it_again()
end)

local LOBBY_NEED = "music"
local MINE_NEED = "costume_self"
local function radio_row(panel, seq, name, about, askable)
    local room = (music.lobby_track() == seq)
    local mine = music.mine_state("track", seq)
    local marked = panel.mine_marked(mine)

    local r, g, b = 255, 255, 255
    if room then
        r, g, b = OF.util.gold().r, OF.util.gold().g, OF.util.gold().b
    end

    local sets = panel.may(LOBBY_NEED)
    local asks = askable and not sets

    local built = panel.two_box({
        lobbyOn = room,

        mineBox = panel.mine_shown(mine, room),
        name = name,
        lobbyNeed = asks and "panel" or LOBBY_NEED,
        mineNeed = MINE_NEED,
        r = r, g = g, b = b,
        onLobby = function()
            if asks then
                OF.util.report(music.request(seq))
                return
            end
            OF.util.report(music.set_lobby(seq))
        end,

        onMine = function()
            local next = panel.next_mine(music.mine_state("track", seq),
                music.lobby_track() == seq)

            if next == true then
                OF.util.report(music.set_mine_track(seq))
            elseif next == false then
                OF.util.report(music.set_mine_track(music.VANILLA))
            else
                OF.util.report(music.set_mine_track(nil))
            end
            panel.mark_dirty()
        end,
    })
    if asks then

        built.actionLabel = "to ask"
    end
    return panel.with_help(
        panel.level_right(built, marked,
            marked and OF.lang.t("(yours)") or nil),
        about)
end

local VOLUME_STEP = 10

local function volume_row(panel)
    local mine = music.mine_state("volume")
    local marked = panel.mine_marked(mine)
    local loud = music.volume() > 0

    local held = music.in_force("volume")

    local QUARTER = 25
    local stops = math.floor(100 / QUARTER)

    local built = panel.two_box({
        lobbyOn = loud,
        mineBox = panel.mine_shown(mine, loud),
        name = OF.lang.t("Volume"),
        lobbyNeed = LOBBY_NEED,
        mineNeed = MINE_NEED,
        r = 255, g = 255, b = 255,
        onLobby = function()
            local stepped = music.volume() + QUARTER
            if stepped > 100 then stepped = 0 end
            OF.util.report(music.set_volume(stepped))
        end,

        onMine = function()
            local room = music.volume()

            local roomStop = -1
            if room % QUARTER == 0 then roomStop = room // QUARTER end
            local want = panel.next_mine_level(mine,
                music.in_force("volume") // QUARTER, stops, roomStop)
            if want == nil then
                OF.util.report(music.set_mine_volume(nil))
            else
                OF.util.report(music.set_mine_volume(want * QUARTER))
            end
            panel.mark_dirty()
        end,
    })

    built = panel.level_right(built, true,
        panel.two_box_level(OF.lang.fill("@%", tostring(held)), marked))

    local dialsRoom = (mine == nil) and panel.may(LOBBY_NEED)
    local need = dialsRoom and LOBBY_NEED or MINE_NEED
    local at = math.floor(held / VOLUME_STEP)
    if panel.may(need) then
        built = panel.with_slider(built, at, 10, function(step)
            if dialsRoom then
                OF.util.report(music.set_volume(step * VOLUME_STEP))
            else

                OF.util.report(music.set_mine_volume(step * VOLUME_STEP))
            end
        end)
    else

        built = panel.with_slider(built, at, 10, nil)
    end
    return panel.with_help(built,
        OF.lang.t("the music only - sound effects and voices are untouched"))
end

function music.build_page(panel)
    local rows = {}

    table.insert(rows, panel.label_row(
        OF.lang.fill("Playing: @", music.track_name(music.in_force()))))

    if music.round_hides() then
        table.insert(rows, panel.label_row(OF.lang.t(
            "A round is choosing the music - the lobby's and yours come back "
            .. "after it.")))
    end

    table.insert(rows, radio_row(panel, music.VANILLA,
        OF.lang.t("Back to the level's own music"),
        OF.lang.t("every place plays what it always played - A for the lobby, "
            .. "Z for your own speakers"), false))

    for _, r in ipairs(OF.util.asks(OF.modifiers, "build_rows")
            and OF.modifiers.build_rows(panel, "music") or {}) do
        table.insert(rows, r)
    end

    table.insert(rows, panel.with_help(
        panel.header_row(OF.lang.t("The lobby's sound")),
        "how loud the music is, and the press that stops it altogether - both "
        .. "of them for the lobby or for you alone"))

    table.insert(rows, radio_row(panel, music.SILENCE,
        OF.lang.t("Silence - nothing at all"),
        OF.lang.t("the music stops - everything else still makes its noise"),
        false))

    table.insert(rows, volume_row(panel))

    table.insert(rows, panel.with_help(panel.with_right(panel.gated_row("music",
        OF.lang.t("Rounds play"),
        255, 255, 255, function()
            OF.util.report(music.set_policy(
                music.rounds_policy() == "" and "vanilla" or ""))
        end),
        OF.lang.t(music.rounds_name())),
        "one answer for everybody in the round - a mode with no music of its "
        .. "own leaves your track playing"))

    local heading = nil
    for _, track in ipairs(music.TRACKS) do
        if track.group ~= heading then
            heading = track.group
            table.insert(rows, panel.header_row(OF.lang.t(heading)))
        end

        local about = track.about ~= nil and OF.lang.t(track.about) or nil
        table.insert(rows,
            radio_row(panel, track.seq, track.name, about, true))
    end

    table.insert(rows, panel.back_row("control"))
    return rows
end
