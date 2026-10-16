OF = OF or {}
OF.corpse = OF.corpse or {}

local corpse = OF.corpse

corpse.KEY = "ofCorpse"
corpse.ACTION = "corpse"
corpse.CLEAR_ACTION = "corpseclear"
corpse.PRESS_ACTION = "corpsepress"
corpse.MODE_FOUND = 1
corpse.MODE_TAKE = 2

corpse.STOPS = {

    { key = "fade",  name = "it fades",                life = 900, find = false, many = false },
    { key = "stay",  name = "it stays",                life = 0,   find = false, many = false },
    { key = "find",  name = "somebody has to find it", life = 0,   find = true,  many = false },
    { key = "grave", name = "they stack up",           life = 0,   find = true,  many = true  },
}

corpse.REACH = 200

corpse.BEAM_HEIGHT = 1000
corpse.BEAM_WIDTH = 4

corpse.CEILING = 64

local SEAT_FIELD = "oBehParams2ndByte"
local ANIM_FIELD = "oAction"
local COIN_FIELD = "oHealth"
local FOUND_FIELD = "oSubAction"
local CARRIED_FIELD = "oDamageOrCoinValue"
corpse.BEHAVIOUR = nil

local prompted = false

corpse.DROP_WINDOW = 90
local carryEcho = 0

local function stop_at(key)
    if key == nil or key == "" then return nil end
    for _, entry in ipairs(corpse.STOPS) do
        if entry.key == key then return entry end
    end
    return nil
end

corpse.stop_at = stop_at

function corpse.stop()
    return stop_at(gGlobalSyncTable[corpse.KEY])
end

function corpse.on()
    return corpse.stop() ~= nil
end

function corpse.label()
    local entry = corpse.stop()
    if entry == nil then return nil end
    return entry.name
end

function corpse.round_holds()
    return OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down()
end

function corpse.in_force()
    if corpse.round_holds() then return nil end
    return corpse.stop()
end

function corpse.can_ask_host()
    if OF.util.is_host() then return true end
    if not OF.util.asks(OF.net, "host_does") then return false end
    local seat = OF.util.local_from_global(0)
    return seat ~= nil and seat > 0
end

function corpse.reset_options()
    local was = gGlobalSyncTable[corpse.KEY]
    if not OF.util.is_host() or was == nil or was == "" then return false end
    return corpse.set("", 0) == true
end

function corpse.set(key, askerLocal)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end

    if key == nil then key = "" end
    key = tostring(key)
    if key ~= "" and stop_at(key) == nil then
        return false, "No such setting."
    end

    if not OF.util.is_host() then
        if OF.util.asks(OF.net, "host_does") then
            return OF.net.host_does(corpse.ACTION, key)
        end
        return false, "No host to ask yet - try again in a second."
    end

    local was = gGlobalSyncTable[corpse.KEY]
    if was == key or (was == nil and key == "") then
        return false, "That is already the setting."
    end

    if key == "" then
        OF.util.publish(corpse.KEY, nil)

        corpse.sweep()
        OF.notify.send_all("Bodies are gone", "info", 4)
    else
        OF.util.publish(corpse.KEY, key)

        if not stop_at(key).many then corpse.sweep() end
        OF.notify.send_all("A body where you died: @", "info", 5,
            OF.lang.t(stop_at(key).name))
    end

    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
        OF.notify.credit_named(askerLocal, OF.lang.t("what a death leaves"))
    end
    if OF.util.asks(OF.actionlog, "by_hand") then
        OF.actionlog.by_hand(OF.util.presser(askerLocal),
            OF.lang.fill("set what a death leaves: @",
                key == "" and OF.lang.t("nothing") or OF.lang.t(stop_at(key).name)))
    end
    return true
end

