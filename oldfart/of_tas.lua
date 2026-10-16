OF = OF or {}
OF.tas = OF.tas or {}

local tas = OF.tas

tas.MAX_FRAMES = 30 * 60 * 10
tas.PATH = "tas/take.txt"
tas.FORM = "OFTAS1"
local ARM_WAIT = 5 * 30

tas.mode = "idle"
tas.take = nil

tas.frame = 0

tas.driftAt = nil
tas.driftBy = 0

tas.counted = 0

local armedAt = 0
local ticks = 0

local KEY_READOUT, KEY_PAD = "tas_readout", "tas_pad"
local settings = {}

local function word(key)
    if settings[key] == nil then settings[key] = mod_storage_load(key) == "on" end
    return settings[key]
end

local function store_word(key, on)
    settings[key] = on == true
    OF.util.store(key, on and "on" or "off")
end

function tas.forget_settings()
    settings = {}
end

function tas.readouts_on() return word(KEY_READOUT) end

function tas.pad_on()
    if word(KEY_PAD) then return true end
    return OF.util.asks(OF.cheats, "is_on") and OF.cheats.is_on("inputs") == true
end

function tas.pad_follows(on)
    store_word(KEY_PAD, on == true)
    return true
end

function tas.set_readouts(on)
    store_word(KEY_READOUT, on)
    tas.counted = 0
    return true
end

function tas.set_pad(on)
    store_word(KEY_PAD, on)
    local cheats = OF.cheats
    if OF.util.asks(cheats, "set_mine") then
        local wanted = nil
        if on then
            wanted = true
        elseif OF.util.asks(cheats, "room_level") and cheats.room_level("inputs") ~= nil then

            wanted = false
        end
        local ok, why = cheats.set_mine("inputs", wanted)

        store_word(KEY_PAD, on)

        if not ok and why ~= nil then return false, why end
    end
    return true
end

function tas.reset_screen()
    local moved = tas.readouts_on() or tas.pad_on()
    if tas.readouts_on() then tas.set_readouts(false) end
    if tas.pad_on() then tas.set_pad(false) end
    return moved
end

function tas.refusal()
    if OF.util.asks(OF.roundscope, "inside") and OF.roundscope.inside(0) then
        return "TAS tools rest while you are in a race or a round."
    end
    if OF.util.asks(OF.speedrun, "is_running") and OF.speedrun.is_running()
        and OF.util.can_play(0) then
        return "TAS tools rest while you are in a race or a round."
    end
    return nil
end

local function new_take(np)
    return { level = np.currLevelNum, area = np.currAreaIndex, act = np.currActNum,
             frames = 0, sx = {}, sy = {}, mag = {}, down = {}, pressed = {},
             yaw = {}, px = {}, py = {}, pz = {} }
end

local function stop_everything(quiet)
    local was = tas.mode
    tas.mode = "idle"
    if was == "rec" and tas.take ~= nil and tas.take.frames > 0 then
        local ok, why = tas.save()
        if not quiet then
            if ok then
                OF.notify.show("Recorded @ frames", "good", 4, tostring(tas.take.frames))
            else
                OF.notify.show(why or "The take could not be saved.", "warn", 5)
            end
        end
    elseif was == "play" and not quiet then
        if tas.driftAt ~= nil then
            OF.notify.show("Playback left your path at frame @", "info", 6,
                tostring(tas.driftAt))
        else
            OF.notify.show("Playback matched every frame", "good", 5)
        end
    end
end

function tas.record()
    local why = tas.refusal()
    if why ~= nil then return false, why end
    if tas.mode ~= "idle" then stop_everything(true) end
    local np = gNetworkPlayers[0]
    if np == nil then return false, "Nothing is loaded." end
    local ok = OF.net.reload_here()
    if not ok then return false, "This map has no entry to start a take from." end
    tas.mode = "armrec"
    armedAt = ticks
    return true
end

