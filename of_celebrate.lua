OF = OF or {}
OF.celebrate = OF.celebrate or {}

local celebrate = OF.celebrate

local LEVELS = {
    { key = "off",     blurb = "the chat line and nothing else",
      help = "a round ends with no sound, no shimmer and your camera left alone" },
    { key = "minimal", blurb = "the camera stop, the sound and your placing",
      help = "marks the end and shows where you came, without the ending sequence" },
    { key = "full",    blurb = "the whole ending, the star and all",
      help = "plays a round's ending the way the game plays a star's" },
}

local BLURB = {}
for _, level in ipairs(LEVELS) do BLURB[level.key] = level.blurb end

local shown = "full"
function celebrate.presentation()
    return shown
end

local function showing()
    return shown ~= "off"
end

local function spectacle()
    return shown == "full"
end

function celebrate.showing()
    return showing()
end

function celebrate.spectacle()
    return spectacle()
end

function celebrate.levels()
    local list = {}
    for index, level in ipairs(LEVELS) do
        list[index] = { key = level.key, blurb = level.blurb,
                        help = level.help }
    end
    return list
end

function celebrate.set_presentation(name)
    name = string.lower(tostring(name or ""))
    if BLURB[name] == nil then
        return false, "Presentation is off, minimal or full."
    end
    shown = name
    if not showing() then celebrate.stand_down() end
    return true
end

celebrate.particles = celebrate.particles or {}

local SPREAD_PERIOD = 1009

local acrossSeed = 0
local downSeed = 0

local ACROSS_STEP = 623
local DOWN_STEP = 385

local function scaled(seed, range)
    return math.floor(seed * (range * 2 + 1) / SPREAD_PERIOD) - range
end

local function spread_across(range)
    acrossSeed = (acrossSeed + ACROSS_STEP) % SPREAD_PERIOD
    return scaled(acrossSeed, range)
end

local function spread_down(range)
    downSeed = (downSeed + DOWN_STEP) % SPREAD_PERIOD
    return scaled(downSeed, range)
end

local WEATHER = {
    rain  = { drops = 70,  fall = 15, lean = -1.6, long = 11, storm = false },
    storm = { drops = 130, fall = 19, lean = -2.6, long = 14, storm = true  },
}

local RAIN_MAX = 140

local RAIN_COLOUR = { r = 178, g = 202, b = 232 }
local RAIN_ALPHA = 120

local STRIKES = {
    { wait = 210, delay = 62, peak = 150 },
    { wait = 130, delay = 38, peak = 190 },
    { wait = 260, delay = 88, peak = 110 },
    { wait = 95,  delay = 14, peak = 235 },
    { wait = 175, delay = 50, peak = 165 },
    { wait = 320, delay = 74, peak = 125 },
    { wait = 110, delay = 22, peak = 215 },
}

local FLASH = { 1.0, 0.45, 0.95, 0.60, 0.35, 0.18, 0.07 }

local weatherKind = nil

local rainDrops = {}

local strikeAt = 0
local strikeWait = 0
local strikesDone = 0
local flashFrame = 0
local flashPeak = 0
local bangIn = nil
local bangFar = false

function celebrate.weather_kinds()
    local out = {}
    for name in pairs(WEATHER) do table.insert(out, name) end
    table.sort(out)
    return out
end

function celebrate.weather()
    return weatherKind
end

function celebrate.rain_live()
    return #rainDrops
end

function celebrate.storm_strikes()
    return strikesDone
end

function celebrate.bang_left()
    return bangIn
end

function celebrate.flash_alpha()
    if flashFrame <= 0 or flashFrame > #FLASH then return 0 end
    return math.floor(flashPeak * FLASH[flashFrame])
end

local function forget_storm()
    strikeAt = 0
    strikeWait = 0
    strikesDone = 0
    flashFrame = 0
    flashPeak = 0
    bangIn = nil
    bangFar = false
end

function celebrate.set_weather(kind)
    if kind ~= nil and WEATHER[kind] == nil then return false end
    if kind == weatherKind then return true end
    weatherKind = kind
    rainDrops = {}
    forget_storm()
    if kind ~= nil and WEATHER[kind].storm then

        strikeWait = STRIKES[1].wait
    end
    return true
end

