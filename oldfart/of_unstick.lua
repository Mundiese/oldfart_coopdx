OF = OF or {}
OF.unstick = OF.unstick or {}

local unstick = OF.unstick

local COOLDOWN = 15 * 30

local CUTSCENE_FRAMES = 12 * 30
local TIMESTOP_FRAMES = 6 * 30

local PAUSED_FRAMES   = 3 * 60 * 30

local DOOR_WARP_ARG   = 4
local DOOR_WARP_FRAME = 16

local DOOR_QUIET = 5 * 30

local cooldown = 0
local inCutscene = 0
local inTimeStop = 0
local inPause = 0

local doorArmed = false
local doorQuiet = 0

local putBackAt = false

unstick.doorRefused = unstick.doorRefused or 0
unstick.doorLetThrough = unstick.doorLetThrough or 0

unstick.freed = unstick.freed or 0

local function group_of(m)
    if m == nil or m.action == nil then return nil end
    return m.action & ACT_GROUP_MASK
end

function unstick.what_is_wrong()
    if doorArmed then return "a door armed a warp that will not fire" end
    if inCutscene >= CUTSCENE_FRAMES then return "a cutscene that will not end" end
    if inTimeStop >= TIMESTOP_FRAMES then return "the world is frozen" end
    if inPause >= PAUSED_FRAMES then return "the pause menu is stuck open" end
    return nil
end

function unstick.door_faults()
    return unstick.doorRefused, unstick.doorLetThrough
end

function unstick.cooling_for()
    return cooldown
end

unstick.REFUSED_IN_ROUND = "Unstick is off during rounds and speedruns"
function unstick.refused_now()
    if OF.util.asks(OF.gamemodes, "is_open") and OF.gamemodes.is_open() then return true end
    if OF.util.asks(OF.speedrun, "is_running") and OF.speedrun.is_running() then return true end
    return false
end

function unstick.free()
    if unstick.refused_now() then
        return false, unstick.REFUSED_IN_ROUND
    end
    if cooldown > 0 then
        return false, "Give it a few seconds and try again."
    end
    cooldown = COOLDOWN
    unstick.freed = unstick.freed + 1

    OF.util.optional("reset_dialog_render_state")
    OF.util.optional("set_dialog_box_state", nil, 0)
    OF.util.optional("set_menu_mode", nil, -1)
    OF.util.optional("disable_time_stop_including_mario")
    OF.util.optional("disable_time_stop")

    local myArea = gMarioStates[0] ~= nil and gMarioStates[0].area or nil
    local camera = myArea ~= nil and myArea.camera or nil
    if camera ~= nil then
        camera.cutscene = 0
        OF.util.optional("play_cutscene", nil, camera)
    end

    local me0 = gMarioStates[0]
    if me0 ~= nil and group_of(me0) == ACT_GROUP_CUTSCENE then
        OF.util.optional("set_mario_action", nil, me0, ACT_IDLE, 0)
    end

    local me = gNetworkPlayers[0]
    if me ~= nil then
        local level = me.currLevelNum
        local area = me.currAreaIndex or 1
        local act = me.currActNum or 1

        if OF.util.asks(OF.gamemodes, "hold_here")
            and OF.util.asks(OF.gamemodes, "holding") then
            local held = OF.gamemodes.holding()
            if held ~= nil then
                local also = {}
                for other in pairs(held.also or {}) do
                    table.insert(also, other)
                end
                table.sort(also)
                OF.gamemodes.hold_here(level, area, act, also)
            end
        end

        local heldByRound = OF.util.asks(OF.gamemodes, "may_leave_level")
            and OF.gamemodes.may_leave_level() == false
        local back = (not heldByRound)
            and OF.util.asks(OF.together, "checkpoint")
            and OF.together.checkpoint() or nil
        if back ~= nil and (back.level ~= level or back.area ~= area) then
            back = nil
        end
        if OF.util.optional("warp_to_level", false, level, area, act) then
            putBackAt = back ~= nil
            OF.notify.show(back ~= nil
                and "Unstuck - back where you were standing"
                or "Unstuck - reloading the level", "good", 4)
            return true
        end
    end

    if OF.util.optional("warp_restart_level", false) then
        OF.notify.show("Unstuck - restarting the level", "good", 4)
        return true
    end
    if OF.util.optional("warp_to_start_level", false) then
        OF.notify.show("Unstuck - back to the castle", "warn", 4)
        return true
    end

    return false, "Nothing this mod can do will move you. Rejoin the lobby."
