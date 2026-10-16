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

celebrate.WEATHER = {
    rain  = { drops = 70,  fall = 15,  lean = -1.6, long = 11, storm = false },
    storm = { drops = 130, fall = 19,  lean = -2.6, long = 14, storm = true  },
}

celebrate.RAIN_MAX = 140

celebrate.RAIN_COLOUR = { r = 178, g = 202, b = 232 }
celebrate.RAIN_ALPHA = 120

function celebrate.drop_paint(kind)
    local c = celebrate.RAIN_COLOUR
    return kind.r or c.r, kind.g or c.g, kind.b or c.b, kind.a or celebrate.RAIN_ALPHA, kind.wide or 1
end

celebrate.STRIKES = {
    { wait = 210, delay = 62, peak = 150 },
    { wait = 130, delay = 38, peak = 190 },
    { wait = 260, delay = 88, peak = 110 },
    { wait = 95,  delay = 14, peak = 235 },
    { wait = 175, delay = 50, peak = 165 },
    { wait = 320, delay = 74, peak = 125 },
    { wait = 110, delay = 22, peak = 215 },
}

celebrate.FLASH = { 1.0, 0.45, 0.95, 0.60, 0.35, 0.18, 0.07 }

function celebrate.storm_new(kind)
    local st = { kind = kind, drops = {}, at = 0, wait = 0, strikes = 0, flash = 0, peak = 0,
                 bang = nil, far = false }
    if kind ~= nil and celebrate.WEATHER[kind].storm then

        st.wait = celebrate.STRIKES[1].wait
    end
    return st
end

function celebrate.storm_flash(st)
    local flash = celebrate.FLASH
    if st == nil or st.flash <= 0 or st.flash > #flash then return 0 end
    return math.floor(st.peak * flash[st.flash])
end