function tas.record_here()
    local why = tas.refusal()
    if why ~= nil then return false, why end
    if tas.mode ~= "idle" then stop_everything(true) end
    local np = gNetworkPlayers[0]
    local m = gMarioStates[0]
    if np == nil or m == nil or m.pos == nil then return false, "Nothing is loaded." end
    local take = new_take(np)
    take.start = { x = m.pos.x, y = m.pos.y, z = m.pos.z, yaw = m.faceAngle.y,
        vx = m.vel.x, vy = m.vel.y, vz = m.vel.z, fwd = m.forwardVel,
        action = m.action }
    tas.take = take
    tas.loaded = true
    tas.frame = 0
    tas.mode = "rec"
    return true
end

local startOwed = false
function tas.put_at_start(m)
    local take = tas.take
    local st = take ~= nil and take.start or nil
    if st == nil or m == nil then return false end
    m.pos.x, m.pos.y, m.pos.z = st.x, st.y, st.z
    m.vel.x, m.vel.y, m.vel.z = st.vx, st.vy, st.vz
    m.forwardVel = st.fwd
    m.faceAngle.y = st.yaw
    if type(st.action) == "number" and st.action ~= 0 and m.action ~= st.action then
        pcall(set_mario_action, m, st.action, 0)
    end
    return true
end

function tas.play()
    local why = tas.refusal()
    if why ~= nil then return false, why end
    local take = tas.load()
    if take == nil or take.frames == 0 then return false, "There is no take to play." end
    if tas.mode ~= "idle" then stop_everything(true) end

    local np = gNetworkPlayers[0]
    if take.start ~= nil and np ~= nil and np.currLevelNum == take.level
        and np.currAreaIndex == take.area then
        tas.frame = 0
        tas.driftAt, tas.driftBy = nil, 0
        startOwed = true
        tas.mode = "play"
        return true
    end
    local ok = OF.net.warp_local(take.level, take.area, take.act, nil,
        "That take's entry cannot be reached from here.")
    if not ok then return false, "That take's entry cannot be reached from here." end
    tas.mode = "armplay"
    armedAt = ticks
    return true
end

function tas.stop()
    if tas.mode == "idle" then return false, "Nothing is recording or playing." end
    stop_everything(false)
    return true
end

function tas.forget()
    stop_everything(true)
    tas.take = nil
    tas.loaded = true
    local fs = OF.util.optional("mod_fs_get")
    if fs ~= nil then
        pcall(function()
            if fs:get_file(tas.PATH) ~= nil then
                fs:delete_file(tas.PATH)
                fs:save()
            end
        end)
    end
    return true
end

local function arrived()
    if tas.mode == "armrec" then
        tas.take = new_take(gNetworkPlayers[0])
        tas.loaded = true
        tas.frame = 0
        tas.mode = "rec"
    elseif tas.mode == "armplay" then
        tas.frame = 0
        tas.driftAt, tas.driftBy = nil, 0
        startOwed = tas.take ~= nil and tas.take.start ~= nil
        tas.mode = "play"
    end
end

local function round(value)
    value = tonumber(value) or 0
    if value >= 0 then return math.floor(value + 0.5) end
    return -math.floor(-value + 0.5)
end

function tas.encode(take)
    local head = { tas.FORM, take.level, take.area, take.act, take.frames }

    local st = take.start
    if st ~= nil then
        for _, v in ipairs({ round(st.x), round(st.y), round(st.z), round(st.yaw),
            round(st.vx * 100), round(st.vy * 100), round(st.vz * 100),
            round(st.fwd * 100), st.action or 0 }) do
            head[#head + 1] = v
        end
    end
    local out = { table.concat(head, "|") }
    for i = 1, take.frames do
        out[#out + 1] = table.concat({
            round((take.sx[i] or 0) * 100), round((take.sy[i] or 0) * 100),
            round((take.mag[i] or 0) * 100), take.down[i] or 0, take.pressed[i] or 0,
            take.yaw[i] ~= nil and tostring(take.yaw[i]) or "",
            round(take.px[i] or 0), round(take.py[i] or 0), round(take.pz[i] or 0),
        }, ",")
    end
    return table.concat(out, "\n")
end

