OF = OF or {}

OF.PARTY_ARENAS = OF.PARTY_ARENAS or {
    "bowser1", "bowser2", "bowser3", "the_plate",
}

local ROLE_IN  = "in"
local ROLE_OUT = "out"
local CHOOSE_SECONDS = 7
local CHOOSE_FRAMES = CHOOSE_SECONDS * 30

local CHOOSE_STOPS = { seven = 7, five = 5, ten = 10 }
local function choose_seconds()
    return CHOOSE_STOPS[OF.gamemodes.option_now("choose") or "seven"] or CHOOSE_SECONDS
end

local BACKSTOP_FRAMES = 2 * 30
local BOOM_SECONDS = 3
local BOOM_FRAMES = BOOM_SECONDS * 30

local BETWEEN_FRAMES = 20

local SWITCH_FOOT = 583
local SWITCH_SCALE = 0.5
local SWITCH_CLEAR = 100
local SWITCH_GAP = math.ceil(SWITCH_FOOT * SWITCH_SCALE + SWITCH_CLEAR)
local ROW_SPREAD = SWITCH_GAP * 16

local FRONT = 350

local QUEUE_BACK = 1100
local QUEUE_GAP = 200
local QUEUE_HOLD = 60

local DROP_HEIGHT = 400

local NUMBER_LIFT = 160

local BACKSTOP_SECONDS = 5 * 60

local ROW_KEY = "ofGmBlastRow"
local SWITCH_LIFT = 71
local SWITCH_TOKEN = "blastswitch"
local BASE_TOKEN = "blastbase"
local function solid_with(mesh)
    return function(o)
        if o == nil then return end
        local data = _G["gGlobalObjectCollisionData"]
        o.collisionData = data ~= nil and data[mesh] or nil
        o.oFlags = OF.util.add_flag(tonumber(o.oFlags) or 0, OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE)
    end
end
local function solid_loop(o)
    if o ~= nil and o.collisionData ~= nil then
        OF.util.optional("load_object_collision_model", nil)
    end
end

local function hooked(mesh, name)
    if type(hook_behavior) ~= "function" then return nil end
    local ok, id = pcall(hook_behavior, nil, OBJ_LIST_SURFACE, false, solid_with(mesh), solid_loop, name)
    return ok and id or nil
end
local SWITCH_BHV = hooked("capswitch_collision_050033D0", "of roulette switch")
local BASE_BHV = hooked("capswitch_collision_05003448", "of roulette switch base")

local function switch_under(m, count, used)
    local under = m ~= nil and m.marioObj ~= nil and m.marioObj.platform or nil
    if under == nil then return nil end
    for i = 1, count do
        if not used[i] and OF.gamemodes.tokens[SWITCH_TOKEN .. i] == under then return i end
    end
    return nil
end

local DUCK_AFTER = 20
local USED_KEY = "ofGmBlastUsed"
local BOOM_KEY = "ofGmBlastBoom"
local S = {
    players = nil,
    turn = 1,
    count = 0,
    used = {},
    timer = 0,
    secs = -1,
    seen = {},
    phase = "choose",
    wait = 0,
    victim = nil,
}

local function reset_round()
    S.players = nil
    S.turn = 1
    S.count = 0
    S.used = {}
    S.timer = 0
    S.secs = -1
    S.seen = {}
    S.phase = "choose"
    S.wait = 0
    S.victim = nil
end

local rowText, rowAt = nil, nil
local function row_at()
    local text = gGlobalSyncTable[ROW_KEY]
    if type(text) ~= "string" or text == "" then return nil end
    if text ~= rowText then
        rowText = text
        local x, y, z = text:match("^(%-?[%d%.]+) (%-?[%d%.]+) (%-?[%d%.]+)$")
        rowAt = x and { x = tonumber(x), y = tonumber(y), z = tonumber(z) } or nil
    end
    return rowAt
end

local function switch_count()
    return math.floor(tonumber(gGlobalSyncTable.ofGmBlastCount) or 0)
end

local function used_list()
    local text = gGlobalSyncTable[USED_KEY]
    local out = {}
    if type(text) ~= "string" then return out end
    for i = 1, #text do out[i] = string.sub(text, i, i) == "1" end
    return out
end