function corpse.cycle(askerLocal)
    local now = gGlobalSyncTable[corpse.KEY]
    local at = 0
    for index, entry in ipairs(corpse.STOPS) do
        if entry.key == now then at = index end
    end
    at = at + 1
    if at > #corpse.STOPS then return corpse.set("", askerLocal) end
    return corpse.set(corpse.STOPS[at].key, askerLocal)
end

function corpse.each()
    local list = {}
    if corpse.BEHAVIOUR == nil then return list end
    local o = obj_get_first_with_behavior_id(corpse.BEHAVIOUR)
    while o ~= nil do
        if o.activeFlags ~= 0 then list[#list + 1] = o end
        o = obj_get_next_with_same_behavior_id(o)
    end
    return list
end

function corpse.count()
    return #corpse.each()
end

local function drop(o)
    if o == nil then return false end
    if o.activeFlags == 0 then return false end
    obj_mark_for_deletion(o)
    return true
end

function corpse.sweep()

    if OF.util.asks(OF.persist, "forget_kind") and corpse.BEHAVIOUR ~= nil then
        OF.persist.forget_kind(corpse.BEHAVIOUR)
    end

    local gone = 0
    for _, o in ipairs(corpse.each()) do
        if drop(o) then gone = gone + 1 end
    end
    return gone
end

function corpse.clear(askerLocal)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    if not OF.util.is_host() then
        if OF.util.asks(OF.net, "host_does") then
            return OF.net.host_does(corpse.CLEAR_ACTION, "")
        end
        return false, "No host to ask yet - try again in a second."
    end

    local here = corpse.count()
    if here <= 0 then return false, "There is nothing here to clear." end

    corpse.sweep()
    if OF.util.asks(OF.util, "tell_all") then
        OF.util.tell_all({ ofp = corpse.CLEAR_ACTION })
    end
    OF.notify.send_all("The graveyard is cleared", "info", 4)
    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
        OF.notify.credit_named(askerLocal, OF.lang.t("cleared the graveyard"))
    end
    return true
end

local function body_init(o)
    if o == nil then return end

    o.oInteractType = 0
    o.oIntangibleTimer = -1
    o.oCollisionDistance = 0

    o.oFlags = OF.util.add_flag(o.oFlags or 0, OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE or 1)

    o.oGravity = 4.0
    o.oBounciness = 0.0
    o.oBuoyancy = 1.1
    o.oDragStrength = 10.0
    o.oForwardVel = 0.0

    local anim = OF.util.optional("get_mario_vanilla_animation", nil,
        o[ANIM_FIELD])
    if anim ~= nil and o.header ~= nil and o.header.gfx ~= nil
        and o.header.gfx.animInfo ~= nil then
        local info = o.header.gfx.animInfo
        info.curAnim = anim
        info.animID = o[ANIM_FIELD]
        info.animAccel = 0

        info.animYTrans = 0xBD

        local last = (tonumber(anim.loopEnd) or 1) - 1
        if last < 0 then last = 0 end
        info.animFrame = last
        info.animFrameAccelAssist = last * 0x10000

        local node = o.header.gfx.node
        if node ~= nil then
            local flags = tonumber(node.flags) or 0
            if (flags & GRAPH_RENDER_HAS_ANIMATION) ~= 0 then
                node.flags = flags - GRAPH_RENDER_HAS_ANIMATION
            end
        end
    end

    o.globalPlayerIndex = o[SEAT_FIELD]

    o.hookRender = 1
end

function corpse.owner_away(localIndex)
    if localIndex == nil or localIndex == 0 then return false end
    local np, me = gNetworkPlayers[localIndex], gNetworkPlayers[0]
    if np == nil or me == nil or not np.connected then return true end
    return np.currLevelNum ~= me.currLevelNum or np.currAreaIndex ~= me.currAreaIndex
        or np.currActNum ~= me.currActNum or np.currCourseNum ~= me.currCourseNum
end

corpse.EYES = MARIO_EYES_DEAD or 8
local eyesHeld = {}
local function tick()
    return type(get_global_timer) == "function" and get_global_timer() or 0
end

function corpse.eyes_back()
    local now = tick()
    for k = #eyesHeld, 1, -1 do
        local held = eyesHeld[k]
        if held.at == now and held.body.eyeState == corpse.EYES then
            held.body.eyeState = held.was
        end
        eyesHeld[k] = nil
    end
end
function corpse.body_render(o)
    if o == nil or corpse.BEHAVIOUR == nil then return false end
    if obj_has_behavior_id(o, corpse.BEHAVIOUR) == 0 then return false end
    local li = OF.util.local_from_global(o.globalPlayerIndex)
    local m = li ~= nil and gMarioStates[li] or nil
    local body = m ~= nil and m.marioBodyState or nil
    if body ~= nil and body.eyeState ~= corpse.EYES then
        eyesHeld[#eyesHeld + 1] = { body = body, was = body.eyeState, at = tick() }
        body.eyeState = corpse.EYES
    end
    if not corpse.owner_away(li) then return false end
    if body == nil then return false end
    local state = tonumber(body.modelState) or 0
    if not OF.util.has_flag(state, 0x100) then return false end
    body.modelState = state - state % 0x200
    return true
end

local function body_loop(o)
    if o == nil then return end

    local entry = corpse.stop()

    if entry == nil then
        drop(o)
        return
    end

    if entry.life > 0 and o.oTimer > entry.life then
        drop(o)
        return
    end

    object_step()

    cur_obj_update_floor()
    local floor = o.oFloor
    if floor ~= nil and floor.object ~= nil then
        apply_platform_displacement(o, floor.object)
    end
end

corpse.QUIET = 60
corpse.lastDeath = nil
function corpse.leave(m)
    if m == nil or m.marioObj == nil then return false end
    if m.playerIndex ~= 0 then return false end

    local now = get_global_timer()
    local last = corpse.lastDeath
    corpse.lastDeath = now
    if last ~= nil and now - last <= corpse.QUIET and now >= last then return false end

    local entry = corpse.in_force()
    if entry == nil then return false end
    if corpse.BEHAVIOUR == nil then return false end

    local mine = network_global_index_from_local(0)
    local standing = corpse.each()
    if not entry.many then
        for _, old in ipairs(standing) do
            if old[SEAT_FIELD] == mine then drop(old) end
        end
    elseif #standing >= corpse.CEILING then
        drop(standing[1])
    end

    local model = OF.util.optional("obj_get_model_id_extended", nil, m.marioObj)
    if model == nil then return false end

    local animId = 0
    if m.marioObj.header ~= nil and m.marioObj.header.gfx ~= nil then
        animId = tonumber(m.marioObj.header.gfx.animInfo.animID) or 0
    end
    local coins = tonumber(m.numCoins) or 0
    if coins < 0 then coins = 0 end

    local carried = (m.heldObj ~= nil or carryEcho > 0) and 1 or 0

    local made = OF.slots.spawn_lobby(
        corpse.BEHAVIOUR, model, m.pos.x, m.pos.y, m.pos.z,
        function(o)
            o[SEAT_FIELD] = mine
            o[ANIM_FIELD] = animId
            o[COIN_FIELD] = coins
            o[FOUND_FIELD] = 0
            o[CARRIED_FIELD] = carried
            o.oMoveAngleYaw = m.faceAngle.y
            o.oFaceAngleYaw = m.faceAngle.y

            o.oAnimState = 0
            o.globalPlayerIndex = mine
        end)

    if made == nil then return false end

    if entry.life <= 0 and OF.util.asks(OF.persist, "remember") then
        OF.persist.remember(corpse.BEHAVIOUR, made,
            { uniq = (not entry.many) and mine or nil, model = model })
    end
    return true
end

function corpse.nearest(m)
    if m == nil then return nil end
    if corpse.BEHAVIOUR == nil then return nil end
    local best, bestDist = nil, nil
    local o = obj_get_first_with_behavior_id(corpse.BEHAVIOUR)
    while o ~= nil do
        if o.activeFlags ~= 0 and o[FOUND_FIELD] == 0 then
            local dx = o.oPosX - m.pos.x
            local dy = o.oPosY - m.pos.y
            local dz = o.oPosZ - m.pos.z
            local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
            if bestDist == nil or dist < bestDist then best, bestDist = o, dist end
        end
        o = obj_get_next_with_same_behavior_id(o)
    end
    if best == nil or bestDist > corpse.REACH then return nil end
    return best, bestDist
end

local function body_with_sync_id(syncId)
    syncId = tonumber(syncId)
    if syncId == nil then return nil end
    for _, o in ipairs(corpse.each()) do
        if o.oSyncID == syncId then return o end
    end
    return nil
end

local function name_of(globalIndex)
    local seat = OF.util.local_from_global(globalIndex)
    if seat == nil then return nil end
    local np = gNetworkPlayers[seat]
    if np == nil or np.name == nil or np.name == "" then return nil end
    return OF.util.plain(np.name)
end

corpse.name_of = name_of

function corpse.announce(whoseGlobal, finderGlobal, rest)
    local finder = name_of(finderGlobal)
    local whose = name_of(whoseGlobal)
    local where = OF.util.level_name(gNetworkPlayers[0].currLevelNum,
        gNetworkPlayers[0].currAreaIndex)

    if finder ~= nil and whose ~= nil then
        OF.util.chat(OF.lang.fill("@ found @'s body", finder, whose))
    elseif whose ~= nil then
        OF.util.chat(OF.lang.fill("@'s body has been found", whose))
    else
        OF.util.chat(OF.lang.t("A body has been found."))
    end

    rest = tonumber(rest) or 0
    if rest > 0 then
        OF.util.chat(OF.lang.fill("In @ - @ body(s) still here",
            where, tostring(rest)))
    else
        OF.util.chat(OF.lang.fill("In @ - and that was the last one here",
            where))
    end
end

function corpse.host_press(askerLocal, syncId, mode)
    if not OF.util.is_host() then return false, "Only the host." end

    local o = body_with_sync_id(syncId)
    if o == nil then return false, "That body is gone." end

    if o[FOUND_FIELD] ~= 0 then return false, "That one is already reported." end
    o[FOUND_FIELD] = 1

    local finderGlobal = network_global_index_from_local(askerLocal or 0)
    mode = tonumber(mode) or corpse.MODE_FOUND

    if mode == corpse.MODE_TAKE then
        if o[SEAT_FIELD] ~= finderGlobal then
            return false, "That body is not yours."
        end
        drop(o)
        if OF.util.asks(OF.util, "tell_all") then
            OF.util.tell_all({ ofp = corpse.PRESS_ACTION, i = syncId,
                               q = corpse.MODE_TAKE })
        end
        return true
    end

    local whose = o[SEAT_FIELD]
    drop(o)
    local rest = corpse.count()
    corpse.announce(whose, finderGlobal, rest)
    if OF.util.asks(OF.util, "tell_all") then
        OF.util.tell_all({ ofp = corpse.PRESS_ACTION, i = syncId,
                           q = corpse.MODE_FOUND, w = whose, f = finderGlobal,
                           n = rest })
    end
    return true
end

function corpse.press(m)
    if m == nil then return false end

    if not OF.perms.can("corpse_find") then
        return false, "Your rank cannot do that.", "corpse_find"
    end
    local entry = corpse.in_force()
    if entry == nil or not entry.find then return false end

    local o = corpse.nearest(m)
    if o == nil then return false, "There is no body within reach." end

    local mine = network_global_index_from_local(0)
    if o[SEAT_FIELD] == mine then
        local coins = tonumber(o[COIN_FIELD]) or 0

        o[FOUND_FIELD] = 1

        if coins > 0 then
            m.numCoins = (tonumber(m.numCoins) or 0) + coins
            if OF.util.asks(OF.notify, "show") then
                OF.notify.show("Taken back off your own body: @ coin(s)",
                    "good", 4, coins)
            end
        elseif OF.util.asks(OF.notify, "show") then
            OF.notify.show("Your body had nothing on it", "info", 3)
        end
        return corpse.ask_host(o, corpse.MODE_TAKE)
    end

    return corpse.ask_host(o, corpse.MODE_FOUND)
end

function corpse.ask_host(o, mode)
    if o == nil then return false end
    if not OF.util.asks(OF.net, "host_does") then
        return false, "No host to ask yet - try again in a second."
    end
    return OF.net.host_does(corpse.PRESS_ACTION, o.oSyncID, mode)
end

local function watch(m)
    if m == nil or m.playerIndex ~= 0 then return end

    if m.heldObj ~= nil then
        carryEcho = corpse.DROP_WINDOW
    elseif carryEcho > 0 then
        carryEcho = carryEcho - 1
    end

    local entry = corpse.in_force()
    if entry == nil or not entry.find then
        prompted = false
        return
    end

    local near = corpse.nearest(m)
    if near == nil then
        prompted = false
        return
    end

    if not prompted then
        prompted = true
        if OF.util.asks(OF.notify, "show") then
            OF.notify.show("A body - D-pad up", "info", 3)
        end
    end

    if OF.util.asks(OF.input, "blocked") and OF.input.blocked() then return end

    if OF.util.menu_has_screen() then return end
    if not OF.util.asks(OF.input, "pressed") then return end
    if OF.input.pressed(U_JPAD) then OF.util.report(corpse.press(m)) end
end

corpse.watch = watch

function corpse.left_something(o)
    if o == nil then return false end
    return (tonumber(o[CARRIED_FIELD]) or 0) == 1
end

corpse.beamsDrawn = 0

local function render_beams()
    corpse.beamsDrawn = 0
    if corpse.BEHAVIOUR == nil then return end
    if OF.util.menu_has_screen() then return end
    if corpse.in_force() == nil then return end

    if not OF.util.asks(OF.util, "world_beam") then return end

    local gold = OF.util.gold()
    local o = obj_get_first_with_behavior_id(corpse.BEHAVIOUR)
    local at = { x = 0, y = 0, z = 0 }
    while o ~= nil do
        if o.activeFlags ~= 0 and corpse.left_something(o) then
            at.x, at.y, at.z = o.oPosX, o.oPosY, o.oPosZ
            if OF.util.world_beam(at, corpse.BEAM_HEIGHT, corpse.BEAM_WIDTH,
                gold.r, gold.g, gold.b, 170) then
                corpse.beamsDrawn = corpse.beamsDrawn + 1
            end
        end
        o = obj_get_next_with_same_behavior_id(o)
    end
end

corpse.render_beams = render_beams

function corpse.build_rows(panel)
    local rows = {}

    if not corpse.can_ask_host() then
        table.insert(rows, panel.label_row(
            OF.lang.t("Waiting for the host - this is the host's to set.")))
    end

    local on = corpse.on()
    local r, g, b = 255, 255, 255
    if on then r, g, b = OF.util.gold().r, OF.util.gold().g, OF.util.gold().b end

    local switch = panel.with_help(panel.gated_row("speedrun",
        panel.tick(on, OF.lang.t("A body where you died")), r, g, b,

        function() OF.util.report(corpse.cycle(0)) end),
        OF.lang.t("leaves a body where you died - it fades, it stays, or somebody has to find it"))
    switch = panel.level_right(switch, on, corpse.label())
    local at = 0
    local now = gGlobalSyncTable[corpse.KEY]
    for index, entry in ipairs(corpse.STOPS) do
        if entry.key == now then at = index end
    end
    if OF.util.asks(panel, "with_slider") then
        switch = panel.with_slider(switch, at, #corpse.STOPS,
            panel.may("speedrun") and function(wanted)
                local entry = corpse.STOPS[wanted]
                OF.util.report(corpse.set(entry ~= nil and entry.key or "", 0))
            end or nil)
    end
    table.insert(rows, switch)

    local entry = corpse.stop()

    if entry ~= nil then
        table.insert(rows, panel.label_row(OF.lang.t(
            "A light stands where somebody died holding something.")))
    end

    if entry ~= nil and entry.find then
        table.insert(rows, panel.label_row(OF.lang.t(
            "Stand within 200 of one and press D-pad up to report it.")))
        table.insert(rows, panel.label_row(OF.lang.t(
            "Your own gives back the coins the death cost you.")))
    end

    if entry ~= nil and entry.many then
        local here = panel.label_row(OF.lang.fill("Here now: @ of @",
            tostring(corpse.count()), tostring(corpse.CEILING)))
        table.insert(rows, here)
        table.insert(rows, panel.with_help(panel.gated_row("speedrun",
            OF.lang.t("Clear the graveyard"), 255, 140, 90,
            function() OF.util.report(corpse.clear(0)) end),
            OF.lang.t("every body in this level, off every screen in the lobby")))
    end

    return rows
end

if type(hook_behavior) == "function" then
    corpse.BEHAVIOUR = hook_behavior(nil, OBJ_LIST_UNIMPORTANT, false,
        body_init, body_loop, "of body")
end

hook_event(HOOK_ON_DEATH, function(m)
    corpse.leave(m)
end)

hook_event(HOOK_MARIO_UPDATE, watch, OF.LOCAL_MARIO)
hook_event(HOOK_ON_OBJECT_RENDER, corpse.body_render)

hook_event(HOOK_ON_HUD_RENDER, function()
    corpse.eyes_back()
    render_beams()
end)

hook_event(HOOK_ON_LEVEL_INIT, function() prompted = false carryEcho = 0 end)
hook_event(HOOK_ON_SYNC_VALID, function() prompted = false carryEcho = 0 end)

local function body_is_still_wanted()
    local entry = corpse.stop()
    return entry ~= nil and entry.life <= 0
end

hook_event(HOOK_ON_MODS_LOADED, function()
    if corpse.BEHAVIOUR ~= nil and OF.util.asks(OF.persist, "carries") then
        OF.persist.carries(corpse.BEHAVIOUR,
            { SEAT_FIELD, ANIM_FIELD, COIN_FIELD, FOUND_FIELD, CARRIED_FIELD },
            body_is_still_wanted)
    end

    if OF.net == nil or OF.net.register_action == nil then return end

    OF.net.register_action(corpse.ACTION, "speedrun", function(asker, key)
        if not OF.util.is_host() then return false, "Only the host." end
        return corpse.set(tostring(key or ""), asker)
    end)

    OF.net.register_action(corpse.CLEAR_ACTION, "speedrun", function(asker)
        if not OF.util.is_host() then return false, "Only the host." end
        return corpse.clear(asker)
    end)

    OF.net.register_action(corpse.PRESS_ACTION, "corpse_find",
        function(asker, syncId, mode)
            return corpse.host_press(asker, syncId, mode)
        end)
end)

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if type(data) ~= "table" then return end
    if data.ofp ~= corpse.CLEAR_ACTION then return end
    if not OF.util.from_host(data) then return end
    corpse.sweep()
end)

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if type(data) ~= "table" then return end
    if data.ofp ~= corpse.PRESS_ACTION then return end
    if not OF.util.from_host(data) then return end
    local o = nil
    for _, one in ipairs(corpse.each()) do
        if one.oSyncID == tonumber(data.i) then o = one end
    end
    if o ~= nil then drop(o) end
    if tonumber(data.q) == corpse.MODE_FOUND then
        corpse.announce(data.w, data.f, data.n)
    end
end)

function corpse.ready()
    return true
end
