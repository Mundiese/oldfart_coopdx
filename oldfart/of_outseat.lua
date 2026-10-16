OF = OF or {}
OF.outseat = OF.outseat or {}

local outseat = OF.outseat

outseat.OWN_SEAT = {

    sumo = true,

    simon = true,

    hexheat = true,

    logroll = true,

    laststanding = true,
    oitc = true,

    hotpotato = true,

    greendemon = true,

    snd = true,

}

function outseat.offers(key)
    local modes = OF.gamemodes
    if modes == nil or modes.when_out == nil then return false end

    if key == nil then
        local mode = modes.current()
        if mode == nil then return false end
        key = mode.key
    end
    if type(key) ~= "string" then return false end

    local row = modes.when_out(key)
    if row == nil or row.out == "none" then return false end
    if outseat.OWN_SEAT[key] == true then return false end

    return OF.util.asks(OF.spectate, "start")
        and OF.util.asks(OF.spectate, "watchable")
end

local seated = false

local offered = false

local function still_in()
    local list = {}
    for _, globalIndex in ipairs(OF.spectate.watchable()) do
        local li = OF.util.local_from_global(globalIndex)
        if li ~= nil and not OF.gamemodes.is_out(li)
            and OF.gamemodes.can_play(li) then
            local role = OF.gamemodes.role(li)
            if role ~= "" and role ~= OF.gamemodes.WAITING then
                table.insert(list, { globalIndex = globalIndex, localIndex = li })
            end
        end
    end
    return list
end

local function best_seat()
    local best, bestNear = nil, nil
    for _, entry in ipairs(still_in()) do
        local near = OF.gamemodes.distance(0, entry.localIndex) or math.huge
        if best == nil or near < bestNear
            or (near == bestNear and entry.localIndex < best.localIndex) then
            best, bestNear = entry, near
        end
    end
    if best == nil then return nil end
    return best.globalIndex
end

outseat.COMMAND = "sitout"
function outseat.sitting_out()
    return OF.util.asks(OF.speedrun, "is_excluded")
        and OF.speedrun.is_excluded(0, OF.speedrun.KIND_MODE)
end

function outseat.set_sitting_out(on)
    if not OF.util.asks(OF.speedrun, "set_excluded") then
        return false, "Sitting out is not available in this build."
    end

    return OF.speedrun.set_excluded(0, on == true, OF.speedrun.KIND_MODE)
end

function outseat.reset_mine()
    if not outseat.sitting_out() then return false end
    return outseat.set_sitting_out(false) == true
end

function outseat.toggle()
    return outseat.set_sitting_out(not outseat.sitting_out())
end

local wasLate = false
local roaming = false

local function late_here()
    local modes = OF.gamemodes
    local state = modes.state()
    if state == modes.OFF then
        wasLate, roaming = false, false
        return false
    end
    if OF.util.asks(modes, "left_out_of_this_round")
        and modes.left_out_of_this_round(0) then
        wasLate = true
    elseif state == modes.COUNTDOWN or state == modes.LOBBY or modes.is_waiting() then

        wasLate, roaming = false, false
    end
    return wasLate
end

function outseat.roaming()
    return roaming and late_here()
end

local function still_out()
    local modes = OF.gamemodes
    if modes.state() == modes.OFF then return false end

    if outseat.sitting_out() then return false end

    if late_here() then return not roaming end
    if not outseat.offers() then return false end
    if modes.is_over() then return modes.survived(0) == false end
    return modes.is_out(0)
end

local function watching()
    return OF.util.asks(OF.spectate, "is_active") and OF.spectate.is_active()
end

local function make_the_offer()
    if offered then return end
    offered = true

    if outseat.line() ~= nil then return end
    local leave = outseat.leave_name()
    if late_here() then
        OF.notify.show("Round on - D-pad left watches, @ plays elsewhere",
            "info", 8, leave)
    elseif outseat.offers() then
        OF.notify.show("D-pad left watches the rest - @ leaves the run",
            "info", 8, leave)
    else
        OF.notify.show("@ leaves the run and you play on your own", "info", 8, leave)
    end
end

local function press(m)
    if OF.util.menu_has_screen() then return end

    OF.input.poll(m)
    if not OF.input.pressed(L_JPAD) then return end

    if watching() then

        if not seated then return end
        OF.spectate.stop()
        seated = false
        return
    end

    local seat = best_seat()
    if seat == nil then

        OF.util.report(false, "There is nobody left to watch.")
        return
    end
    seated = OF.spectate.start(seat) == true
end

local function give_it_back()
    if not seated then return end
    seated = false
    if OF.util.asks(OF.spectate, "stop") then OF.spectate.stop() end
end

function outseat.leave_button()
    local input = OF.input
    if input == nil or type(input.OPEN_BUTTONS) ~= "table" then return nil, nil end
    local opener = OF.util.asks(input, "opener") and input.opener() or nil
    local wheel = OF.util.asks(input, "wheel_button") and input.wheel_button() or nil
    for _, entry in ipairs(input.OPEN_BUTTONS) do
        if entry.button ~= opener and entry.button ~= wheel then
            return entry.button, entry.name
        end
    end
    return nil, nil
end

function outseat.leave_name()
    local _, name = outseat.leave_button()
    return name or ("/" .. outseat.COMMAND)
end

function outseat.choosing()
    local modes = OF.gamemodes
    if modes == nil or modes.state() ~= modes.ACTIVE then return false end
    if outseat.sitting_out() then return false end
    if late_here() then return not roaming end
    return modes.is_out(0)
end