end

hook_event(HOOK_UPDATE, function()
    if cooldown > 0 then cooldown = cooldown - 1 end

    local m = gMarioStates[0]
    if m == nil then
        inCutscene, inTimeStop, inPause = 0, 0, 0
        return
    end

    if group_of(m) == ACT_GROUP_CUTSCENE then
        inCutscene = inCutscene + 1
    else
        inCutscene = 0
    end

    local frozen = OF.util.optional("get_time_stop_flags", 0)
    if type(frozen) == "number" and frozen ~= 0 then
        inTimeStop = inTimeStop + 1
    else
        inTimeStop = 0
    end

    if OF.util.optional("is_game_paused", false) == true then
        inPause = inPause + 1
    else
        inPause = 0
    end
end)

hook_event(HOOK_ON_LEVEL_INIT, function()
    inCutscene, inTimeStop, inPause = 0, 0, 0
    doorArmed = false
    doorQuiet = 0

    if putBackAt then
        putBackAt = false
        if OF.util.asks(OF.together, "to_checkpoint") then
            OF.together.to_checkpoint()
        end
    end

    unstick.skip_next_frame()
end)

local DOOR_PULL_ACT = ACT_PULLING_DOOR or 0x00001320
local DOOR_PUSH_ACT = ACT_PUSHING_DOOR or 0x00001321

local function door_node_of(door)
    local params = door ~= nil and door.oBehParams or nil
    if type(params) ~= "number" then return nil end
    return (math.floor(params) >> 16) & 0xFF
end

local function door_fault(m)
    if m == nil or m.action == nil then return nil end
    if m.action ~= DOOR_PULL_ACT and m.action ~= DOOR_PUSH_ACT then return nil end

    if not OF.util.has_flag(m.actionArg or 0, DOOR_WARP_ARG) then return nil end

    if (m.actionTimer or 0) ~= DOOR_WARP_FRAME then return nil end

    if m.usedObj == nil then return "armed" end

    local id = door_node_of(m.usedObj)
    if id == nil then return nil end
    local node = OF.util.optional("area_get_warp_node", false, id)
    if node == false then return nil end

    if node ~= nil then return nil end
    return "death"
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, function(m)
    if doorQuiet > 0 then doorQuiet = doorQuiet - 1 end

    if m == nil or m.playerIndex ~= 0 then return end

    local fault = door_fault(m)
    if fault == nil then return end

    if OF.util.asks(OF.gamemodes, "is_running") and OF.gamemodes.is_running() then
        unstick.doorRefused = unstick.doorRefused + 1
        OF.util.optional("set_mario_action", nil, m, ACT_IDLE, 0)
        if doorQuiet <= 0 then
            doorQuiet = DOOR_QUIET
            OF.notify.show("That door leads nowhere - the round kept you here",
                "warn", 5)
        end
        return
    end

    unstick.doorLetThrough = unstick.doorLetThrough + 1
    if fault == "armed" then doorArmed = true end
end)

local told = nil

hook_event(HOOK_UPDATE, function()
    local wrong = unstick.what_is_wrong()
    if wrong == nil then
        told = nil
        return
    end
    if told == wrong then return end
    told = wrong

    OF.util.chat(OF.lang.fill("Stuck? Type @", "/unstick"), "warn")
end)

local HITCH_SECONDS = 0.1

local HITCH_KEEP = 6

local lastFrameAt = nil
local lastCrowd = 0
local lastWrites = 0
local lastCopies = 0