local function gap_for(count)
    if count <= 1 then return 0 end
    return math.min(SWITCH_GAP, ROW_SPREAD / (count - 1))
end

local function switch_place(i, count, row)
    row = row or row_at()
    if row == nil then return nil end
    local gap = gap_for(count)
    return { x = row.x + (i - (count + 1) / 2) * gap, y = row.y, z = row.z }
end

local function front_place(row)
    return { x = row.x, y = row.y, z = row.z + FRONT }
end
local function queue_place(slot, n, row)
    return { x = row.x + (slot - (n + 1) / 2) * QUEUE_GAP, y = row.y,
             z = row.z + QUEUE_BACK }
end

local function pressers()
    local list = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_IN)) do
        if OF.util.can_play(entry.localIndex) then list[#list + 1] = entry end
    end
    return list
end
OF.gm_blast_pressers = pressers

local function my_turn()
    local np = gNetworkPlayers[0]
    if np == nil then return false end
    return gGlobalSyncTable.ofGmBlastTurn == np.globalIndex
end

local function my_queue_slot()
    local alive = pressers()
    local order = {}
    for _, entry in ipairs(alive) do table.insert(order, entry.np.globalIndex) end
    table.sort(order)
    local me = gNetworkPlayers[0] and gNetworkPlayers[0].globalIndex
    for i, g in ipairs(order) do
        if g == me then return i, #order end
    end
    return 1, math.max(1, #order)
end

local function nearest_unused(x, z, count, used, row)
    local best, bestD = nil, nil
    for i = 1, count do
        if not used[i] then
            local at = switch_place(i, count, row)
            if at ~= nil then
                local dx, dz = at.x - x, at.z - z
                local d = dx * dx + dz * dz
                if bestD == nil or d < bestD then best, bestD = i, d end
            end
        end
    end
    return best
end

local function same_roster(list, alive)
    if list == nil or #list ~= #alive then return false end
    local have = {}
    for _, entry in ipairs(list) do have[entry.localIndex] = true end
    for _, entry in ipairs(alive) do
        if not have[entry.localIndex] then return false end
    end
    return true
end

local function publish_used()
    local parts = {}
    local left = 0
    for i = 1, S.count do
        parts[i] = S.used[i] and "1" or "0"
        if not S.used[i] then left = left + 1 end
    end
    OF.util.publish(USED_KEY, table.concat(parts))
    OF.util.publish("ofGmBlastLeft", left)
    return left
end

local function publish_turn()
    local acting = S.players[S.turn]
    OF.util.publish("ofGmBlastTurn", acting.np.globalIndex)
    local secs = choose_seconds()
    S.timer = secs * 30
    S.secs = secs
    OF.util.publish("ofGmBlastTimer", secs)

end

local function start_cycle(alive)
    S.players = {}
    for _, entry in ipairs(alive) do table.insert(S.players, entry) end
    table.sort(S.players, function(a, b)
        return a.np.globalIndex < b.np.globalIndex
    end)
    S.count = #S.players + 1
    S.used = {}

    S.turn = 1
    for li in pairs(OF.gamemodes.deal_fair(S.players, 1, "roulette")) do
        for k, entry in ipairs(S.players) do
            if entry.localIndex == li then S.turn = k end
        end
    end
    S.phase = "choose"
    S.victim = nil
    S.seen = {}
    for _, entry in ipairs(S.players) do
        local row = gPlayerSyncTable[entry.localIndex]
        S.seen[entry.localIndex] = (row ~= nil and row.ofGmBlastPress) or 0
    end
    OF.util.publish(BOOM_KEY, 0)
    OF.util.publish("ofGmBlastCycle", (gGlobalSyncTable.ofGmBlastCycle or 0) + 1)
    OF.util.publish("ofGmBlastCount", S.count)
    publish_used()
    publish_turn()
end

local function declare(alive)
    if #alive == 1 then
        OF.gamemodes.finish("@ won.",
            alive[1].np.name, alive[1].np.name)
        return
    end
    if #alive == 0 then
        OF.gamemodes.finish("Nobody won.")
        return
    end

    local names = {}
    for _, entry in ipairs(alive) do
        if entry.np ~= nil and entry.np.name ~= nil then
            table.insert(names, entry.np.name)
        end
    end
    OF.gamemodes.finish(#alive == 1 and "Time - 1 player won." or "Time - @ players won.", { names = names },
        tostring(#alive))
end

local function new_row()
    S.used = {}
    OF.util.publish("ofGmBlastCycle", (gGlobalSyncTable.ofGmBlastCycle or 0) + 1)
    publish_used()
    OF.notify.send_all("Nobody found it - a new row", "info", 3)
end

function OF.gm_blast_lives_for(left)
    return (left or 0) >= 9 and 2 or 1
end

local function resolve_press(acting, index)
    local unused = 0
    for i = 1, S.count do
        if not S.used[i] then unused = unused + 1 end
    end
    S.used[index] = true
    publish_used()

    local lives = OF.gm_blast_lives_for(#pressers())
    local live = unused <= lives or math.random(1, unused) <= lives
    if live then
        S.phase = "boom"
        S.wait = BOOM_FRAMES
        S.victim = acting
        OF.util.publish(BOOM_KEY, BOOM_SECONDS)

        return
    end
    S.phase = "between"
    S.wait = BETWEEN_FRAMES

    if unused - 1 <= 1 then new_row() end
end

local PRESS_BASE = 32

local function next_turn()
    S.turn = S.turn % #S.players + 1
    S.phase = "choose"
    publish_turn()
end

local toldTime = false
local duckTurn, duckLeft = nil, 0
local lastTurnMine = false
local pressedThisTurn = false
local dropped = false
local lastBoom = 0
local blasted = false
local boomSaid = false

function OF.gm_blast_switch_at(i)
    return switch_place(i, switch_count())
end

function OF.gm_blast_row(i, count)
    return SWITCH_FOOT * SWITCH_SCALE, switch_place(i, count, { x = 0, y = 0, z = 0 })
end

local mode = {
    key = "blast",
    name = "Switch Roulette",
    blurb = "a row of switches, one of them live - step up and pick one",
    aims = {
        [ROLE_IN] = "Wait for your turn, then step on a switch - "
            .. "hope it is not the live one.",
        [ROLE_OUT] = "You found it. Watch the row shrink round whoever is "
            .. "still standing at it.",
    },
    how = "One player at a time steps up to a row of switches.\n"
        .. "Everybody else waits in the queue behind it.\n"
        .. "A few seconds to choose, or you drop onto the nearest.\n"
        .. "A dead switch sends you back to the queue.\n"
        .. "The live one: a three-second countdown, then the blast.\n"
        .. "One switch left and nobody found it: a new row.\n"
        .. "Last one who never found the live switch wins.",
    minPlayers = 2,
    maps = OF.PARTY_ARENAS,

    room = { rules = { interactions = PLAYER_INTERACTIONS_NONE } },
    defaultLimit = BACKSTOP_SECONDS,
    resultsBy = "survival",
    options = {
        { key = "choose", name = "Time to choose",
          help = "how long a turn at the row lasts before you drop",
          choices = {
              { key = "seven", name = "seven seconds", help = "the usual turn" },
              { key = "five", name = "five seconds", help = "a quick turn - less time to think" },
              { key = "ten", name = "ten seconds", help = "a slow turn - time to read the row" },
          } },
    },
}

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_IN)
    end
    reset_round()
end

function mode.pin()
    local here = OF.gamemodes.here_place(0)
    if here == nil then return end
    local y = here.y
    local floor = OF.util.optional("find_floor_height", nil,
        here.x, here.y + 100, here.z)
    if type(floor) == "number" and floor > -10000 then y = floor end
    OF.util.publish(ROW_KEY, string.format("%.0f %.0f %.0f", here.x, y, here.z))
end

mode.leadPin = { keys = { ROW_KEY } }

function mode.on_start()
    toldTime = false
    lastTurnMine = false
    pressedThisTurn = false
    dropped = false
    lastBoom = 0
    blasted = false
    boomSaid = false
end

local function the_blast(victimLocal)
    local m = gMarioStates[victimLocal]
    if m == nil or m.pos == nil then return end
    for k = 0, 5 do
        local a = k * math.pi / 3
        local o = OF.util.optional("spawn_non_sync_object", nil,
            id_bhvExplosion, E_MODEL_EXPLOSION,
            m.pos.x + math.sin(a) * 150, m.pos.y + 80, m.pos.z + math.cos(a) * 150,
            nil)
        if o ~= nil then OF.util.optional("obj_scale", nil, o, 3) end
    end

    OF.gamemodes.round_sound_from(m.marioObj, SOUND_GENERAL2_BOBOMB_EXPLOSION)
    OF.util.optional("set_camera_shake_from_point", nil, SHAKE_POS_LARGE,
        m.pos.x, m.pos.y, m.pos.z)
    if victimLocal == 0 then
        m.vel.y = 70
        m.forwardVel = -45
        OF.util.optional("set_mario_action", nil, m, ACT_HARD_BACKWARD_AIR_KB, 0)
    end
end

function mode.hold_in_queue(m, row)
    if m == nil or m.pos == nil or row == nil then return false end
    local slot, n = my_queue_slot()
    local at = queue_place(slot, n, row)
    local dx, dz = m.pos.x - at.x, m.pos.z - at.z
    if dx * dx + dz * dz <= QUEUE_HOLD * QUEUE_HOLD then return false end
    m.pos.x, m.pos.z = at.x, at.z
    if m.pos.y < at.y then m.pos.y = at.y end
    if m.vel ~= nil then m.vel.x, m.vel.z = 0, 0 end
    m.forwardVel = 0
    return true
end

function mode.ducking()
    local boom = tonumber(gGlobalSyncTable[BOOM_KEY]) or 0
    local turn = gGlobalSyncTable.ofGmBlastTurn
    if boom > 0 then
        duckTurn, duckLeft = turn, DUCK_AFTER
        return true
    end
    if duckTurn ~= nil then
        if turn == duckTurn then return true end
        duckTurn = nil
    end
    if duckLeft > 0 then
        duckLeft = duckLeft - 1
        return true
    end
    return false
end

function mode.duck(m)
    local pad = m ~= nil and m.controller or nil
    if pad == nil then return end
    pad.buttonDown = OF.util.add_flag(pad.buttonDown or 0, Z_TRIG)
    if m.action ~= ACT_CROUCHING and m.action ~= ACT_START_CROUCHING then
        pad.buttonPressed = OF.util.add_flag(pad.buttonPressed or 0, Z_TRIG)
    end
    pad.stickX, pad.stickY, pad.stickMag = 0, 0, 0
end

function mode.update()
    if OF.gamemodes.role(0) == ROLE_OUT and not toldTime then
        toldTime = true
        OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
    end

end

function mode.before_mario_update(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if OF.gamemodes.role(0) == ROLE_OUT then
        OF.gamemodes.set_ghost(true)
        return
    end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    if OF.gamemodes.role(0) ~= ROLE_IN or not OF.util.can_play(0) then return end
    local row = row_at()
    if row == nil then return end

    local mine = my_turn()

    if mine and not lastTurnMine then
        pressedThisTurn, dropped = false, false

        if OF.util.asks(OF.hud, "banner") then
            OF.hud.banner("role", OF.lang.t("YOUR TURN"), nil)
        end
        local at = front_place(row)
        if OF.util.asks(OF.net, "snap_to") then
            OF.net.snap_to(at.x, at.y + 20, at.z, 0x8000)
            OF.util.camera_behind_soon()
        end
    elseif lastTurnMine and not mine then

        if pressedThisTurn
            and (tonumber(gGlobalSyncTable[BOOM_KEY]) or 0) == 0 then
            OF.gamemodes.cue("good")
        end
        local slot, n = my_queue_slot()
        local at = queue_place(slot, n, row)
        if OF.util.asks(OF.net, "snap_to") then
            OF.net.snap_to(at.x, at.y + 20, at.z, 0x8000)
            OF.util.camera_behind_soon()
        end
    elseif not mine then
        mode.hold_in_queue(m, row)
    end
    if not mine and mode.ducking() then mode.duck(m) end
    lastTurnMine = mine
    if not mine or pressedThisTurn then return end
    if (tonumber(gGlobalSyncTable[BOOM_KEY]) or 0) > 0 then return end

    local count = switch_count()
    local used = used_list()
    local grounded = not OF.util.has_flag(m.action or 0, ACT_FLAG_AIR or 0x800)

    local i = grounded and switch_under(m, count, used) or nil
    if i ~= nil then
        pressedThisTurn = true
        local serial = math.floor((tonumber(
            gPlayerSyncTable[0].ofGmBlastPress) or 0) / PRESS_BASE) + 1
        OF.util.publish_row(0, "ofGmBlastPress", serial * PRESS_BASE + i)
        OF.gamemodes.round_sound(SOUND_GENERAL_ACTIVATE_CAP_SWITCH or SOUND_GENERAL_BUTTON_PRESS_2)
        return
    end

    if not dropped and (tonumber(gGlobalSyncTable.ofGmBlastTimer) or 1) <= 0 then
        dropped = true
        local i = nearest_unused(m.pos.x, m.pos.z, count, used, row)
        if i ~= nil then
            local at = switch_place(i, count, row)
            if OF.util.asks(OF.net, "snap_to") then
                OF.net.snap_to(at.x, at.y + DROP_HEIGHT, at.z, nil)
                OF.util.camera_behind_soon()
            end

            if OF.util.asks(OF.hud, "banner") then
                OF.hud.banner("medal", OF.lang.t("TOO SLOW"), nil, { quiet = true })
            end
        end
    end
end

function mode.host_update()
    local alive = pressers()

    if S.phase == "boom" then
        S.wait = S.wait - 1
        local secs = math.max(0, math.ceil(S.wait / 30))
        if secs ~= S.secs then
            S.secs = secs
            OF.util.publish(BOOM_KEY, secs)
        end
        if S.wait > 0 then return end
        if S.victim ~= nil then
            OF.gamemodes.set_role(S.victim.localIndex, ROLE_OUT)
        end
        S.players = nil
        S.phase = "choose"
        OF.util.publish(BOOM_KEY, 0)
        return
    end

    if #alive <= 1 then
        declare(alive)
        return
    end

    if not same_roster(S.players, alive) then
        start_cycle(alive)
        return
    end

    if S.phase == "between" then
        S.wait = S.wait - 1
        if S.wait <= 0 then next_turn() end
        return
    end

    local acting = S.players[S.turn]
    if acting == nil then
        S.players = nil
        return
    end

    S.timer = S.timer - 1
    local secs = math.max(0, math.ceil(S.timer / 30))
    if secs ~= S.secs then
        S.secs = secs
        OF.util.publish("ofGmBlastTimer", secs)
    end

    local row = gPlayerSyncTable[acting.localIndex]
    local asked = (row ~= nil and row.ofGmBlastPress) or 0
    local seen = S.seen[acting.localIndex] or 0
    if asked ~= seen then
        S.seen[acting.localIndex] = asked
        local index = asked % PRESS_BASE
        if index >= 1 and index <= S.count and not S.used[index] then
            resolve_press(acting, index)
            return
        end
    end

    if S.timer <= -BACKSTOP_FRAMES then
        local m = gMarioStates[acting.localIndex]
        local at = row_at()
        local i = nil
        if m ~= nil and m.pos ~= nil and at ~= nil then
            i = nearest_unused(m.pos.x, m.pos.z, S.count, S.used, at)
        end
        if i == nil then
            for k = 1, S.count do
                if not S.used[k] then i = k break end
            end
        end
        if i ~= nil then resolve_press(acting, i) end
    end
end

function mode.on_timeout()
    declare(pressers())
end

local shownUpTo = 0

local function hide_switches(from)
    for i = from, shownUpTo do
        OF.gamemodes.hide_token(SWITCH_TOKEN .. i)
        OF.gamemodes.hide_token(BASE_TOKEN .. i)
    end
    if from <= shownUpTo then shownUpTo = from - 1 end
end

function mode.scenery()
    local row = row_at()

    if row == nil or OF.gamemodes.state() ~= OF.gamemodes.ACTIVE
        or not OF.util.round_screen() then
        hide_switches(1)
        return
    end
    local count = switch_count()
    local used = used_list()
    for i = 1, count do
        if used[i] then
            OF.gamemodes.hide_token(SWITCH_TOKEN .. i)
            OF.gamemodes.hide_token(BASE_TOKEN .. i)
        else
            local at = switch_place(i, count, row)
            local base = OF.gamemodes.show_token(BASE_TOKEN .. i,
                E_MODEL_CAP_SWITCH_BASE, at, nil, BASE_BHV)
            local top = OF.gamemodes.show_token(SWITCH_TOKEN .. i,
                E_MODEL_CAP_SWITCH, { x = at.x, y = at.y + SWITCH_LIFT, z = at.z }, nil, SWITCH_BHV)
            if base ~= nil then OF.util.optional("obj_scale", nil, base, SWITCH_SCALE) end
            if top ~= nil then
                top.oAnimState = 0
                OF.util.optional("obj_scale", nil, top, SWITCH_SCALE)
            end
        end
    end
    if count > shownUpTo then shownUpTo = count end
    hide_switches(count + 1)

    local boom = tonumber(gGlobalSyncTable[BOOM_KEY]) or 0

    if boom > 0 then
        if lastBoom == 0 then OF.gamemodes.cue("hazard") end
        OF.gamemodes.tick_down(boom)
    end
    if lastBoom > 0 and boom == 0 and not blasted then
        blasted = true
        local g = gGlobalSyncTable.ofGmBlastTurn
        local who = OF.util.local_from_global(g)
        if who ~= nil then the_blast(who) end
    elseif boom > 0 then
        blasted = false
    end
    lastBoom = boom
end

function mode.cleanup()
    reset_round()
    toldTime = false
    lastTurnMine = false
    hide_switches(1)
    OF.util.publish_row(0, "ofGmBlastPress", nil)
    if OF.util.is_host() then
        OF.util.publish(ROW_KEY, nil)
        OF.util.publish(USED_KEY, nil)
        OF.util.publish(BOOM_KEY, nil)
    end
end

function mode.terms()
    return OF.lang.t("one switch is live - last one left wins")
end

local numberFrom = { x = 0, y = 0, z = 0 }
local numberAt = { x = 0, y = 0, z = 0 }

function mode.hud()
    if not OF.gamemodes.is_running() then return end
    local now = OF.gamemodes.current()
    if now == nil or now.key ~= mode.key then return end

    local row = row_at()
    local count = switch_count()
    local used = used_list()
    if row ~= nil then
        for i = 1, count do
            if not used[i] then
                local at = switch_place(i, count, row)
                numberFrom.x, numberFrom.y, numberFrom.z = at.x, at.y + NUMBER_LIFT, at.z
                if OF.util.world_screen(numberFrom, numberAt) then
                    OF.util.world_label(numberAt.x, numberAt.y, tostring(i),
                        1.2, 255, 230, 120, 255)
                end
            end
        end
    end

    local boom = tonumber(gGlobalSyncTable[BOOM_KEY]) or 0
    local left = gGlobalSyncTable.ofGmBlastLeft or 0
    local timer = gGlobalSyncTable.ofGmBlastTimer or 0

    local turnG = gGlobalSyncTable.ofGmBlastTurn
    local turnName = nil
    for _, entry in ipairs(OF.util.connected_players()) do
        if entry.np.globalIndex == turnG then turnName = entry.np.name end
    end

    if boom > 0 then
        if not boomSaid then
            boomSaid = true
            if OF.util.asks(OF.hud, "banner") then
                OF.hud.banner("objective", OF.lang.t("LIVE SWITCH"),
                    turnName ~= nil and OF.util.plain(turnName) or nil)
            end
        end
        return
    end
    boomSaid = false
    if OF.gamemodes.role(0) == ROLE_OUT then return end

    if not OF.util.asks(OF.hud, "state_line") then return end
    if my_turn() then
        OF.hud.state_line("turn", OF.lang.t("Your turn"), { prio = 85, tone = "warn",
            urgent = true, figure = tonumber(timer) or 0 })
        return
    end
    if turnName == nil then return end
    OF.hud.state_line("whose", OF.lang.fill("@'s turn", mode.short_name(turnName)),
        { prio = 20, tone = "mute" })
end

function mode.short_name(name)
    local plain = OF.util.plain(name or "")
    if #plain > 12 then plain = plain:sub(1, 11) .. "." end
    return plain
end

mode.choose_seconds = choose_seconds
mode.SWITCH_BHV, mode.BASE_BHV, mode.SWITCH_LIFT = SWITCH_BHV, BASE_BHV, SWITCH_LIFT
mode.switch_under = switch_under

mode.roundKeys = { "ofGmBlastCount", "ofGmBlastLeft", "ofGmBlastTimer", "ofGmBlastTurn" }
OF.gamemodes.register(mode)
