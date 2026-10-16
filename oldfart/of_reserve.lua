OF = OF or {}
OF.reserve = OF.reserve or {}

local reserve = OF.reserve

local WAIT = 15

local MOST = 8

local pending = {}

local function here_area()
    local me = gNetworkPlayers[0]
    if me == nil then return -1 end
    return me.currAreaIndex or -1
end

reserve.served = reserve.served or 0

function reserve.waiting()
    return #pending
end

local function snapshot(obj)
    if obj == nil then return nil end
    if obj.oPosX == nil or obj.oPosY == nil or obj.oPosZ == nil then return nil end

    local isKey = OF.util.optional("obj_has_behavior_id", 0, obj, id_bhvBowserKey) ~= 0

    return {
        wait = WAIT,
        x = obj.oPosX,
        y = obj.oPosY,
        z = obj.oPosZ,

        params = obj.oBehParams or 0,
        key = isKey,
    }
end

local blocked = nil

local SAME_SPOT = 150

local WALKED_AWAY = 320

local SIGN_FRAMES = 150

local function stand_back(entry)

    blocked = { x = entry.x, y = entry.y, z = entry.z,
        sign = WAIT + SIGN_FRAMES, told = false }
end

local function near(x, y, z, radius)
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return false end
    local dx, dy, dz = m.pos.x - x, m.pos.y - y, m.pos.z - z
    return (dx * dx + dy * dy + dz * dz) <= (radius * radius)
end

hook_event(HOOK_UPDATE, function()
    if blocked == nil then return end
    if not near(blocked.x, blocked.y, blocked.z, WALKED_AWAY) then
        blocked = nil
        return
    end
    if blocked.sign > 0 then blocked.sign = blocked.sign - 1 end
end)

hook_event(HOOK_ON_LEVEL_INIT, function() blocked = nil end)

local function render_hud()
    if blocked == nil or blocked.sign <= 0 then return end
    if not near(blocked.x, blocked.y, blocked.z, SAME_SPOT) then return end
    if OF.util.menu_has_screen() then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    OF.util.banner(OF.lang.t("This one is for the others"), 0.8,
        OF.util.gold().r, OF.util.gold().g, OF.util.gold().b, nil,
        { under = { { text = OF.lang.t("Step off the spot - you already took it"),
            r = 200, g = 200, b = 200 } } })
end

hook_event(HOOK_ON_HUD_RENDER, render_hud)

hook_event(HOOK_ALLOW_INTERACT, function(m, obj, interactType)
    if interactType ~= INTERACT_STAR_OR_KEY then return end
    if m == nil or m.playerIndex ~= 0 then return end
    if blocked == nil then return end
    if obj == nil or obj.oPosX == nil then return end

    local dx = obj.oPosX - blocked.x
    local dy = (obj.oPosY or 0) - blocked.y
    local dz = (obj.oPosZ or 0) - blocked.z
    if (dx * dx + dy * dy + dz * dz) > (SAME_SPOT * SAME_SPOT) then return end

    if not blocked.told then
        blocked.told = true
        return OF.util.report(false,
            "You already took that one - step away and it is theirs.")
    end
    return false
end)

function reserve.blocked_spot()
    return blocked
end

local untilExit = {}

local UNTIL_EXIT_MOST = 8

function reserve.until_exit()
    return #untilExit
end

local function remember_until_exit(entry)
    if #untilExit >= UNTIL_EXIT_MOST then return end
    local area = here_area()
    for index = 1, #untilExit do
        local spot = untilExit[index]
        if spot.area == area then
            local dx, dy, dz = entry.x - spot.x, entry.y - spot.y,
                entry.z - spot.z

            if (dx * dx + dy * dy + dz * dz) <= (SAME_SPOT * SAME_SPOT) then
                return
            end
        end
    end
    table.insert(untilExit, { area = area, x = entry.x, y = entry.y,
        z = entry.z })
end

function reserve.put_away()
    if #untilExit == 0 then return 0 end
    local area = here_area()
    local doomed = {}

    local object = OF.util.optional("obj_get_first_with_behavior_id", nil,
        id_bhvStar)
    while object ~= nil do
        if object.oPosX ~= nil then
            for index = 1, #untilExit do
                local spot = untilExit[index]
                if spot.area == area then
                    local dx = object.oPosX - spot.x
                    local dy = (object.oPosY or 0) - spot.y
                    local dz = (object.oPosZ or 0) - spot.z
                    if (dx * dx + dy * dy + dz * dz)
                        <= (SAME_SPOT * SAME_SPOT) then
                        table.insert(doomed, object)
                        break
                    end
                end
            end
        end
        object = OF.util.optional("obj_get_next_with_same_behavior_id", nil,
            object)
    end

    for _, star in ipairs(doomed) do
        OF.util.optional("obj_mark_for_deletion", nil, star)
    end
    untilExit = {}
    return #doomed
end