local function step_weather()
    if bangIn ~= nil then
        bangIn = bangIn - 1
        if bangIn <= 0 then
            bangIn = nil

            celebrate.shake(SHAKE_ENV_EXPLOSION)

            local bang = bangFar and SOUND_GENERAL_VOLCANO_EXPLOSION
                or SOUND_GENERAL_BOWSER_BOMB_EXPLOSION

            if OF.util.asks(OF.sounds, "play") then OF.sounds.play(bang) end
        end
    end

    if flashFrame > 0 then flashFrame = flashFrame + 1 end
    if flashFrame > #FLASH then flashFrame = 0 end

    if weatherKind == nil or not WEATHER[weatherKind].storm then return end

    if not showing() then return end

    strikeWait = strikeWait - 1
    if strikeWait > 0 then return end

    strikeAt = (strikeAt % #STRIKES) + 1
    local strike = STRIKES[strikeAt]
    strikeWait = STRIKES[(strikeAt % #STRIKES) + 1].wait
    strikesDone = strikesDone + 1

    if spectacle() then
        flashFrame = 1
        flashPeak = strike.peak
    end
    bangIn = strike.delay

    bangFar = strike.delay >= 40
end

local function paint_weather()
    if weatherKind == nil then return end
    if not spectacle() then return end

    local who = gMarioStates[0]
    if who == nil or who.marioObj == nil then return end

    local kind = WEATHER[weatherKind]

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    local width = djui_hud_get_screen_width()
    local height = djui_hud_get_screen_height()

    local wanted = math.min(kind.drops, RAIN_MAX)
    while #rainDrops < wanted do
        table.insert(rainDrops, {
            x = width * 0.5 + spread_across(math.floor(width * 0.62)),
            y = spread_down(math.floor(height)),
        })
    end
    while #rainDrops > wanted do table.remove(rainDrops) end

    local hidden = OF.util.menu_has_screen() or (OF.diagOpen == true)

    for index = 1, #rainDrops do
        local drop = rainDrops[index]
        drop.y = drop.y + kind.fall
        drop.x = drop.x + kind.lean

        if drop.y > height or drop.x < -kind.long or drop.x > width + kind.long then
            drop.y = -kind.long - math.abs(spread_down(math.floor(height * 0.5)))
            drop.x = width * 0.5 + spread_across(math.floor(width * 0.62))
        elseif not hidden then
            OF.util.rect(drop.x, drop.y, 1, kind.long,
                RAIN_COLOUR.r, RAIN_COLOUR.g, RAIN_COLOUR.b, RAIN_ALPHA)
        end
    end

    local alpha = celebrate.flash_alpha()
    if alpha > 0 and not hidden then

        OF.util.rect(0, 0, width, height, 255, 255, 255, alpha)
    end
end

local PLACING_SECONDS = 3

local MOMENT_FRAMES = 3 * 30

local function peace_beat(m)
    if m == nil or m.pos == nil then return 40 end
    local water = tonumber(m.waterLevel)
    if water == nil then return 40 end
    if tonumber(m.pos.y or 0) < water - 130 then return 62 end
    return 40
end

local function win_beats()
    local sheet = {
        [42] = function()
            play_character_sound(gMarioStates[0], CHAR_SOUND_HERE_WE_GO)
        end,
    }
    local hand = peace_beat(gMarioStates[0])
    if spectacle() then
        sheet[hand] = function()

            celebrate.peace_sign(MOMENT_FRAMES - hand)
        end
    end
    celebrate.play_beats(sheet)
end

celebrate.TRAIL_STARS = "stars"
celebrate.TRAIL_SPARKLE = "sparkle"
local trailFlags = nil
local trailLeft = 0

local function trail_bit(kind)
    if kind == celebrate.TRAIL_SPARKLE then return PARTICLE_SPARKLES end
    return PARTICLE_VERTICAL_STAR
end

function celebrate.trail(kind, frames)
    if not spectacle() then return false end
    local bit = trail_bit(kind)
    if type(bit) ~= "number" then return false end
    frames = math.floor(tonumber(frames) or 60)
    if frames <= 0 then return false end
    trailFlags = bit
    if frames > trailLeft then trailLeft = frames end
    return true
end

function celebrate.trail_left() return trailLeft end

function celebrate.stop_trail()
    trailFlags = nil
    trailLeft = 0
end

function celebrate.tick_trail(m)
    if trailLeft <= 0 then return end
    if m == nil or (m.playerIndex or 0) ~= 0 then return end
    trailLeft = trailLeft - 1
    if trailLeft <= 0 then
        trailFlags = nil
        return
    end
    if trailFlags ~= nil then
        m.particleFlags = (m.particleFlags or 0) | trailFlags
    end
end

function celebrate.win()
    if not showing() then return false end

    local sung = OF.util.asks(OF.music, "fanfare") and OF.music.fanfare("win")
    if not sung then OF.sounds.play(SOUND_MENU_STAR_SOUND) end

    celebrate.hit(SHAKE_LARGE_DAMAGE)

    celebrate.trail(celebrate.TRAIL_SPARKLE, 60)

    win_beats()
    return true
end

function celebrate.team_win(colour)
    if not showing() then return false end

    local sung = OF.util.asks(OF.music, "fanfare") and OF.music.fanfare("win")
    if not sung then OF.sounds.play(SOUND_MENU_STAR_SOUND) end

    celebrate.hit(SHAKE_LARGE_DAMAGE)

    celebrate.trail(celebrate.TRAIL_SPARKLE, 60)
    win_beats()
    return true
end

function celebrate.personal_best(score, was, wasDay)
    if not showing() then return false end

    OF.sounds.play(SOUND_MENU_COLLECT_SECRET)

    celebrate.trail(celebrate.TRAIL_SPARKLE, 30)

    if OF.util.asks(OF.notify, "show") then

        was = tonumber(was)
        if was ~= nil and was > 0 and OF.util.asks(OF.stats, "ago_text") then
            OF.notify.show("Your best yet - @, up from @", "good",
                PLACING_SECONDS, tostring(math.floor(score or 0)),
                OF.lang.fill("@, @", tostring(math.floor(was)),
                    OF.stats.ago_text(wasDay)))
        else
            OF.notify.show("Your best yet - @", "good", PLACING_SECONDS,
                tostring(math.floor(score or 0)))
        end
    end
    return true
end

function celebrate.comeback(gap)
    if not showing() then return false end

    OF.sounds.play(SOUND_GENERAL_STAR_APPEARS)

    if OF.util.asks(OF.notify, "show") then
        OF.notify.show("From @ behind - and you took it", "good",
            PLACING_SECONDS, tostring(math.floor(gap or 0)))
    end
    return true
end

function celebrate.shake(kind)
    if not showing() then return end
    set_environmental_camera_shake(kind or SHAKE_ENV_EXPLOSION)
end

function celebrate.hit(kind)
    if not showing() then return end
    set_camera_shake_from_hit(kind or SHAKE_LARGE_DAMAGE)
end

function celebrate.star_over(localIndex)
    if not spectacle() then return false end

    if OF.util.asks(OF.spectate, "is_spectating")
        and OF.spectate.is_spectating(localIndex) then
        return false
    end

    local m = gMarioStates[localIndex]
    if m == nil or m.marioObj == nil then return false end
    if m.pos == nil then return false end

    local star = spawn_non_sync_object(id_bhvCelebrationStar, E_MODEL_STAR,
        m.pos.x, m.pos.y, m.pos.z, function(o)
            o.parentObj = m.marioObj
            local keep = ACTIVE_FLAG_INITIATED_TIME_STOP
            if type(keep) == "number" then
                o.activeFlags = (o.activeFlags or 0) | keep
            end
        end)
    return star ~= nil
end

local beats = nil
local beatFrame = 0

function celebrate.play_beats(sheet)
    beats = sheet
    beatFrame = 0
    return true
end

function celebrate.beat_frame()
    return beats ~= nil and beatFrame or nil
end

function celebrate.forget_beats()
    beats = nil
    beatFrame = 0
end

local function step_beats()
    if beats == nil then return end
    beatFrame = beatFrame + 1
    local beat = beats[beatFrame]
    if beat ~= nil then OF.util.report(pcall(beat)) end

    for at in pairs(beats) do
        if at > beatFrame then return end
    end
    celebrate.forget_beats()
end

local peaceLeft = 0

function celebrate.peace_sign(frames)
    peaceLeft = math.max(0, math.floor(tonumber(frames) or 0))
    return peaceLeft
end

function celebrate.peace_left()
    return peaceLeft
end

hook_event(HOOK_MARIO_UPDATE, function(m)

    celebrate.tick_trail(m)

    if peaceLeft <= 0 then return end
    if m == nil or m.playerIndex ~= 0 then return end
    peaceLeft = peaceLeft - 1
    if m.marioBodyState ~= nil then
        m.marioBodyState.handState = MARIO_HAND_PEACE_SIGN
    end
end)

local HUSH_FRAMES = 50

local hushHeld = nil
local hushLeft = 0

local function background_banks()
    local function bit(name)
        local value = _G[name]
        if type(value) ~= "number" then return 0 end
        return 1 << value
    end

    return bit("SOUND_BANK_MOVING") | bit("SOUND_BANK_GENERAL")
        | bit("SOUND_BANK_ENV") | bit("SOUND_BANK_OBJ")
        | bit("SOUND_BANK_AIR") | bit("SOUND_BANK_GENERAL2")
        | bit("SOUND_BANK_OBJ2")
end

local function lent_elsewhere()
    if OF.modifiers == nil then return 0 end
    local held = OF.modifiers.quietHeld
    if type(held) ~= "number" then return 0 end
    return held
end

function celebrate.hush(frames)
    frames = math.floor(tonumber(frames) or 0)
    if frames <= 0 then return false end
    if OF.util.binding("sound_banks_disable") == nil then return false end

    if hushHeld == nil then
        local mask = background_banks() & ~lent_elsewhere()

        if mask == 0 then return false end
        hushHeld = mask

        OF.util.optional("sound_banks_disable", nil, 0, mask)
    end

    if frames > hushLeft then hushLeft = frames end
    return true
end

function celebrate.unhush()
    hushLeft = 0
    if hushHeld == nil then return false end
    OF.util.optional("sound_banks_enable", nil, 0, hushHeld & ~lent_elsewhere())
    hushHeld = nil
    return true
end

function celebrate.hush_left()
    return hushLeft
end

local function step_hush()
    if hushLeft <= 0 then return end
    hushLeft = hushLeft - 1
    if hushLeft <= 0 then celebrate.unhush() end
end

local DUCK_FRAMES = 50
local DUCK_IN = 5
local DUCK_OUT = 50

local duckHeld = false
local duckLeft = 0

local function seq_call(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return false end
    return (pcall(fn, ...))
end

function celebrate.duck(frames)
    if not showing() then return false end
    frames = math.floor(tonumber(frames) or DUCK_FRAMES)
    if frames <= 0 then return false end

    if not duckHeld then

        if not seq_call("seq_player_lower_volume", 0, DUCK_IN, 40) then
            return false
        end
        duckHeld = true
    end

    if frames > duckLeft then duckLeft = frames end
    return true
end

function celebrate.unduck()
    duckLeft = 0
    if not duckHeld then return false end
    seq_call("seq_player_unlower_volume", 0, DUCK_OUT)
    duckHeld = false
    return true
end

function celebrate.duck_left()
    return duckLeft
end

local function step_duck()
    if duckLeft <= 0 then return end
    duckLeft = duckLeft - 1
    if duckLeft <= 0 then celebrate.unduck() end
end

local STOP_FRAMES = 42

local stopHeld = false
local stopLeft = 0

local unfrozen = {}

local function stop_bit()
    local value = TIME_STOP_ENABLED
    if type(value) ~= "number" then return nil end
    return value
end

local function keep_running_bit()
    local value = ACTIVE_FLAG_INITIATED_TIME_STOP
    if type(value) ~= "number" then return nil end
    return value
end

local function let_players_run()
    local bit = keep_running_bit()
    if bit == nil then return 0 end

    local count = 0
    for _, entry in ipairs(OF.util.connected_players()) do
        local m = gMarioStates[entry.localIndex]
        local obj = m ~= nil and m.marioObj or nil
        if obj ~= nil then
            obj.activeFlags = (obj.activeFlags or 0) | bit
            unfrozen[entry.localIndex] = true
            count = count + 1
        end
    end
    return count
end

function celebrate.world_stop(frames)
    if not spectacle() then return false end
    frames = math.floor(tonumber(frames) or STOP_FRAMES)
    if frames <= 0 then return false end

    local bit = stop_bit()
    if bit == nil then return false end
    if OF.util.binding("set_time_stop_flags") == nil then return false end

    if keep_running_bit() == nil then return false end

    if not stopHeld then

        local held = OF.util.optional("get_time_stop_flags", 0)
        if type(held) == "number" and (held & bit) ~= 0 then return false end

        if let_players_run() == 0 then return false end
        OF.util.optional("set_time_stop_flags", nil, bit)
        stopHeld = true
    end

    if frames > stopLeft then stopLeft = frames end
    return true
end

function celebrate.world_go()
    stopLeft = 0
    if not stopHeld then return false end

    local bit = stop_bit()
    if bit ~= nil then OF.util.optional("clear_time_stop_flags", nil, bit) end

    local keep = keep_running_bit()
    if keep ~= nil then
        for localIndex in pairs(unfrozen) do
            local m = gMarioStates[localIndex]
            local obj = m ~= nil and m.marioObj or nil
            if obj ~= nil then
                obj.activeFlags = (obj.activeFlags or 0) & ~keep
            end
        end
    end
    unfrozen = {}
    stopHeld = false
    return true
end

function celebrate.stop_left()
    return stopLeft
end

local function step_stop()
    if stopLeft <= 0 then return end

    let_players_run()

    if type(SHAKE_ATTACK) == "number" then celebrate.hit(SHAKE_ATTACK) end

    stopLeft = stopLeft - 1
    if stopLeft <= 0 then celebrate.world_go() end
end

function celebrate.stand_down()
    celebrate.unhush()
    celebrate.unduck()
    celebrate.world_go()
    celebrate.forget_beats()
    celebrate.peace_sign(0)

    celebrate.stop_trail()

    forget_storm()
    celebrate.clear()
    return true
end

local BEAT_TWO = 15

function celebrate.my_placing()
    if not OF.util.asks(OF.gamemodes, "podium") then return nil end

    local mode = OF.gamemodes.current()
    local board
    if mode ~= nil and mode.resultsBy == "survival" then
        board = OF.gamemodes.survival_board()
    else
        board = OF.gamemodes.podium()
    end
    if board == nil or #board < 2 then return nil end

    for place, row in ipairs(board) do
        if row.localIndex == 0 then return place, #board end
    end
    return nil
end

local behindBy = 0

local bestScore = {}

local BEST_KEY = "cb_best"
local BEST_MAX = 9999
celebrate.BEST_MAX = BEST_MAX

local function best_row(key, held)
    if key == nil or held == nil then return nil end
    if string.find(key, "[|;]") ~= nil then return nil end
    local score = math.floor(tonumber(held.score) or 0)
    if score <= 0 then return nil end
    if score > BEST_MAX then score = BEST_MAX end

    return string.format("%s|%.0f|%.0f|100", key, score,
        math.floor(tonumber(held.day) or 0))
end

local beatenAt = 0

local loaded = false

local function ensure_loaded()
    if loaded then return end
    loaded = true
    celebrate.load_bests()
end

function celebrate.pack_bests()
    ensure_loaded()
    local order = {}
    for key, held in pairs(bestScore) do
        local row = best_row(key, held)
        if row ~= nil then
            table.insert(order, { row = row, at = held.beatenAt or 0 })
        end
    end
    table.sort(order, function(a, b)
        if a.at ~= b.at then return a.at > b.at end
        return a.row < b.row
    end)
    local rows = {}
    for _, entry in ipairs(order) do table.insert(rows, entry.row) end
    local packed, used = OF.util.pack_rows(rows, ";", OF.util.STORE_MAX)
    return packed, used, #rows
end

local function save_bests()
    return OF.util.store_soon(BEST_KEY, (celebrate.pack_bests()))
end

function celebrate.load_bests()
    loaded = true
    local packed = OF.util.stored(BEST_KEY, "")
    if packed == nil or packed == "" then return 0 end
    local rows = {}
    for row in string.gmatch(packed, "[^;]+") do table.insert(rows, row) end
    local read = 0
    for at = #rows, 1, -1 do
        local key, score, day, percent =
            string.match(rows[at], "^([^|]+)|(%d+)|(%d+)|(%d+)$")
        if key ~= nil then
            read = read + 1
            beatenAt = beatenAt + 1
            bestScore[key] = { score = tonumber(score) or 0,
                               day = tonumber(day) or 0,
                               beatenAt = beatenAt }
        end
    end
    return read
end

function celebrate.forget_bests()
    bestScore = {}
    beatenAt = 0

    loaded = true
    OF.util.clear(BEST_KEY)
end

function celebrate.best_in(key)
    if key == nil then return nil end
    ensure_loaded()
    local held = bestScore[key]
    if held == nil then return nil end
    return held.score
end

function celebrate.best_record(key)
    if key == nil then return nil end
    ensure_loaded()
    local held = bestScore[key]
    if held == nil then return nil end
    return { score = held.score, day = held.day, last = held.last }
end

function celebrate.behind_by()
    return behindBy
end

local COMEBACK_GAP = 3
local COMEBACK_SHARE = 3

local function my_score()
    local row = gPlayerSyncTable[0]
    return (row ~= nil and row.ofScore) or 0
end

function celebrate.comeback_won()
    if not OF.util.asks(OF.gamemodes, "i_won") then return false end
    if not OF.gamemodes.i_won() then return false end
    if behindBy < COMEBACK_GAP then return false end
    if behindBy * COMEBACK_SHARE < my_score() then return false end
    return true
end

local function today()
    if not OF.util.asks(OF.stats, "today_number") then return 0 end
    return math.floor(tonumber(OF.stats.today_number()) or 0)
end

function celebrate.take_best()
    if not OF.util.asks(OF.gamemodes, "current") then return nil end
    local mode = OF.gamemodes.current()
    if mode == nil or mode.key == nil then return nil end

    local score = my_score()
    if score <= 0 then return nil end

    ensure_loaded()
    local held = bestScore[mode.key]
    local was = held ~= nil and held.score or nil
    local wasDay = held ~= nil and held.day or nil
    local beat = was == nil or score > was

    if held == nil then
        held = { score = score, day = today() }
        bestScore[mode.key] = held
    elseif beat then
        held.score = score
        held.day = today()
    end

    held.last = score
    if beat then
        beatenAt = beatenAt + 1
        held.beatenAt = beatenAt

        save_bests()
    end

    if was == nil or score <= was then return nil end

    return score, was, wasDay
end

local function show_placing()

    if not showing() then return false end

    if not OF.util.asks(OF.gamemodes, "winner_line") then return false end

    if OF.gamemodes.winner_line() == "" then return false end
    if OF.util.asks(OF.gamemodes, "i_won") and OF.gamemodes.i_won() then
        return false
    end

    local place, total = celebrate.my_placing()
    if place == nil then return false end
    if not OF.util.asks(OF.stats, "ordinal") then return false end

    OF.notify.show("You finished @ of @", "info", PLACING_SECONDS,
        OF.stats.ordinal(place), total)
    return true
end

function celebrate.beat_two()
    local best, was, wasDay = celebrate.take_best()

    if celebrate.comeback_won() then
        celebrate.comeback(celebrate.behind_by())
    else
        show_placing()
    end

    if best ~= nil then celebrate.personal_best(best, was, wasDay) end
    return true
end

local lastRoundState = nil
local beatTwoLeft = 0

local function watch_ending()
    if not OF.util.asks(OF.gamemodes, "state") then return end

    local state = OF.gamemodes.state()
    if state ~= lastRoundState then
        local was = lastRoundState
        lastRoundState = state

        if state == OF.gamemodes.COUNTDOWN or state == OF.gamemodes.ACTIVE then
            behindBy = 0
        end
        if state == OF.gamemodes.MOMENT and was ~= nil then

            celebrate.hush(HUSH_FRAMES)
            celebrate.duck(HUSH_FRAMES)
            celebrate.world_stop(STOP_FRAMES)
            beatTwoLeft = BEAT_TWO
        else

            beatTwoLeft = 0

            celebrate.world_go()
        end
    end

    if beatTwoLeft > 0 then
        beatTwoLeft = beatTwoLeft - 1
        if beatTwoLeft <= 0 then OF.util.report(pcall(celebrate.beat_two)) end
    end
end

function celebrate.clear()
    celebrate.particles = {}

    rainDrops = {}
end

local NUMBER_MAX = 999
local NUMBER_HEIGHT = 120

function celebrate.number(amount, x, y, z)

    if not showing() then return false end
    amount = math.floor(tonumber(amount) or 0)

    if amount < 1 then return false end
    if amount > NUMBER_MAX then amount = NUMBER_MAX end

    if spawn_non_sync_object == nil then return false end
    local made = spawn_non_sync_object(id_bhvOrangeNumber, E_MODEL_NUMBER,
        x, y, z, function(obj)

            obj.oBehParams2ndByte = amount
        end)
    return made ~= nil
end

function celebrate.puff(x, y, z)
    if not showing() then return false end
    if spawn_non_sync_object == nil then return false end

    local made = spawn_non_sync_object(id_bhvStarKeyCollectionPuffSpawner,
        E_MODEL_NONE, x, y, z, nil)
    return made ~= nil
end

function celebrate.puff_over(localIndex)
    local m = gMarioStates[localIndex]
    if m == nil or m.pos == nil then return false end
    return celebrate.puff(m.pos.x, m.pos.y + 60, m.pos.z)
end

function celebrate.number_over(localIndex, amount)
    local m = gMarioStates[localIndex]
    if m == nil or m.pos == nil then return false end
    return celebrate.number(amount, m.pos.x, m.pos.y + NUMBER_HEIGHT, m.pos.z)
end

local lastScore = {}

local runOfScores = 0

local lastRole = {}

function celebrate.forget_scores()
    lastScore = {}
    lastRole = {}
    runOfScores = 0

end

function celebrate.presentation_rows(panel)
    local rows = {}

    if panel == nil or panel.row == nil or panel.with_help == nil then
        return rows
    end

    table.insert(rows, panel.header_row("How a win looks to you"))
    for _, level in ipairs(celebrate.levels()) do
        local key = level.key
        local mark = "   "
        local r, g, b = 255, 255, 255
        if shown == key then
            mark = " > "
            r, g, b = OF.util.gold().r, OF.util.gold().g, OF.util.gold().b
        end
        table.insert(rows, panel.with_help(
            panel.row(mark .. key .. " - " .. level.blurb,
                r, g, b, function()
                    OF.util.report(celebrate.set_presentation(key))
                end),
            level.help))
    end
    return rows
end

local function numbers_wanted()
    local mode = OF.gamemodes.current()
    return mode == nil or not mode.scoreIsTime
end

function celebrate.watch_scores()
    if not (OF.util.asks(OF.gamemodes, "is_running") and OF.gamemodes.is_running()) then

        celebrate.forget_scores()
        return
    end

    local wanted = numbers_wanted()

    local mine, ahead = 0, 0
    for _, entry in ipairs(OF.util.connected_players()) do
        local row = gPlayerSyncTable[entry.localIndex]
        local score = row ~= nil and row.ofScore or 0
        if entry.localIndex == 0 then mine = score end
        if score > ahead then ahead = score end
    end
    if ahead - mine > behindBy then behindBy = ahead - mine end

    for _, entry in ipairs(OF.util.connected_players()) do
        local index = entry.localIndex
        local row = gPlayerSyncTable[index]
        local score = row ~= nil and row.ofScore or nil
        if score ~= nil then
            local before = lastScore[index]

            if wanted and before ~= nil and score > before then
                celebrate.number_over(index, score - before)

                if index == 0 then
                    if OF.util.asks(OF.sounds, "ladder") then
                        OF.sounds.ladder(runOfScores + 1)
                    end
                    runOfScores = runOfScores + 1
                end
            end
            lastScore[index] = score
        end

        local role = row ~= nil and row.ofRole or nil
        if role ~= nil and role ~= "" then
            local was = lastRole[index]

            if was ~= nil and was ~= "" and was ~= role then
                celebrate.puff_over(index)
            end
            lastRole[index] = role
        end
    end
end

local function update_and_render()

    paint_weather()

end

hook_event(HOOK_ON_HUD_RENDER, update_and_render)

hook_event(HOOK_UPDATE, function()
    celebrate.watch_scores()

    step_beats()

    watch_ending()
    step_hush()
    step_duck()

    step_weather()

    step_stop()
end)

hook_event(HOOK_ON_LEVEL_INIT, function()
    celebrate.forget_scores()

    celebrate.unhush()

    celebrate.unduck()
    celebrate.world_go()
end)
