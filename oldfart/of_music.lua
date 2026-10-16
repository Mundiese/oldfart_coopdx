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
music.FAMILIES = {
    { key = "mario2d",   label = "Super Mario: 2D and Yoshi" },
    { key = "mario3d",   label = "Super Mario: 3D" },
    { key = "galaxy",    label = "Super Mario Galaxy" },
    { key = "kart",      label = "Mario Kart and racing" },
    { key = "rpg",       label = "Mario RPGs" },
    { key = "party",     label = "Mario Party and Luigi's Mansion" },
    { key = "rare",      label = "Donkey Kong and Banjo" },
    { key = "zelda",     label = "Zelda" },
    { key = "kirby",     label = "Kirby and Pokemon" },
    { key = "sonic",     label = "Sonic" },
    { key = "undertale", label = "Undertale" },
    { key = "other",     label = "Other games" },
}
music.FAMILY_FALLBACK = "other"
music.CATEGORIES = {
    { key = "mine",      label = "My music" },
}

function music.family_of(key)
    for _, one in ipairs(music.FAMILIES) do
        if one.key == key then return one.label end
    end
    for _, one in ipairs(music.FAMILIES) do
        if one.key == music.FAMILY_FALLBACK then return one.label end
    end
    return "Other games"
end

function music.place_of(key)
    local function category(k)
        for _, one in ipairs(music.CATEGORIES or {}) do
            if one.key == k then return one end
        end
        return nil
    end
    local top = category(key)
    if top ~= nil then return top.label, nil end
    for _, one in ipairs(music.FAMILIES) do
        if one.key == key and one.under ~= nil then
            local up = category(one.under)
            if up ~= nil then return up.label, one.label end
        end
    end
    return music.OTHER, music.family_of(key)
end

local IMPORTED = {

    { file = "uf64b_unjolly_dires", family = "other", ext = "mp3",
      game = "Unfunny 64-bit Platformer",
      name = "Unfunny 64-bit Platformer - Unjolly Dires",
      about = "Unfunny 64-bit's water theme, by Baut & PacTheAnimator" },

}

music.IMPORTED = IMPORTED

music.RETIRED_TRACKS = {
    ["b64_blue_resort"] = "",
    ["bk_mumbos_mountain"] = "",
    ["bk_treasure_trove_cove"] = "",
    ["cvhod_vampire_killer"] = "",
    ["dk64_creepy_castle"] = "",
    ["dk64_mad_jack"] = "",
    ["dkc2_forest_interlude"] = "",
    ["dkc2_stickerbrush"] = "",
    ["dkc_aquatic_ambience"] = "",
    ["dkr_ancient_lake"] = "",
    ["dkr_greenwood_village"] = "",
    ["ff7_one_winged_angel"] = "",
    ["k64_shiver_star"] = "",
    ["kdl3_sand_canyon"] = "",
    ["kdl_green_greens"] = "",
    ["kndl_butter_building"] = "",
    ["lm_game_boy_horror"] = "",
    ["mk64_bowsers_castle"] = "",
    ["mk64_frappe_snowland"] = "",
    ["mk64_kalimari_desert"] = "",
    ["mk64_raceways"] = "",
    ["mk64_rainbow_road"] = "",
    ["mk7_rainbow_road"] = "",
    ["mk8_cloudtop_cruise"] = "",
    ["mkds_waluigi_pinball"] = "",
    ["mkwii_maple_treeway"] = "",
    ["mkwii_race_menu"] = "",
    ["mlbis_showtime"] = "",
    ["mlss_battle"] = "",
    ["mlss_boss_battle"] = "",
    ["mm_stone_tower"] = "",
    ["mp2_going_somewhere"] = "",
    ["mp2_horror_land"] = "",
    ["mp3_inside_the_castle"] = "",
    ["mp5_toy_dream"] = "",
    ["nsmb_athletic"] = "",
    ["nsmb_overworld"] = "",
    ["oot_ganondorf_battle"] = "",
    ["oot_gerudo_valley"] = "",
    ["oot_kokiri_forest"] = "",
    ["oot_lost_woods"] = "",
    ["oot_mini_game"] = "",
    ["oot_song_of_storms"] = "",
    ["pkmn_eterna_forest"] = "",
    ["pkmn_lavender_town"] = "",
    ["sm3dw_beach"] = "",
    ["sm3dw_bowser"] = "",
    ["sm3dw_sprawling_savannah"] = "",
    ["smb3_airship"] = "",
    ["smb3_athletic"] = "",
    ["smb3_overworld"] = "",
    ["smb_overworld"] = "",
    ["smg2_supermassive_galaxy"] = "",
    ["smg2_yoshi_star_galaxy"] = "",
    ["smg_buoy_base_galaxy"] = "",
    ["smg_comet_observatory"] = "",
    ["smg_good_egg_galaxy"] = "",
    ["smg_gusty_garden"] = "",
    ["smg_purple_comet"] = "",
    ["smg_space_junk_galaxy"] = "",
    ["smg_waltz_of_the_boos"] = "",
    ["smk_beach"] = "",
    ["smk_mario_circuit"] = "",
    ["smo_cap_kingdom"] = "",
    ["smo_cascade_kingdom"] = "",
    ["smo_jump_up_super_star"] = "",
    ["smrpg_forest_maze"] = "",
    ["smrpg_sunken_ship"] = "",
    ["sms_delfino_plaza"] = "",
    ["sms_gelato_beach"] = "",
    ["smw2_athletic"] = "",
    ["smw2_big_boss"] = "",
    ["smw2_cave"] = "",
    ["smw2_flower_garden"] = "",
    ["smw2_fuzzy_dizzy"] = "",
    ["smw_athletic"] = "",
    ["smw_overworld"] = "",
    ["sonicr_super_sonic_racing"] = "",
    ["spm_floro_caverns"] = "",
    ["spm_the_ultimate_show"] = "",
    ["ssb_meta_crystal_brawl"] = "",
    ["sth2_chemical_plant"] = "",
    ["sth3_ice_cap"] = "",
    ["sth_green_hill_zone"] = "",
    ["sthcd_stardust_speedway"] = "",
    ["tetris_theme_a"] = "",
    ["ttyd_shadow_queen"] = "",
    ["tww_dragon_roost"] = "",
    ["uf64b_unfunny_slide"] = "",
    ["ut_bonetrousle"] = "",
    ["ut_death_by_glamour"] = "",
    ["ut_megalovania"] = "",
    ["ut_ruins"] = "",
    ["ut_sans"] = "",
    ["ut_snowdin_town"] = "",
    ["ut_spider_dance"] = "",
}