hook_event(HOOK_BEFORE_WARP, function()
    reserve.put_away()
end)

function reserve.again(obj, stillNeed, leavingNow, untilLevelExit)
    if stillNeed == nil or stillNeed <= 0 then return false end
    if not leavingNow and #pending >= MOST then return false end

    local entry = snapshot(obj)
    if entry == nil then return false end
    entry.untilExit = untilLevelExit == true

    entry.need = stillNeed

    stand_back(entry)

    if leavingNow then return reserve.now(entry) end

    table.insert(pending, entry)
    return true
end

local function serve(entry)
    local behaviorId = entry.key and id_bhvBowserKey or id_bhvStar
    local modelId = entry.key and E_MODEL_BOWSER_KEY or E_MODEL_STAR

    local spawned = OF.slots.spawn_sync(
        behaviorId, modelId, entry.x, entry.y, entry.z,
        function(o)

            o.oBehParams = entry.params
        end)

    if spawned == nil then return false end
    reserve.served = reserve.served + 1

    if entry.untilExit then remember_until_exit(entry) end

    local line = entry.key
        and "A Bowser key is back where it was taken. Still needed by @."
        or "A star is back where it was taken. Still needed by @."
    OF.notify.show(line, "info", 5, tostring(entry.need or 0))
    return true
end

function reserve.tick()
    if #pending == 0 then return end

    for i = #pending, 1, -1 do
        local entry = pending[i]
        entry.wait = entry.wait - 1
        if entry.wait <= 0 then
            table.remove(pending, i)
            serve(entry)
        end
    end
end

function reserve.now(entry)
    if entry == nil then return false end
    return serve(entry)
end

local function servable_coin(obj)
    if obj == nil then return false end
    if obj.oPosX == nil or obj.oPosY == nil or obj.oPosZ == nil then return false end
    if OF.util.optional("obj_has_behavior_id", 0, obj, id_bhvYellowCoin) == 0 then
        return false
    end
    return obj.oDamageOrCoinValue == 1
end

local COIN_SPOT = 30

local COIN_MOST = 24

local COIN_SPOTS_MAX = 400

local pendingCoins = {}
local coinSpots = {}

local coinTold = false

reserve.coinsServed = reserve.coinsServed or 0

function reserve.coins_waiting()
    return #pendingCoins
end

function reserve.coin_spots()
    return #coinSpots
end

local function spot_taken(area, x, y, z)
    for index = 1, #coinSpots do
        local spot = coinSpots[index]
        if spot.area == area then
            local dx, dy, dz = x - spot.x, y - spot.y, z - spot.z
            if (dx * dx + dy * dy + dz * dz) <= (COIN_SPOT * COIN_SPOT) then
                return true
            end
        end
    end
    return false
end

function reserve.coin_again(obj, stillNeed)
    if stillNeed == nil or stillNeed <= 0 then return false end
    if not servable_coin(obj) then return false end
    if #pendingCoins >= COIN_MOST then return false end
    if #coinSpots >= COIN_SPOTS_MAX then return false end

    local area = here_area()
    local x, y, z = obj.oPosX, obj.oPosY, obj.oPosZ

    if spot_taken(area, x, y, z) then return false end

    table.insert(coinSpots, { area = area, x = x, y = y, z = z })
    table.insert(pendingCoins, { wait = WAIT, area = area, x = x, y = y, z = z })
    return true
end

local function serve_coin(entry)

    local spawned = OF.util.optional("spawn_sync_object", nil,
        id_bhvYellowCoin, E_MODEL_YELLOW_COIN, entry.x, entry.y, entry.z,
        function(_) end)
    if spawned == nil then return false end
    reserve.coinsServed = reserve.coinsServed + 1

    return true
end

local function coin_tick()
    if #pendingCoins == 0 then return end

    for index = #pendingCoins, 1, -1 do
        local entry = pendingCoins[index]
        entry.wait = entry.wait - 1
        if entry.wait <= 0 then
            table.remove(pendingCoins, index)
            serve_coin(entry)
        end
    end
end

hook_event(HOOK_ALLOW_INTERACT, function(m, obj, interactType)
    if interactType ~= INTERACT_COIN then return end
    if m == nil or m.playerIndex ~= 0 then return end
    if #coinSpots == 0 then return end

    if not servable_coin(obj) then return end
    if not spot_taken(here_area(), obj.oPosX, obj.oPosY or 0, obj.oPosZ or 0) then
        return
    end

    if not coinTold then
        coinTold = true
        return OF.util.report(false,
            "You already took that coin - it is back for the others.")
    end
    return false
end)

function reserve.forget()
    pending = {}
    pendingCoins = {}
    coinSpots = {}
    coinTold = false
    untilExit = {}
end

hook_event(HOOK_UPDATE, function()
    reserve.tick()
    coin_tick()
end)
hook_event(HOOK_ON_LEVEL_INIT, function() reserve.forget() end)
