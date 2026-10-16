OF = OF or {}
OF.lockdown = OF.lockdown or {}

local lockdown = OF.lockdown

lockdown.KEY = "ofLock"
lockdown.ROUND = "r"
lockdown.HOST  = "h"
lockdown.RACE  = "s"
local function reasons()
    local value = gGlobalSyncTable[lockdown.KEY]
    if value == nil or value == false then return "" end
    return tostring(value)
end

local function has_reason(letter)
    local held = reasons()
    if held == "" and type(letter) == "string" and letter ~= "" then
        return false
    end
    return string.find(held, letter, 1, true) ~= nil
end

function lockdown.held_by_round() return has_reason(lockdown.ROUND) end
function lockdown.held_by_host()  return has_reason(lockdown.HOST) end
function lockdown.held_by_race()  return has_reason(lockdown.RACE) end

function lockdown.on()
    return reasons() ~= ""
end

local function round_or_run_asked()
    if OF.util.asks(OF.gamemodes, "state")
        and OF.gamemodes.state() ~= OF.gamemodes.OFF then
        return true
    end
    if OF.util.asks(OF.speedrun, "is_running")
        and OF.speedrun.is_running() then
        return true
    end
    return false
end

local askedFunction = nil

function lockdown.round_or_run()
    local asks = OF.util.asks
    if asks ~= askedFunction then
        if type(asks) ~= "function" then return round_or_run_asked() end
        askedFunction = asks
    end
    local modes = OF.gamemodes
    if modes ~= nil and modes.state ~= nil and modes.state() ~= modes.OFF then
        return true
    end

    local speedrun = OF.speedrun
    if speedrun ~= nil and speedrun.is_running ~= nil and speedrun.is_running() then
        return true
    end
    return false
end

function lockdown.menu_stands_down(localIndex)
    if lockdown.held_for_everybody() then return true end
    if not lockdown.round_or_run() then

        if not (lockdown.held_by_round() or lockdown.held_by_race()) then return false end
        if (localIndex == nil or localIndex == 0)
            and OF.util.asks(OF.speedrun, "is_excluded") and OF.speedrun.is_excluded(0) then
            return false
        end
        return true
    end
    local scope = OF.roundscope
    if scope == nil or scope.inside == nil then return true end
    if localIndex == nil then
        if scope.inside(0) == true then return true end
        return lockdown.watching_the_round()
    end
    return OF.roundscope.about(localIndex) == true
end

function lockdown.watching_the_round()
    local spectate = OF.spectate
    if spectate == nil or spectate.is_spectating == nil
        or spectate.is_spectating(0) ~= true then
        return false
    end
    local act = OF.roundact
    return act ~= nil and act.watches ~= nil and act.watches(0) == true
end

function lockdown.held_for_everybody()
    if not lockdown.on() then return false end

    if reasons() == "" then return true end
    local rest = string.gsub(reasons(), lockdown.ROUND, "")
    rest = string.gsub(rest, lockdown.RACE, "")
    return rest ~= ""
end

function lockdown.stands_down_for_me()
    return lockdown.menu_stands_down()
end

local heldSwitches = nil

local heldPalettes = nil

local askedMovesets = false

function lockdown.is_on()
    return reasons() ~= ""
end

local function lobby_wide(text)
    local rest = string.gsub(text or "", lockdown.ROUND, "")
    rest = string.gsub(rest, lockdown.RACE, "")
    return rest ~= ""
end

local function round_or_race_in(text)
    text = text or ""
    return string.find(text, lockdown.ROUND, 1, true) ~= nil
        or string.find(text, lockdown.RACE, 1, true) ~= nil
end

local function set_reason(letter, on)
    if not OF.util.is_host() then return false end

    local before = reasons()
    local after = string.gsub(before, letter, "")
    if on then after = after .. letter end
    if after == before then return false end

    local wasOn = before ~= ""
    local nowOn = after ~= ""
    OF.util.publish(lockdown.KEY, after)

    local remember = nowOn and not wasOn
    local roundBegan = on and letter == lockdown.ROUND
        and string.find(before, letter, 1, true) == nil

    local wideBefore = lobby_wide(before)
    local wideAfter = lobby_wide(after)

    if remember then

    end
    if wideAfter and not wideBefore then
        if OF.util.asks(OF.fresh, "take_all") then
            heldSwitches = OF.fresh.take_all()
        end

        if OF.util.asks(OF.perms, "set_lockdown") then
            OF.perms.set_lockdown(true)
        end
    end

    if OF.util.asks(OF.perms, "set_round_hold") then
        OF.perms.set_round_hold(round_or_race_in(after))
    end
    if remember then

        if OF.util.asks(OF.rules, "pin_the_room") then
            OF.util.report(OF.rules.pin_the_room())
        end
        if OF.util.asks(OF.rules, "apply") then OF.rules.apply() end
    end

    if roundBegan then

        local dress = ""
        if OF.util.asks(OF.gamemodes, "round_mods") then
            dress = OF.gamemodes.round_mods() or ""
        end

        if OF.util.asks(OF.modifiers, "publish_round") then
            OF.modifiers.publish_round(dress)
        end

    end

    if wideBefore and not wideAfter then
        if OF.util.asks(OF.perms, "set_lockdown") then
            OF.perms.set_lockdown(false)
        end
        if heldSwitches ~= nil then
            local store = heldSwitches
            heldSwitches = nil
            if OF.util.asks(OF.fresh, "give_back_all") then
                OF.fresh.give_back_all(store)
            end
        end
    end
    if wasOn and not nowOn then

        if OF.util.asks(OF.modifiers, "publish_round") then
            OF.modifiers.publish_round("")
        end

        if OF.util.asks(OF.rules, "round_release") then
            OF.rules.round_release()
        end

        if OF.util.asks(OF.rules, "apply") then OF.rules.apply() end

    end
    return true
end

function lockdown.settle_rules()
    if not OF.util.is_host() then return false end
    if not OF.util.asks(OF.rules, "round_release") then return false end
    if lockdown.round_or_run() then return false end
    if OF.rules.round_dress() == "" then return false end

    OF.rules.round_release()
    if OF.util.asks(OF.rules, "apply") then OF.rules.apply() end
    return true