function outseat.leave()
    if not outseat.choosing() then return false, "There is no round to leave." end
    if watching() and OF.util.asks(OF.spectate, "can_stop")
        and OF.spectate.can_stop() then
        OF.spectate.stop()
    end
    seated = false
    if late_here() then
        roaming = true
        OF.notify.show("You play on your own until the next round", "info", 6)
        return true
    end
    return outseat.set_sitting_out(true)
end

outseat.WALK_EVERY = 150

local walkWait = 0
local walkSaid = false

function outseat.in_round_room(level)
    local modes = OF.gamemodes
    if modes == nil or modes.state() == modes.OFF then return false end
    local mode = modes.current()
    if mode ~= nil and mode.wholeGame then return nil end
    local place = modes.round_place()
    if place == nil then return nil end
    if level == nil then
        local np = gNetworkPlayers[0]
        if np == nil then return nil end
        level = np.currLevelNum
    end

    if OF.util.asks(OF.roundact, "separates") and OF.roundact.separates(level) then
        return false
    end
    if level == place.level then return true end
    local also = place.also
    if OF.util.asks(OF.lockdown, "castle_also") then
        also = OF.lockdown.castle_also(mode ~= nil and mode.key or nil,
            place.level, place.also)
    end
    for _, other in ipairs(also or {}) do
        if other == level then return true end
    end
    return false
end

function outseat.free_of_the_round()
    local modes = OF.gamemodes
    if modes == nil or modes.state() == modes.OFF then return false end
    if OF.util.asks(OF.speedrun, "is_running") and OF.speedrun.is_running() then
        return false
    end
    if outseat.sitting_out() then return true end
    return roaming and late_here()
end

function outseat.plays_free()
    if not outseat.free_of_the_round() then return false end
    if watching() then return false end
    return outseat.in_round_room() == false
end

function outseat.way_out()

    local back = OF.util.asks(OF.gamemodes, "lobby_way_back")
        and OF.gamemodes.lobby_way_back() or nil
    if back ~= nil then return back end
    local ways = {
        { level = LEVEL_CASTLE_GROUNDS, area = 1 },
        { level = LEVEL_CASTLE, area = 1 },
        { level = LEVEL_CASTLE_COURTYARD, area = 1 },
        { level = LEVEL_BOB, area = 1 },
    }
    for _, way in ipairs(ways) do
        if way.level ~= nil and outseat.in_round_room(way.level) == false then
            return way
        end
    end
    return nil
end

local function keep_out()
    if not outseat.free_of_the_round() then
        walkWait, walkSaid = 0, false
        return
    end

    if outseat.plays_free() then return end
    if watching() then return end
    if outseat.in_round_room() ~= true then return end
    local np = gNetworkPlayers[0]
    if np == nil or not np.currAreaSyncValid then return end

    if OF.util.asks(OF.roundact, "has_copy") and OF.roundact.has_copy(np.currLevelNum) then
        walkWait, walkSaid = 0, false
        return
    end
    if walkWait > 0 then
        walkWait = walkWait - 1
        return
    end
    walkWait = outseat.WALK_EVERY
    local way = outseat.way_out()
    if way == nil then return end
    if not walkSaid then
        walkSaid = true
        OF.notify.show("A round is being played here - you are walked out of it",
            "info", 6)
    end
    warp_to_level(way.level, way.area, 0)
end

local function choice_step(m)
    local modes = OF.gamemodes
    local state = modes.state()

    if state == modes.OFF or state == modes.COUNTDOWN or state == modes.LOBBY then
        offered = false
    end
    if not outseat.choosing() then return end
    make_the_offer()
    if OF.util.menu_has_screen() then return end
    local button = outseat.leave_button()
    if button == nil then return end
    OF.input.poll(m)
    if OF.input.pressed(button) then OF.util.report(outseat.leave()) end
end

local function step(m)
    if m == nil or m.playerIndex ~= 0 then return end

    keep_out()
    choice_step(m)

    if not still_out() then
        give_it_back()
        return
    end

    if not watching() then seated = false end

    press(m)
end

local function rounds_ahead()
    local modes = OF.gamemodes
    if modes.state() ~= modes.OFF then return true end
    if OF.util.asks(modes, "nonstop") and modes.nonstop() then return true end
    return OF.util.asks(OF.rounds, "is_running") and OF.rounds.is_running()
end

function outseat.line()
    local modes = OF.gamemodes
    if modes == nil then return nil end
    if outseat.sitting_out() then
        if not rounds_ahead() then return nil end

        if OF.speedrun.muted_out(0) then
            return OF.lang.t("You are muted and sit rounds out")
        end
        return OF.lang.fill("You are sitting rounds out - /@ to play",
            outseat.COMMAND)
    end
    if outseat.roaming() then
        return OF.lang.t("You play on your own until the next round")
    end
    if not outseat.choosing() then return nil end

    if watching() then return nil end
    local leave = outseat.leave_name()
    if late_here() then
        return OF.lang.fill("D-pad left to watch - @ to play on your own", leave)
    end
    if outseat.offers() and best_seat() ~= nil then
        return OF.lang.fill("D-pad left to watch - @ to leave the run", leave)
    end
    return OF.lang.fill("@ to leave the run", leave)
end

function outseat.leave_hint()
    if not outseat.choosing() then return nil end
    if late_here() then
        return OF.lang.fill("@   -   Play on your own", outseat.leave_name())
    end
    return OF.lang.fill("@   -   Leave the run", outseat.leave_name())
end

local function render()
    if OF.util.menu_has_screen() then return end
    local text = outseat.line()
    if text == nil then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)
    OF.util.banner_low(text, 0.7, 200, 200, 200, 255)
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, step, OF.LOCAL_MARIO)
hook_event(HOOK_ON_HUD_RENDER, render)

hook_chat_command("sitout",
    "- sit the next rounds out, or join in again", function()
        return OF.util.report(outseat.toggle())
    end)