local MAX_SEQUENCE = 128

local function bring_in(entry, slot)
    if type(smlua_audio_utils_allocate_sequence) ~= "function" then return nil end
    if type(smlua_audio_utils_replace_sequence) ~= "function" then return nil end
    if type(mod_file_exists) ~= "function" then return nil end
    if not mod_file_exists("sound/" .. entry.file .. ".m64") then return nil end

    local seq = slot or smlua_audio_utils_allocate_sequence()
    if slot == nil and type(seq) == "number" and seq >= MAX_SEQUENCE then
        return nil, "full"
    end

    local floor = type(SEQ_COUNT) == "number" and SEQ_COUNT or 0
    if type(seq) ~= "number" or seq <= floor or seq >= MAX_SEQUENCE then
        return nil
    end
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

music.CLAIM_BASE = 2000

local waiting = {}

local claimedAs = {}

local unclaimable = {}

music.STREAM_BASE = 1000
music.STREAM_KINDS = { mp3 = true, ogg = true, aiff = true }

local streams = {}

function music.is_stream(seq)
    seq = tonumber(seq)
    return seq ~= nil and streams[seq] ~= nil
end

local function stream_path(entry)
    local want = "sound/" .. entry.file .. "." .. entry.ext
    local bare = entry.file .. "." .. entry.ext
    if type(mod_file_exists) == "function" and mod_file_exists(want) then
        return bare
    end
    if type(get_mod_files) ~= "function" or type(get_active_mod) ~= "function" then
        return nil
    end
    local files = get_mod_files(get_active_mod())
    if type(files) ~= "table" then return nil end
    local tail = "/" .. string.lower(want)
    local lowBare = string.lower(bare)
    for _, path in ipairs(files) do
        if type(path) == "string" then
            local norm = string.lower((string.gsub(path, "\\", "/")))
            if norm == string.lower(want)
                or string.sub(norm, -#tail) == tail then
                return bare
            end

            if norm == lowBare
                or string.sub(norm, -(#lowBare + 1)) == "/" .. lowBare then
                return bare
            end
        end
    end
    return nil
end

local function bring_in_stream(entry, index)
    if type(audio_stream_load) ~= "function" then return nil end
    if type(audio_stream_play) ~= "function" then return nil end
    local path = stream_path(entry)
    if path == nil then return nil end
    local handle = audio_stream_load(path)
    if handle == nil then return nil end
    local seq = music.STREAM_BASE + index
    streams[seq] = { handle = handle, entry = entry }
    if type(entry.loopFrom) == "number" then
        audio_stream_set_loop_points(handle, entry.loopFrom, entry.loopTo or 0)
    end
    return seq
end

local function row_of_key(key)
    for _, track in ipairs(music.TRACKS) do
        if track.key == key then return track end
    end
    return nil
end

function music.artist_of(about)
    if type(about) ~= "string" then return nil end
    local at = nil
    local from = 1
    while true do
        local s, e = string.find(about, ", by ", from, true)
        if s == nil then break end
        at, from = e + 1, e + 1
    end
    if at == nil and string.sub(about, 1, 3) == "by " then at = 4 end
    if at == nil then return nil end
    local who = string.sub(about, at)
    return who ~= "" and who or nil
end

function music.track_artist(entry)
    if type(entry) ~= "table" then return nil end
    if type(entry.artist) == "string" and entry.artist ~= "" then return entry.artist end
    return music.artist_of(entry.about)
end

function music.row_label(entry)
    if type(entry) ~= "table" then return nil end
    local title = tostring(entry.name or entry.file or "")
    local game = entry.game
    if type(game) == "string" and game ~= "" then
        if string.find(title, game, 1, true) ~= nil then return title end
        return game .. " - " .. title
    end
    local artist = music.track_artist(entry)
    if artist == nil then return title end
    local tail = " - " .. artist
    if string.sub(title, -#tail) == tail then return title end
    return title .. tail
end

function music.import_tracks()
    local added = 0
    for index, entry in ipairs(IMPORTED) do
        local seq = imported[entry.file]
        if seq == nil then
            local stream = entry.ext ~= nil and entry.ext ~= "m64"
            if stream then
                if music.STREAM_KINDS[entry.ext] then
                    seq = bring_in_stream(entry, index)
                end
            elseif type(mod_file_exists) == "function"
                and mod_file_exists("sound/" .. entry.file .. ".m64") then

                seq = music.CLAIM_BASE + index
                waiting[seq] = entry
            end
            if seq ~= nil then imported[entry.file] = seq end
        end

        if seq ~= nil and row_of_key(entry.file) == nil then
            table.insert(music.TRACKS, {

                seq = seq, key = entry.file,

                name = entry.name, group = select(1, music.place_of(entry.family)),
                family = select(2, music.place_of(entry.family)),
                about = entry.about,
                stream = (entry.ext ~= nil and entry.ext ~= "m64") or nil,

                game = entry.game,
                artist = music.track_artist(entry),

                label = music.row_label(entry),
            })
            added = added + 1
        end
    end
    return added
end

local slotOwner = {}
local lastWanted = {}
local everPlayed = {}
local spent = {}
local wantTick = 0
local slot_in_use = function() return false end

function music.files_reread()
    if type(network_is_server) == "function" and network_is_server() then
        return true
    end
    if type(get_active_mod) ~= "function" then return true end
    local mod = get_active_mod()
    local name = mod ~= nil and mod.name or nil
    if type(name) ~= "string" then return true end
    name = string.lower(name)
    return name:find("[wip]", 1, true) == nil and name:find("(wip)", 1, true) == nil
end

local function touch(localId)
    wantTick = wantTick + 1
    lastWanted[localId] = wantTick
end

local function victim()
    local best, bestKey = nil, nil
    for slot, localId in pairs(slotOwner) do
        if not slot_in_use(slot) then
            local key = (everPlayed[localId] and 1e9 or 0)
                + (lastWanted[localId] or 0)
            if bestKey == nil or key < bestKey
                    or (key == bestKey and slot < best) then
                best, bestKey = slot, key
            end
        end
    end
    return best
end

local function release(slot)
    local localId = slotOwner[slot]
    if localId == nil then return end
    local entry = nil
    for _, one in ipairs(IMPORTED) do
        if imported[one.file] == slot then entry = one break end
    end
    slotOwner[slot] = nil
    claimedAs[localId] = nil
    if entry == nil then return end
    imported[entry.file] = localId
    local row = row_of_key(entry.file)
    if row ~= nil then row.seq = localId end
    if everPlayed[localId] and not music.files_reread() then
        spent[localId] = true
        unclaimable[localId] = true
    else
        waiting[localId] = entry
    end
    everPlayed[localId] = nil
end

function music.mark_played(slot)
    local localId = slotOwner[tonumber(slot) or -1]
    if localId ~= nil then everPlayed[localId] = true end
end

function music.is_spent(seq)
    seq = tonumber(seq)
    return seq ~= nil and spent[seq] == true
end

function music.slots_held()
    local n = 0
    for _ in pairs(slotOwner) do n = n + 1 end
    return n
end

function music.claim(seq)
    seq = tonumber(seq)
    if seq == nil then return nil end
    if claimedAs[seq] ~= nil then
        touch(seq)
        return claimedAs[seq]
    end
    if slotOwner[seq] ~= nil then touch(slotOwner[seq]) end
    local entry = waiting[seq]
    if entry == nil then
        if unclaimable[seq] then return nil end
        return seq
    end
    local real, why = bring_in(entry)
    if real == nil and why == "full" then
        local slot = victim()
        if slot ~= nil then
            release(slot)
            real = bring_in(entry, slot)
        end

        if real == nil then return nil end
    end
    if real == nil then
        waiting[seq] = nil
        unclaimable[seq] = true
        return nil
    end
    waiting[seq] = nil
    claimedAs[seq] = real
    slotOwner[real] = seq
    touch(seq)
    imported[entry.file] = real
    local row = row_of_key(entry.file)
    if row ~= nil then row.seq = real end
    return real
end

function music.alias(seq)
    local n = tonumber(seq)
    if n ~= nil and claimedAs[n] ~= nil then return claimedAs[n] end
    return seq
end

music.import_tracks()

local STREAM_RETRY = 60
local sinceRetry = 0

local function streams_owed()
    for _, entry in ipairs(IMPORTED) do
        if entry.ext ~= nil and entry.ext ~= "m64"
            and music.STREAM_KINDS[entry.ext] and not imported[entry.file] then
            return true
        end
    end
    return false
end

function music.retry_streams(now)
    if not now then
        sinceRetry = sinceRetry + 1
        if sinceRetry < STREAM_RETRY then return 0 end
    end
    sinceRetry = 0
    if not streams_owed() then return 0 end
    return music.import_tracks()
end

local ownBankOwed = {}

local function imported_entry(seq)
    for _, entry in ipairs(IMPORTED) do
        if imported[entry.file] == seq and seq ~= nil then return entry end
    end
    return nil
end
music.imported_entry = imported_entry

function music.restore_banks()
    local put = 0
    for _, entry in ipairs(IMPORTED) do
        local seq = imported[entry.file]

        if type(seq) == "number" and seq < MAX_SEQUENCE
            and not music.is_stream(seq) then
            ownBankOwed[seq] = true
            put = put + 1
        end
    end
    return put
end

function music.own_bank_owed(seq)
    if not ownBankOwed[seq] then return nil end
    local entry = imported_entry(seq)
    if entry == nil then ownBankOwed[seq] = nil return nil end
    return entry.bank
end

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
    seq = tonumber(music.alias(seq))
    if seq == nil then return nil end
    for _, entry in ipairs(music.TRACKS) do
        if entry.seq == seq and entry.key ~= nil then
            return music.IMPORT_MARK .. entry.key
        end
    end
    return seq
end

local function seq_of_key(key)
    for _, entry in ipairs(music.TRACKS) do
        if entry.key == key then return entry.seq end
    end
    return nil
end

function music.seq_for(wire)
    local key = marked(wire)
    if key == nil then
        local n = tonumber(wire)
        if n == nil then return nil end
        return music.claim(n)
    end
    local seq = seq_of_key(key)
    if seq ~= nil then return music.claim(seq) end

    if music.retry_streams() > 0 then
        seq = seq_of_key(key)
        if seq ~= nil then return music.claim(seq) end
    end

    local instead = music.RETIRED_TRACKS[key]
    if instead ~= nil then
        if instead == "" or instead == key then return 0 end

        local other = seq_of_key(instead)
        return other ~= nil and music.claim(other) or 0
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

local ownBankUp = false

function music.worn_bank()
    return wornBank
end

function music.wear_bank(bank)
    if type(bank) ~= "number" or bank <= 0 then bank = nil end
    wornBank = bank

    OF.util.optional("set_sound_bank_override", nil, -1)
    return true
end

music.SHUFFLED = {
    SEQ_LEVEL_GRASS, SEQ_LEVEL_INSIDE_CASTLE, SEQ_LEVEL_WATER, SEQ_LEVEL_HOT,
    SEQ_LEVEL_SNOW, SEQ_LEVEL_SLIDE, SEQ_LEVEL_SPOOKY, SEQ_LEVEL_UNDERGROUND,
    SEQ_LEVEL_KOOPA_ROAD,
}

function music.shuffled_for(seqPlayer, seqId)
    if seqPlayer ~= SEQ_PLAYER_LEVEL or type(seqId) ~= "number" then return nil end
    if OF.rando == nil or type(OF.rando.layer_track) ~= "function" then return nil end
    if music.round_hides() then return nil end
    local own = music.in_force()
    if own ~= nil and own ~= 0 then return nil end
    local base = seqId % 128
    local to = OF.rando.layer_track(base)
    if to == nil or to == base then return nil end
    return to + (seqId - base)
end

function music.replay_level()

    if music.round_hides() then return false end
    local own = music.in_force()
    if own ~= nil and own ~= 0 then return false end
    local head = OF.util.optional("get_current_background_music", nil)

    if type(head) ~= "number" or head < 0 or head == 65535 then return false end
    if OF.util.binding("play_music") == nil then return false end
    play_music(SEQ_PLAYER_LEVEL, head, 0)
    return true
end

hook_event(HOOK_ON_SEQ_LOAD, function(seqPlayer, seqId)

    if music.starves_level ~= nil and music.starves_level(seqPlayer) then
        return music.NO_LOAD
    end
    local swapped = music.shuffled_for(seqPlayer, seqId)
    local id = (type(swapped) == "number" and swapped or seqId)
    id = type(id) == "number" and id % 256 or nil

    if id ~= nil then music.mark_played(id) end
    if wornBank ~= nil then
        if seqPlayer == SEQ_PLAYER_LEVEL then
            OF.util.optional("set_sound_bank_override", nil, wornBank)
            bankOwed = true

            if imported_entry(id) ~= nil then ownBankOwed[id] = true end
        else
            OF.util.optional("set_sound_bank_override", nil, -1)
        end
    elseif seqPlayer == SEQ_PLAYER_LEVEL and id ~= nil then

        local own = music.own_bank_owed(id)
        if own ~= nil then
            OF.util.optional("set_sound_bank_override", nil, own)
            ownBankOwed[id] = nil
            ownBankUp = true
            bankOwed = true
        end
    elseif ownBankUp then

        OF.util.optional("set_sound_bank_override", nil, -1)
    end
    return swapped
end)

function music.free_the_voice()
    if OF.util.binding("play_music") == nil then return false end
    play_music(SEQ_PLAYER_SFX, SEQ_SOUND_PLAYER, 0)
    return true
end

function music.track_name(seq)
    seq = music.alias(seq)
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
    seq = tonumber(music.alias(seq))
    if seq == nil then return false end

    if unclaimable[seq] then return false end

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

function music.sounding()
    return playing
end

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

local streamOn = nil

local parkedStream = nil
local stop_stream
local streamGain = 0
local levelHeldFor = nil

music.env = { acc = nil, still = 0, on = false }

music.PAUSE_SCALE = 0.5
music.JINGLE_SCALE = 20 / 127
music.JINGLE_STILL = 3

music.STREAM_BOOST = 2

music.LOWERED_CAP = 40

music.NO_LOAD = 255
function music.engine_cap()
    local cap = 127
    if music.optional("is_current_background_music_volume_lowered", 0) == 1
        or music.optional("is_current_background_music_volume_lowered", 0) == true then
        cap = math.min(cap, music.LOWERED_CAP)
    end
    for _, getter in ipairs({ "get_current_background_music_max_target_volume",
            "get_current_background_music_target_volume" }) do
        local raw = tonumber(music.optional(getter, 0)) or 0

        if raw >= 0x80 then cap = math.min(cap, raw - 0x80) end
    end
    return cap
end

function music.stream_gain(rowVolume, dial, paused, jingle)
    local volume = math.max(0, math.min(127, tonumber(rowVolume) or 75))
    local gain = volume / 127 * (tonumber(dial) or 100) / 100 * music.STREAM_BOOST
    if paused then gain = gain * music.PAUSE_SCALE end
    local held = 1
    if volume > 0 then held = math.min(1, music.engine_cap() / volume) end
    if jingle then held = math.min(held, music.JINGLE_SCALE) end
    return gain * held
end

function music.env_step(st)
    local acc = music.optional("sequence_player_get_tempo_acc", nil, SEQ_PLAYER_ENV or 1)
    if acc == nil then st.on = false return false end
    if st.acc == nil then st.acc = acc return st.on end
    if acc ~= st.acc then
        st.acc, st.still, st.on = acc, 0, true
        return true
    end
    st.still = st.still + 1
    if st.still >= music.JINGLE_STILL then st.on = false end
    return st.on
end

function music.gain_toward(gain, target, snap, fade)
    if snap then return target end
    if gain < target then return math.min(target, gain + 1 / fade) end
    if gain > target then return math.max(target, gain - 1 / fade) end
    return gain
end

function music.refuses_load(seqPlayer, selectUp, streamInForce)
    if seqPlayer ~= (SEQ_PLAYER_LEVEL or 0) then return false end
    if selectUp then return false end
    return streamInForce == true
end

function music.optional(name, fallback, ...)
    return OF.util.optional(name, fallback, ...)
end

local function stream_target()
    if streamOn == nil or streams[streamOn] == nil then return 0 end
    if quiet() then return 0 end
    return music.stream_gain(streams[streamOn].entry.volume, music.in_force("volume"),
        OF.util.optional("is_game_paused", false), music.env.on)
end

local function hold_level(force)
    local head = get_current_background_music()
    if not force and levelHeldFor == head then return false end
    levelHeldFor = head
    fade_volume_scale(SEQ_PLAYER_LEVEL, 0, 1)
    return true
end

local function tend(snap)
    if streamOn == nil then return false end
    local handle = streams[streamOn].handle
    local was = streamGain
    streamGain = music.gain_toward(streamGain, stream_target(), snap, QUIET_FADE)
    if streamGain == was then return false end
    audio_stream_set_volume(handle, streamGain)
    return true
end

function music.tend_stream()
    if next(streams) == nil then return false end
    music.env_step(music.env)
    if streamOn ~= nil and music.star_select_up() then
        local seq = streamOn
        stop_stream()
        parkedStream = seq
        return true
    end
    if streamOn == nil and parkedStream ~= nil and not music.star_select_up() then
        parkedStream = nil
        music.refresh()
        return true
    end
    if streamOn == nil then return false end
    hold_level(false)
    return tend(false)
end

local starved = false

function music.starves_level(seqPlayer)

    local answer = streamOn
    if answer == nil then answer = music.in_force() end
    if not music.refuses_load(seqPlayer, music.star_select_up(), music.is_stream(answer)) then
        return false
    end
    starved = true
    return true
end

local function feed_level()
    if not starved then return false end
    starved = false
    local head = get_current_background_music()
    if head == nil or head == EMPTY_QUEUE or head < 0 then return false end
    play_music(SEQ_PLAYER_LEVEL, head, FADE_IN)
    return true
end

function music.level_starved()
    return starved
end

stop_stream = function()
    if streamOn == nil then return false end
    local one = streams[streamOn]
    streamOn, streamGain, levelHeldFor = nil, 0, nil
    if one ~= nil then audio_stream_stop(one.handle) end
    feed_level()
    return true
end

local function start_stream(seq)
    local one = streams[seq]
    if one == nil then return false end
    if music.star_select_up() then
        parkedStream = seq
        return false
    end
    parkedStream = nil
    streamOn = seq
    streamGain = stream_target()
    audio_stream_set_volume(one.handle, streamGain)
    audio_stream_set_looping(one.handle, true)
    audio_stream_play(one.handle, true, streamGain)
    return true
end

function music.stream_on()
    return streamOn
end

local function apply_volume()

    if streamOn ~= nil then
        volumeTouched = true
        hold_level(true)
        tend(false)
        return
    end
    levelHeldFor = nil

    local percent = music.in_force("volume")
    if percent >= 100 and not volumeTouched then

        return
    end
    volumeTouched = true
    fade_volume_scale(SEQ_PLAYER_LEVEL,
        math.floor(127 * percent / 100), QUIET_FADE)
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

    if OF.util.asks(OF.venues, "selecting") then return true end
    if OF.util.binding("obj_get_first_with_behavior_id") == nil then
        return false
    end
    if id_bhvActSelector == nil then return false end
    return obj_get_first_with_behavior_id(id_bhvActSelector) ~= nil
end

music.star_select_up = act_selector_up

function music.stream_parked()
    return parkedStream
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

slot_in_use = function(slot)
    for _, held in ipairs({ wanted, playing, orphan, overlay, mineTrack }) do
        if type(held) == "number" and held % 256 == slot % 256 then return true end
    end
    local key = marked(gGlobalSyncTable ~= nil and gGlobalSyncTable.ofMusic or nil)
    if key ~= nil and imported[key] == slot then return true end
    return false
end

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
    local lobby = music.lobby_track()
    if lobby ~= 0 then return lobby end

    if OF.util.asks(OF.venues, "stream_track") then
        return OF.venues.stream_track() or 0
    end
    return 0
end

local function start(seq)

    if seq ~= nil and seq ~= 0 and seq ~= music.SILENCE then
        seq = music.claim(seq) or 0

        if seq ~= 0 then music.mark_played(seq) end
    end

    if seq ~= nil and seq ~= 0 and seq ~= music.SILENCE and not silent
        and wanted ~= nil and playing ~= nil and wanted == PRIORITY * 256 + seq
        and ours_at_head() then
        return
    end

    if seq ~= nil and seq == streamOn then
        apply_volume()
        return
    end

    if music.is_stream(seq) then
        if playing == nil and wanted ~= nil then orphan = wanted % 256 end
        stop_stream()
        pop_ours()
        wanted = nil
        local wasSilent = silent
        silent = false
        if wasSilent and not quiet() then lift_quiet() end
        start_stream(tonumber(seq))
        apply_volume()
        if quiet() then hold_quiet() end
        return
    end

    if stop_stream() then apply_volume() end

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
        stop_stream()
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
    if OF.perms.tier(asker) < OF.perms.required("music", asker) then
        return false, "Your rank cannot do that."
    end

    return music.apply_lobby(seq, asker)
end

function music.apply_lobby(seq, askerLocal, quiet)

    seq = music.seq_for(seq)
    if seq == nil then
        return false, "This lobby has not got that track."
    end
    if not offers(seq) then return false, "That is not one of the tracks." end

    OF.util.publish("ofMusic", music.wire_for(seq))

    if quiet then return true end

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
    if OF.perms.tier(asker) < OF.perms.required("music", asker) then
        return false, "Your rank cannot do that."
    end

    return music.apply_volume_lobby(percent, asker)
end

function music.apply_volume_lobby(percent, askerLocal)
    percent = tonumber(percent)
    if percent == nil then return false, "Say a number from 0 to 100." end
    percent = OF.util.clamp(math.floor(percent), 0, 100)
    OF.util.publish(music.VOLUME_KEY, percent)

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

function music.reset_options()
    if not OF.util.is_host() or gGlobalSyncTable[music.VOLUME_KEY] == nil then return false end
    OF.util.publish(music.VOLUME_KEY, nil)
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

music.CUES = {
    { key = "warmup",   name = "Warm-up",
      when = "While people arrive, before the first round." },
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
            if key ~= nil then
                cues[key] = tonumber(answer)
            else
                key, answer = string.match(piece, "^(%a+)=(of:[%w_]+)$")
                if key ~= nil then cues[key] = answer end
            end
        end
    end
    return policy or "", cues
end

local function pack_evening(policy, cues)
    local parts = { tostring(policy or "") }
    for _, entry in ipairs(music.CUES) do
        local answer = cues[entry.key]
        if type(answer) == "number" then
            table.insert(parts, entry.key .. "=" .. tostring(math.floor(answer)))
        elseif type(answer) == "string" and marked(answer) ~= nil then
            table.insert(parts, entry.key .. "=" .. answer)
        end
    end
    return table.concat(parts, CUE_FIELD)
end

function music.cue(key)
    local _, cues = parse_evening(gGlobalSyncTable[music.ROUNDS_KEY])
    local answer = cues[key]
    if answer == nil then return nil end

    answer = music.seq_for(answer)
    if answer == nil or not offers(answer) then return nil end
    return answer
end

function music.cue_name(key)
    local answer = music.cue(key)
    if answer == nil then return "whatever the lobby is on" end
    return music.track_name(answer)
end

function music.round_wants()
    if not music.round_hides() then return nil end

    local asked = nil
    if OF.util.asks(OF.gamemodes, "current") then
        local mode = OF.gamemodes.current()
        if mode ~= nil then asked = mode.music end
    end

    if asked == nil then return music.VANILLA end
    return asked
end

function music.set_rounds_here(asker, value)
    if not OF.util.is_host() then return false, "Only the host sets these." end
    if asker == nil then return false, "Who asked?" end
    if OF.perms.tier(asker) < OF.perms.required("music", asker) then
        return false, "Your rank cannot do that."
    end

    return music.apply_rounds(value, asker)
end

function music.apply_rounds(value, askerLocal)
    local _, cues = parse_evening(value)

    local kept = {}
    for _, entry in ipairs(music.CUES) do
        local answer = cues[entry.key]
        local seq = answer ~= nil and music.seq_for(answer) or nil
        if seq ~= nil and offers(seq) then

            kept[entry.key] = music.wire_for(seq)
        end
    end

    local _, wasCues = parse_evening(gGlobalSyncTable[music.ROUNDS_KEY])
    OF.util.publish(music.ROUNDS_KEY, pack_evening("", kept))

    for _, entry in ipairs(music.CUES) do
        if kept[entry.key] ~= wasCues[entry.key] then

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

function music.set_cue(key, answer)
    if music.CUE_BY_KEY[key] == nil then
        return false, "Say warmup, breather or board."
    end
    if answer ~= nil and not offers(answer) then
        return false, "That is not one of the tracks."
    end
    local _, cues = parse_evening(gGlobalSyncTable[music.ROUNDS_KEY])

    cues[key] = answer ~= nil and music.wire_for(answer) or nil
    return music.set_rounds(pack_evening("", cues))
end

function music.set_rounds(value)
    if not OF.perms.can("music") then return false, "Your rank cannot do that.", "music" end

    if OF.util.is_host() then return music.apply_rounds(value, 0) end
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does("musicround", value)
    end
    return false, "No host to ask yet - try again in a second."
end

local REQUEST_GAP = 60 * 30
local askedAt = {}

function music.may_request(localIndex)
    local at = askedAt[localIndex]

    return at == nil or (get_global_timer() - at) >= REQUEST_GAP
end

function music.is_offered(seq)
    return offers(seq)
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

    OF.util.chat(OF.lang.fill("Put it on from Fun, Music: @",
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
    if seq == nil then return false end
    if not offers(seq) then
        if OF.util.asks(OF.chatlog, "add_system") then
            OF.chatlog.add_system("round music refused: " .. tostring(seq))
        end
        return false
    end
    return true
end

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
    if state ~= nil and state ~= OF.gamemodes.OFF then return nil end
    if not OF.util.asks(OF.night, "state") then return nil end
    local phase = OF.night.state()
    if phase == OF.night.WARMUP then return music.cue("warmup") end
    if phase == OF.night.BREAK then return music.cue("breather") end
    if phase == OF.night.BOARD then return music.cue("board") end
    return nil
end

function music.follow_the_room()
    local cue = nil
    if evening_set() then

        if music.mine_track() == nil then cue = room_cue() end
    end

    local round = music.round_wants()

    local moved = false
    if cue ~= overlay or round ~= roundHeard then
        overlay = cue
        roundHeard = round
        start(music.in_force())
        moved = true
    end
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
    seq = music.alias(seq)
    local room = music.lobby_track()
    if mineTrack == room then return nil end
    if mineTrack == seq then return true end
    if room == seq then return false end
    return nil
end

function music.set_mine_track(seq)
    if seq ~= nil then

        if not OF.perms.can("music_self") then
            return false, "Your rank cannot do that.", "music_self"
        end
        if not offers(seq) then return false, "That is not one of the tracks." end
        local asked = seq
        seq = music.claim(seq)
        if seq == nil and music.is_spent(asked) then
            return false, "That track was already unloaded on your machine this session."
        end
        if seq == nil then return false, "No room left for that track here." end

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

music.FANFARE_FRAMES = { win = 70, start = 81, finish = 104, asked = 66, notice = 89 }
local FANFARE_GAP = 90
local lastFanfare = nil
local lastFanfareFrames = FANFARE_GAP

function music.fanfare_gap()
    return lastFanfareFrames + 1
end

function music.fanfares_on()
    return OF.settings == nil or OF.settings.fanfares ~= false
end

function music.fanfare(kind)
    if not music.fanfares_on() then return false end
    local name = music.FANFARES[kind]
    if name == nil then return false end

    local now = get_global_timer()
    if lastFanfare ~= nil and now - lastFanfare < music.fanfare_gap() then return false end

    local play = OF.util.binding(name)
    if play == nil then return false end

    lastFanfare = now
    lastFanfareFrames = music.FANFARE_FRAMES[kind] or FANFARE_GAP
    play()
    return true
end

function music.set_fanfares(value)
    if OF.settings == nil then return false end
    OF.settings.set_fanfares(value)

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

    if marked(gGlobalSyncTable.ofMusic) ~= nil then music.retry_streams(true) end

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

    if playing ~= nil and playing % 256 > SEQ_COUNT then
        stop_background_music(playing)
    end
    playing = nil
    wanted = nil

    orphan = nil

    stop_stream()
    music.refresh()
end

hook_event(HOOK_ON_LEVEL_INIT, arrived)

hook_event(HOOK_ON_WARP, arrived)

local CHECK_FRAMES = 30
local sinceCheck = 0

music.STILL_FRAMES = 3

function music.level_stalled(st)
    if type(sequence_player_get_tempo_acc) ~= "function" then return false end

    if music.optional("is_game_paused", false) then
        st.acc, st.still = nil, 0
        return false
    end

    if (tonumber((music.optional("sequence_player_get_fade_volume", 1.0,
        SEQ_PLAYER_LEVEL or 0))) or 1.0) <= 0 then
        st.acc, st.still = nil, 0
        return false
    end

    local acc = sequence_player_get_tempo_acc(SEQ_PLAYER_LEVEL or 0)
    if acc ~= st.acc then
        st.acc, st.still = acc, 0
        return false
    end
    st.still = st.still + 1
    return st.still >= music.STILL_FRAMES
end

music.stall = { acc = nil, still = 0 }
local function level_player_stalled()
    return music.level_stalled(music.stall)
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
    music.stall.acc, music.stall.still = nil, 0
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

local restartOwed = false

function music.owe_restart_after_star()
    restartOwed = true
end

function music.pay_star_restart()
    if not restartOwed then return false end
    restartOwed = false
    if quiet() then return false end
    local head = queue_head()
    if head == nil then head = level_track() end
    if head == nil then return false end
    play_music(SEQ_PLAYER_LEVEL, head, FADE_IN)
    if wanted ~= nil and ours_at_head() then playing = wanted end
    apply_volume()
    return true
end

hook_event(HOOK_UPDATE, function()
    music.pay_star_restart()

    if wornBank ~= nil or ownBankUp then
        ownBankUp = false
        OF.util.optional("set_sound_bank_override", nil, -1)

        if bankOwed then
            bankOwed = false
            music.free_the_voice()
        end
    end

    music.follow_the_room()
    music.watch_the_sign()
    music.keep_playing()

    music.retry_streams()

    music.tend_stream()

    play_it_again()
end)

local LOBBY_NEED = "music"
local MINE_NEED = "music_self"
local function radio_row(panel, seq, name, about, askable)

    seq = music.alias(seq)
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

    built.track = seq
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

    if music.worn_bank() ~= nil and music.is_stream(music.in_force()) then
        table.insert(rows, panel.label_row(OF.lang.t(
            "This track is a recording and keeps its own sound - One set of "
            .. "instruments changes the other tracks only.")))
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

    local heading = nil
    local bySeries, otherHeading = {}, false

    local mine, mineByLabel = {}, {}
    for _, one in ipairs(music.CATEGORIES or {}) do
        mineByLabel[one.label] = { direct = {}, folders = {}, any = false }
    end
    for _, track in ipairs(music.TRACKS) do

      if offers(track.seq) then

        local about = track.about ~= nil and OF.lang.t(track.about) or nil
        mine = mineByLabel[track.group]
        if mine ~= nil and track.group ~= music.OTHER then
            local r = radio_row(panel, track.seq, track.label or track.name, about, true)
            if track.family == nil then
                table.insert(mine.direct, r)
            else
                mine.folders[track.family] = mine.folders[track.family] or {}
                table.insert(mine.folders[track.family], r)
            end
            mine.any = true
        elseif track.group == music.OTHER then
            otherHeading = true
            local label = track.family or music.family_of(nil)
            bySeries[label] = bySeries[label] or {}
            table.insert(bySeries[label],
                radio_row(panel, track.seq, track.label or track.name, about, true))
        else
            if track.group ~= heading then
                heading = track.group
                table.insert(rows, panel.header_row(OF.lang.t(heading)))
            end
            table.insert(rows,
                radio_row(panel, track.seq, track.name, about, true))
        end
      end
    end
    if otherHeading then
        table.insert(rows, panel.header_row(OF.lang.t(music.OTHER)))
        for _, one in ipairs(music.FAMILIES) do

            local elsewhere = one.under ~= nil
                and select(2, music.place_of(one.key)) ~= nil
                and select(1, music.place_of(one.key)) ~= music.OTHER
            local list = (not elsewhere) and bySeries[one.label] or nil
            if list ~= nil and #list > 0 then
                table.insert(rows, panel.sub_header_row(OF.lang.t(one.label)))
                for _, r in ipairs(list) do table.insert(rows, r) end
            end
        end
    end
    for _, top in ipairs(music.CATEGORIES or {}) do
        local got = mineByLabel[top.label]
        if got ~= nil and got.any then
            table.insert(rows, panel.header_row(OF.lang.t(top.label)))
            for _, r in ipairs(got.direct) do table.insert(rows, r) end
            for _, one in ipairs(music.FAMILIES) do
                local list = one.under == top.key and got.folders[one.label] or nil
                if list ~= nil and #list > 0 then
                    table.insert(rows, panel.sub_header_row(OF.lang.t(one.label)))
                    for _, r in ipairs(list) do table.insert(rows, r) end
                end
            end
        end
    end

    table.insert(rows, panel.back_row("control"))
    return rows
end