end

local function log_auto(line, value)
    if not OF.util.asks(OF.actionlog, "auto") then return end
    if value ~= nil then
        OF.actionlog.auto(OF.lang.fill(line, value))
        return
    end
    OF.actionlog.auto(OF.lang.t(line))
end

local roundName = nil

local function round_name()
    if not OF.util.asks(OF.gamemodes, "current") then return nil end
    local ok, mode = pcall(OF.gamemodes.current)
    if not ok or type(mode) ~= "table" then return nil end
    if type(mode.name) ~= "string" or mode.name == "" then return nil end
    return OF.lang.t(mode.name)
end

function lockdown.arm()
    if lockdown.held_by_round() then return false end
    if not set_reason(lockdown.ROUND, true) then return false end

    roundName = round_name()
    if roundName ~= nil then
        log_auto("a round of @ took its players' rules and ranks", roundName)
    else
        log_auto("a round took its players' rules and ranks")
    end
    return true
end

function lockdown.arm_race()
    if lockdown.held_by_race() then return false end
    if not set_reason(lockdown.RACE, true) then return false end
    log_auto("a race took its racers' rules and ranks")
    return true
end

function lockdown.lift_race()
    if not lockdown.held_by_race() then return false end
    if not set_reason(lockdown.RACE, false) then return false end
    log_auto("a race ended and gave the lobby back")
    return true
end

function lockdown.lift()
    if not lockdown.held_by_round() then return false end
    if not set_reason(lockdown.ROUND, false) then return false end

    local named = roundName
    roundName = nil
    if named ~= nil then
        log_auto("the round of @ ended and gave the lobby back", named)
    else
        log_auto("a round ended and gave the lobby back")
    end
    return true
end

function lockdown.hold(on, askerLocal)
    if not OF.perms.can("jail") then return false, "Your rank cannot do that.", "jail" end
    if not OF.util.is_host() then
        return false, "Only the host can hold the lobby."
    end
    if on == lockdown.held_by_host() then
        return false, on and "The lobby is already held."
            or "The lobby is not being held."
    end

    set_reason(lockdown.HOST, on)

    local who = OF.util.presser(askerLocal)
    if on then
        if who ~= nil then
            OF.notify.send_all("@ has taken hold of the lobby", "warn", 6, who)
        else
            OF.notify.send_all("The host has taken hold of the lobby", "warn", 6)
        end
        if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
            OF.notify.credit_named(askerLocal,
                OF.lang.t("took hold of the lobby"))
        end
        OF.chatlog.add_system(OF.lang.t("took hold of the lobby"), who)
    else

        if not lockdown.is_on() then
            if who ~= nil then
                OF.notify.send_all("@ let the lobby go - it is yours again",
                    "good", 5, who)
            else
                OF.notify.send_all("The lobby is yours again", "good", 5)
            end
        end
        if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
            OF.notify.credit_named(askerLocal,
                OF.lang.t("let go of the lobby"))
        end
        OF.chatlog.add_system(OF.lang.t("let go of the lobby"), who)
    end
    return true
end

function lockdown.toggle_hold(askerLocal)
    return lockdown.hold(not lockdown.held_by_host(), askerLocal)
end

function lockdown.round_unlocks_caps()
    if not lockdown.held_by_round() then return false end
    if not OF.util.asks(OF.gamemodes, "current") then return false end
    local mode = OF.gamemodes.current()
    return mode ~= nil and mode.capsUnlocked == true
end

local roundCapsWere = nil

function lockdown.caps_unlocked()
    return roundCapsWere ~= nil or lockdown.castle_held() ~= nil
end

local function write_caps(list, value)
    local wasUndo = OF.save.before
    local ok = OF.save.set_flags(list, value)
    OF.save.before = wasUndo
    return ok
end

function lockdown.hold_caps()
    if not OF.util.is_host() then return end
    if not OF.util.asks(OF.save, "set_flags") then return end
    if OF.save.CAP_FLAGS == nil then return end

    if lockdown.castle_held() ~= nil then return end

    if lockdown.round_unlocks_caps() then
        if roundCapsWere ~= nil then return end
        local were, wanted = {}, {}
        for _, flag in ipairs(OF.save.CAP_FLAGS) do
            were[flag] = OF.save.has_flag(flag)
            if not were[flag] then table.insert(wanted, flag) end
        end
        roundCapsWere = were

        if #wanted > 0 then write_caps(wanted, true) end
    elseif roundCapsWere ~= nil then
        local were = roundCapsWere
        roundCapsWere = nil
        local off = {}
        for _, flag in ipairs(OF.save.CAP_FLAGS) do
            if not were[flag] then table.insert(off, flag) end
        end

        if #off > 0 then write_caps(off, false) end
    end
end

function lockdown.round_opens_castle()
    if not lockdown.held_by_round() then return false end
    if not OF.util.asks(OF.gamemodes, "current") then return false end
    local mode = OF.gamemodes.current()
    return mode ~= nil and mode.castleOpen == true
end

local roundCastleWas = nil

local ROUND_CASTLE_KEY = "ofRoundCastle"
local strandedCastleAsked = false

function lockdown.castle_held()
    return roundCastleWas
end