local skipFrame = true

unstick.hitches = unstick.hitches or {}
unstick.hitchCount = unstick.hitchCount or 0

unstick.lastHitchAt = unstick.lastHitchAt or nil

function unstick.stalled_within(now, seconds)
    if type(now) ~= "number" or now ~= now then return nil end
    if type(seconds) ~= "number" or seconds ~= seconds or seconds < 0 then return nil end
    if unstick.lastHitchAt == nil then return nil end
    local since = now - unstick.lastHitchAt
    if since < 0 or since > seconds then return nil end
    return since
end

function unstick.note_frame(now, crowd, writes, host, copies)
    if type(now) ~= "number" then return false end

    local gap = lastFrameAt ~= nil and (now - lastFrameAt) or nil
    local spent = writes - lastWrites
    local moved = crowd - lastCrowd
    copies = tonumber(copies) or 0

    local copied = math.max(0, copies - lastCopies)

    lastFrameAt, lastWrites, lastCrowd = now, writes, crowd
    lastCopies = copies

    if skipFrame then
        skipFrame = false
        return false
    end

    if gap == nil or gap < HITCH_SECONDS then return false end

    unstick.hitchCount = unstick.hitchCount + 1
    unstick.lastHitchAt = now
    table.insert(unstick.hitches,
        { seconds = gap, host = host == true, crowd = crowd,
          roster = moved, writes = spent, reads = copied })
    table.sort(unstick.hitches, function(x, y) return x.seconds > y.seconds end)
    while #unstick.hitches > HITCH_KEEP do table.remove(unstick.hitches) end
    return true
end

function unstick.skip_next_frame()
    skipFrame = true
end

function unstick.hitch_lines()
    local out = {}
    for _, entry in ipairs(unstick.hitches) do
        local text = string.format("%.2fs", entry.seconds)
            .. (entry.host and "  host" or "  guest")
            .. "  " .. tostring(entry.crowd) .. " here"
        if entry.roster ~= 0 then
            text = text .. "  roster " .. (entry.roster > 0 and "+" or "")
                .. tostring(entry.roster)
        end
        if entry.writes ~= 0 then
            text = text .. "  " .. tostring(entry.writes) .. " file write(s)"
        end
        if (entry.reads or 0) ~= 0 then
            text = text .. "  " .. tostring(entry.reads) .. " file read(s)"
        end
        table.insert(out, text)
    end
    return out
end

hook_event(HOOK_UPDATE, function()
    local now = OF.util.optional("clock_elapsed_f64")
    local crowd = #OF.util.connected_players()
    unstick.note_frame(now, crowd, OF.util.storeWrites or 0, OF.util.is_host(),
        OF.util.storage_copies ~= nil and OF.util.storage_copies() or 0)
end)

local function log_freeing()
    if not OF.util.asks(OF.actionlog, "report") then return false end
    return OF.actionlog.report(OF.lang.t("Travel") .. ": "
        .. OF.lang.t("Get me unstuck"), false, OF.actionlog.KIND_MINE)
end

hook_chat_command("unstick", "- get yourself out of a stuck level", function()
    log_freeing()
    return OF.util.report(unstick.free())
end)

hook_chat_command("u", "- get yourself out of a stuck level", function()
    log_freeing()
    return OF.util.report(unstick.free())
end)

function unstick.build_row(panel)
    local label = OF.lang.t("Get me unstuck")
    local wrong = unstick.what_is_wrong()
    local refused, letThrough = unstick.door_faults()
    if wrong ~= nil then
        label = OF.lang.fill("Get me unstuck (@)", OF.lang.t(wrong))
    elseif refused + letThrough > 0 then
        label = OF.lang.fill("Get me unstuck - @ bad doors this session",
            tostring(refused + letThrough))
    end
    return panel.row(label, 255, 200, 120, function()
        if OF.util.report(unstick.free()) then panel.close() end
    end)
end

function unstick.ready()
    return true
end
