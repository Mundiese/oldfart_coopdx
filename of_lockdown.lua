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
    return string.find(reasons(), letter, 1, true) ~= nil
end

function lockdown.held_by_round() return has_reason(lockdown.ROUND) end
function lockdown.held_by_host()  return has_reason(lockdown.HOST) end
function lockdown.held_by_race()  return has_reason(lockdown.RACE) end

function lockdown.on()
    return reasons() ~= ""
end

function lockdown.round_or_run()
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

function lockdown.menu_stands_down()
    if lockdown.round_or_run() then return true end
    return lockdown.on()
end

local heldSwitches = nil

local heldPalettes = nil

local askedMovesets = false

function lockdown.is_on()
    return reasons() ~= ""
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

    if remember then

        if OF.util.asks(OF.fresh, "take_all") then
            heldSwitches = OF.fresh.take_all()
        end

        if OF.util.asks(OF.perms, "set_lockdown") then
            OF.perms.set_lockdown(true)
        end

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

    if wasOn and not nowOn then
        if OF.util.asks(OF.perms, "set_lockdown") then
            OF.perms.set_lockdown(false)
        end

        if OF.util.asks(OF.modifiers, "publish_round") then
            OF.modifiers.publish_round("")
        end

        if OF.util.asks(OF.rules, "round_release") then
            OF.rules.round_release()
        end

        if OF.util.asks(OF.rules, "apply") then OF.rules.apply() end

        if heldSwitches ~= nil then
            local store = heldSwitches

            heldSwitches = nil
            if OF.util.asks(OF.fresh, "give_back_all") then
                OF.fresh.give_back_all(store)
            end
        end
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
    local first = not lockdown.is_on()
    if not set_reason(lockdown.ROUND, true) then return false end
    if first then
        OF.notify.send_all("Round rules: everything is off and the lobby is the host's",
            "info", 5)
    end
    roundName = round_name()
    if roundName ~= nil then
        log_auto("a round of @ took the rules and every rank", roundName)
    else
        log_auto("a round took the rules and every rank")
    end
    return true
end

function lockdown.arm_race()
    if lockdown.held_by_race() then return false end
    local first = not lockdown.is_on()
    if not set_reason(lockdown.RACE, true) then return false end
    if first then
        OF.notify.send_all("Race rules: everything is off and the lobby is the host's",
            "info", 5)
    end
    log_auto("a race took the rules and every rank")
    return true
end

function lockdown.lift_race()
    if not lockdown.held_by_race() then return false end
    if not set_reason(lockdown.RACE, false) then return false end
    if not lockdown.is_on() then
        OF.notify.send_all("Race over: the lobby is yours again", "good", 5)
    end
    log_auto("a race ended and gave the lobby back")
    return true
end

function lockdown.lift()
    if not lockdown.held_by_round() then return false end
    if not set_reason(lockdown.ROUND, false) then return false end
    if not lockdown.is_on() then
        OF.notify.send_all("Round over: the lobby is yours again", "good", 5)
    end

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

    local running = OF.gamemodes.is_running()
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
        and OF.perms.lockdown ~= lockdown.is_on() then
        OF.perms.set_lockdown(lockdown.is_on())
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

function lockdown.refuses_dialog(dialogId)
    if not text_is_taken() then return false end
    return not is_the_star_box(dialogId)
end

hook_event(HOOK_ON_DIALOG, function(dialogId)
    if lockdown.refuses_dialog(dialogId) then return false end
end)

local SPECIAL_CAPS = { id_bhvWingCap, id_bhvMetalCap, id_bhvVanishCap }

local function round_caps_are_the_round()
    if not lockdown.held_by_round() then return false end
    if not OF.util.asks(OF.gamemodes, "current") then return false end
    local mode = OF.gamemodes.current()
    return mode ~= nil and mode.wantsCaps == true
end

lockdown.round_caps_are_the_round = round_caps_are_the_round

function lockdown.refuses_cap(o)
    if o == nil then return false end
    if not lockdown.held_by_round() then return false end

    if lockdown.caps_unlocked() then return false end

    if round_caps_are_the_round() then return false end
    for _, id in ipairs(SPECIAL_CAPS) do
        if id ~= nil
            and OF.util.optional("obj_has_behavior_id", 0, o, id) ~= 0 then
            return true
        end
    end
    return false
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
    return round_keeps_the_level()
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

    meltdown = { roam = false,
        why = "The floor that burns is laid on one level, and the flagpole the "
           .. "run ends at stands in the same room. A basement with no fire in "
           .. "it is a route the course was never measured over." },
    shellrace = { roam = false,
        why = "A start and a flagpole are two points in one room, and the line "
           .. "between them is the round. Spread it over three levels and it "
           .. "stops being a race and becomes a walk between two of them." },
    bank = { roam = false,
        why = "The vault is one object in one room and a coin only counts once "
           .. "it is carried home. Five levels of walk-in is five different "
           .. "lengths of the same errand." },
    bossrush = { roam = false,
        why = "Every runner is in their own copy of their own Bowser arena, "
           .. "and the hold already carries the stage's second level. No part "
           .. "of this round is ever in the castle." },
    bounty = { roam = false,
        why = "A knockdown drops a tag where it fell and the scramble for it "
           .. "is the round. A tag lying in a room nobody is in is a tag "
           .. "nobody contests." },
    coinrush = { roam = false,
        why = "Named against it by the host. The rain falls on the room the "
           .. "round is pinned to, so anybody in the courtyard is standing "
           .. "where no coins land." },
    crown = { roam = false,
        why = "The crown is worn in the open and taken with a fist. Given "
           .. "three levels the wearer keeps it by being somewhere else, which "
           .. "is a different game from wearing it the longest." },
    ctf = { roam = false,
        why = "Two bases, both pinned in one level. A flag carried out of the "
           .. "front door is a flag on a walk nobody can cut off." },
    domination = { roam = false,
        why = "Three points laid on the room everybody is in. A point in a "
           .. "level nobody is in scores for whoever last wandered past it." },
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
    hideseek = { roam = false,
        why = "The one mode that has the whole game and keeps it. `wholeGame` "
           .. "publishes no place, so there is no hold here to widen - written "
           .. "down rather than left out, because a missing row is a decision "
           .. "nobody made." },
    hotpotato = { roam = false,
        why = "The bomb is passed by getting close to somebody. Across three "
           .. "levels there is nobody to pass it to and the fuse decides the "
           .. "round on its own." },
    koth = { roam = false,
        why = "Named against it by the host, and it is the clearest case: you "
           .. "cannot contest a hill you cannot find. The circle is drawn on "
           .. "one room and standing in it is the whole mode." },
    laststanding = { roam = false,
        why = "Named against it by the host. Three lives and fists means the "
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
        why = "The host's own example. A murderer needs a crowd to be lost in "
           .. "and a corridor to be alone with somebody in, and one castle "
           .. "room is neither of those." },
    secretrun = { roam = false,
        why = "Five secret courses with one runner each. The round is never "
           .. "played in the castle and the hold it uses is the course's "
           .. "own." },
    simon = { roam = false,
        why = "Named against it by the host. Every call is judged against the "
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
    zombies = { roam = false,
        why = "The horde has to be able to reach people. A survivor who takes "
           .. "the courtyard and waits out the clock has beaten the mode "
           .. "rather than the horde." },
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