function lockdown.hold_castle()
    if not OF.util.is_host() then return end
    if not OF.util.asks(OF.save, "world_give_back") then return end

    if lockdown.round_opens_castle() then
        if roundCastleWas ~= nil then return end
        if not OF.util.asks(OF.save, "world_open") then return end

        if OF.util.asks(OF.speedrun, "castle_held")
            and OF.speedrun.castle_held() ~= nil then return end

        local shot = OF.save.world_open()
        if shot == nil then return end
        roundCastleWas = shot

        if OF.util.asks(OF.save, "world_pack") then
            local packed = OF.save.world_pack(shot)
            if packed ~= nil then OF.util.store(ROUND_CASTLE_KEY, packed) end
        end

        OF.notify.show("The castle is opened for this round - it goes back at the end",
            "info", 6)

        log_auto("a round opened the whole castle")
        return
    end

    if roundCastleWas ~= nil then
        local shot = roundCastleWas

        roundCastleWas = nil
        local ok, why = OF.save.world_give_back(shot)
        if ok then
            OF.util.clear(ROUND_CASTLE_KEY)
            OF.notify.show("The castle is back to how the lobby had it", "info", 6)
            log_auto("the castle went back to how the lobby had it")
            return
        end

        OF.notify.show("The castle could not go back yet and is still held: @",
            "warn", 8, tostring(why))
        return
    end

    if strandedCastleAsked then return end
    strandedCastleAsked = true
    if not OF.util.asks(OF.save, "world_unpack") then return end
    local shot = OF.save.world_unpack(OF.util.stored(ROUND_CASTLE_KEY, ""))
    if shot == nil then return end

    shot.borrow = "stranded"
    local ok, why = OF.save.world_give_back(shot)
    if ok then
        OF.util.clear(ROUND_CASTLE_KEY)
        OF.notify.show("A round did not finish - the castle is back to how it was",
            "info", 8)
    else
        OF.notify.show("A round left the castle open and it is still waiting: @",
            "warn", 8, tostring(why))
    end
end

local function heartbeat()
    if not OF.util.is_host() then return end
    if OF.gamemodes == nil or OF.gamemodes.is_running == nil then return end

    local running = OF.gamemodes.state() ~= OF.gamemodes.OFF
    if running and not lockdown.held_by_round() then
        lockdown.arm()
    elseif not running and lockdown.held_by_round() then
        lockdown.lift()
    end

    if OF.util.asks(OF.speedrun, "is_running") then
        local racing = OF.speedrun.is_running()
        if racing and not lockdown.held_by_race() then
            lockdown.arm_race()
        elseif not racing and lockdown.held_by_race() then
            lockdown.lift_race()
        end
    end

    if OF.util.asks(OF.perms, "set_lockdown")
        and OF.perms.lockdown ~= lockdown.held_for_everybody() then
        OF.perms.set_lockdown(lockdown.held_for_everybody())
    end
    if OF.util.asks(OF.perms, "set_round_hold")
        and OF.perms.roundHold ~= round_or_race_in(reasons()) then
        OF.perms.set_round_hold(round_or_race_in(reasons()))
    end

    lockdown.hold_palettes()
    lockdown.hold_movesets()

    lockdown.hold_castle()
    lockdown.hold_caps()
end

function lockdown.hold_palettes()
    if not OF.util.is_host() then return nil end
    if not OF.util.asks(OF.charselect, "palettes_restricted") then return nil end

    local is = OF.charselect.palettes_restricted()

    if is == nil then
        heldPalettes = nil
        return nil
    end

    local want = OF.util.asks(OF.teams, "painting_anybody")
        and OF.teams.painting_anybody() or false

    if want then
        if heldPalettes == nil then heldPalettes = is end
        if is then return false end
        OF.charselect.restrict_palettes(true)
        return true
    end

    if heldPalettes == nil then return false end
    local was = heldPalettes
    heldPalettes = nil
    if is == was then return false end
    OF.charselect.restrict_palettes(was)

    if OF.util.asks(OF.teams, "repaint") then OF.teams.repaint() end
    return true
end

function lockdown.hold_movesets()
    if not OF.util.is_host() then return nil end
    if not OF.util.asks(OF.charselect, "movesets_restricted") then return nil end

    if OF.charselect.movesets_restricted() == nil then
        askedMovesets = false
        return nil
    end

    local want = lockdown.held_by_round() or lockdown.held_by_race()
    if want == askedMovesets then return false end
    askedMovesets = want
    OF.charselect.restrict_movesets(want)
    return true
end

hook_event(HOOK_UPDATE, function()
    local answer = lockdown.answer_the_waiting_fight
    if answer ~= nil then answer() end
    heartbeat()
end)

local function cheats_follow_the_round()
    if OF.cheats == nil then return end
    if not OF.util.asks(OF.cheats, "room_changed") then return end
    OF.cheats.room_changed()
end

function lockdown.take_cheats()
    cheats_follow_the_round()
end

function lockdown.give_cheats_back()
    cheats_follow_the_round()
end

function lockdown.cheats_held()
    if OF.cheats == nil or not OF.util.asks(OF.cheats, "suspended") then
        return nil
    end
    if not lockdown.is_on() then return nil end
    local held = 0
    for _, entry in ipairs(OF.cheats.LIST or {}) do
        if OF.cheats.suspended(entry.key) then held = held + 1 end
    end
    return held
end

lockdown.REASON_NAMES = {
    [lockdown.ROUND] = "a round",
    [lockdown.RACE]  = "a race",
    [lockdown.HOST]  = "the host",
}

function lockdown.holding()
    local text = reasons()
    if text == "" then return nil end

    local said = {}
    local strangers = {}
    for letter in string.gmatch(text, ".") do
        local name = lockdown.REASON_NAMES[letter]
        if name ~= nil then
            table.insert(said, name)
        else
            table.insert(strangers, letter)
        end
    end
    if #strangers > 0 then
        table.insert(said, "something this build does not know ('"
            .. table.concat(strangers) .. "')")
    end
    return table.concat(said, " and ")
end

hook_on_sync_table_change(gGlobalSyncTable, lockdown.KEY, lockdown.KEY, function()

    if OF.util.asks(OF.guard, "repair") and OF.guard.repair(lockdown.KEY) then
        return
    end

    if lockdown.is_on() then
        lockdown.take_cheats()
    else
        lockdown.give_cheats_back()
    end
end)

hook_event(HOOK_ON_LEVEL_INIT, function()
    if lockdown.is_on() then lockdown.take_cheats() end
end)

local function round_or_race()
    return lockdown.held_by_round() or lockdown.held_by_race()
end

lockdown.round_or_race = round_or_race

local function text_is_taken()

    if lockdown.held_by_race() and not lockdown.held_by_round()
        and OF.util.asks(OF.speedrun, "keeps_text") and OF.speedrun.keeps_text() then
        return false
    end
    return round_or_race()
end

lockdown.text_is_taken = text_is_taken

local function is_the_star_box(dialogId)
    local values = gBehaviorValues
    local list = values ~= nil and values.dialogs or nil
    if list == nil then return false end
    return dialogId == list.CollectedStarDialog
        or dialogId == list.HundredCoinsDialog
