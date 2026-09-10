OF = OF or {}
OF.outseat = OF.outseat or {}

local outseat = OF.outseat

outseat.OWN_SEAT = {

    sumo = true,

    simon = true,

    hexheat = true,

    logroll = true,

    laststanding = true,

    hotpotato = true,

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

local function still_out()
    local modes = OF.gamemodes
    if modes.state() == modes.OFF then return false end
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
    OF.notify.show("D-pad left watches somebody still in - L and R change who",
        "info", 7)
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
    offered = false
    if not seated then return end
    seated = false
    if OF.util.asks(OF.spectate, "stop") then OF.spectate.stop() end
end

local function step(m)
    if m == nil or m.playerIndex ~= 0 then return end

    if not still_out() then
        give_it_back()
        return
    end

    if not watching() then seated = false end

    if OF.gamemodes.state() == OF.gamemodes.ACTIVE then make_the_offer() end

    press(m)
end

local function render()
    if OF.util.menu_has_screen() then return end
    if not still_out() then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if watching() then return end
    if best_seat() == nil then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)
    OF.util.banner_low(OF.lang.t("D-pad left to watch"), 0.7, 200, 200, 200, 255)
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, step)
hook_event(HOOK_ON_HUD_RENDER, render)
