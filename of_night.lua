OF = OF or {}
OF.night = OF.night or {}

local night = OF.night

night.OFF     = ""
night.WARMUP  = "warmup"
night.PLAYING = "playing"
night.BREAK   = "break"
night.FINALE  = "finale"
night.BOARD   = "board"
night.SHAPES = {

    { key = "usual", name = "The usual",
      warmup = 45, breather = 20, blocks = { 3, 3 },
      blurb = "warm up, three rounds, a breather, three more" },

    { key = "quick", name = "A quick one",
      warmup = 20, breather = 15, blocks = { 3 },
      blurb = "three rounds and out, for a lobby with half an hour" },

    { key = "long", name = "A long one",
      warmup = 60, breather = 30, blocks = { 4, 4, 4 },
      blurb = "twelve rounds and two breathers, for a full lobby" },

    { key = "narrow", name = "A session that narrows",
      warmup = 45, breather = 20, blocks = { 4, 2, 1 },
      blurb = "four rounds, then two, then the one the lobby picked" },

    { key = "theme", name = "One kind of session",
      warmup = 45, breather = 20, blocks = { 3, 3 }, theme = true,
      blurb = "every round out of one corner of the roster" },

    { key = "fits", name = "Fits the lobby", fits = true,
      blurb = "short for a handful, long for a full lobby" },
}

night.shapeChoice = "usual"
function night.shape(key)
    if key == nil or key == "" then return nil end
    for _, shape in ipairs(night.SHAPES) do
        if shape.key == key then return shape end
    end
    return nil
end

function night.usable_shape(key)
    local shape = night.shape(key)
    if shape == nil or shape.blocks == nil or #shape.blocks == 0 then return nil end
    return shape
end