end

local function is_a_response_dialog(dialogId)
    if is_the_star_box(dialogId) then return true end
    local m = gMarioStates[0]
    local camera = m ~= nil and m.area ~= nil and m.area.camera or nil
    if camera ~= nil
        and (camera.cutscene == CUTSCENE_CAP_SWITCH_PRESS
            or camera.cutscene == CUTSCENE_RACE_DIALOG) then
        return true
    end
    local values = gBehaviorValues
    local list = values ~= nil and values.dialogs or nil
    return list ~= nil and dialogId == list.UkikiHeldDialog
end

lockdown.dialog_is_a_response = is_a_response_dialog

function lockdown.refuses_dialog(dialogId)
    if not text_is_taken() then return false end
    return not is_a_response_dialog(dialogId)
end

hook_event(HOOK_ON_DIALOG, function(dialogId)
    if lockdown.refuses_dialog(dialogId) then return false end
end)

local SPECIAL_CAPS = { id_bhvWingCap, id_bhvMetalCap, id_bhvVanishCap }

function lockdown.refuses_cap(o)
    if o == nil then return false end
    if not lockdown.cap_rule_applies() then return false end
    local kind = lockdown.cap_kind(o)
    if kind == nil then return false end
    return not lockdown.round_allows_cap(kind)
end

function lockdown.cap_kind(o)
    if o == nil then return nil end

    local names = { "wing", "metal", "vanish" }
    for index, id in ipairs(SPECIAL_CAPS) do
        if id ~= nil
            and OF.util.optional("obj_has_behavior_id", 0, o, id) ~= 0 then
            return names[index]
        end
    end
    return nil
end

function lockdown.cap_rule_applies()
    if not lockdown.held_by_round() then return false end
    if not lockdown.round_or_run() then return true end
    local scope = OF.roundscope
    if scope == nil or scope.inside == nil then return true end
    return scope.inside(0) == true
end

lockdown.CAP_STAGES = {}
for _, level in ipairs({ LEVEL_TOTWC, LEVEL_COTMC, LEVEL_VCUTM }) do
    if level ~= nil then lockdown.CAP_STAGES[level] = true end
end

function lockdown.cap_stage_is_the_map()
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if np == nil or lockdown.CAP_STAGES[np.currLevelNum] ~= true then
        return false
    end
    if not OF.util.asks(OF.gamemodes, "current") then return false end
    local mode = OF.gamemodes.current()
    if mode == nil then return true end
    local modes = OF.gamemodes
    if OF.util.asks(modes, "owns_its_place") and modes.owns_its_place(mode) then
        return false
    end
    if OF.util.asks(modes, "maps_of") and modes.maps_of(mode) == "own" then
        return false
    end
    return true
end

function lockdown.round_allows_cap(kind)
    if kind ~= "wing" then return false end
    if lockdown.cap_stage_is_the_map() then return false end
    if not OF.util.asks(OF.gamemodes, "current") then return false end
    local mode = OF.gamemodes.current()
    return mode ~= nil and mode.wingCap == true
end

local CAP_BITS = {
    { kind = "wing",   flag = function() return MARIO_WING_CAP end },
    { kind = "metal",  flag = function() return MARIO_METAL_CAP end },
    { kind = "vanish", flag = function() return MARIO_VANISH_CAP end },
}

function lockdown.strip_refused_caps(m)
    if m == nil or m.playerIndex ~= 0 then return false end

    if (m.capTimer or 0) <= 1 then return false end
    if not lockdown.cap_rule_applies() then return false end
    local took, kept = false, false
    for _, bit in ipairs(CAP_BITS) do
        local flag = bit.flag()
        if flag ~= nil and OF.util.has_flag(m.flags or 0, flag) then
            if lockdown.round_allows_cap(bit.kind) then
                kept = true
            else
                m.flags = m.flags - flag
                took = true
            end
        end
    end
    if not took then return false end
    if not kept then
        m.capTimer = 0
        OF.util.optional("stop_cap_music", nil)
    end
    return true
end

local ARRIVAL_WATCH = 90
local arrivalLeft = 0
local capRuleWas = false

hook_event(HOOK_ON_LEVEL_INIT, function() arrivalLeft = ARRIVAL_WATCH end)

function lockdown.watch_caps(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    local applies = lockdown.cap_rule_applies()
    local look = applies and not capRuleWas
    capRuleWas = applies
    if arrivalLeft > 0 then
        arrivalLeft = arrivalLeft - 1
        if applies then look = true end
    end
    if not look then return false end
    return lockdown.strip_refused_caps(m)
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, function(m) lockdown.watch_caps(m) end)

local SWITCH_WAITING = 1
local SWITCH_DONE = 3

function lockdown.holds_cap_switches()
    return lockdown.cap_rule_applies()
end

local function cap_switch_loop(o)
    if o == nil then return end
    local flat = o.header ~= nil and o.header.gfx ~= nil
        and o.header.gfx.scale ~= nil and o.header.gfx.scale.y ~= nil
        and o.header.gfx.scale.y < 0.3
    if lockdown.holds_cap_switches() then
        if o.oAction == SWITCH_WAITING then o.oAction = SWITCH_DONE end
    elseif o.oAction == SWITCH_DONE and not flat then
        o.oAction = SWITCH_WAITING
    end
end

lockdown.cap_switch_loop = cap_switch_loop

if id_bhvCapSwitch ~= nil and type(hook_behavior) == "function" then
    hook_behavior(id_bhvCapSwitch, OBJ_LIST_SURFACE, false, nil,
        cap_switch_loop)
end

hook_event(HOOK_ALLOW_INTERACT, function(m, o, interactType)
    if interactType ~= INTERACT_CAP then return end
    if m == nil or m.playerIndex ~= 0 then return end
    if lockdown.refuses_cap(o) then return false end
end)

local HELD_FOR_TEXT = { "ACT_WAITING_FOR_DIALOG", "ACT_READING_NPC_DIALOG" }

local SWALLOWED = 1