function tas.decode(text)
    if type(text) ~= "string" then return nil end
    local lines = {}
    for line in string.gmatch(text .. "\n", "([^\n]*)\n") do lines[#lines + 1] = line end
    local head = {}
    for piece in string.gmatch((lines[1] or "") .. "|", "([^|]*)|") do head[#head + 1] = piece end
    local form, level, area, act, frames = head[1], head[2], head[3], head[4], head[5]
    if form ~= tas.FORM or (#head ~= 5 and #head ~= 14) then return nil end
    for k = 2, #head do
        if tonumber(head[k]) == nil then return nil end
    end
    frames = tonumber(frames)
    if frames > tas.MAX_FRAMES or #lines < frames + 1 then return nil end
    local take = { level = tonumber(level), area = tonumber(area), act = tonumber(act),
        frames = frames, sx = {}, sy = {}, mag = {}, down = {}, pressed = {},
        yaw = {}, px = {}, py = {}, pz = {} }
    if #head == 14 then
        local h = function(k) return tonumber(head[k]) end
        take.start = { x = h(6), y = h(7), z = h(8), yaw = h(9),
            vx = h(10) / 100, vy = h(11) / 100, vz = h(12) / 100,
            fwd = h(13) / 100, action = h(14) }
    end
    for i = 1, frames do
        local f = {}
        for piece in string.gmatch(lines[i + 1] .. ",", "([^,]*),") do f[#f + 1] = piece end
        if #f ~= 9 then return nil end
        local function n(k) return tonumber(f[k]) end
        if n(1) == nil or n(2) == nil or n(3) == nil or n(4) == nil or n(5) == nil then
            return nil
        end
        take.sx[i], take.sy[i], take.mag[i] = n(1) / 100, n(2) / 100, n(3) / 100
        take.down[i], take.pressed[i] = n(4), n(5)
        take.yaw[i] = n(6)
        take.px[i], take.py[i], take.pz[i] = n(7) or 0, n(8) or 0, n(9) or 0
    end
    return take
end

function tas.save()
    local take = tas.take
    if take == nil then return false, "There is no take." end
    local fs = OF.util.optional("mod_fs_get")
    if fs == nil then fs = OF.util.optional("mod_fs_create") end
    if fs == nil then return false, "This build keeps no files." end
    local ok = pcall(function()
        local file = fs:get_file(tas.PATH)
        if file == nil then file = fs:create_file(tas.PATH, true) end
        file:set_text_mode(true)
        file:rewind()
        local size = tonumber(file.size) or 0
        if size > 0 then file:erase(size) end
        file:rewind()
        if file:write_string(tas.encode(take)) ~= true then error("write") end
        if fs:save() ~= true then error("save") end
    end)
    if not ok then return false, "The take could not be saved." end
    return true
end

function tas.load()
    if tas.take ~= nil or tas.loaded then return tas.take end
    tas.loaded = true
    local fs = OF.util.optional("mod_fs_get")
    if fs == nil then return nil end
    local text = nil
    pcall(function()
        local file = fs:get_file(tas.PATH)
        if file == nil then return end
        file:set_text_mode(true)
        file:rewind()
        text = file:read_string()
    end)
    tas.take = tas.decode(text)
    return tas.take
end

tas.seen = { sx = 0, sy = 0, down = 0 }

hook_event(HOOK_BEFORE_MARIO_UPDATE, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    local c = m.controller
    if c == nil then return end
    if tas.mode == "rec" then
        local take = tas.take
        if take.frames >= tas.MAX_FRAMES then
            stop_everything(false)
        else
            local i = take.frames + 1
            take.frames = i
            take.sx[i], take.sy[i], take.mag[i] = c.stickX, c.stickY, c.stickMag
            take.down[i], take.pressed[i] = c.buttonDown, c.buttonPressed
            tas.frame = i
        end
    elseif tas.mode == "play" then
        local take = tas.take
        if startOwed then
            startOwed = false
            tas.put_at_start(m)
        end
        local i = tas.frame + 1
        if take == nil or i > take.frames then
            stop_everything(false)
        else
            tas.frame = i
            c.stickX, c.stickY, c.stickMag = take.sx[i], take.sy[i], take.mag[i]
            c.buttonDown, c.buttonPressed = take.down[i], take.pressed[i]
        end
    end
    if tas.readouts_on() then tas.counted = tas.counted + 1 end
    tas.seen.sx, tas.seen.sy, tas.seen.down = c.stickX or 0, c.stickY or 0, c.buttonDown or 0
end, OF.LOCAL_MARIO)

hook_event(HOOK_MARIO_OVERRIDE_GEOMETRY_INPUTS, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    local take = tas.take
    if take == nil then return end
    if tas.mode == "rec" and tas.frame > 0 then
        if (m.intendedMag or 0) > 0 then take.yaw[tas.frame] = m.intendedYaw end
    elseif tas.mode == "play" and tas.frame > 0 then
        local yaw = take.yaw[tas.frame]
        if yaw ~= nil and (m.intendedMag or 0) > 0 then m.intendedYaw = yaw end
    end
end)

hook_event(HOOK_MARIO_UPDATE, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    local take = tas.take
    if take == nil or tas.frame == 0 then return end
    local i = tas.frame
    if tas.mode == "rec" then
        take.px[i], take.py[i], take.pz[i] = m.pos.x, m.pos.y, m.pos.z
    elseif tas.mode == "play" and tas.driftAt == nil and take.px[i] ~= nil then
        local dx, dy, dz = m.pos.x - take.px[i], m.pos.y - take.py[i], m.pos.z - take.pz[i]
        local by = math.sqrt(dx * dx + dy * dy + dz * dz)
        if by > 1 then tas.driftAt, tas.driftBy = i, by end
    end
end, OF.LOCAL_MARIO)

hook_event(HOOK_ON_LEVEL_INIT, function()
    if tas.mode == "armrec" or tas.mode == "armplay" then arrived() end
end)

hook_event(HOOK_UPDATE, function()
    ticks = ticks + 1

    if tas.mode ~= "idle" and tas.refusal() ~= nil then
        stop_everything(true)
        OF.notify.show("TAS tools rest while you are in a race or a round.", "info", 5)
    end
    if (tas.mode == "armrec" or tas.mode == "armplay") and ticks - armedAt > ARM_WAIT then
        tas.mode = "idle"
        OF.notify.show("The level entry never came, so nothing started.", "warn", 5)
    end

    if not OF.util.menu_has_screen() and OF.util.asks(OF.input, "pressed") then
        if tas.mode ~= "idle" and OF.input.pressed(D_JPAD) then
            tas.stop()
        end
    end
end)

tas.ROW_KEY = "ofTasPlay"
local publishedPlay = false

function tas.publish_playing()
    local now = tas.mode == "play"
    if now == publishedPlay then return false end
    publishedPlay = now

    OF.util.publish_row(0, "ofTasPlay", now)
    return true
end

function tas.replaying(li)
    if li == nil or li == 0 then return tas.mode == "play" end
    local row = gPlayerSyncTable[li]
    return row ~= nil and row[tas.ROW_KEY] == true
end

function tas.untouchable(a, b)
    return tas.replaying(a) or tas.replaying(b)
end

hook_event(HOOK_ALLOW_INTERACT, function(m, o, interactType)
    if m == nil or o == nil or interactType ~= INTERACT_PLAYER then return end
    for j = 0, MAX_PLAYERS - 1 do
        local other = gMarioStates[j]
        if other ~= nil and other.marioObj == o then
            if tas.untouchable(m.playerIndex, j) then return false end
            return
        end
    end
end)

hook_event(HOOK_ALLOW_PVP_ATTACK, function(attacker, victim)
    if attacker == nil or victim == nil then return end
    if tas.untouchable(attacker.playerIndex, victim.playerIndex) then return false end
end)

hook_event(HOOK_UPDATE, function() tas.publish_playing() end)

local function action_text(action)
    return string.format("0x%08X", math.floor(tonumber(action) or 0) % 0x100000000)
end

function tas.readout_lines(m)
    local lines = {}
    local frame = tas.counted
    if tas.mode == "rec" then
        lines[#lines + 1] = OF.lang.fill("Recording - frame @", tostring(tas.frame))
    elseif tas.mode == "play" then
        lines[#lines + 1] = OF.lang.fill("Playing - frame @ of @", tostring(tas.frame),
            tostring(tas.take and tas.take.frames or 0))
    else
        lines[#lines + 1] = OF.lang.fill("Frame @", tostring(frame))
    end
    local h = math.sqrt(m.vel.x * m.vel.x + m.vel.z * m.vel.z)
    lines[#lines + 1] = string.format("Speed %.2f   H %.2f   Y %.2f", m.forwardVel, h, m.vel.y)
    lines[#lines + 1] = string.format("X %.1f   Y %.1f   Z %.1f", m.pos.x, m.pos.y, m.pos.z)
    lines[#lines + 1] = string.format("Facing %.0f   Action %s", m.faceAngle.y, action_text(m.action))
    if tas.mode == "play" and tas.driftAt ~= nil then
        lines[#lines + 1] = OF.lang.fill("Off the path since frame @", tostring(tas.driftAt))
    end
    return lines
end

tas.PAD = {
    { "A", A_BUTTON }, { "B", B_BUTTON }, { "Z", Z_TRIG }, { "L", L_TRIG },
    { "R", R_TRIG }, { "S", START_BUTTON }, { "C^", U_CBUTTONS },
    { "Cv", D_CBUTTONS }, { "C<", L_CBUTTONS }, { "C>", R_CBUTTONS },
}

local TAS_PLATE = { alpha = 150 }

local function draw_readout(m)
    local lines = tas.readout_lines(m)
    local x, y, scale = 16, djui_hud_get_screen_height() * 0.28, 0.8

    local widest = 0
    for _, line in ipairs(lines) do
        local w = OF.util.width(line, scale)
        if w > widest then widest = w end
    end
    local step = OF.util.line_height(scale) + 1
    OF.util.plate(x - 6, y - 4, widest + 12, #lines * step + 8, TAS_PLATE)
    for i, line in ipairs(lines) do
        OF.util.text(line, x, y + (i - 1) * step, scale, 230, 230, 230, 255)
    end
end

local PAD_SIZE, PAD_DETAIL_SCALE = 64, 0.6
function tas.pad_rect()
    if not tas.pad_on() then return nil end
    local x = 16
    local y = djui_hud_get_screen_height() - PAD_SIZE - 80
    local detail = OF.util.line_height(PAD_DETAIL_SCALE) + 4
    return x - 6, y - 6, PAD_SIZE + 12 + 150, PAD_SIZE + 12 + detail
end

local function draw_pad()
    local seen = tas.seen
    local size = PAD_SIZE
    local x = 16
    local y = djui_hud_get_screen_height() - size - 80
    local px, py, pw, ph = tas.pad_rect()

    local detail = OF.util.asks(OF.cheats, "inputs_detail")
        and OF.cheats.inputs_detail(gMarioStates[0]) or nil
    if detail ~= nil then
        pw = math.max(pw, OF.util.width(detail, PAD_DETAIL_SCALE) + 12)
    end
    OF.util.plate(px or (x - 6), py or (y - 6), pw or (size + 162), ph or (size + 12), TAS_PLATE)
    if detail ~= nil then
        OF.util.text(detail, x, y + size + 4, PAD_DETAIL_SCALE, 230, 230, 230, 255)
    end
    OF.util.rect(x, y, size, size, 60, 60, 60, 200)
    local dotX = x + size * 0.5 + (seen.sx / 64) * (size * 0.5) - 4
    local dotY = y + size * 0.5 - (seen.sy / 64) * (size * 0.5) - 4
    OF.util.rect(dotX, dotY, 8, 8, 255, 255, 255, 255)
    for i, entry in ipairs(tas.PAD) do
        local col = (i - 1) % 5
        local rowY = y + math.floor((i - 1) / 5) * 32
        local lit = OF.util.has_flag(seen.down, entry[2])
        local r, g, b = 110, 110, 110
        if lit then r, g, b = 255, 230, 90 end
        OF.util.text(entry[1], x + size + 12 + col * 30, rowY, 0.8, r, g, b, 255)
    end
end

hook_event(HOOK_ON_HUD_RENDER, function()
    local readout, pad = tas.readouts_on(), tas.pad_on()
    if not readout and not pad and tas.mode == "idle" then return end
    if OF.util.menu_has_screen() then return end
    local m = gMarioStates[0]
    if m == nil then return end
    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    if pad then draw_pad() end
    if tas.refusal() ~= nil then return end
    if readout or tas.mode ~= "idle" then draw_readout(m) end
end)

function tas.build_page(panel)
    local rows = {}
    local why = tas.refusal()
    if why ~= nil then
        table.insert(rows, panel.label_row("   " .. OF.lang.t(why)))
    end

    table.insert(rows, panel.with_help(panel.row(
        panel.tick(tas.readouts_on(), OF.lang.t("Frame readouts on screen")), 255, 255, 255,
        function() OF.util.report(tas.set_readouts(not tas.readouts_on())) end),
        OF.lang.t("a frame counter, your speed, position, facing and action")))
    table.insert(rows, panel.with_help(panel.row(
        panel.tick(tas.pad_on(), OF.lang.t("Input display on screen")), 255, 255, 255,
        function() OF.util.report(tas.set_pad(not tas.pad_on())) end),
        OF.lang.t("the stick and every button Mario was given, each frame")))

    table.insert(rows, panel.header_row(OF.lang.t("Record and replay")))
    if tas.mode == "rec" or tas.mode == "armrec" then
        table.insert(rows, panel.with_help(panel.row(
            OF.lang.t("Stop recording  (or D-pad down)"), 255, 140, 90,
            function() OF.util.report(tas.stop()) end),
            OF.lang.t("keeps the take on this machine")))
    elseif tas.mode == "play" or tas.mode == "armplay" then
        table.insert(rows, panel.with_help(panel.row(
            OF.lang.t("Stop playback  (or D-pad down)"), 255, 140, 90,
            function() OF.util.report(tas.stop()) end),
            OF.lang.t("hands the pad back to you")))
    else
        table.insert(rows, panel.with_help(panel.row(
            OF.lang.t("Record from the level entry"), 255, 255, 255,
            function() OF.util.report(tas.record()); panel.close() end),
            OF.lang.t("sends you back to where you entered, then records every frame")))
        table.insert(rows, panel.with_help(panel.row(
            OF.lang.t("Record from where you stand"), 255, 255, 255,
            function() OF.util.report(tas.record_here()); panel.close() end),
            OF.lang.t("starts at once, and playback puts you back here first")))
        local take = tas.load()
        if take ~= nil and take.frames > 0 then
            table.insert(rows, panel.with_help(panel.row(
                OF.lang.fill("Play it back  (@ frames)", tostring(take.frames)),
                255, 255, 255,
                function() OF.util.report(tas.play()); panel.close() end),
                take.start ~= nil
                    and OF.lang.fill("from where it began in @",
                        OF.util.level_name(take.level, take.area) or OF.lang.t("its level"))
                    or OF.lang.fill("from the entry of @",
                        OF.util.level_name(take.level, take.area) or OF.lang.t("its level"))))
            table.insert(rows, panel.with_help(panel.confirm_row("tasforget",
                OF.lang.t("Forget the take"), 255, 180, 120,
                function() OF.util.report(tas.forget()) end),
                OF.lang.t("the recorded inputs go from this machine")))
        end
    end
    table.insert(rows, panel.label_row("   " .. OF.lang.t("A take replays your inputs, not the world.")))
    table.insert(rows, panel.label_row("   " .. OF.lang.t("Enemies and players can differ, so it shows")))
    table.insert(rows, panel.label_row("   " .. OF.lang.t("the frame where you left the recorded path.")))

    table.insert(rows, panel.label_row("   " .. OF.lang.t("No savestates: the engine cannot save the world.")))
    table.insert(rows, panel.back_row())
    return rows
end
