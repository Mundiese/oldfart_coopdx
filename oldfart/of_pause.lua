OF = OF or {}
OF.pause = OF.pause or {}

local pause = OF.pause

pause.MOD_NAME = "Oldfart's Mod Menu"
pause.ALPHA_STEP = 25
pause.ALPHA_TOP = 250
pause.COURSES = 15
pause.STICK = 60
pause.COIN_STAR_BIT = 7

pause.SECRET_STARS = {
    { course = 19, name = "The Princess's Secret Slide", stars = 2 },
    { course = 16, name = "Bowser in the Dark World", stars = 1 },
    { course = 20, name = "Cavern of the Metal Cap", stars = 1 },
    { course = 21, name = "Tower of the Wing Cap", stars = 1 },
    { course = 22, name = "Vanish Cap under the Moat", stars = 1 },
    { course = 17, name = "Bowser in the Fire Sea", stars = 1 },
    { course = 24, name = "The Secret Aquarium", stars = 1 },
    { course = 23, name = "Wing Mario over the Rainbow", stars = 1 },
    { course = 18, name = "Bowser in the Sky", stars = 1 },
    { course = 0, name = "Toad and MIPS", stars = 5 },
}

local function venues() return OF.venues end

local function in_round()
    return OF.util.asks(OF.roundscope, "inside") and OF.roundscope.inside(0) == true
end

function pause.venue_here()
    local v = venues()
    if v == nil or type(v.built) ~= "string" then return nil end
    return v.built
end