function lockdown.instead_of_talking(action)
    if action == nil then return nil end
    if not text_is_taken() then return nil end
    for _, name in ipairs(HELD_FOR_TEXT) do
        local held = _G[name]
        if held ~= nil and action == held then return SWALLOWED end
    end
    return nil
end

hook_event(HOOK_BEFORE_SET_MARIO_ACTION, function(m, action)
    if m == nil or m.playerIndex ~= 0 then return end
    return lockdown.instead_of_talking(action)
end)

local BOSSES = {
    "id_bhvKingBobomb", "id_bhvWhompKingBoss",
    "id_bhvGhostHuntBigBoo", "id_bhvMerryGoRoundBooManager",
    "id_bhvBalconyBigBoo",
    "id_bhvBigBully", "id_bhvBigBullyWithMinions", "id_bhvBigChillBully",
    "id_bhvEyerokBoss", "id_bhvEyerokHand",
    "id_bhvWigglerHead", "id_bhvWigglerBody",
    "id_bhvBowser",
}

local function round_fights_bosses()
    if not OF.util.asks(OF.gamemodes, "current") then return false end
    local mode = OF.gamemodes.current()
    return mode ~= nil and mode.fightsBosses == true
end

lockdown.round_fights_bosses = round_fights_bosses

function lockdown.refuses_boss(o)
    if o == nil then return false end
    if not lockdown.held_by_round() then return false end
    if round_fights_bosses() then return false end
    for _, name in ipairs(BOSSES) do
        local id = _G[name]
        if id ~= nil
            and OF.util.optional("obj_has_behavior_id", 0, o, id) ~= 0 then
            return true
        end
    end
    return false
end

function lockdown.boss_count()
    local held = 0
    for _, name in ipairs(BOSSES) do
        if _G[name] ~= nil then held = held + 1 end
    end
    return held, #BOSSES
end

hook_event(HOOK_ALLOW_INTERACT, function(m, o, interactType)
    if m == nil or m.playerIndex ~= 0 then return end
    if lockdown.refuses_boss(o) then return false end
end)

local STALLED_AT = 1

local ENDS_CUTSCENE = 3
local ENDS_PLAIN = 4

local THE_ANSWER = 1

local function the_fight_is_allowed(object)
    return not lockdown.refuses_boss(object)
end

local function the_race_is_the_point()
    return lockdown.held_by_race()
end

local function whenever_the_text_is_taken()
    return true
end

local ANSWERED = {
    { name = "id_bhvKingBobomb",    ends = ENDS_CUTSCENE,
      allowed = the_fight_is_allowed },
    { name = "id_bhvWhompKingBoss", ends = ENDS_CUTSCENE,
      allowed = the_fight_is_allowed },
    { name = "id_bhvWigglerHead",   ends = ENDS_CUTSCENE,
      allowed = the_fight_is_allowed },
    { name = "id_bhvBowser",        ends = ENDS_PLAIN,
      allowed = the_fight_is_allowed },
    { name = "id_bhvGhostHuntBoo",  ends = ENDS_PLAIN,
      allowed = whenever_the_text_is_taken },
    { name = "id_bhvKoopa",         ends = ENDS_CUTSCENE,
      allowed = the_race_is_the_point },
}

function lockdown.answer_the_waiting_fight()
    if not text_is_taken() then return 0 end
    local firstOf = OF.util.binding("obj_get_first_with_behavior_id")
    local nextOf = OF.util.binding("obj_get_next_with_same_behavior_id")
    if firstOf == nil or nextOf == nil then return 0 end

    local answered = 0
    for _, row in ipairs(ANSWERED) do
        local id = _G[row.name]
        if id ~= nil then
            local object = firstOf(id)
            while object ~= nil do
                if object.oDialogState == STALLED_AT and row.allowed(object) then

                    object.oDialogResponse = THE_ANSWER
                    object.oDialogState = row.ends
                    answered = answered + 1
                end
                object = nextOf(object)
            end
        end
    end
    return answered
end

function lockdown.answered_count()
    local held = 0
    for _, row in ipairs(ANSWERED) do
        if _G[row.name] ~= nil then held = held + 1 end
    end
    return held, #ANSWERED
end

local function round_keeps_the_level()
    if not lockdown.held_by_round() then return false end
    if not OF.util.asks(OF.gamemodes, "current") then return false end
    local mode = OF.gamemodes.current()
    return mode ~= nil and mode.inertStarsAndCaps == true
end

lockdown.round_keeps_the_level = round_keeps_the_level

function lockdown.refuses_star(interactType)
    if interactType == nil then return false end
    local star = INTERACT_STAR_OR_KEY
    if star == nil or interactType ~= star then return false end
    if round_keeps_the_level() then return true end
    return lockdown.round_withholds_stars()
end

function lockdown.round_withholds_stars()
    local modes = OF.gamemodes
    if modes == nil or modes.state == nil or modes.state() == modes.OFF then
        return false
    end
    if not OF.util.asks(modes, "current") then return false end
    local mode = modes.current()
    if mode == nil or mode.collectsStars == true then return false end
    if OF.util.asks(OF.roundscope, "inside") and OF.roundscope.inside(0) ~= true then
        return false
    end
    return true
end

local CAP_BOX_BYTES = { 0, 1, 2 }

local BOX_STANDING = 2

local BOX_POPPING = 3

function lockdown.refuses_cap_box(o)
    if o == nil then return false end
    if not round_keeps_the_level() then return false end

    if lockdown.caps_unlocked() then return false end
    if id_bhvExclamationBox == nil then return false end
    local box = OF.util.optional("obj_has_behavior_id", 0, o,
        id_bhvExclamationBox)
    if box == nil or box == 0 or box == false then return false end
    local which = o.oBehParams2ndByte
    if type(which) ~= "number" then return false end
    for _, byte in ipairs(CAP_BOX_BYTES) do
        if which == byte then return true end
    end
    return false
end

hook_event(HOOK_ALLOW_INTERACT, function(m, o, interactType)
    if m == nil or m.playerIndex ~= 0 then return end
    if lockdown.refuses_star(interactType) then return false end
    local breakable = INTERACT_BREAKABLE
    if breakable ~= nil and interactType == breakable
        and lockdown.refuses_cap_box(o) then
        return false
    end
end)