function night.fit_key(count)
    count = math.floor(tonumber(count) or #OF.gamemodes.participants())
    if count <= 3 then return "quick" end
    if count >= 8 then return "long" end
    return "usual"
end

function night.chosen_shape()
    local chosen = night.shape(night.shapeChoice)
    if chosen ~= nil and chosen.fits then
        return night.usable_shape(night.fit_key()) or night.usable_shape("usual")
    end
    return night.usable_shape(night.shapeChoice) or night.usable_shape("usual")
end

function night.rounds_in(shape)
    if shape == nil or shape.blocks == nil then return 0 end
    local total = 0
    for _, count in ipairs(shape.blocks) do total = total + count end
    return total
end

function night.set_shape(key)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    if night.shape(key) == nil then return false, "No such shape." end

    if night.is_on() and not night.showing_board() then
        return false, "The session is running - stand it down first."
    end
    night.shapeChoice = key
    return true
end

function night.next_shape()
    for index, shape in ipairs(night.SHAPES) do
        if shape.key == night.shapeChoice then
            return night.SHAPES[index % #night.SHAPES + 1].key
        end
    end
    return night.SHAPES[1].key
end

local BOARD_SECONDS = 25
local BOARD_ROWS = 8

local WIRE_MODES = 5

local TONIGHT_MAX = 2

local TONIGHT_KEEP = 40

local MEND_FRAMES = 30

local hostTimer = 0

local warmupLeft = nil
local warmupComing = ""
local tonightShape = nil
local blockAt = 0
local themeName = nil
local playedKeys = {}
local playedCount = 0
local playedLast = ""
local startedAt = nil

local function fields()
    local packed = gGlobalSyncTable.ofNight
    if packed == nil or packed == "" then return nil end
    local parts = {}
    for piece in string.gmatch(packed .. "|", "([^|]*)|") do
        table.insert(parts, piece)
    end
    if parts[1] == nil or parts[1] == "" then return nil end
    return parts
end

function night.state()
    local parts = fields()
    if parts == nil then return night.OFF, 0, "" end
    return parts[1], tonumber(parts[2]) or 0, parts[3] or ""
end

function night.progress()
    local parts = fields()
    if parts == nil then return "", 0, 0 end
    return parts[4] or "", tonumber(parts[5]) or 0, tonumber(parts[6]) or 0
end

function night.tally()
    local parts = fields()
    if parts == nil then return 0, 0 end
    return tonumber(parts[7]) or 0, tonumber(parts[8]) or 0
end

function night.showing_board()
    local phase = night.state()
    return phase == night.BOARD
end

local function publish(phase, seconds, keys)

    if not OF.util.is_host() then return end
    local minutes = 0
    if startedAt ~= nil then
        minutes = math.floor((clock_elapsed() - startedAt) / 60)
        if minutes < 0 then minutes = 0 end
    end
    OF.util.publish("ofNight", table.concat({
        phase,
        tostring(math.floor(seconds or 0)),
        keys or "",
        tonightShape ~= nil and tonightShape.key or "",
        tostring(blockAt),
        tostring(tonightShape ~= nil and #tonightShape.blocks or 0),
        tostring(playedCount),
        tostring(minutes),
    }, "|"))
end

function night.phase_text()
    local phase, seconds = night.state()
    if phase == night.WARMUP then
        return OF.lang.fill("Warming up - @s until the first round", seconds)
    elseif phase == night.BREAK then

        if night.awaiting_finale_vote() then
            return OF.lang.t("Breather - what should this session finish on?")
        end
        return OF.lang.fill("Breather - @s", seconds)
    elseif phase == night.FINALE then

        local left = gGlobalSyncTable.ofQueueLeft or 0
        if left > 1 then return OF.lang.fill("The last stretch - @ to go", left) end
        return OF.lang.t("The last one")
    elseif phase == night.PLAYING then
        return OF.lang.fill("This session: @ to go", gGlobalSyncTable.ofQueueLeft or 0)
    elseif phase == night.BOARD then
        return OF.lang.t("That was the session")
    end
    return ""
end

function night.programme()
    local phase = night.state()
    local shapeKey, at = night.progress()
    local shape = night.usable_shape(shapeKey) or night.chosen_shape()
    local steps = {}
    if shape == nil then return steps end

    table.insert(steps, {
        text = OF.lang.t("Warm up while people arrive"),
        at = phase == night.WARMUP,
    })

    for index, count in ipairs(shape.blocks) do
        local last = index == #shape.blocks
        local text
        if last and #shape.blocks > 1 then
            text = OF.lang.fill("@ to finish, ending on the lobby's pick", count)
        else
            text = OF.lang.fill("@ round(s)", count)
        end
        table.insert(steps, {
            text = text,
            at = (phase == night.PLAYING or phase == night.FINALE) and at == index,
        })
        if not last then
            table.insert(steps, {
                text = OF.lang.t("A breather"),
                at = phase == night.BREAK and at == index,
            })
        end
    end

    table.insert(steps, {
        text = OF.lang.t("The session's board"),
        at = phase == night.BOARD,
    })
    return steps
end

function night.playable()
    local list = {}
    for _, mode in ipairs(OF.gamemodes.LIST) do
        if OF.gamemodes.can_start_here(mode) then table.insert(list, mode) end
    end
    return list
end

function night.theme()
    return themeName
end

local function pick_theme()
    local able = {}
    for _, group in ipairs(OF.gamemodes.grouped()) do
        local count = 0
        for _, mode in ipairs(group.modes) do
            if OF.gamemodes.can_start_here(mode) then count = count + 1 end
        end
        if count >= 2 then table.insert(able, group.name) end
    end
    if #able == 0 then return nil end
    return able[math.random(#able)]
end

function night.pool()
    if themeName == nil then return night.playable() end
    for _, group in ipairs(OF.gamemodes.grouped()) do
        if group.name == themeName then
            local list = {}
            for _, mode in ipairs(group.modes) do
                if OF.gamemodes.can_start_here(mode) then table.insert(list, mode) end
            end
            if #list > 0 then return list end
        end
    end
    return night.playable()
end

local function times_played(key)
    local count = 0
    for _, played in ipairs(playedKeys) do
        if played == key then count = count + 1 end
    end
    return count
end

night.times_played = times_played

local nextIndex = 0

local function walk(from, count)
    local pool = night.pool()
    local list, steps = {}, 0
    if #pool == 0 then return list, 0 end
    count = math.floor(tonumber(count) or 1)
    if count < 1 then return list, 0 end

    while #list < count and steps < #pool do
        local mode = pool[((from + steps) % #pool) + 1]
        steps = steps + 1
        if times_played(mode.key) < TONIGHT_MAX then table.insert(list, mode) end
    end

    local extra = 0
    while #list < count and extra < count do
        table.insert(list, pool[((from + steps + extra) % #pool) + 1])
        extra = extra + 1
    end

    return list, steps + extra
end

function night.line_up(count)
    local list = walk(nextIndex, count)
    return list
end

function night.plan(count)
    local list, steps = walk(nextIndex, count)
    if #list == 0 then return {} end

    local plan = {}
    for _, mode in ipairs(list) do table.insert(plan, mode.key) end
    local pool = #night.pool()
    if pool > 0 then nextIndex = (nextIndex + steps) % pool end
    return plan
end

local function line_up_keys(count)
    local keys = {}
    for _, mode in ipairs(night.line_up(count)) do
        if #keys >= WIRE_MODES then break end
        table.insert(keys, mode.key)
    end
    return table.concat(keys, ",")
end

local function queued_keys()
    local keys = {}
    for _, entry in ipairs(OF.rounds.queue) do
        if #keys >= WIRE_MODES then break end
        table.insert(keys, entry.mode)
    end
    return table.concat(keys, ",")
end

local function names_of(packed)
    local names = {}
    if packed == nil or packed == "" then return names end
    for key in string.gmatch(packed, "[^,]+") do
        local mode = OF.gamemodes.BY_KEY ~= nil and OF.gamemodes.BY_KEY[key] or nil
        if mode ~= nil then
            table.insert(names, OF.lang.t(mode.name))
        elseif key == OF.rounds.SURPRISE then
            table.insert(names, OF.lang.t("a surprise"))
        else
            table.insert(names, key)
        end
    end
    return names
end

function night.coming_up()
    local _, _, keys = night.state()
    return names_of(keys)
end

function night.played_up()
    if not night.showing_board() then return {} end
    local _, _, keys = night.state()
    return names_of(keys)
end

function night.finale_pair()
    local pool = night.pool()
    if #pool < 2 then return nil, nil end

    local fresh = {}
    for step = 1, #pool do
        local mode = pool[((nextIndex + step - 1) % #pool) + 1]
        if times_played(mode.key) == 0 then table.insert(fresh, mode) end
        if #fresh >= 2 then break end
    end
    if #fresh >= 2 then return fresh[1], fresh[2] end

    local first = pool[(nextIndex % #pool) + 1]
    local second = pool[((nextIndex + 1) % #pool) + 1]
    return first, second
end

local finaleOffer = nil
local finaleMode = nil

function night.finale_question()
    if finaleOffer == nil then return "Which round should finish the session?" end
    return "Finish the session on " .. finaleOffer.yesName
        .. "?   (no = " .. finaleOffer.noName .. ")"
end

function night.choose_finale(yes)
    if finaleOffer == nil then return false end
    finaleMode = yes and finaleOffer.yes or finaleOffer.no
    local name = yes and finaleOffer.yesName or finaleOffer.noName
    finaleOffer = nil

    OF.notify.send_all("The session finishes on @", "good", 6, name)
    return true
end

function night.finale_mode()
    return finaleMode
end

function night.finale_offer()
    return finaleOffer
end

function night.awaiting_finale_vote()
    return finaleOffer ~= nil and OF.vote.is_open()
end

local function ask_the_room()
    if finaleMode ~= nil or finaleOffer ~= nil then return false end

    local first, second = night.finale_pair()
    if first == nil then return false end

    finaleOffer = {
        yes = first.key, yesName = first.name,
        no = second.key, noName = second.name,
    }

    local ok, why = OF.vote.start("finale")
    if not ok then
        finaleOffer = nil
        OF.chatlog.add_system("no finale vote: " .. tostring(why))
        return false
    end
    return true
end

local function place_finale(plan)
    if finaleMode == nil or #plan == 0 then return plan end

    for index, key in ipairs(plan) do
        if key == finaleMode then
            table.remove(plan, index)
            table.insert(plan, finaleMode)
            return plan
        end
    end

    plan[#plan] = finaleMode
    return plan
end

local function mend()
    if not OF.util.is_host() then return 0, 0 end
    if not OF.util.asks(OF.rounds, "mend") then return 0, 0 end

    return OF.rounds.mend(function(_, entry)
        local lined = {}
        for _, other in ipairs(OF.rounds.queue) do lined[other.mode] = true end

        local best, fewest = nil, nil
        for _, mode in ipairs(night.pool()) do
            if not lined[mode.key] and mode.key ~= entry.mode then
                local played = times_played(mode.key)
                if fewest == nil or played < fewest then
                    best, fewest = mode.key, played
                end
            end
        end
        return best
    end)
end

local function queue_plan(plan)
    OF.rounds.clear()
    local queued = 0
    for _, key in ipairs(plan) do
        local mode = OF.gamemodes.BY_KEY[key]

        if mode ~= nil and OF.gamemodes.can_start_here(mode)
            and OF.rounds.add(key) then
            queued = queued + 1
        end
    end
    if queued == 0 then
        return false, "Nobody can play anything with this many here."
    end
    return OF.rounds.start()
end

function night.start(askerLocal)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end

    if not OF.util.is_host() then
        return false, "Only the host can run the session."
    end

    if night.is_on() and not night.showing_board() then
        return false, "The session is already running."
    end
    if #OF.gamemodes.participants() < 2 then
        return false, "There is nobody here to run a session for."
    end

    local shape = night.chosen_shape()
    if shape == nil then return false, "That shape cannot be run." end

    themeName = nil
    if shape.theme then themeName = pick_theme() end
    if #night.pool() == 0 then
        themeName = nil
        return false, "Nobody can play anything with this many here."
    end

    hostTimer = 0

    finaleOffer = nil
    finaleMode = nil
    tonightShape = shape
    blockAt = 0
    playedKeys = {}
    playedCount = 0
    playedLast = ""
    startedAt = clock_elapsed()
    warmupLeft = shape.warmup
    warmupComing = line_up_keys(shape.blocks[1])
    publish(night.WARMUP, shape.warmup, warmupComing)

    if themeName ~= nil then
        OF.notify.send_all("This session is all: @", "good", 6, themeName)
    end

    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
        OF.notify.credit_named(askerLocal,
            OF.lang.fill("started a session: @", OF.lang.t(shape.name)))
    end
    OF.actionlog.by_hand(OF.util.presser(askerLocal),
        OF.lang.fill("started a session: @", OF.lang.t(shape.name)))

    OF.notify.send_all("This session: @, @ round(s)", "good", 6, shape.name,
        tostring(night.rounds_in(shape)))
    return true
end

local function stand_down(reason, askerLocal)
    OF.util.publish("ofNight", "")
    hostTimer = 0

    warmupLeft = nil
    warmupComing = ""
    OF.rounds.stop(true)

    if night.awaiting_finale_vote() then
        local ok, why = OF.vote.cancel()
        if not ok then OF.chatlog.add_system("finale vote left open: " .. tostring(why)) end
    end
    finaleOffer = nil
    finaleMode = nil

    tonightShape = nil
    blockAt = 0
    themeName = nil

    if reason ~= nil then
        OF.notify.send_all("@", "warn", 5, reason)

        if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
            OF.notify.credit_named(askerLocal,
                OF.lang.t("stood the session down"))
        end
        OF.actionlog.by_hand(OF.util.presser(askerLocal),
            OF.lang.t("stood the session down"))
    end
end

function night.stop(quiet, askerLocal)
    if not night.is_on() then return false, OF.lang.t("No session is running.") end

    if night.showing_board() then
        stand_down(nil)
        return true
    end
    stand_down(not quiet and "The session was stood down" or nil, askerLocal)
    return true
end

function night.keep_tonight(name)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    if not OF.util.is_host() then return false, "The host holds the list." end
    if #playedKeys == 0 then return false, "Nothing was played this session." end

    local list = {}
    for _, key in ipairs(playedKeys) do table.insert(list, { mode = key }) end
    if name == nil or name == "" then
        name = OF.lang.fill("session of @", tostring(#list))
    end
    return OF.rounds.keep(name, nil, list)
end

function night.kept_rounds()
    return #playedKeys
end

local function finish()

    local shape = tonightShape
    local theme = themeName
    stand_down(nil)

    if OF.stats ~= nil then
        OF.stats.publish()

        OF.stats.print_board(OF.stats.published_tonight(), OF.lang.t("This session:"),
            OF.lang.t("Nothing was played this session."))
    end

    local said = shape ~= nil and OF.lang.t(shape.name) or nil
    if said ~= nil and theme ~= nil then said = said .. " - " .. OF.lang.t(theme) end
    if said ~= nil then
        OF.notify.send_all("That is the session - @", "good", 8, said)
    else
        OF.notify.send_all("That is the session - well played", "good", 8)
    end

    local keys = {}
    for index = math.max(1, #playedKeys - WIRE_MODES + 1), #playedKeys do
        table.insert(keys, playedKeys[index])
    end
    publish(night.BOARD, BOARD_SECONDS, table.concat(keys, ","))
    hostTimer = 0
end

local function queue_block(index)
    if not OF.util.is_host() then return false, "The host runs the session." end
    if tonightShape == nil then return false, "No session is running." end
    local count = tonightShape.blocks[index]
    if count == nil then return false, "No such block." end

    local plan = night.plan(count)

    if index == #tonightShape.blocks then plan = place_finale(plan) end
    return queue_plan(plan)
end

local function host_update()
    if not OF.util.is_host() then return end

    local phase, _ = night.state()
    if phase == night.OFF then return end

    local playing = gGlobalSyncTable.ofGmKey or ""
    if playing ~= "" and playing ~= playedLast then
        table.insert(playedKeys, playing)
        while #playedKeys > TONIGHT_KEEP do table.remove(playedKeys, 1) end
        playedCount = playedCount + 1
    end
    playedLast = playing

    if (phase == night.PLAYING or phase == night.FINALE)
        and gGlobalSyncTable.ofQueueOn ~= true
        and not OF.gamemodes.is_running()
        and OF.gamemodes.state() == OF.gamemodes.OFF then
        stand_down("The session stood down - somebody stopped a round.")
        return
    end

    if tonightShape == nil and phase ~= night.BOARD then
        local key, at = night.progress()
        tonightShape = night.usable_shape(key) or night.chosen_shape()
        if tonightShape == nil then
            stand_down("The session has no shape to run")
            return
        end
        blockAt = math.floor(at)
        if blockAt < 1 then blockAt = 1 end
        if blockAt > #tonightShape.blocks then blockAt = #tonightShape.blocks end

        local behind, minutes = night.tally()
        if playedCount == 0 and behind > 0 then playedCount = math.floor(behind) end
        if startedAt == nil then
            startedAt = clock_elapsed() - math.max(0, math.floor(minutes)) * 60
        end
    end

    hostTimer = hostTimer + 1

    if phase == night.WARMUP then
        local count = tonightShape ~= nil and tonightShape.blocks[1] or 0
        local length = tonightShape ~= nil and tonightShape.warmup or 0
        local left = length - math.floor(hostTimer / 30)

        if left ~= warmupLeft then
            warmupLeft = left
            warmupComing = line_up_keys(count)
        end
        publish(night.WARMUP, math.max(0, left), warmupComing)
        if left <= 0 then
            hostTimer = 0
            blockAt = 1
            local ok, why = queue_block(1)
            if not ok then
                stand_down(why or "Nothing could be started")
                return
            end

            publish(blockAt >= #tonightShape.blocks and night.FINALE
                or night.PLAYING, 0, queued_keys())
        end
        return
    end

    if phase == night.PLAYING or phase == night.FINALE then
        if hostTimer % MEND_FRAMES == 0 then mend() end
        publish(phase, 0, queued_keys())

        if (gGlobalSyncTable.ofQueueLeft or 0) > 0
            or OF.gamemodes.is_running()
            or OF.gamemodes.state() ~= OF.gamemodes.OFF then
            return
        end

        if phase == night.FINALE or tonightShape == nil
            or blockAt >= #tonightShape.blocks then
            finish()
            return
        end

        hostTimer = 0
        publish(night.BREAK, tonightShape.breather, "")

        OF.notify.send_all("Breather - stretch your legs", "info", 6)

        if blockAt + 1 >= #tonightShape.blocks then ask_the_room() end
        return
    end

    if phase == night.BREAK then
        local length = tonightShape ~= nil and tonightShape.breather or 0
        local left = length - math.floor(hostTimer / 30)
        publish(night.BREAK, math.max(0, left), "")

        if left <= 0 and night.awaiting_finale_vote() then return end
        if left <= 0 then
            hostTimer = 0
            blockAt = blockAt + 1
            local ok, why = queue_block(blockAt)
            if not ok then

                if playedCount > 0 then
                    finish()
                else
                    stand_down(why or "Nothing could be started")
                end
                return
            end
            if blockAt >= #tonightShape.blocks then
                publish(night.FINALE, 0, queued_keys())
                OF.notify.send_all("Last stretch", "good", 5)
            else
                publish(night.PLAYING, 0, queued_keys())
            end
        end
        return
    end

    if phase == night.BOARD then
        local _, _, keys = night.state()
        local left = BOARD_SECONDS - math.floor(hostTimer / 30)
        publish(night.BOARD, math.max(0, left), keys)
        if left <= 0 then
            OF.util.publish("ofNight", "")
            hostTimer = 0
        end
        return
    end
end

hook_event(HOOK_UPDATE, host_update)

local function render_board()
    local board = OF.stats.published_tonight()
    local screenWidth = djui_hud_get_screen_width()

    local heading = "This session"
    local headScale = 1.8
    local headWidth, headHeight = OF.util.text_size(heading, headScale)
    local top = djui_hud_get_screen_height() * 0.22

    OF.util.plate((screenWidth - headWidth) * 0.5 - 18, top - 10, headWidth + 36, headHeight + 20)
    OF.util.rect((screenWidth - headWidth) * 0.5 - 18, top + headHeight + 8,
        headWidth + 36, 3, OF.util.gold().r, OF.util.gold().g, OF.util.gold().b, 255)
    OF.util.text(heading, (screenWidth - headWidth) * 0.5, top, headScale,
        OF.util.gold().r, OF.util.gold().g, OF.util.gold().b, 255)

    local rowScale = 1.0
    local lineHeight = OF.util.line_height(rowScale) + 8
    local listTop = top + headHeight + 26

    local lines = {}
    local widest = 0
    local function add(text)
        table.insert(lines, text)
        local width = OF.util.width(text, rowScale)
        if width > widest then widest = width end
    end

    for place, entry in ipairs(board) do
        if place > BOARD_ROWS then break end
        add(place .. ".  " .. entry.name .. "   "
            .. OF.lang.fill("@ win(s) in @ round(s)", entry.wins, entry.rounds))
    end
    local scores = #lines

    local rounds, minutes = night.tally()
    if rounds > 0 then
        add(OF.lang.fill("@ round(s) in @ minute(s)", tostring(rounds),
            tostring(minutes)))
    end
    local played = night.played_up()
    if #played > 0 then
        add(OF.lang.fill("Played: @", table.concat(played, ", ")))
    end

    if #lines == 0 then
        add(OF.lang.t("Nothing was played this session."))
    end

    OF.util.plate((screenWidth - widest) * 0.5 - 16, listTop - 8,
        widest + 32, lineHeight * #lines + 14)

    for place, text in ipairs(lines) do
        local r, g, b = 220, 220, 220
        if place == 1 and scores > 0 then
            r, g, b = OF.util.gold().r, OF.util.gold().g, OF.util.gold().b
        end
        if place > scores then r, g, b = 150, 150, 150 end
        OF.util.text(text, (screenWidth - widest) * 0.5,
            listTop + (place - 1) * lineHeight, rowScale, r, g, b, 255)
    end
end

local function render()
    local phase, _ = night.state()
    if phase ~= night.WARMUP and phase ~= night.BREAK and phase ~= night.BOARD then
        return
    end

    if OF.util.menu_has_screen() then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    if phase == night.BOARD then
        render_board()
        return
    end

    local text = night.phase_text()
    if text == "" then return end

    local under = {}
    local coming = night.coming_up()
    if #coming > 0 then
        table.insert(under, { text = OF.lang.fill("Coming up: @",
            table.concat(coming, ", ")) })
    end

    local _, at, blocks = night.progress()
    if blocks > 1 and at > 0 then
        table.insert(under, { text = OF.lang.fill("Block @ of @",
            tostring(at), tostring(blocks)), scale = 0.7 })
    end

    OF.util.banner(text, 1.1, OF.util.gold().r, OF.util.gold().g, OF.util.gold().b,
        255, #under > 0 and { under = under } or nil)
end

hook_event(HOOK_ON_HUD_RENDER, render)

function night.is_on()
    local phase = night.state()
    return phase ~= night.OFF
end