function celebrate.storm_tick(st, showing, spectacle)
    local landed = nil
    if st.bang ~= nil then
        st.bang = st.bang - 1
        if st.bang <= 0 then
            st.bang = nil
            landed = st.far and SOUND_GENERAL_VOLCANO_EXPLOSION or SOUND_GENERAL_BOWSER_BOMB_EXPLOSION
        end
    end
    if st.flash > 0 then st.flash = st.flash + 1 end
    if st.flash > #celebrate.FLASH then st.flash = 0 end
    if st.kind == nil or not celebrate.WEATHER[st.kind].storm then return landed end
    if not showing then return landed end
    st.wait = st.wait - 1
    if st.wait > 0 then return landed end
    local strikes = celebrate.STRIKES
    st.at = (st.at % #strikes) + 1
    local strike = strikes[st.at]
    st.wait = strikes[(st.at % #strikes) + 1].wait
    st.strikes = st.strikes + 1
    if spectacle then
        st.flash = 1
        st.peak = strike.peak
    end
    st.bang = strike.delay
    st.far = strike.delay >= 40
    return landed
end

function celebrate.rain_frame(st, width, height, across, down, rect, hidden)
    local kind = celebrate.WEATHER[st.kind]
    local dr, dg, db, da, dwide = celebrate.drop_paint(kind)
    local lean = kind.lean
    local drops = st.drops
    local wanted = math.min(kind.drops, celebrate.RAIN_MAX)
    while #drops < wanted do
        table.insert(drops, {
            x = width * 0.5 + across(math.floor(width * 0.62)),
            y = down(math.floor(height)),
        })
    end
    while #drops > wanted do table.remove(drops) end
    for index = 1, #drops do
        local one = drops[index]
        one.y = one.y + kind.fall
        one.x = one.x + lean

        if one.y > height or one.x < -kind.long or one.x > width + kind.long then
            one.y = -kind.long - math.abs(down(math.floor(height * 0.5)))
            one.x = width * 0.5 + across(math.floor(width * 0.62))
        elseif not hidden then
            rect(one.x, one.y, dwide, kind.long, dr, dg, db, da)
        end
    end
    local alpha = celebrate.storm_flash(st)
    if alpha > 0 and not hidden then

        rect(0, 0, width, height, 255, 255, 255, alpha)
    end
end

local storm = celebrate.storm_new(nil)

function celebrate.weather_kinds()
    local out = {}
    for name in pairs(celebrate.WEATHER) do table.insert(out, name) end
    table.sort(out)
    return out
end

function celebrate.weather()
    return storm.kind
end

function celebrate.rain_live()
    return #storm.drops
end

function celebrate.storm_strikes()
    return storm.strikes
end

function celebrate.bang_left()
    return storm.bang
end

function celebrate.flash_alpha()
    return celebrate.storm_flash(storm)
end

local function forget_storm()
    local drops = storm.drops
    storm = celebrate.storm_new(storm.kind)
    storm.wait, storm.drops = 0, drops
end

function celebrate.set_weather(kind)
    if kind ~= nil and celebrate.WEATHER[kind] == nil then return false end
    if kind == storm.kind then return true end
    storm = celebrate.storm_new(kind)
    return true
end

local function step_weather()
    local bang = celebrate.storm_tick(storm, showing(), spectacle())
    if bang == nil then return end

    celebrate.shake(SHAKE_ENV_EXPLOSION)

    if OF.util.asks(OF.sounds, "play") then OF.sounds.play(bang) end
end

local function paint_weather()
    if storm.kind == nil then return end
    if not spectacle() then return end

    local who = gMarioStates[0]
    if who == nil or who.marioObj == nil then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    local hidden = OF.util.menu_has_screen() or (OF.diagOpen == true)
    celebrate.rain_frame(storm, djui_hud_get_screen_width(), djui_hud_get_screen_height(),
        spread_across, spread_down, OF.util.rect, hidden)
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

function celebrate.comeback(gap)
    if not showing() then return false end

    OF.sounds.play(SOUND_GENERAL_STAR_APPEARS)

    local sub = OF.lang.fill("From @ behind", tostring(math.floor(gap or 0)))
    if OF.util.asks(OF.hud, "banner") then
        OF.hud.banner("objective", OF.lang.t("COMEBACK"), sub,
            { side = "us", tone = "good", quiet = true })
    elseif OF.util.asks(OF.notify, "show") then
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

function celebrate.hush_held()
    return hushHeld
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
    if celebrate.release_winner_shot ~= nil then celebrate.release_winner_shot() end
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
    if celebrate.comeback_won() then
        celebrate.comeback(celebrate.behind_by())
    else
        show_placing()
    end
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

        if state == OF.gamemodes.MOMENT and was ~= nil
            and (not OF.util.asks(OF.gamemodes, "hears_round")
                or OF.gamemodes.hears_round()) then

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

local SHOT_DIST = 420
local SHOT_PITCH = 0x0600
local SHOT_LIFT = 110
local SHOT_TURN = 0x60
local SHOT_EASE = 0.25

local shot = { seat = nil, yaw = 0, held = false, waited = 0,
               px = 0, py = 0, pz = 0, fx = 0, fy = 0, fz = 0 }
local shotLens = { pos = {}, focus = {}, curPos = {}, curFocus = {},
                   goalPos = {}, goalFocus = {} }
local shotLensYaw = nil
celebrate.SHOT_DIST = SHOT_DIST

function celebrate.winner_shot()
    if not shot.held then return nil end
    return shot.seat
end

local function shot_lens_keep(s)
    for key, into in pairs(shotLens) do
        local from = s[key]
        if from ~= nil then into.x, into.y, into.z = from.x, from.y, from.z
        else into.x = nil end
    end
    shotLensYaw = s.yaw
end

local function shot_release()
    if not shot.held then
        shot.seat = nil
        return false
    end
    shot.held = false
    shot.seat = nil
    local s = gLakituState
    if s == nil then return true end
    for key, from in pairs(shotLens) do
        local into = s[key]
        if into ~= nil and from.x ~= nil then
            into.x, into.y, into.z = from.x, from.y, from.z
        end
    end
    if shotLensYaw ~= nil then s.yaw = shotLensYaw end
    OF.util.optional("skip_camera_interpolation", nil)
    return true
end
celebrate.release_winner_shot = shot_release

local function camera_elsewhere()
    if OF.util.asks(OF.replay, "playing") and OF.replay.playing() ~= nil then
        return true
    end
    if OF.util.asks(OF.replay, "holds_camera") and OF.replay.holds_camera() then
        return true
    end
    if OF.util.asks(OF.spectate, "driving") and OF.spectate.driving() then
        return true
    end
    if OF.util.asks(OF.camera, "driving") and OF.camera.driving() then
        return true
    end
    return false
end

local function shot_seat()
    local seat = nil
    local modes = OF.gamemodes
    local mode = modes ~= nil and OF.util.asks(modes, "current") and modes.current() or nil
    if mode ~= nil and type(mode.replayDecider) == "function" then
        local ok, picked = pcall(mode.replayDecider)
        if ok and type(picked) == "number" then seat = picked end
    end
    if seat == nil and modes ~= nil and OF.util.asks(modes, "winners") then
        seat = modes.winners()[1]
    end
    if seat == nil and OF.util.asks(OF.replay, "last_scorer") then
        seat = OF.replay.last_scorer()
    end
    if type(seat) ~= "number" then return nil end
    local np, me = gNetworkPlayers[seat], gNetworkPlayers[0]
    local m = gMarioStates[seat]
    if np == nil or me == nil or m == nil or m.pos == nil then return nil end
    if not np.connected then return nil end
    if np.currLevelNum ~= me.currLevelNum or np.currAreaIndex ~= me.currAreaIndex then
        return nil
    end
    if OF.util.asks(OF.spectate, "is_spectating") and OF.spectate.is_spectating(seat) then
        return nil
    end
    return seat
end

local function shot_frame()
    local modes = OF.gamemodes
    if modes == nil or not OF.util.asks(modes, "state") then return end
    if modes.state() ~= modes.MOMENT or not showing() then
        shot.waited = 0
        shot_release()
        return
    end
    shot.waited = shot.waited + 1

    if shot.waited < 2 then return end
    if camera_elsewhere() then

        shot.held = false
        shot.seat = nil
        return
    end
    if not shot.held and shot.waited > 2 then return end
    local s = gLakituState
    if s == nil then return end
    local seat = shot.seat or shot_seat()
    if seat == nil then return end
    local m = gMarioStates[seat]
    if m == nil or m.pos == nil then shot_release() return end

    local cut = false
    if not shot.held then
        shot_lens_keep(s)
        shot.held = true
        shot.seat = seat

        shot.yaw = ((m.faceAngle ~= nil and m.faceAngle.y or 0) + 0x8000) % 0x10000
        cut = true
    else
        shot.yaw = (shot.yaw + SHOT_TURN) % 0x10000
    end
    local fx, fy, fz = m.pos.x, m.pos.y + SHOT_LIFT, m.pos.z
    local p = SHOT_PITCH * math.pi / 32768
    local w = shot.yaw * math.pi / 32768
    local px = fx + SHOT_DIST * math.cos(p) * math.sin(w)
    local py = fy + SHOT_DIST * math.sin(p)
    local pz = fz + SHOT_DIST * math.cos(p) * math.cos(w)
    if OF.util.asks(OF.replay, "clear_view") then
        px, py, pz = OF.replay.clear_view(fx, fy, fz, px, py, pz)
    end
    if cut then
        shot.px, shot.py, shot.pz, shot.fx, shot.fy, shot.fz = px, py, pz, fx, fy, fz
    else
        shot.px = shot.px + (px - shot.px) * SHOT_EASE
        shot.py = shot.py + (py - shot.py) * SHOT_EASE
        shot.pz = shot.pz + (pz - shot.pz) * SHOT_EASE
        shot.fx = shot.fx + (fx - shot.fx) * SHOT_EASE
        shot.fy = shot.fy + (fy - shot.fy) * SHOT_EASE
        shot.fz = shot.fz + (fz - shot.fz) * SHOT_EASE
    end
    for _, key in ipairs({ "pos", "curPos", "goalPos" }) do
        local v = s[key]
        if v ~= nil then v.x, v.y, v.z = shot.px, shot.py, shot.pz end
    end
    for _, key in ipairs({ "focus", "curFocus", "goalFocus" }) do
        local v = s[key]
        if v ~= nil then v.x, v.y, v.z = shot.fx, shot.fy, shot.fz end
    end
    s.posHSpeed, s.posVSpeed = 0, 0
    s.focHSpeed, s.focVSpeed = 0, 0

    s.yaw = math.floor(math.atan(shot.px - shot.fx, shot.pz - shot.fz)
        * 32768 / math.pi) % 0x10000
    if cut then OF.util.optional("skip_camera_interpolation", nil) end
end
celebrate.shot_frame = shot_frame

function celebrate.clear()
    celebrate.particles = {}

    storm.drops = {}
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

    local levels = celebrate.levels()
    local at = 1
    for index, level in ipairs(levels) do
        if level.key == shown then at = index end
    end
    local now = levels[at]
    local nextKey = levels[at % #levels + 1].key
    local built = panel.row(OF.lang.t("How a win looks"), 255, 255, 255,
        function() OF.util.report(celebrate.set_presentation(nextKey)) end)
    if panel.with_right ~= nil then built = panel.with_right(built, now.key) end
    table.insert(rows, panel.with_help(built, now.blurb .. " - " .. now.help))
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

    shot_frame()
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