local function cap_box_loop(o)
    if o == nil then return end
    if o.oAction ~= BOX_POPPING then return end
    if not lockdown.refuses_cap_box(o) then return end
    o.oAction = BOX_STANDING
    o.oPrevAction = -1
end

lockdown.cap_box_loop = cap_box_loop

if id_bhvExclamationBox ~= nil and type(hook_behavior) == "function" then
    hook_behavior(id_bhvExclamationBox, OBJ_LIST_SURFACE, false, nil,
        cap_box_loop)
end

local WATER_BOMB_HOLD = 30
local WATER_BOMB_FROM_CANNON = 0
local WATER_BOMB_EXPLODE = 3

function lockdown.round_drops_no_water_bombs()
    if not lockdown.held_by_round() then return false end
    if not OF.util.asks(OF.gamemodes, "current") then return false end
    local mode = OF.gamemodes.current()
    return mode ~= nil and mode.noWaterBombs == true
end

function lockdown.water_bomb_spawner_loop(o)
    if o == nil or not lockdown.round_drops_no_water_bombs() then return end
    local left = o.oWaterBombSpawnerTimeToSpawn
    if type(left) ~= "number" or left < WATER_BOMB_HOLD then
        o.oWaterBombSpawnerTimeToSpawn = WATER_BOMB_HOLD
    end
end

function lockdown.water_bomb_loop(o)
    if o == nil or not lockdown.round_drops_no_water_bombs() then return end
    local action = o.oAction
    if action == WATER_BOMB_FROM_CANNON then
        obj_mark_for_deletion(o)
    elseif action ~= WATER_BOMB_EXPLODE then
        o.oAction = WATER_BOMB_EXPLODE
    end
end

function lockdown.water_bomb_cannon_loop(o)
    if o == nil or not lockdown.round_drops_no_water_bombs() then return end
    o.oWaterCannonUnkF4 = 0
    if type(o.oWaterCannonUnkF8) ~= "number"
        or o.oWaterCannonUnkF8 < WATER_BOMB_HOLD then
        o.oWaterCannonUnkF8 = WATER_BOMB_HOLD
    end
end

if type(hook_behavior) == "function" then
    if id_bhvWaterBombSpawner ~= nil then
        hook_behavior(id_bhvWaterBombSpawner, OBJ_LIST_GENACTOR, false, nil,
            lockdown.water_bomb_spawner_loop)
    end
    if id_bhvWaterBomb ~= nil then
        hook_behavior(id_bhvWaterBomb, OBJ_LIST_GENACTOR, false, nil,
            lockdown.water_bomb_loop)
    end
    if id_bhvWaterBombCannon ~= nil then
        hook_behavior(id_bhvWaterBombCannon, OBJ_LIST_DEFAULT, false, nil,
            lockdown.water_bomb_cannon_loop)
    end
end

lockdown.CALM_WIND_GROUPS = { "Catch somebody", "Hide from them" }
lockdown.CALM_WIND_ALSO = { assassins = true }

lockdown.CALM_WIND_NOT = { manhunt = true, hotpotato = true }

function lockdown.calms_the_wind(modeKey)
    if type(modeKey) ~= "string" then return false end
    if lockdown.CALM_WIND_NOT[modeKey] then return false end
    if lockdown.CALM_WIND_ALSO[modeKey] then return true end
    local groups = OF.gamemodes ~= nil and OF.gamemodes.GROUPS or nil
    if type(groups) ~= "table" then return false end
    for _, group in ipairs(groups) do
        for _, name in ipairs(lockdown.CALM_WIND_GROUPS) do
            if group.name == name then
                for _, key in ipairs(group.keys or {}) do
                    if key == modeKey then return true end
                end
            end
        end
    end
    return false
end

function lockdown.round_calms_the_snowman()
    if not lockdown.held_by_round() then return false end
    if not OF.util.asks(OF.gamemodes, "current") then return false end
    local mode = OF.gamemodes.current()
    if mode == nil or not lockdown.calms_the_wind(mode.key) then return false end
    local scope = OF.roundscope
    if scope == nil or scope.inside == nil then return true end
    if scope.inside(0) then return true end
    return scope.shares_room_with_round ~= nil
        and scope.shares_room_with_round() == true
end

local SNOWMAN_LIFT = 100000

function lockdown.snowman_wind_loop(o)
    if o == nil or type(o.oPosY) ~= "number" then return end
    if lockdown.round_calms_the_snowman() then
        o.oHomeY = o.oPosY + SNOWMAN_LIFT
    elseif type(o.oHomeY) == "number"
        and o.oHomeY - o.oPosY > SNOWMAN_LIFT / 2 then
        o.oHomeY = o.oPosY
    end
end

if type(hook_behavior) == "function" and id_bhvSLSnowmanWind ~= nil then
    hook_behavior(id_bhvSLSnowmanWind, OBJ_LIST_DEFAULT, false, nil,
        lockdown.snowman_wind_loop)
end

function lockdown.round_refills_enemies()
    if not lockdown.held_by_round() then return nil end
    if not OF.util.asks(OF.gamemodes, "current") then return nil end
    local mode = OF.gamemodes.current()
    if mode == nil then return nil end
    local secs = mode.enemiesBack
    if type(secs) ~= "number" or secs < 0 then return nil end
    return secs
end

lockdown.CASTLE = { LEVEL_CASTLE, LEVEL_CASTLE_GROUNDS, LEVEL_CASTLE_COURTYARD }

local CASTLE_SET = {}
for _, level in ipairs(lockdown.CASTLE) do
    if level ~= nil then CASTLE_SET[level] = true end
end

function lockdown.in_the_castle(level)
    return level ~= nil and CASTLE_SET[level] == true
end