function pause.worlds()
    local v = venues()
    local out = {}
    if v == nil or type(v.LAYOUTS) ~= "table" or not OF.util.asks(v, "select_number") then
        return out
    end
    for key, layout in pairs(v.LAYOUTS) do
        if type(layout.stars) == "table" and #layout.stars > 0 then
            local n = v.select_number(key)
            if n > 0 then out[#out + 1] = { key = key, number = n } end
        end
    end
    table.sort(out, function(a, b)
        if a.number ~= b.number then return a.number < b.number end
        return a.key < b.key
    end)
    return out
end

local function course_here()
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    return np ~= nil and (np.currCourseNum or 0) or 0
end

function pause.screen_for(course, venueKey, round)
    if round then return "mode" end
    if venueKey ~= nil then return "course" end
    if type(course) == "number" and course >= 1 and course <= 24 then return "course" end
    return "hub"
end

local function save_file()
    return (OF.util.optional("get_current_save_file_num", 1) or 1) - 1
end

local function flags_of(course)
    return OF.util.optional("save_file_get_star_flags", 0, save_file(), course - 1) or 0
end

local function bit(flags, n)
    return math.floor((tonumber(flags) or 0) / (2 ^ (n - 1))) % 2 == 1
end

function pause.course_entry(course)
    local flags = flags_of(course)
    local stars = {}
    for i = 1, 6 do stars[i] = bit(flags, i) end
    return {
        kind = "course", number = course, name = OF.util.course_name(course),
        stars = stars, coinStar = bit(flags, pause.COIN_STAR_BIT),
        coins = OF.util.optional("save_file_get_course_coin_score", 0, save_file(), course - 1) or 0,
    }
end

function pause.secret_entry(secret)
    local flags = flags_of(secret.course)
    local stars = {}
    for i = 1, secret.stars do stars[i] = bit(flags, i) end
    return { kind = "secret", name = secret.name, stars = stars }
end

function pause.world_entry(world)
    local v = venues()
    local layout = v.LAYOUTS[world.key]
    local stars = {}
    for i = 1, #layout.stars do stars[i] = v.bonus_taken(world.key, i) == true end
    local coinStar = nil
    if OF.util.asks(v, "coin_star") and v.coin_star(world.key) then
        coinStar = v.bonus_taken(world.key, v.COIN_STAR_ID) == true
    end
    local place = OF.util.asks(v, "place_of") and v.place_of(world.key) or nil
    return {
        kind = "world", key = world.key, number = world.number,
        name = place ~= nil and place.name or world.key,
        stars = stars, coinStar = coinStar,
        coins = OF.util.asks(v, "coin_best") and v.coin_best(world.key) or 0,
    }
end

local function taken_in(entry)
    local n = 0
    for _, on in ipairs(entry.stars) do if on then n = n + 1 end end
    if entry.coinStar == true then n = n + 1 end
    return n, #entry.stars + (entry.coinStar ~= nil and 1 or 0)
end
pause.taken_in = taken_in

function pause.overview()
    local rows = {}
    local function part(title, entries)
        local got, most = 0, 0
        for _, e in ipairs(entries) do
            local g, m = taken_in(e)
            got, most = got + g, most + m
        end
        rows[#rows + 1] = { kind = "head", name = title, got = got, most = most }
        for _, e in ipairs(entries) do rows[#rows + 1] = e end
    end
    local courses = {}
    for course = 1, pause.COURSES do courses[#courses + 1] = pause.course_entry(course) end
    part("Courses", courses)
    local secrets = {}
    for _, secret in ipairs(pause.SECRET_STARS) do secrets[#secrets + 1] = pause.secret_entry(secret) end
    part("Castle secret stars", secrets)
    local worlds = {}
    for _, world in ipairs(pause.worlds()) do worlds[#worlds + 1] = pause.world_entry(world) end
    part("Studio courses", worlds)
    if #worlds == 0 then
        rows[#rows + 1] = { kind = "note", name = "No Studio courses with stars yet" }
    end
    return rows
end

function pause.tracker()
    local v = venues()
    local key = pause.venue_here()
    if key ~= nil and v ~= nil and type(v.LAYOUTS) == "table" and v.LAYOUTS[key] ~= nil then
        local layout = v.LAYOUTS[key]
        local place = OF.util.asks(v, "place_of") and v.place_of(key) or nil
        local entry = { kind = "world", key = key, number = OF.util.asks(v, "select_number")
            and v.select_number(key) or 0, stars = {}, coins = 0,
            name = place ~= nil and place.name or key }
        if type(layout.stars) == "table" and #layout.stars > 0 then
            entry = pause.world_entry({ key = key, number = entry.number })
        end
        entry.act = pause.picked[key]
        entry.names = {}
        for i = 1, #entry.stars do
            entry.names[i] = OF.util.asks(v, "star_name") and v.star_name(key, i) or ("Star " .. i)
        end
        entry.coinsNow = gMarioStates ~= nil and gMarioStates[0] ~= nil and gMarioStates[0].numCoins or 0
        return entry
    end
    local course = course_here()
    if course < 1 then return nil end
    local entry
    if course <= pause.COURSES then
        entry = pause.course_entry(course)
        entry.names = {}
        for i = 1, 6 do
            entry.names[i] = OF.util.optional("get_star_name", nil, course, i) or ("Star " .. i)
        end
        local np = gNetworkPlayers[0]
        entry.act = np ~= nil and np.currActNum or nil
    else
        for _, secret in ipairs(pause.SECRET_STARS) do
            if secret.course == course then entry = pause.secret_entry(secret) end
        end
        if entry == nil then return nil end
        entry.number = course
        entry.names = {}
    end
    entry.coinsNow = gMarioStates ~= nil and gMarioStates[0] ~= nil and gMarioStates[0].numCoins or 0
    return entry
end

local function exit_offered(m)
    if gLevelValues ~= nil and OF.util.flag(gLevelValues.pauseExitAnywhere) == 1 then
        return true
    end
    local flag = ACT_FLAG_PAUSE_EXIT or (1 << 27)
    return m ~= nil and OF.util.has_flag(m.action or 0, flag)
end
pause.exit_offered = exit_offered

function pause.exit_refused()
    if OF.util.asks(OF.gamemodes, "may_leave_level") and not OF.gamemodes.may_leave_level() then
        return true
    end
    if type(OF.gm_hideseek_exit_locked) == "function" and OF.gm_hideseek_exit_locked() then
        return true
    end
    return false
end

pause.REASON = {
    round = "Locked during the round",
    waiting = "Locked while you wait",
    seeker = "A seeker is in your level",
    run = "Locked during the run",
    start = "Wait for the start",
    still = "Stand still first",
}

function pause.exit_rule(ctx)
    local R = pause.REASON
    local course = { act = "exit", label = "Exit course" }
    local castle = { act = "castle", label = "Exit to castle" }
    local phase = ctx.phase or "free"
    if phase == "free" then
        if not ctx.inCourse then course.hidden, castle.hidden = true, true end
    elseif phase == "waiting" then
        if not ctx.whole and ctx.held then
            course.act = "spawn"
            castle.reason = R.waiting
        end
    elseif phase == "live" then
        if ctx.whole then
            if ctx.seeker then course.reason, castle.reason = R.seeker, R.seeker end
        elseif ctx.held then
            course.reason, castle.reason = R.round, R.round
        end
    elseif phase == "run" then
        if not ctx.whole and ctx.runner then
            course.act, course.label = "start", "Back to the start"
            if ctx.countdown then course.reason = R.start end
            castle.reason = R.run
        end
    end

    for _, row in ipairs({ course, castle }) do
        if row.reason == nil and not row.hidden and (row.act == "exit" or row.act == "castle") and not ctx.standing then
            row.reason = R.still
        end
    end
    return course, castle
end

function pause.context(m)
    local ctx = { standing = exit_offered(m) }
    local modes = OF.gamemodes

    if pause.screen ~= nil and pause.screen ~= "mode" then
        ctx.phase = "free"
        ctx.inCourse = pause.venue_here() ~= nil or course_here() >= 1
        return ctx
    end
    local mode = (OF.util.asks(modes, "is_open") and modes.is_open() == true
        and OF.util.asks(modes, "current")) and modes.current() or nil
    if mode ~= nil then
        ctx.phase = modes.is_waiting() and "waiting" or "live"
        ctx.whole = mode.wholeGame == true
        ctx.held = OF.util.asks(modes, "may_leave_level") and modes.may_leave_level() == false
        ctx.seeker = type(OF.gm_hideseek_exit_locked) == "function" and OF.gm_hideseek_exit_locked() == true
        return ctx
    end
    local run = OF.speedrun
    if OF.util.asks(run, "is_running") and run.is_running() == true then
        ctx.phase = "run"
        ctx.whole = run.from_the_beginning() == true
        ctx.countdown = run.state() == run.COUNTDOWN
        ctx.runner = OF.util.can_play(0) and not run.finished
            and (ctx.countdown or run.retries_on_death() == true)
        return ctx
    end
    ctx.phase = "free"
    ctx.inCourse = pause.venue_here() ~= nil or course_here() >= 1
    return ctx
end

function pause.options(m)
    local course, castle = pause.exit_rule(pause.context(m))
    local rows = { { name = "Continue", act = "continue" } }
    for _, row in ipairs({ course, castle }) do
        if not row.hidden then
            rows[#rows + 1] = { name = row.label, act = row.act, reason = row.reason }
        end
    end
    rows[#rows + 1] = { name = "Camera angle", act = "camera", kind = "choice",
        options = { "Lakitu - Mario", "Lakitu - Stop" } }
    return rows
end

pause.screen = nil
pause.alpha = 0
pause.line = 1
pause.camera = 1
pause.age = 0
pause.picked = {}
pause.scrollY = 0
pause.scrollShown = 0
pause.rows_now = nil
pause.rightStick = nil

local function note_pick()
    local v = venues()
    local s = v ~= nil and v.selecting or nil
    if s ~= nil and type(s.key) == "string" and type(s.cursor) == "number" then
        pause.picked[s.key] = s.cursor
    end
end

local function sound(id)
    if id ~= nil then OF.util.optional("play_sound", nil, id, gGlobalSoundSource) end
end

local function set_hidden(on)
    OF.util.optional("set_pause_menu_hidden", nil, on)
end

local function hud_screen(screen)
    return screen == "hub" or screen == "course"
end

function pause.holds_hud()
    return hud_screen(pause.screen)
end

local function settle_hud()
    if OF.util.asks(OF.modifiers, "settle_hud") then OF.modifiers.settle_hud() end
end

local function close()
    local held = hud_screen(pause.screen)
    if pause.screen ~= nil then set_hidden(false) end
    pause.screen, pause.rows_now, pause.rightStick = nil, nil, nil
    if held then settle_hud() end
end

local modeDir, modeDue = 0, 0
function pause.mode_scroll(stick, index, low, high)
    local dir = 0
    if stick > pause.STICK then dir = -1 elseif stick < -pause.STICK then dir = 1 end
    if dir == 0 then
        modeDir, modeDue = 0, 0
        return index
    end
    local input = OF.input or {}
    if dir ~= modeDir then
        modeDir, modeDue = dir, input.REPEAT_DELAY or 17
    else
        modeDue = modeDue - 1
        if modeDue > 0 then return index end
        modeDue = input.REPEAT_INTERVAL or 5
    end
    local moved = math.max(low, math.min(high, index + dir))
    if moved ~= index then sound(SOUND_MENU_CHANGE_SELECT) end
    return moved
end

local function unpause()
    sound(SOUND_MENU_PAUSE_2)
    close()
    OF.util.optional("game_unpause", nil)
end

function pause.round_gone()
    close()
    if OF.util.optional("is_game_paused", false) == true then
        OF.util.optional("game_unpause", nil)
    end
end

function pause.to_spawn()
    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    local v = venues()
    local key = pause.venue_here()
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if key ~= nil and OF.util.asks(v, "arrival_spot") and OF.util.asks(OF.doorways, "put_at") then
        local spot = v.arrival_spot(key, np ~= nil and np.globalIndex or 0)
        if spot ~= nil and m ~= nil and OF.doorways.put_at(m, spot.x, spot.y, spot.z) == true then
            if m.faceAngle ~= nil and type(spot.yaw) == "number" then m.faceAngle.y = spot.yaw end
            if OF.util.asks(OF.util, "camera_behind_soon") then OF.util.camera_behind_soon() end
            return "spot"
        end
    end
    local place = OF.util.asks(OF.gamemodes, "round_place") and OF.gamemodes.round_place() or nil
    if place == nil and np ~= nil then
        place = { level = np.currLevelNum, area = np.currAreaIndex, act = np.currActNum }
    end
    if place ~= nil and OF.util.asks(OF.net, "warp_local") then
        OF.net.warp_local(place.level, place.area or 1, place.act or 1, nil,
            "Could not take you back to the start.")
        return "warp"
    end
    return nil
end

local function exit_course(m)
    local back = pause.entry
    local free = pause.context(m).phase == "free"
    if free and pause.venue_here() ~= nil and back ~= nil and OF.util.asks(OF.net, "teleport_to_position") then
        if WARP_TRANSITION_FADE_INTO_CIRCLE ~= nil then
            OF.util.optional("play_transition", nil, WARP_TRANSITION_FADE_INTO_CIRCLE, 0x14, 0, 0, 0)
        end
        OF.net.teleport_to_position({ level = back.level, area = back.area, act = back.act,
            x = back.x, y = back.y, z = back.z, angle = back.angle })
    elseif WARP_OP_EXIT ~= nil then
        OF.util.optional("level_trigger_warp", nil, m, WARP_OP_EXIT)
    end
end

local function exit_castle()
    local lv = gLevelValues
    if lv ~= nil and WARP_ARG_EXIT_COURSE ~= nil then
        OF.util.optional("initiate_warp", nil, lv.exitCastleLevel, lv.exitCastleArea,
            lv.exitCastleWarpNode, WARP_ARG_EXIT_COURSE)
        OF.util.optional("fade_into_special_warp", nil, 0, 0)
    end
end

function pause.choose(m)
    local row = pause.options(m)[pause.line]
    if row == nil then return end
    if row.reason ~= nil then
        sound(SOUND_MENU_CAMERA_BUZZ)
        return "refused"
    end
    local act = row.act
    if act == "camera" then
        pause.camera = pause.camera == 1 and 2 or 1
        OF.util.optional("cam_select_alt_mode", nil, pause.camera)
        sound(SOUND_MENU_CHANGE_SELECT)
        return act
    end
    if (act == "exit" or act == "castle") and pause.exit_refused() then
        sound(SOUND_MENU_CAMERA_BUZZ)
        return "refused"
    end
    unpause()
    if act == "exit" then
        exit_course(m)
    elseif act == "castle" then
        exit_castle()
    elseif act == "spawn" then
        pause.to_spawn()
    elseif act == "start" and OF.util.asks(OF.speedrun, "back_to_start") then
        OF.speedrun.back_to_start()
    end
    return act
end

pause.entry = nil
function pause.note_entry()
    if pause.venue_here() ~= nil or in_round() then return end
    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if m == nil or np == nil or m.pos == nil or m.floor == nil then return end
    if np.currAreaSyncValid == false then return end
    if m.pos.y > (m.floorHeight or -1e9) + 1 then return end

    local at = pause.entry
    if at == nil then at = {}; pause.entry = at end
    at.level, at.area, at.act = np.currLevelNum, np.currAreaIndex, np.currActNum
    at.x, at.y, at.z = m.pos.x, m.pos.y, m.pos.z
    at.angle = m.faceAngle ~= nil and m.faceAngle.y or 0
end

pause.BOX = { row = 34, head = 44, note = 34, pad = 12, stick = 24, speed = 16, wheelRows = 3 }

function pause.overview_layout(rows)
    local B, y, out = pause.BOX, 0, {}
    for i, row in ipairs(rows) do
        local h = row.kind == "head" and B.head or (row.kind == "note" and B.note or B.row)
        out[i] = { top = y, h = h }
        y = y + h
    end
    return out, y
end

local function scroll_most()
    local lay = pause.layout
    if lay == nil or lay.box == nil then return 0 end
    return math.max(0, (lay.box.content or 0) - (lay.box.view or 0))
end

function pause.scroll_box(ry, wheel)
    local B = pause.BOX
    local y = pause.scrollY
    ry = tonumber(ry) or 0
    if math.abs(ry) > B.stick then
        local push = (math.abs(ry) - B.stick) / (128 - B.stick)
        y = y - (ry > 0 and 1 or -1) * math.max(2, B.speed * math.min(1, push) * 1.4)
    end
    wheel = tonumber(wheel) or 0
    if wheel ~= 0 then y = y - wheel * B.row * B.wheelRows end
    pause.scrollY = math.max(0, math.min(scroll_most(), y))
    return pause.scrollY
end

function pause.hold_camera(m)
    if m == nil or m.playerIndex ~= 0 or m.controller == nil then return end
    if pause.screen ~= "hub" then return end
    pause.rightStick = m.controller.extStickY or 0
    if OF.util.asks(OF.input, "claim_camera") then
        OF.input.claim_camera(m)
    else
        m.controller.extStickX, m.controller.extStickY = 0, 0
    end
end

local function pressed(c, button)
    return button ~= nil and OF.util.has_flag(c.buttonPressed or 0, button)
end

function pause.course_done(m)
    return m ~= nil and ACT_EXIT_LAND_SAVE_DIALOG ~= nil and m.action == ACT_EXIT_LAND_SAVE_DIALOG
end

function pause.update()
    note_pick()
    local paused = OF.util.optional("is_game_paused", false) == true
    if paused and pause.course_done(gMarioStates ~= nil and gMarioStates[0] or nil) then
        close()
        return
    end
    if not paused then
        close()
        pause.note_entry()
        return
    end
    local m = gMarioStates ~= nil and gMarioStates[0] or nil

    if pause.screen == "mode" and not pause.mode_here() then
        pause.round_gone()
        return
    end
    if pause.screen ~= nil then set_hidden(true) end
    if pause.screen == nil then
        local inRun = OF.util.asks(OF.speedrun, "is_running") and OF.speedrun.is_running() == true
            and OF.util.asks(OF.speedrun, "in_this_run") and OF.speedrun.in_this_run() == true
        local round = (in_round() or inRun) and pause.mode_here()
        pause.screen = pause.screen_for(course_here(), pause.venue_here(), round)
        set_hidden(true)
        if hud_screen(pause.screen) then settle_hud() end
        pause.alpha, pause.age, pause.line = 0, 0, 1
        pause.scrollY, pause.scrollShown, pause.rightStick = 0, 0, nil
        modeDir, modeDue = 0, 0
        if pause.screen == "hub" then pause.rows_now = pause.overview() end
        local mode = OF.util.optional("cam_select_alt_mode", 1, 0)
        pause.camera = (mode == (CAM_SELECTION_MARIO or 1)) and 1 or 2
        return
    end
    pause.age = pause.age + 1
    if pause.alpha < pause.ALPHA_TOP then pause.alpha = pause.alpha + pause.ALPHA_STEP end
    if OF.util.optional("djui_hud_is_pause_menu_created", false) == true then return end
    local c = m ~= nil and m.controller or nil
    if c == nil then return end

    local options = pause.options(m)
    local last = #options
    pause.line = math.max(1, math.min(last, pause.line))
    local was = pause.line
    pause.line = pause.mode_scroll(c.rawStickY or 0, pause.line, 1, last)
    if pressed(c, U_JPAD) then pause.line = math.max(1, pause.line - 1) end
    if pressed(c, D_JPAD) then pause.line = math.min(last, pause.line + 1) end
    if pause.line ~= was and (pressed(c, U_JPAD) or pressed(c, D_JPAD)) then
        sound(SOUND_MENU_CHANGE_SELECT)
    end
    if options[pause.line].act == "camera" then

        local side = 0
        if (c.rawStickX or 0) > pause.STICK and pause.sideHeld ~= 1 then side = 1 end
        if (c.rawStickX or 0) < -pause.STICK and pause.sideHeld ~= -1 then side = -1 end
        pause.sideHeld = (c.rawStickX or 0) > pause.STICK and 1
            or ((c.rawStickX or 0) < -pause.STICK and -1 or 0)
        if pressed(c, R_JPAD) then side = 1 end
        if pressed(c, L_JPAD) then side = -1 end
        local want = side > 0 and 2 or (side < 0 and 1 or pause.camera)
        if want ~= pause.camera then
            pause.camera = want
            OF.util.optional("cam_select_alt_mode", nil, pause.camera)
            sound(SOUND_MENU_CHANGE_SELECT)
        end
    end

    if pause.screen == "hub" then
        local ry = pause.rightStick
        if ry == nil then ry = c.extStickY or 0 end
        pause.rightStick = nil
        local wheel = tonumber(OF.util.optional("djui_hud_get_mouse_scroll_y", 0)) or 0
        pause.scroll_box(ry, wheel)
    end
    pause.mouse(m)
    if pause.screen == nil then return end

    if pressed(c, B_BUTTON) then
        unpause()
        return
    end
    if pressed(c, START_BUTTON) then
        local row = pause.options(m)[pause.line]
        if row == nil or row.reason ~= nil
            or ((row.act == "exit" or row.act == "castle") and pause.exit_refused()) then
            unpause()
            return
        end
        pause.choose(m)
        return
    end
    if pressed(c, A_BUTTON) then
        pause.choose(m)
    end
end

function pause.mode_card()
    local modes = OF.gamemodes
    if OF.util.asks(modes, "current") and OF.util.asks(modes, "is_open") and modes.is_open() == true then
        local mode = modes.current()
        if mode ~= nil then return modes.intro_card(mode, nil), mode end
    end
    local run = OF.speedrun
    if OF.util.asks(run, "is_running") and run.is_running() == true then
        local title = gGlobalSyncTable ~= nil and gGlobalSyncTable.ofRunTitle or nil
        return { name = OF.lang.t("Speedrun"), rules = {},
            objective = type(title) == "string" and OF.lang.t(title) or "" }, nil
    end
    return nil, nil
end

function pause.mode_here()
    return pause.mode_card() ~= nil
end

pause.MODE = { width = 640, wide = 760, gap = 12, row = 32, chip = 22 }

pause.BAND = 64

pause.PAD_KEY = { A = "L", B = ",", Z = "K", L = "LShift", R = "RShift", Y = "M", X = "I",
    C = "Arrows", STICK = "WASD", START = "Space" }

function pause.control_of(line)
    local plain = OF.util.plain(tostring(line))
    local head, rest = string.match(plain, "^(.-) %- (.+)$")
    if head == nil then return { nil, plain } end
    head = string.gsub(head, "^Hold ", "")
    head = string.gsub(head, "^Press ", "")
    local pads, used = {}, 0
    local pos = 1
    while true do
        local token, stop = string.match(head, "^(%u+)()", pos)
        if token == nil or pause.PAD_KEY[token] == nil then
            local word = string.match(head, "^(Stick)()", pos)
            if word ~= nil then token, stop = "STICK", pos + 5 else break end
        end
        pads[#pads + 1] = token
        pos = stop
        local joint = string.match(head, "^ %+ ()", pos)
        if joint == nil then break end
        pos = joint
    end
    if #pads == 0 then return { nil, plain } end
    local tail = string.gsub(string.sub(head, pos), "^%s+", "")
    local keys = {}
    for index, pad in ipairs(pads) do keys[index] = pause.PAD_KEY[pad] end
    local label = tail ~= "" and (tail .. " - " .. rest) or rest
    return { { pad = table.concat(pads, "+"), key = table.concat(keys, "+") }, label }
end

function pause.mode_controls(mode)
    local function parsed(lines)
        local list = {}
        for _, line in ipairs(lines) do list[#list + 1] = pause.control_of(line) end
        return list
    end
    if mode ~= nil and type(mode.pauseControls) == "function" then
        local ok, list = pcall(mode.pauseControls)
        if ok and type(list) == "table" and #list > 0 then return list, "own" end
    end
    if mode ~= nil and type(mode.controls_lines) == "function" then
        local ok, lines = pcall(mode.controls_lines)
        if ok and type(lines) == "table" and #lines > 0 then return parsed(lines), "lines" end
    end

    if mode ~= nil and type(mode.controls) == "table" and #mode.controls > 0 then
        local lines = {}
        for index, line in ipairs(mode.controls) do lines[index] = OF.lang.t(line) end
        return parsed(lines), "declared"
    end
    local said = OF.util.legendLines
    if mode ~= nil and said ~= nil and said.key == mode.key and #said.lines > 0 then
        return parsed(said.lines), "legend"
    end
    return {
        { "move", "Move" }, { "jump", "Jump" }, { "attack", "Punch" },
        { "crouch", "Crouch" }, { "camera", "Camera" }, { "list", "Players" },
    }, "generic"
end

pause.layout = nil

local gridCache = setmetatable({}, { __mode = "k" })
function pause.controls_grid(list, cw, cols)
    local H, P = OF.hud, pause.MODE
    cols = cols or 2
    local inner = (cw or P.width) - H.S.s4 * 2
    local colw = inner / cols
    local set = H.glyph_set()
    local byList = type(list) == "table" and gridCache[list] or nil
    if byList == nil and type(list) == "table" then
        byList = {}
        gridCache[list] = byList
    end
    local hit = byList ~= nil and byList[cols] or nil
    if hit ~= nil and hit.cw == cw and hit.set == set and hit.count == #list then return hit end
    local grid = { cells = {}, rows = 0, colw = colw, cols = cols, cw = cw, set = set, count = #(list or {}) }
    if byList ~= nil then byList[cols] = grid end
    local col, row, tall = 0, 0, 1
    for i, item in ipairs(list or {}) do
        local lead = 16
        if item[1] ~= nil then lead = H.glyph_width(item[1], P.chip, set) + 6 end
        local word = OF.lang.t(item[2])
        local says = item[1] ~= nil and H.chip_says ~= nil and H.chip_says(item[1], word, set)
        local ww = says and 0 or H.measure(word, "caption")
        local need = 4 + lead + ww + H.S.s3
        local span = math.min(cols, math.max(1, math.ceil(need / colw - 0.001)))
        local lines = { says and "" or word }
        if need > inner and not says then
            lines = H.wrap(word, "caption", inner - 4 - lead - H.S.s3)
            if #lines == 0 then lines = { word } end
        end
        if col > 0 and col + span > cols then
            row, col, tall = row + tall, 0, 1
        end
        grid.cells[i] = { col = col, row = row, span = span, lines = lines }
        tall = math.max(tall, #lines)
        col = col + span
        if col >= cols then row, col, tall = row + tall, 0, 1 end
    end
    grid.rows = row + (col > 0 and tall or 0)
    return grid
end

function pause.controls_height(count, cols, list, cw)
    local H, P = OF.hud, pause.MODE
    local rows = math.ceil((count or 0) / (cols or 2))
    if type(list) == "table" then rows = pause.controls_grid(list, cw, cols).rows end
    return H.S.s4 * 2 + 18 + rows * (P.chip + H.S.s2) - H.S.s2
end

pause.controlsDrawn = nil
function pause.draw_controls(x, y, cw, list, k, cols)
    local H, P = OF.hud, pause.MODE
    k = k or 1
    cols = cols or 2
    local grid = pause.controls_grid(list, cw, cols)
    local ch = pause.controls_height(#list, cols, list, cw)
    H.plate(x, y, cw, ch, { alpha = k })
    H.text_mid(OF.lang.t("Controls"), x + H.S.s4 + 4, y + H.S.s4 + 5, "caption", "mute", 255 * k, "left")
    local set = H.glyph_set()
    local colw = grid.colw
    local drawn = {}
    for i, item in ipairs(list) do
        local cell = grid.cells[i]
        local gx = x + H.S.s4 + cell.col * colw + 4
        local gy = y + H.S.s4 + 18 + cell.row * (P.chip + H.S.s2)
        local lx = gx
        if item[1] ~= nil then
            lx = gx + H.glyph(item[1], gx, gy, P.chip, 255 * k, set) + 6
        else
            H.diamond(gx + 4, gy + P.chip / 2, 6, "gold", 255 * k)
            lx = gx + 16
        end
        local right = lx

        for n, line in ipairs(cell.lines) do
            if line ~= "" then
                local ly = gy + P.chip / 2 + (n - 1) * (P.chip + H.S.s2)
                right = math.max(right, lx + H.menu_text_mid(line, lx, ly, "caption", "ink2", 255 * k))
            end
        end
        drawn[i] = { x = gx, y = gy, w = right - gx, right = right, h = #cell.lines * (P.chip + H.S.s2) - H.S.s2,
            cellRight = gx - 4 + cell.span * colw, lines = #cell.lines }
    end
    pause.controlsDrawn = { x = x, y = y, w = cw, h = ch, items = drawn }
    return ch
end

function pause.owns_hud()
    return pause.screen ~= nil
end

pause.GLYPH = { full = "of_pause_star_full", open = "of_pause_star_open", coin = "of_pause_coin" }
local glyphInfo = {}
function pause.glyph(key)
    local info = glyphInfo[key]
    if info == nil then
        info = OF.util.optional("get_texture_info", nil, pause.GLYPH[key]) or false
        glyphInfo[key] = info
    end
    return info or nil
end

function pause.forget_glyphs() glyphInfo = {} end

pause.GLYPH_INK = {
    full = { 0, 10, 3, 13 },
    open = { 0, 10, 3, 13 },
    coin = { 0, 7, 4, 12 },
}

local function icon(key, x, y, size, c, a, solid)
    local H = OF.hud
    local info = pause.glyph(key)
    if info ~= nil and type(djui_hud_render_texture) == "function" then
        local r, g, b = H.colour(c)
        local cw, ch = info.width or 16, info.height or 16
        local kx, ky = size / cw, size / ch
        local ink = pause.GLYPH_INK[key] or { 0, cw, 0, ch }
        local dx = (cw / 2 - (ink[1] + ink[2]) / 2) * kx
        local dy = (ch / 2 - (ink[3] + ink[4]) / 2) * ky
        djui_hud_set_color(r, g, b, math.floor(a))
        djui_hud_render_texture(info, x + dx, y + dy, kx, ky)
        return
    end
    if solid == false then
        H.diamond(x + size / 2, y + size / 2, size * 0.62, c, a)
        H.diamond(x + size / 2, y + size / 2, size * 0.34, "plate", a)
    else
        H.diamond(x + size / 2, y + size / 2, size * 0.62, c, a)
    end
end

function pause.star_icon(x, y, size, taken, a, coin)
    local H = OF.hud
    if coin then

        local pad = math.floor(size * 0.12 + 0.5)
        H.rect(x - pad, y - pad, size + pad * 2, size + pad * 2,
            taken and "best" or "mute", (taken and 60 or 26) * a / 255)
    end
    if taken then
        icon("full", x, y, size, "best", a)
    else
        icon("open", x, y, size, "mute", a * 0.8, false)
    end
end

pause.BRAND_PART = "Old"
pause.BRAND_COLOUR = { 255, 255, 0 }
function pause.draw_brand_title(text, cx, cy, alpha)
    local H = OF.hud
    local part = pause.BRAND_PART
    if string.sub(text, 1, #part) ~= part or #text <= #part then return false end
    local rest = string.sub(text, #part + 1)
    local l, r = H.ink(text, "title")
    local pen = cx - ((l or 0) + (r or 0)) / 2
    local top, base = H.cap("title", nil, text)
    local y = cy - (top + base) / 2
    local lPart = H.ink(part, "title")
    H.text(part, pen + (lPart or 0), y, "title", pause.BRAND_COLOUR, alpha, "left")
    local advance = H.measure(part, "title")
    local lRest = H.ink(rest, "title")
    H.text(rest, pen + advance + (lRest or 0), y, "title", "ink", alpha, "left")
    return true
end

local function draw_top(title, sw, k, lay)
    local H = OF.hud
    local P = pause.MODE

    local _, _, capT = H.cap("title", 1, "A")
    local y = H.MARGIN + 8
    local band = math.max(pause.BAND, y + capT + H.S.s3)
    H.rect(0, 0, sw, band, H.C.plate, 255)
    H.rect(0, band - 1, sw, 1, H.C.edge, 60)
    local set = H.glyph_set()
    local word = OF.lang.t("Options")
    local ww = H.ink_width(word, "caption")
    local hint = { pad = "R", key = pause.PAD_KEY.R }
    local gw = H.glyph_width(hint, P.chip, set)
    local hx = sw - H.MARGIN - ww - 6 - gw
    local hy = math.floor(band / 2 - P.chip / 2)
    H.glyph(hint, hx, hy, P.chip, 255 * k, set)
    H.text_mid(word, hx + gw + 6, hy + P.chip / 2, "caption", "ink2", 255 * k, "left")
    lay.band = { h = band, hint = { x = hx, y = hy, w = gw + 6 + ww, h = P.chip } }
    local said = tostring(title or "")
    if not pause.draw_brand_title(said, sw / 2, y + capT / 2, 255 * k) then
        H.text_mid(said, sw / 2, y + capT / 2, "title", "ink", 255 * k, "center")
    end
    lay.title = { y = y, h = capT, text = said }
    y = y + capT + H.S.s2
    H.rect(sw / 2 - 28, y, 56, 2, "gold", 255 * k)
    return y + 2 + P.gap + H.S.s2
end

local function draw_options(x, y, cw, m, k, lay)
    local H = OF.hud
    local P = pause.MODE
    local options = pause.options(m)
    local oh = #options * P.row + H.S.s2 * 2
    H.plate(x, y, cw, oh, { alpha = k })
    lay.rows = {}
    for i, row in ipairs(options) do
        local item = { name = OF.lang.t(row.name), kind = row.kind }
        if row.kind == "choice" then
            item.index = pause.camera
            item.options = {}
            for n, word in ipairs(row.options) do item.options[n] = OF.lang.t(word) end
        end
        if row.reason ~= nil then
            item.disabled = OF.lang.t(row.reason)
            item.lockWord = item.disabled
        end
        local rx, ry, rw = x + H.S.s2, y + H.S.s2 + (i - 1) * P.row, cw - H.S.s2 * 2
        H.menu_row(rx, ry, rw, item,
            { focus = (i == pause.line) and 1 or 0, now = H.now(), accent = "gold" }, k)
        lay.rows[i] = { x = rx, y = ry, w = rw, h = P.row, name = item.name, reason = item.disabled }
    end
    lay.options = { x = x, y = y, w = cw, h = oh }
    lay.bottom = y + oh
    return oh
end

local function options_height(m)
    return #pause.options(m) * pause.MODE.row + OF.hud.S.s2 * 2
end

function pause.draw_mode(a, m)
    local H = OF.hud
    local card, mode = pause.mode_card()
    if H == nil or card == nil then return end
    local sw, sh = H.screen()
    local P = pause.MODE
    local k = math.min(1, a / 255)
    local cw = math.min(P.width, sw - H.MARGIN * 2)
    local x = math.floor((sw - cw) / 2)
    local lay = { screen = { w = sw, h = sh }, kind = "mode" }
    H.rect(0, 0, sw, sh, H.C.shade, 150 * k)
    local y = draw_top(card.name, sw, k, lay)

    local room = cw - H.S.s4 * 2 - 18
    local _, _, capB = H.cap("body", 1, "A")
    local step = capB + 9
    local blocks = {}
    if card.objective ~= nil and card.objective ~= "" then
        blocks[#blocks + 1] = { lines = H.wrap(H.sentence(OF.input.button_text(card.objective)), "body", room + 18, 3), tone = "gold" }
    end
    for i, line in ipairs(card.rules or {}) do
        if i > 3 then break end
        blocks[#blocks + 1] = { lines = H.wrap(H.sentence(OF.input.button_text(line)), "body", room, 2), tone = "ink2", dot = true }
    end
    local inner = 0
    for _, b in ipairs(blocks) do inner = inner + #b.lines * step + 3 end
    local rh = H.S.s4 * 2 + math.max(inner, step)
    H.plate(x, y, cw, rh, { alpha = k, strip = "gold" })
    local ty = y + H.S.s4
    for _, b in ipairs(blocks) do
        for n, line in ipairs(b.lines) do
            local indent = b.dot and 18 or 0
            if b.dot and n == 1 then H.diamond(x + H.S.s4 + 8, ty + capB / 2, 6, "gold", 255 * k) end
            H.text(line, x + H.S.s4 + 6 + indent, ty, "body", b.tone, 255 * k)
            ty = ty + step
        end
        ty = ty + 3
    end
    lay.rules = { x = x, y = y, w = cw, h = rh }
    y = y + rh + P.gap

    local ch = pause.draw_controls(x, y, cw, pause.mode_controls(mode), k)
    lay.controls = { x = x, y = y, w = cw, h = ch }
    y = y + ch + P.gap

    draw_options(x, y, cw, m, k, lay)
    lay.controlsFrom = select(2, pause.mode_controls(mode))
    pause.layout = lay
end

local function star_line(entry, x, cy, size, gap, a)
    local at = x
    for _, on in ipairs(entry.stars) do
        pause.star_icon(at, cy - size / 2, size, on, a)
        at = at + size + gap
    end
    if entry.coinStar ~= nil then
        at = at + gap
        pause.star_icon(at, cy - size / 2, size, entry.coinStar, a, true)
        at = at + size + gap
    end
    return at
end

local function badge(number, x, cy, size, full, a)
    local H = OF.hud
    H.plate(x, cy - size / 2, size, size, { alpha = a / 255, lit = full })
    if full then H.rect(x + 2, cy + size / 2 - 3, size - 4, 2, "gold", a) end

    H.text_in(tostring(number), x, cy - size / 2, size, size, "caption", full and "gold" or "ink2", a)
end

local function coin_score(coins, right, cy, a)
    local H = OF.hud
    local text = tostring(math.floor(tonumber(coins) or 0))
    local tw = H.digits_width(text, "caption")
    H.menu_digits_mid(text, right, cy, "caption", coins > 0 and "ink" or "mute", a, "right")
    icon("coin", right - tw - 26, cy - 11, 22, "best", coins > 0 and a or a * 0.5)
end

local function draw_line(row, x, top, w, h, a, odd)
    local H = OF.hud
    local cy = top + h / 2
    if row.kind == "head" then
        H.text_mid(OF.lang.t(row.name), x + 4, cy + 4, "heading", "ink", a, "left")
        local count = string.format("%.0f / %.0f", row.got, row.most)
        local cw = H.digits_width(count, "caption")
        H.menu_digits_mid(count, x + w - 4, cy + 4, "caption", row.got >= row.most and row.most > 0
            and "gold" or "ink2", a, "right")
        pause.star_icon(x + w - 4 - cw - 24, cy + 4 - 9, 18, true, a)
        H.rect(x, top + h - 3, w, 1, "gold", 90 * a / 255)
        return
    end
    if row.kind == "note" then
        H.text_mid(OF.lang.t(row.name), x + 12, cy, "caption", "mute", a, "left")
        return
    end
    if odd then H.rect(x, top + 1, w, h - 2, "ink", 10 * a / 255) end
    local got, most = taken_in(row)
    local nx = x + 8
    if row.number ~= nil then
        badge(row.number, x + 6, cy, 24, got == most and most > 0, a)
        nx = x + 40
    end

    local size, gap = 20, 4
    local starsW = #row.stars * (size + gap) + (row.coinStar ~= nil and (size + gap * 2) or 0)
    local coinsW = 76
    local right = x + w - 8
    local sx = math.min(right - coinsW - (6 * (size + gap) + size + gap * 2), right - coinsW - starsW)
    H.menu_text_mid(H.fit(OF.lang.t(row.name), "body", sx - nx - 12), nx, cy, "body",
        got == most and most > 0 and "ink" or "ink2", a)
    star_line(row, sx, cy, size, gap, a)
    if row.kind ~= "secret" then coin_score(row.coins or 0, right, cy, a) end
end

function pause.draw_hub(a, m)
    local H = OF.hud
    if H == nil then return end
    local sw, sh = H.screen()
    local P, B = pause.MODE, pause.BOX
    local k = math.min(1, a / 255)
    local cw = math.min(P.wide, sw - H.MARGIN * 2)
    local x = math.floor((sw - cw) / 2)
    local lay = { screen = { w = sw, h = sh }, kind = "hub" }
    H.rect(0, 0, sw, sh, H.C.shade, 150 * k)
    local y = draw_top(OF.lang.t(pause.MOD_NAME), sw, k, lay)

    local oh = options_height(m)
    local oy = sh - H.MARGIN - oh
    local bh = math.max(80, oy - P.gap - y)
    H.plate(x, y, cw, bh, { alpha = k, strip = "gold" })
    local rows = pause.rows_now or pause.overview()
    local tops, content = pause.overview_layout(rows)
    local view = bh - B.pad * 2
    lay.box = { x = x, y = y, w = cw, h = bh, view = view, content = content }
    local most = math.max(0, content - view)
    pause.scrollY = math.max(0, math.min(most, pause.scrollY))
    pause.scrollShown = math.max(0, math.min(most, pause.scrollShown))
    pause.scrollShown = pause.scrollShown + (pause.scrollY - pause.scrollShown) * 0.45
    if math.abs(pause.scrollY - pause.scrollShown) < 0.5 then pause.scrollShown = pause.scrollY end
    local inX, inW = x + B.pad + 4, cw - B.pad * 2 - 4 - 16
    local inTop, inBottom = y + B.pad, y + B.pad + view

    lay.lines = {}
    local fade = 28
    for i, row in ipairs(rows) do
        local top = inTop + tops[i].top - pause.scrollShown
        local bottom = top + tops[i].h
        if top >= inTop - 0.5 and bottom <= inBottom + 0.5 then

            local edge = math.huge
            if pause.scrollShown > 0.5 then edge = math.min(edge, top - inTop) end
            if pause.scrollShown < most - 0.5 then edge = math.min(edge, inBottom - bottom) end
            local la = 255 * k * math.max(0.25, math.min(1, (edge + 6) / fade))
            draw_line(row, inX, top, inW, tops[i].h, la, i % 2 == 0)
            lay.lines[#lay.lines + 1] = { index = i, kind = row.kind, name = row.name, y = top, h = tops[i].h }
        end
    end
    local rail = H.menu_scrollbar(x + cw - B.pad - 4, inTop, view, pause.scrollShown / B.row,
        view / B.row, content / B.row, k, "gold")
    lay.scrollbar = rail
    draw_options(x, oy, cw, m, k, lay)
    pause.layout = lay
end

function pause.draw_course(a, m)
    local H = OF.hud
    if H == nil then return end
    local sw, sh = H.screen()
    local P = pause.MODE
    local k = math.min(1, a / 255)
    local ka = 255 * k
    local cw = math.min(P.width, sw - H.MARGIN * 2)
    local x = math.floor((sw - cw) / 2)
    local lay = { screen = { w = sw, h = sh }, kind = "course" }
    H.rect(0, 0, sw, sh, H.C.shade, 150 * k)
    local y = draw_top(OF.lang.t(pause.MOD_NAME), sw, k, lay)
    local entry = pause.tracker()
    local ch = 200
    H.plate(x, y, cw, ch, { alpha = k, strip = "gold" })
    if entry ~= nil then
        local px = x + H.S.s4 + 6
        local cy = y + H.S.s4 + 16
        if entry.number ~= nil and entry.number > 0 then
            local got, most = taken_in(entry)
            badge(entry.number, px, cy, 30, got == most and most > 0, ka)
            px = px + 42
        end
        H.text_mid(H.fit(OF.lang.t(entry.name), "heading", x + cw - px - H.S.s4), px, cy, "heading", "ink", ka, "left")

        local ay = cy + 40
        local act = entry.act
        if act ~= nil and entry.names ~= nil and entry.names[act] ~= nil then
            pause.star_icon(x + H.S.s4 + 6, ay - 11, 22, entry.stars[act] == true, ka)
            H.text_mid(H.fit(OF.lang.t(entry.names[act]), "body", cw - 80), x + H.S.s4 + 38, ay, "body",
                "gold", ka, "left")
        else
            H.text_mid(OF.lang.t("Stars in this course"), x + H.S.s4 + 6, ay, "body", "ink2", ka, "left")
        end

        local size, gap = 34, 10
        local n = #entry.stars + (entry.coinStar ~= nil and 1 or 0)
        local rowW = n * (size + gap) - gap + (entry.coinStar ~= nil and gap or 0)
        local sx = math.floor(x + (cw - rowW) / 2)
        local sy = ay + 44
        for i, on in ipairs(entry.stars) do
            local lift = (i == act) and 4 or 0
            if i == act then H.rect(sx - 3, sy + size / 2 + 6, size + 6, 2, "gold", ka) end
            pause.star_icon(sx, sy - size / 2 - lift, size, on, ka)
            H.menu_digits_mid(tostring(i), sx + size / 2, sy + size / 2 + 16, "caption",
                i == act and "gold" or "mute", ka, "center")
            sx = sx + size + gap
        end
        if entry.coinStar ~= nil then
            sx = sx + gap
            pause.star_icon(sx, sy - size / 2, size, entry.coinStar, ka, true)
            H.menu_text_mid("100", sx + size / 2, sy + size / 2 + 16, "caption", "mute", ka, "center")
        end

        local cyc = y + ch - H.S.s4 - 6
        if entry.kind ~= "secret" then
            icon("coin", x + H.S.s4 + 2, cyc - 12, 24, "best", ka)
            H.menu_text_mid(OF.lang.t("Coins"), x + H.S.s4 + 32, cyc, "caption", "ink2", ka)
            H.menu_digits_mid(tostring(entry.coinsNow or 0), x + H.S.s4 + 120, cyc, "body", "ink", ka, "left")
            H.menu_text_mid(OF.lang.t("Best"), x + cw - H.S.s4 - 60, cyc, "caption", "mute", ka, "right")
            H.menu_digits_mid(tostring(entry.coins or 0), x + cw - H.S.s4 - 6, cyc, "body", "gold", ka, "right")
        end
    end
    lay.tracker = { x = x, y = y, w = cw, h = ch, entry = entry }
    y = y + ch + P.gap
    draw_options(x, y, cw, m, k, lay)
    pause.layout = lay
end

function pause.mouse(m)
    local lay = pause.layout
    if lay == nil or lay.rows == nil then return end
    local mx = tonumber(OF.util.optional("djui_hud_get_mouse_x", nil))
    local my = tonumber(OF.util.optional("djui_hud_get_mouse_y", nil))
    if mx == nil or my == nil then return end
    local moved = pause.pointer == nil or pause.pointer[1] ~= mx or pause.pointer[2] ~= my
    pause.pointer = { mx, my }
    local under = nil
    for index, r in ipairs(lay.rows) do
        if mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then under = index end
    end
    if under == nil then return end
    if moved and pause.line ~= under then
        pause.line = under
        sound(SOUND_MENU_CHANGE_SELECT)
    end
    local buttons = math.floor(tonumber(OF.util.optional("djui_hud_get_mouse_buttons_pressed", 0)) or 0)
    if L_MOUSE_BUTTON ~= nil and OF.util.has_flag(buttons, L_MOUSE_BUTTON) then
        pause.line = under
        pause.choose(m)
    end
end
pause.mouse_mode = pause.mouse

function pause.render()
    if pause.screen == nil then return end
    if OF.util.optional("djui_hud_is_pause_menu_created", false) == true then return end

    local held = pause.screen
    pause.screen = nil
    local covered = OF.util.menu_has_screen()
    pause.screen = held
    if covered then return end
    djui_hud_set_resolution(RESOLUTION_DJUI)
    local a = math.min(255, pause.alpha)
    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    if pause.screen == "mode" then
        pause.draw_mode(a, m)
    elseif pause.screen == "hub" then
        pause.draw_hub(a, m)
    else
        pause.draw_course(a, m)
    end
    djui_hud_set_color(255, 255, 255, 255)
end

if type(hook_event) == "function" then
    hook_event(HOOK_UPDATE, pause.update)
    hook_event(HOOK_ON_HUD_RENDER, pause.render)
    hook_event(HOOK_BEFORE_MARIO_UPDATE, pause.hold_camera, OF.LOCAL_MARIO)
end