lockdown.CASTLE_ROAM = {

    oneflag = { roam = false,
        why = "One flag and two bases pinned in one level, Capture the Flag's "
           .. "reason." },

    downhill = { roam = false,
        why = "One slide in one level, its top and its foot; a rider elsewhere "
           .. "has nothing to come down." },
    shellrace = { roam = false,
        why = "A track is one room: its gates, boxes and grid are read from "
           .. "that level. Spread it over three levels and it stops being a "
           .. "race and becomes a walk between two of them." },

    booksquirm = { roam = false,
        why = "The box is one object standing over one arena and the round is "
           .. "the sixteen cells inside it. Spread it over three levels and "
           .. "there is no box at all." },
    bank = { roam = false,
        why = "The vault is one object in one room and a coin only counts once "
           .. "it is carried home. Five levels of walk-in is five different "
           .. "lengths of the same errand." },
    bossrush = { roam = false,
        why = "Every runner is in their own copy of their own Bowser arena, "
           .. "and the hold already carries the stage's second level. No part "
           .. "of this round is ever in the castle." },
    shooter = { roam = false,
        why = "The round is a fight in one arena, and the arenas are the only "
           .. "courses it is offered on. A shot is a line of sight, so a "
           .. "castle nobody can be seen across is a round nobody can play." },
    bounty = { roam = false,
        why = "A death drops a tag where it fell and the race to it is the "
           .. "round. A tag lying in a room nobody is in is a kill nobody can "
           .. "confirm or deny." },
    coinrush = { roam = false,
        why = "Kept to one place. The rain falls on the room the "
           .. "round is pinned to, so anybody in the courtyard is standing "
           .. "where no coins land." },
    crown = { roam = false,
        why = "The crown is worn in the open and taken with a fist. Given "
           .. "three levels the wearer keeps it by being somewhere else, which "
           .. "is a different game from wearing it the longest." },
    football = { roam = false,
        why = "One pitch in one room; a ball in a level nobody is standing in "
           .. "is never kicked." },
    volleyball = { roam = false,
        why = "One court in one level, Football's reason." },
    ctf = { roam = false,
        why = "Two bases, both pinned in one level. A flag carried out of the "
           .. "front door is a flag on a walk nobody can cut off." },
    domination = { roam = false,
        why = "Three points laid on the room everybody is in. A point in a "
           .. "level nobody is in scores for whoever last wandered past it." },
    turf = { roam = false,
        why = "The grid is laid over the level everybody is in. A square in a "
           .. "level nobody is standing in is never painted or seen - "
           .. "Domination's own reason about the same shape." },
    silverfive = { roam = false,
        why = "Every player's five are dealt from one course's points; a "
           .. "racer elsewhere could never reach theirs." },
    wanted = { roam = false,
        why = "The wanted player is hunted on one course; a hunter elsewhere "
           .. "could never land the hit." },
    rabbitchase = { roam = false,
        why = "The rabbits hop about one course's points; a chaser elsewhere "
           .. "could never reach one." },
    bombsort = { roam = false,
        why = "The Bob-ombs and both pens are on one floor; a sorter "
           .. "elsewhere could never carry one." },
    onoffclimb = { roam = false,
        why = "The spiral and its switches stand over one floor; a climber "
           .. "elsewhere could never reach the star." },
    lakitu = { roam = false,
        why = "The cloud and its Spinies are over one floor; a runner "
           .. "elsewhere could never be reached or reach it." },
    snd = { roam = false,
        why = "Two sites and two spawns in one level; a player elsewhere "
           .. "could neither plant nor stop a plant." },
    firesweep = { roam = false,
        why = "The ring and its rows of fire are on one floor; a player "
           .. "elsewhere could never be swept or take a star." },
    flyguy = { roam = false,
        why = "The trampoline and its Fly Guys are on one floor; a bouncer "
           .. "elsewhere could never stomp one." },
    megarampage = { roam = false,
        why = "The giant hunts on one floor; a runner elsewhere could never be "
           .. "flattened and a giant elsewhere could never flatten anybody." },
    copsandrobbers = { roam = false,
        why = "The cell is one point in one level; a robber on another level "
           .. "could never be caught or free anybody." },
    rocketarena = { roam = false,
        why = "A fight in one arena - Deathmatch's reason: a rocket needs "
           .. "the same line of sight a rifle shot does." },
    blastgrid = { roam = false,
        why = "The field is built in one room and every blast is judged on "
           .. "it. A player in another level is never in a cross." },
    shellbattle = { roam = false,
        why = "The bombs lie at the points of one level and a throw is a "
           .. "flight over that level's ground. Spread it over three levels "
           .. "and nobody can reach anybody to pop a balloon." },
    assassins = { roam = false,
        why = "A ring is dealt to one arena and a hit is close-range; spread "
           .. "over five levels half the ring could never reach its pair." },
    flood = { roam = false,
        why = "The water is a height in one level and there is no water "
           .. "anywhere else in the castle. A player on the grounds is not in "
           .. "the round at all." },
    hexagone = { roam = false,
        why = "The floor is built above one room and taken away tile by tile. "
           .. "There is no floor to lose in the basement." },
    hexheat = { roam = false,
        why = "The board is seven platforms built over one arena and the "
           .. "colour is called to the people standing on them. A player who "
           .. "walked to the courtyard is not late for the call, they are "
           .. "outside the only place the round happens." },
    glassbridge = { roam = false,
        why = "The bridge is built over one arena and the queue waits on it. "
           .. "A player in the courtyard is not late for their turn, they are "
           .. "outside the only place the round happens." },
    hideseek = { roam = true,
        why = "Played as the whole game, the castle or one course. "
           .. "The whole game publishes no place and is never held; the castle "
           .. "is one place of three levels, so a hider may run from the grounds "
           .. "to the basement and a painting into a course puts them back; a "
           .. "course is not in the castle and is held alone." },
    greendemon = { roam = false,
        why = "The 1-UPs chase people through the round's own level. A player "
           .. "in the courtyard is out of reach of every demon, and a round "
           .. "anybody can win by leaving is not a chase." },
    oitc = { roam = false,
        why = "Deathmatch's own reason: one round in the rifle is only worth "
           .. "anything with somebody in front of it, and a castle nobody can "
           .. "be seen across is a round where the one bullet is never fired." },
    hotpotato = { roam = false,
        why = "The bomb is passed by getting close to somebody. Across three "
           .. "levels there is nobody to pass it to and the fuse decides the "
           .. "round on its own." },
    koth = { roam = false,
        why = "Kept to one place, and it is the clearest case: you "
           .. "cannot contest a hill you cannot find. The circle is drawn on "
           .. "one room and standing in it is the whole mode." },
    laststanding = { roam = false,
        why = "Kept to one place. Three lives and fists means the "
           .. "fight has to happen; five levels of never meeting anybody is a "
           .. "round decided by the clock." },
    line = { roam = false,
        why = "The finish line is pinned where the host stood and the light is "
           .. "judged against it. There is nothing to run to in the "
           .. "courtyard." },
    logroll = { roam = false,
        why = "One log, one podium and a gap between them, all built in the air "
           .. "over the one arena the round is pinned to. There is nothing to "
           .. "walk to and nothing to find: a player who leaves for the "
           .. "courtyard is not late for the log, they are outside the only "
           .. "place this round exists in." },
    manhunt = { roam = true,
        why = "One runs and everybody else hunts, which is the finding test "
           .. "exactly. A hunt is ground to cover: a runner with one room to "
           .. "use is cornered in the first minute rather than hunted. The "
           .. "second mode with `wholeGame`, so like Hide and Seek there is no "
           .. "hold left here to widen - kept rather than dropped, because a "
           .. "missing row is a decision nobody made." },
    murder = { roam = true,
        why = "The plainest example. A murderer needs a crowd to be lost in "
           .. "and a corridor to be alone with somebody in, and one castle "
           .. "room is neither of those." },
    frenzy = { roam = false,
        why = "One party arena with a slot for everybody round its middle, "
           .. "and every prop stands inward of its slot. A player in the "
           .. "castle has no slot and no Goomba to stomp." },
    simon = { roam = false,
        why = "Kept to one place. Every call is judged against the "
           .. "whole lobby at once and half of them are about the other "
           .. "players - spread out, GET TOGETHER is a two-minute walk." },
    spots = { roam = false,
        why = "One circle too few, laid on the room when the music stops. A "
           .. "circle in a level you are not in is a circle you have already "
           .. "lost." },
    sumo = { roam = false,
        why = "The ring is the mode and it closes. Everything outside the ring "
           .. "is already out, which makes the rest of the castle a very large "
           .. "way of losing." },
    smash = { roam = false,
        why = "The stage is the mode and the edge of it is the whole ending. "
           .. "Spread over five levels there is no edge to be knocked off, and "
           .. "a percentage nobody can cash in is a number that counts up for "
           .. "five minutes and decides nothing." },
    zombies = { roam = false,
        why = "The horde has to be able to reach people. A survivor who takes "
           .. "the courtyard and waits out the clock has beaten the mode "
           .. "rather than the horde." },

    bumperballs = { roam = false,
        why = "The island is one circle in one arena and the sea round it is "
           .. "the ending. There is no shore to cross in the basement, and a "
           .. "round whose only force is two bodies touching needs the bodies "
           .. "in the same arena to have a round at all." },
    bombxing = { roam = false,
        why = "The Bob-ombs walk onto one arena and chase the people on it. A "
           .. "player in another level is never chased, which is not dodging." },
    blizzard = { roam = false,
        why = "The throwers stand round one arena and aim at the people on "
           .. "it. A player in another level is never aimed at, which is not "
           .. "dodging." },
    bombsaway = { roam = false,
        why = "One island under one ship, and the shells fall on the island. "
           .. "A player on the grounds is standing where nothing is ever going "
           .. "to land, which is not a safer place in this round - it is being "
           .. "outside it while the clock pays everybody who stayed." },
    deflect = { roam = false,
        why = "The flame is sent from the middle of one arena and chases "
           .. "whoever it picks across that floor. A target who could walk "
           .. "through a door would be a target it cannot reach." },
    chompfever = { roam = false,
        why = "The platform is laid over one arena and the Chomps are loose on "
           .. "that platform. A hazard that cannot follow anybody through a "
           .. "door is a hazard the courtyard beats, and the round is nothing "
           .. "but the hazard." },
    lavaleave = { roam = false,
        why = "The plateau is one rock in one arena and the fireballs split on "
           .. "it. Spread over three levels the round becomes a walk away from "
           .. "the only thing in it, and the rock narrows for whoever stayed "
           .. "on it." },

    hotrope = { roam = false,
        why = "One rope over one floor in one arena, and the rope is the "
           .. "whole round. A player on the grounds is standing where nothing "
           .. "will ever turn, which is not a safer place in this round - it "
           .. "is being outside it while the clock pays everybody who stayed "
           .. "under the rope." },

    blast = { roam = false,
        why = "Nothing in this round is a place: the row of detonators is a "
           .. "HUD and the turn order is a number on the wire. The row is "
           .. "false rather than absent because roaming would not widen the "
           .. "round, it would only scatter the lobby that is watching it - "
           .. "and the four arenas this mode is offered on are one place by "
           .. "his own instruction." },
    prophunt = { roam = false,
        why = "The furniture is one course's furniture and the hiders are "
           .. "dressed as it. A prop standing in a level with none of the "
           .. "furniture it came from is the one thing a prop must never be - "
           .. "the only crate in sight - and the seekers have one course to "
           .. "walk rather than a castle to sweep." },

    hideballoon = { roam = false,
        why = "Every balloon is hidden and hunted on the one course the "
           .. "round picked; a player who left it for the grounds would be "
           .. "looking in a level with no balloons in it." },
    sardines = { roam = false,
        why = "The whole castle already, the same as Hide and Seek: "
           .. "`wholeGame` publishes no place, so there is no hold here to "
           .. "widen." },
}

function lockdown.roams_the_castle(modeKey)
    if type(modeKey) ~= "string" then return false end
    local row = lockdown.CASTLE_ROAM[modeKey]
    return row ~= nil and row.roam == true
end

function lockdown.castle_also(modeKey, level, alsoLevels)
    local list = {}
    for _, other in ipairs(alsoLevels or {}) do table.insert(list, other) end
    if not lockdown.roams_the_castle(modeKey) then return list end
    if not lockdown.in_the_castle(level) then return list end
    for _, other in ipairs(lockdown.CASTLE) do
        if other ~= level then table.insert(list, other) end
    end
    return list
end

function lockdown.report()
    return lockdown.is_on()
end
