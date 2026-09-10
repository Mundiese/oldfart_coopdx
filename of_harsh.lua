OF = OF or {}
OF.harsh = OF.harsh or {}

local harsh = OF.harsh

local SPEED_STOPPED = 0.5
local SPEED_TIPTOE  = 8.0
local SPEED_SLOW    = 24.0
local SPEED_WALK    = 32.0

local DAWDLE_GRACE = 30

local DAWDLE_EVERY = 8

local BONK_DAMAGE = 8

local COIN_DAMAGE = 8

local HURT_MAX = 255

local HEALTH_DEAD = 0xFF

local HEALTH_UNIT = 0x40

local HEALTH_WEDGE = 0x100

local WATER_MEND = 0x1A

local FRAMES_A_SECOND = 30

local JUMP_SCRATCH = 1
local JUMP_WEDGE = 4
local JUMP_QUARTER = 8

local STRIKE_DAMAGE = 8

local LINK_QUIET = 150

local LINK_WEDGE = 4

harsh.LIST = {

    {
        key = "coins", name = "Coins bite",
        blurb = "a coin is no longer something you want to touch",
        levels = {
            { name = "it hurts", hurt = COIN_DAMAGE },
            { name = "it kills you", kill = true },
        },
    },

    {
        key = "dawdle", name = "Keep moving",
        blurb = "go slower than this and your health drains",
        levels = {
            { name = "standing still", speed = SPEED_STOPPED },
            { name = "slower than a walk", speed = SPEED_TIPTOE },
            { name = "slower than a run", speed = SPEED_SLOW },
            { name = "slower than a full run", speed = SPEED_WALK },
        },
    },

    {
        key = "flawless", name = "Damageless",
        blurb = "get hurt and the level starts again for you",
        levels = {
            { name = "losing a whole wedge", grace = 0x100 },
            { name = "any damage at all", grace = 0 },
        },
    },

    {
        key = "bonk", name = "On a bonk",
        blurb = "hit a wall in the air and this is what it costs",
        levels = {
            { name = "it hurts", hurt = BONK_DAMAGE },
            { name = "it kills you", kill = true },
            { name = "start the level again", restart = true },

            { name = "wipe the lobby's save - every star gone", wipes = true,
              press = "A bonk wipes the lobby's save - every star gone" },
        },
    },

    {
        key = "frail", name = "Fragile",
        blurb = "the meter has a ceiling, and it is not eight wedges",
        levels = {

            { name = "six wedges", cap = 6 * HEALTH_WEDGE },
            { name = "four wedges", cap = 4 * HEALTH_WEDGE },
            { name = "two wedges", cap = 2 * HEALTH_WEDGE },

            { name = "one wedge, and the next hit is the last", cap = HEALTH_WEDGE },
        },
    },
    {
        key = "nomend", name = "Nothing mends you",
        blurb = "what you have lost, you have lost",
        levels = {

            { name = "coins and gifts do nothing", counter = true },

            { name = "nothing at all, not even the water", counter = true, ceiling = true },
        },
    },
    {
        key = "deadline", name = "The level has a deadline",
        blurb = "run out of time and the level starts again for you",
        levels = {

            { name = "five minutes", frames = 300 * FRAMES_A_SECOND },
            { name = "three minutes", frames = 180 * FRAMES_A_SECOND },
            { name = "ninety seconds", frames = 90 * FRAMES_A_SECOND },
            { name = "half a minute", frames = 30 * FRAMES_A_SECOND },
        },
    },
    {
        key = "hits", name = "Everything hits harder",
        blurb = "whatever it was that hurt you, it takes more off",
        levels = {

            { name = "half again", more = 0.5 },
            { name = "twice as much", more = 1.0 },
            { name = "three times as much", more = 2.0 },
        },
    },
    {
        key = "jumps", name = "Jumping costs you",
        blurb = "every jump you take off the ground is paid for",
        levels = {
            { name = "a scratch", hurt = JUMP_SCRATCH },
            { name = "a wedge", hurt = JUMP_WEDGE },
            { name = "a quarter of the meter", hurt = JUMP_QUARTER },
        },
    },
    {
        key = "strike", name = "Hitting back costs you",
        blurb = "beat something and the blow lands on you too",
        levels = {
            { name = "it hurts", hurt = STRIKE_DAMAGE },
            { name = "it kills you", kill = true },
        },
    },

    {
        key = "death", name = "On dying",
        blurb = "what a death costs beyond the life it already costs",
        levels = {
            { name = "a fresh start on the castle grounds", castle = true },

            { name = "wipe the lobby's save too - every star gone", wipes = true,
              press = "A death wipes the lobby's save - every star gone" },
        },
    },

    {
        key = "linked", name = "One death is everybody's",
        blurb = "when one player dies, the others pay for it too",
        levels = {
            { name = "everybody here loses a wedge", link = "here",
              hurt = LINK_WEDGE },
            { name = "everybody here dies too", link = "here", kill = true },
            { name = "everybody in the lobby dies too", link = "all",
              kill = true },
        },
    },
}

harsh.BY_KEY = {}
for _, entry in ipairs(harsh.LIST) do harsh.BY_KEY[entry.key] = entry end

function harsh.standing_drain(step)

    if step == nil or (tonumber(step.speed) or 0) <= 0 then return 0 end
    return 1 / DAWDLE_EVERY
end

function harsh.headroom(step)
    if step == nil or step.cap == nil then return nil end
    return math.floor((step.cap - HEALTH_WEDGE) / HEALTH_UNIT)
end

local function collides(capStep, drainStep)
    if capStep == nil or drainStep == nil then return false end
    local room = harsh.headroom(capStep)
    if room == nil or room > 0 then return false end
    return harsh.standing_drain(drainStep) > 0
end

function harsh.in_the_way(key, step)
    local entry = harsh.BY_KEY[key]
    if entry == nil then return nil end
    local wanted = (entry.levels or {})[math.floor(tonumber(step) or 0)]

    if wanted == nil then return nil end

    for _, other in ipairs(harsh.LIST) do
        if other.key ~= key then

            local at = harsh.lobby_at(other.key)
            local on = at > 0 and (other.levels or {})[at] or nil
            if on ~= nil and (collides(wanted, on) or collides(on, wanted)) then
                return other, on
            end
        end
    end
    return nil
end

function harsh.collision_refusal(entry, other)
    if entry == nil or other == nil then return "" end
    return OF.lang.fill(
        "@ and @ make a death loop - the lobby may have one of them.",
        OF.lang.t(entry.name), OF.lang.t(other.name))
end

local WIRE_CHUNK = 200
local WIRE_KEYS = { "ofHarsh" }

harsh.WIRE_CHUNK = WIRE_CHUNK
harsh.WIRE_KEYS = WIRE_KEYS

harsh.WIRE_KEY = WIRE_KEYS[1]

local WIRE_FIELD = "="
local WIRE_ROW = ","
local wireStamp, setAt, setNow = 0, nil, nil

local armed = {}

local function parse(text)
    local set = {}
    for piece in string.gmatch(tostring(text or ""), "[^" .. WIRE_ROW .. "]+") do
        local key, step = string.match(piece, "^(.-)" .. WIRE_FIELD .. "(%d+)$")
        local entry = key ~= nil and harsh.BY_KEY[key] or nil
        if entry ~= nil then
            step = math.floor(tonumber(step) or 0)

            local top = harsh.dial_steps(entry)
            if step > top then step = top end
            if step > 0 then set[key] = step end
        end
    end

    for _, entry in ipairs(harsh.LIST) do
        local at = set[entry.key]
        local step = at ~= nil and (entry.levels or {})[at] or nil
        if step ~= nil and harsh.standing_drain(step) > 0 then
            for _, other in ipairs(harsh.LIST) do
                local otherAt = other.key ~= entry.key and set[other.key] or nil
                local otherStep = otherAt ~= nil
                    and (other.levels or {})[otherAt] or nil
                if collides(otherStep, step) then set[entry.key] = nil end
            end
        end
    end
    return set
end

harsh.parse = parse

local function pack_parts(set)
    local parts = {}
    for _, entry in ipairs(harsh.LIST) do
        local step = set[entry.key] or 0
        if step > 0 then
            table.insert(parts,
                entry.key .. WIRE_FIELD .. tostring(step) .. WIRE_ROW)
        end
    end
    return parts
end

local function pack(set)
    return table.concat(pack_parts(set))
end

harsh.pack = pack

function harsh.text()
    return pack(harsh.room())
end

function harsh.put_text(text)
    if not OF.util.is_host() then return false end
    text = tostring(text or "")
    if harsh.text() == text then return false end
    local ok = harsh.publish_set(parse(text))
    return ok == true
end

function harsh.room()
    if setNow == nil or setAt ~= wireStamp then
        setAt = wireStamp
        setNow = parse(OF.util.joined(WIRE_KEYS))
    end
    return setNow
end

function harsh.lobby_at(key)
    local held = armed[key] or 0
    if held > 0 then return held end
    return harsh.room()[key] or 0
end

harsh.LOBBY_ONLY = {
    linked = "your death still reaches everybody else - this one is the lobby's",
}

function harsh.can_be_mine(key)
    if harsh.BY_KEY[key] == nil then return false end
    return harsh.LOBBY_ONLY[key] == nil
end

function harsh.lobby_only_why(key)
    return harsh.LOBBY_ONLY[key]
end

harsh.mine = harsh.mine or {}
harsh.mineLevel = harsh.mineLevel or {}

function harsh.mine_level(key)
    local entry = harsh.BY_KEY[key]
    if entry == nil then return 1 end
    local top = harsh.dial_steps(entry)
    if top < 1 then return 1 end
    return OF.util.clamp(math.floor(harsh.mineLevel[key] or 1), 1, top)
end

function harsh.mine_state(key)
    if not harsh.can_be_mine(key) then return nil end
    local held = harsh.mine[key]
    if held == nil then return nil end
    local roomLevel = harsh.room()[key] or 0
    if held == false then

        if roomLevel <= 0 then return nil end
        return false
    end
    if roomLevel > 0 and roomLevel == harsh.mine_level(key) then return nil end
    return true
end

function harsh.mine_any()
    for key in pairs(harsh.mine) do
        if harsh.mine_state(key) ~= nil then return true end
    end
    return false
end

function harsh.round_holds()
    if not OF.util.asks(OF.lockdown, "menu_stands_down") then return false end
    return OF.lockdown.menu_stands_down() == true
end

local function resolved(key, ignoreRound)
    if not ignoreRound and harsh.round_holds() then return 0, false end

    local state = harsh.mine_state(key)
    if state == true then return harsh.mine_level(key), true end

    if state == false then return 0, true end

    return harsh.lobby_at(key), false
end

local function capped_now(exceptKey, ignoreRound)
    for _, other in ipairs(harsh.LIST) do
        if other.key ~= exceptKey then
            local at = (resolved(other.key, ignoreRound))
            local step = at > 0 and (other.levels or {})[at] or nil
            if step ~= nil and harsh.headroom(step) == 0 then return other end
        end
    end
    return nil
end

function harsh.in_force(key, ignoreRound)
    local level, mine = resolved(key, ignoreRound)
    if level <= 0 then return level, mine end
    local entry = harsh.BY_KEY[key]
    local step = entry ~= nil and (entry.levels or {})[level] or nil
    if step ~= nil and harsh.standing_drain(step) > 0
        and capped_now(key, ignoreRound) ~= nil then
        return 0, mine
    end
    return level, mine
end

function harsh.level_is_yours(key)
    local _, mine = harsh.in_force(key)
    return mine
end

function harsh.suspended(key)
    if not harsh.round_holds() then return false end
    return (harsh.in_force(key, true)) > 0 and (harsh.in_force(key)) == 0
end

function harsh.mine_in_the_way(key, step)
    local entry = harsh.BY_KEY[key]
    if entry == nil then return nil end
    local wanted = (entry.levels or {})[math.floor(tonumber(step) or 0)]
    if wanted == nil then return nil end

    for _, other in ipairs(harsh.LIST) do
        if other.key ~= key then
            local at = (resolved(other.key, true))
            local on = at > 0 and (other.levels or {})[at] or nil
            if on ~= nil and (collides(wanted, on) or collides(on, wanted)) then
                return other, on
            end
        end
    end
    return nil
end

function harsh.settle_mine(key)
    if harsh.mine_state(key) == nil then
        harsh.mine[key] = nil
        harsh.mineLevel[key] = nil
    end
end

function harsh.set_mine(key, state)
    if harsh.BY_KEY[key] == nil then return false, "That rule is not in this build." end
    if not harsh.can_be_mine(key) then
        return false, OF.lang.t(harsh.LOBBY_ONLY[key])
    end
    if state == nil then
        harsh.mine[key] = nil
        harsh.mineLevel[key] = nil
        return true
    end
    if state == true then
        local blocked = harsh.mine_in_the_way(key, harsh.mine_level(key))
        if blocked ~= nil then
            return false, harsh.collision_refusal(harsh.BY_KEY[key], blocked)
        end
    end
    harsh.mine[key] = state == true
    if state == true and harsh.mineLevel[key] == nil then
        harsh.mineLevel[key] = 1
    end
    harsh.settle_mine(key)
    return true
end

function harsh.set_mine_level(key, level)
    local entry = harsh.BY_KEY[key]
    if entry == nil then return false, "That rule is not in this build." end
    if not harsh.can_be_mine(key) then
        return false, OF.lang.t(harsh.LOBBY_ONLY[key])
    end
    if type(level) ~= "number" then return false, "That is not a setting." end
    level = math.floor(level)
    if level <= 0 then return harsh.set_mine(key, false) end

    if level > harsh.dial_steps(entry) then
        return false, "That rule does not go that far."
    end
    local blocked = harsh.mine_in_the_way(key, level)
    if blocked ~= nil then
        return false, harsh.collision_refusal(entry, blocked)
    end
    harsh.mine[key] = true
    harsh.mineLevel[key] = level

    harsh.settle_mine(key)
    return true
end

function harsh.clear_mine()
    harsh.mine = {}
    harsh.mineLevel = {}
    return true
end

function harsh.level(key)
    return (harsh.in_force(key))
end

for _, wireKey in ipairs(WIRE_KEYS) do
    hook_on_sync_table_change(gGlobalSyncTable, wireKey, wireKey, function()
        wireStamp = wireStamp + 1
        if OF.util.asks(OF.guard, "repair") and OF.guard.repair(wireKey) then
            return
        end
    end)
end

function harsh.step_count(entry)
    if entry == nil or entry.levels == nil then return 1 end
    return #entry.levels
end

function harsh.dial_steps(entry)
    if entry == nil or entry.levels == nil then return 0 end
    local n = 0
    for _, step in ipairs(entry.levels) do
        if step.wipes then return n end
        n = n + 1
    end
    return n
end

function harsh.step(key)
    local entry = harsh.BY_KEY[key]
    local at = harsh.lobby_at(key)
    if entry == nil or at <= 0 then return nil end
    return (entry.levels or {})[at]
end

function harsh.step_name(key)
    local step = harsh.step(key)
    return step ~= nil and step.name or nil
end

function harsh.stop_name_at(key, level)
    local entry = harsh.BY_KEY[key]
    if entry == nil then return nil end
    if type(level) ~= "number" or level <= 0 then return nil end
    local step = (entry.levels or {})[level]
    return step ~= nil and step.name or nil
end

function harsh.any_on()
    for _, entry in ipairs(harsh.LIST) do
        if harsh.lobby_at(entry.key) > 0 then return true end
    end
    return false
end

function harsh.label()
    local names = {}
    for _, entry in ipairs(harsh.LIST) do
        if harsh.lobby_at(entry.key) > 0 then
            table.insert(names, OF.lang.t(entry.name))
        end
    end
    if #names == 0 then return OF.lang.t("nothing") end
    return table.concat(names, ", ")
end

function harsh.may_wipe()
    if not OF.util.asks(OF.save, "can_edit")
        or not OF.util.asks(OF.save, "set_all_stars") then
        return false, "This build cannot edit the save file."
    end
    local allowed, why = OF.save.can_edit()
    if not allowed then return false, why end
    if not OF.util.asks(OF.perms, "can") or not OF.perms.can("save_edit") then
        return false, OF.util.RANK_REFUSAL
    end
    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() then
        return false, "Not while a round, a race or a hold has the lobby."
    end
    return true
end

harsh.PACKET_INTRO = "hint"
harsh.PACKET_MINE = "hmine"
local introFrom = nil
local introWaited = 0

local INTRO_CEILING = 60 * 30

local function intro_start()

    if OF.util.flag(gServerSettings.skipIntro) == 1 then return false end
    if set_mario_action == nil then return false end
    local m = gMarioStates[0]
    if m == nil then return false end
    if gNetworkPlayers[0] == nil
        or gNetworkPlayers[0].currLevelNum ~= LEVEL_CASTLE_GROUNDS then
        return false
    end

    introFrom = OF.util.hud_room_flags()
    introWaited = 0
    set_mario_action(m, ACT_INTRO_CUTSCENE, 0)
    return true
end

local function intro_watch()
    if introFrom == nil then return end
    local m = gMarioStates[0]
    introWaited = introWaited + 1
    local over = m == nil or m.action ~= ACT_INTRO_CUTSCENE
    if not over and introWaited < INTRO_CEILING then return end
    OF.util.optional("hud_set_value", nil, HUD_DISPLAY_FLAGS, introFrom)
    introFrom = nil
    introWaited = 0
end

local function wipe_and_start_over()
    local allowed, why = harsh.may_wipe()
    if not allowed then return false, why end

    local ok, refused = OF.save.set_all_stars(false)
    if not ok then return false, refused end

    if save_file_erase ~= nil and gCurrSaveFileNum ~= nil then
        save_file_erase(gCurrSaveFileNum - 1)
    end

    local moved = false
    if OF.util.asks(OF.net, "warp_everyone") then
        moved = OF.net.warp_everyone(LEVEL_CASTLE_GROUNDS, 1, 0) == true
    end
    if not moved and OF.util.asks(OF.net, "warp_local") then
        OF.net.warp_local(LEVEL_CASTLE_GROUNDS, 1, 0)
    end

    if OF.util.flag(gServerSettings.skipIntro) == 0 then

        if OF.util.is_host() then
            OF.util.tell_all({ ofp = harsh.PACKET_INTRO })
        end
        intro_start()
    end
    return true
end

harsh.wipe_and_start_over = wipe_and_start_over

function harsh.publish_set(set)
    if not OF.util.is_host() then return false, "Only the host sets these." end

    local chunks = OF.util.chunk_parts(pack_parts(set), WIRE_CHUNK)
    if chunks == nil or #chunks > #WIRE_KEYS then
        return false, "That is too much to send to the lobby at once."
    end
    local sent = true
    for index, wireKey in ipairs(WIRE_KEYS) do
        if not OF.util.publish(wireKey, chunks[index] or "") then sent = false end
    end
    if not sent then
        return false, "That is too much to send to the lobby at once."
    end

    wireStamp = wireStamp + 1
    return true
end

function harsh.apply(key, step, askerLocal)
    if not OF.util.is_host() then return false, "Only the host sets these." end

    local entry = harsh.BY_KEY[key]
    if entry == nil then return false, "That rule is not in this build." end

    step = math.floor(tonumber(step) or 0)
    if step < 0 then step = 0 end

    local top = harsh.dial_steps(entry)
    if step > top then step = top end

    local set = harsh.room()
    if (set[key] or 0) == step then return true end

    local blocked = harsh.in_the_way(key, step)
    if blocked ~= nil then
        return false, harsh.collision_refusal(entry, blocked)
    end

    local wanted = {}
    for other, at in pairs(set) do wanted[other] = at end
    if step <= 0 then wanted[key] = nil else wanted[key] = step end

    local wasName = harsh.step_name(key)

    local ok, why = harsh.publish_set(wanted)
    if not ok then return false, why end

    local nowName = harsh.step_name(key) or "off"
    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit") then
        OF.notify.credit(askerLocal, OF.lang.fill("@: @", OF.lang.t(entry.name),
            OF.lang.t(nowName)))
    end
    OF.actionlog.by_hand(OF.util.presser(askerLocal),
        OF.lang.fill("set harsh rules: @",
            OF.lang.t(entry.name) .. ": " .. OF.lang.t(nowName)),
        wasName, nowName)
    return true
end

function harsh.set_here(asker, key, step)
    if not OF.util.is_host() then return false, "Only the host sets these." end
    if asker == nil then return false, "Who asked?" end
    if OF.perms.tier(asker) < OF.perms.required("rules") then
        return false, OF.util.RANK_REFUSAL
    end
    return harsh.apply(key, step, asker)
end

function harsh.set(key, step)
    local entry = harsh.BY_KEY[key]
    if entry == nil then return false, "That rule is not in this build." end

    step = math.floor(tonumber(step) or 0)
    if step < 0 then step = 0 end
    local top = harsh.step_count(entry)
    if step > top then step = top end

    local wanted = (entry.levels or {})[step]
    if wanted ~= nil and wanted.wipes then
        local allowed, why = harsh.may_wipe()
        if not allowed then return false, why end
        armed[key] = step
        return true
    end

    armed[key] = nil

    if not OF.perms.can("rules") then return false, OF.util.RANK_REFUSAL end

    local blocked = harsh.in_the_way(key, step)
    if blocked ~= nil then
        return false, harsh.collision_refusal(entry, blocked)
    end

    if OF.util.is_host() then return harsh.apply(key, step, 0) end
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does("harsh", key, step)
    end
    return false, "No host to ask yet - try again in a second."
end

function harsh.press_steps(entry)
    if entry == nil or entry.levels == nil then return 0 end
    local dial = harsh.dial_steps(entry)
    if dial >= #entry.levels then return dial end
    if not harsh.may_wipe() then return dial end

    for n, step in ipairs(entry.levels) do
        if step.wipes then return n end
    end
    return dial
end

function harsh.cycle(key)
    local entry = harsh.BY_KEY[key]
    if entry == nil then return false, "That rule is not in this build." end
    local top = harsh.press_steps(entry)

    local at = harsh.lobby_at(key)

    if at > top then return harsh.set(key, 0) end
    return harsh.set(key, at >= top and 0 or at + 1)
end

function harsh.clear()
    for _, entry in ipairs(harsh.LIST) do armed[entry.key] = nil end

    if not next(harsh.room()) then return true end
    if not OF.perms.can("rules") then return false, OF.util.RANK_REFUSAL end
    if OF.util.is_host() then return harsh.clear_now(0) end
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does("harshclear")
    end
    return false, "No host to ask yet - try again in a second."
end

function harsh.clear_here(asker)
    if not OF.util.is_host() then return false, "Only the host clears these." end
    if asker == nil then return false, "Who asked?" end
    if OF.perms.tier(asker) < OF.perms.required("rules") then
        return false, OF.util.RANK_REFUSAL
    end
    return harsh.clear_now(asker)
end

function harsh.clear_now(askerLocal)
    local wasLabel = harsh.label()
    local ok, why = harsh.publish_set({})
    if not ok then return false, why end
    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit") then
        OF.notify.credit(askerLocal, OF.lang.t("Every harsh setting is off"))
    end
    OF.actionlog.by_hand(OF.util.presser(askerLocal),
        OF.lang.t("set harsh rules: every one of them off"), wasLabel, nil)
    return true
end

function harsh.stand_down()
    local down = 0
    for _, entry in ipairs(harsh.LIST) do
        local at = armed[entry.key]
        local step = at ~= nil and (entry.levels or {})[at] or nil
        if step ~= nil and step.wipes then
            armed[entry.key] = nil
            down = down + 1
        end
    end
    if down > 0 then

        OF.notify.show(
            "The lobby was borrowed - the save wipe is switched off again",
            "warn", 8)
    end
    return down
end

function harsh.allowed(m)
    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() then return false end
    if not OF.util.can_play(0) then return false end
    if m == nil then return false end
    if m.action == ACT_BUBBLED then return false end
    if OF.util.has_flag(m.action or 0, ACT_FLAG_INTANGIBLE) then return false end
    return true
end

local function hurt(m, units)
    if m == nil or units == nil or units <= 0 then return false end
    m.hurtCounter = math.min(HURT_MAX, (m.hurtCounter or 0) + units)
    return true
end

local function kill(m)
    if m == nil then return false end
    m.health = HEALTH_DEAD
    return true
end

function harsh.loops_on_respawn()

    if harsh.level("nomend") > 0 then return true end

    local at = harsh.level("frail")
    if at > 0 then
        local step = (harsh.BY_KEY.frail.levels or {})[at]
        if step ~= nil and (step.cap or 0) <= HEALTH_WEDGE then return true end
    end

    return harsh.level("dawdle") > 0
end

local function put_back(moved)
    if moved ~= true then return moved end
    if not harsh.loops_on_respawn() then return moved end
    if OF.util.asks(OF.gamemodes, "give_full_health") then
        OF.gamemodes.give_full_health()
    end
    return moved
end

local function restart_level()
    if not OF.util.asks(OF.save, "reload_level") then return false end
    return put_back(OF.save.reload_level())
end

local function to_the_castle()
    if not OF.util.asks(OF.net, "warp_local") then return false end
    return put_back(OF.net.warp_local(LEVEL_CASTLE_GROUNDS, 1, 0))
end

local function punish(m, key, step)
    if step == nil then return false end

    if step.hurt ~= nil then return hurt(m, step.hurt) end
    if step.kill then return kill(m) end
    if step.restart then return restart_level() end
    if step.castle then return to_the_castle() end
    if step.wipes then

        local allowed, why = harsh.may_wipe()
        if not allowed then
            armed[key] = nil
            return OF.util.report(false, why)
        end
        armed[key] = nil
        return OF.util.report(wipe_and_start_over())
    end
    return false
end

hook_event(HOOK_ON_INTERACT, function(m, obj, interactType)
    if m == nil or m.playerIndex ~= 0 then return end
    if interactType ~= INTERACT_COIN then return end
    local at = harsh.level("coins")
    if at <= 0 then return end
    if not harsh.allowed(m) then return end
    punish(m, "coins", (harsh.BY_KEY.coins.levels or {})[at])
end)

local dawdleFrames = 0
local dawdleSince = 0

local function dawdle_reset()
    dawdleFrames = 0
    dawdleSince = 0
end

local function dawdle(m)
    local at = harsh.level("dawdle")
    if at <= 0 then return dawdle_reset() end

    local step = (harsh.BY_KEY.dawdle.levels or {})[at]
    if step == nil or step.speed == nil then return dawdle_reset() end

    local speed = math.abs(tonumber(m.forwardVel) or 0)
    if speed >= step.speed then return dawdle_reset() end

    dawdleFrames = dawdleFrames + 1
    if dawdleFrames <= DAWDLE_GRACE then return false end

    dawdleSince = dawdleSince + 1
    if dawdleSince < DAWDLE_EVERY then return false end
    dawdleSince = 0
    return hurt(m, 1)
end

local lastHealth = nil

local function flawless(m)
    local at = harsh.level("flawless")
    if at <= 0 then lastHealth = nil return false end

    local step = (harsh.BY_KEY.flawless.levels or {})[at]
    local health = tonumber(m.health)
    if step == nil or health == nil then lastHealth = nil return false end

    local was = lastHealth
    lastHealth = health
    if was == nil then return false end

    if was - health <= (step.grace or 0) then return false end

    lastHealth = nil
    return restart_level()
end

local function frail(m)
    local at = harsh.level("frail")
    if at <= 0 then return false end
    local step = (harsh.BY_KEY.frail.levels or {})[at]
    if step == nil or step.cap == nil then return false end
    local health = tonumber(m.health) or 0
    if health <= step.cap then return false end
    m.health = step.cap

    lastHealth = nil
    return true
end

local mendFloor = nil

local function mend_reset()
    mendFloor = nil
end

local function nomend(m)
    local at = harsh.level("nomend")
    if at <= 0 then return mend_reset() end
    local step = (harsh.BY_KEY.nomend.levels or {})[at]
    if step == nil then return mend_reset() end

    if step.counter then m.healCounter = 0 end

    if not step.ceiling then return mend_reset() end

    local health = tonumber(m.health) or 0
    if health < HEALTH_WEDGE then return mend_reset() end
    if mendFloor == nil or health < mendFloor then mendFloor = health end
    if health > mendFloor then
        m.health = mendFloor

        lastHealth = nil
        return true
    end
    return false
end

local deadlineFrames = 0

local function deadline(m)
    local at = harsh.level("deadline")
    if at <= 0 then
        deadlineFrames = 0
        return false
    end
    local step = (harsh.BY_KEY.deadline.levels or {})[at]
    if step == nil or step.frames == nil then
        deadlineFrames = 0
        return false
    end

    deadlineFrames = deadlineFrames + 1
    if deadlineFrames < step.frames then return false end

    deadlineFrames = 0

    if OF.util.asks(OF.notify, "show") then
        OF.notify.show("Out of time - the level starts again", "bad", 5)
    end
    return restart_level()
end

function harsh.deadline_left()
    local at = harsh.level("deadline")
    if at <= 0 then return nil end
    local step = (harsh.BY_KEY.deadline.levels or {})[at]
    if step == nil or step.frames == nil then return nil end
    local left = step.frames - deadlineFrames
    if left < 0 then left = 0 end
    return left
end

local DEADLINE_WARN = 30 * FRAMES_A_SECOND
local DEADLINE_LAST = 10 * FRAMES_A_SECOND

local function deadline_text(left)

    local seconds = math.ceil(left / FRAMES_A_SECOND)
    return string.format("%.0f:%02.0f", (seconds - seconds % 60) / 60,
        seconds % 60)
end

local function render_deadline()
    local left = harsh.deadline_left()
    if left == nil then return end

    if OF.util.menu_has_screen() then return end
    if not OF.util.asks(OF.util, "banner") then return end

    local r, g, b = OF.util.gold().r, OF.util.gold().g, OF.util.gold().b
    if left <= DEADLINE_LAST then
        r, g, b = 255, 96, 96
    elseif left <= DEADLINE_WARN then
        r, g, b = 255, 176, 96
    end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)
    OF.util.banner(deadline_text(left), 1.1, r, g, b, 255, {
        under = { text = OF.lang.t("out of time and the level starts again"),
                  scale = 0.7 },
    })
end

hook_event(HOOK_ON_HUD_RENDER, render_deadline)

local hitMark = nil

local function harder(m)
    local now = tonumber(m.hurtCounter) or 0
    local at = harsh.level("hits")
    if at <= 0 then
        hitMark = now
        return false
    end
    local step = (harsh.BY_KEY.hits.levels or {})[at]
    if step == nil or step.more == nil then
        hitMark = now
        return false
    end

    local mark = hitMark
    if mark == nil then
        hitMark = now
        return false
    end

    local floorMark = mark > 0 and (mark - 1) or 0
    local rise = now - floorMark
    if rise <= 0 then return false end

    return hurt(m, math.floor(rise * step.more))
end

local JUMP_ACTIONS = {}

;(function()
    local any = { ACT_JUMP, ACT_DOUBLE_JUMP, ACT_TRIPLE_JUMP, ACT_BACKFLIP,
                  ACT_SIDE_FLIP, ACT_LONG_JUMP, ACT_WALL_KICK_AIR }
    for i = 1, 7 do
        if any[i] ~= nil then JUMP_ACTIONS[any[i]] = true end
    end
end)()

function harsh.jump_actions()
    local said = {}
    for action in pairs(JUMP_ACTIONS) do said[action] = true end
    return said
end

local lastJumpAction = nil

local function jumps(m)
    local action = m.action
    local was = lastJumpAction
    lastJumpAction = action

    local at = harsh.level("jumps")
    if at <= 0 then return false end
    local step = (harsh.BY_KEY.jumps.levels or {})[at]
    if step == nil or step.hurt == nil then return false end

    if action == was then return false end
    if JUMP_ACTIONS[action] ~= true then return false end

    return hurt(m, step.hurt)
end

hook_event(HOOK_ON_ATTACK_OBJECT, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    local at = harsh.level("strike")
    if at <= 0 then return end
    if not harsh.allowed(m) then return end
    punish(m, "strike", (harsh.BY_KEY.strike.levels or {})[at])
end)

local lastAction = nil

local BONK_FIRE = {}
local BONK_GATED = {}
local BONK_QUIET = {}

;(function()
    local fire = { ACT_AIR_HIT_WALL, ACT_GROUND_BONK }
    local gated = { ACT_BACKWARD_AIR_KB }

    local quiet = { ACT_SOFT_BONK, ACT_BACKWARD_GROUND_KB,
                    ACT_SOFT_BACKWARD_GROUND_KB, ACT_HARD_BACKWARD_GROUND_KB,
                    ACT_FORWARD_GROUND_KB, ACT_SOFT_FORWARD_GROUND_KB,
                    ACT_HARD_FORWARD_GROUND_KB, ACT_FORWARD_AIR_KB,
                    ACT_HARD_FORWARD_AIR_KB, ACT_HARD_BACKWARD_AIR_KB }
    for i = 1, 2 do
        if fire[i] ~= nil then BONK_FIRE[fire[i]] = true end
    end
    if gated[1] ~= nil then BONK_GATED[gated[1]] = true end
    for i = 1, 10 do
        if quiet[i] ~= nil then BONK_QUIET[quiet[i]] = true end
    end
    for action in pairs(BONK_FIRE) do BONK_QUIET[action] = true end
    for action in pairs(BONK_GATED) do BONK_QUIET[action] = true end
end)()

function harsh.bonk_actions()
    local said = {}
    for action in pairs(BONK_FIRE) do said[action] = "always" end
    for action in pairs(BONK_GATED) do said[action] = "unhurt" end
    return said
end

local function bonk(m)
    local action = m.action
    local was = lastAction
    lastAction = action

    local at = harsh.level("bonk")
    if at <= 0 then return false end

    if action == was then return false end
    if BONK_QUIET[was] == true then return false end

    if BONK_FIRE[action] ~= true then
        if BONK_GATED[action] ~= true then return false end

        if (tonumber(m.hurtCounter) or 0) ~= 0 then return false end
        if (tonumber(m.knockbackTimer) or 0) ~= 0 then return false end
    end

    return punish(m, "bonk", (harsh.BY_KEY.bonk.levels or {})[at])
end

harsh.PACKET_DIED = "hdied"
harsh.PACKET_LINK = "hlink"
local linkQuiet = 0

local linkCool = {}

local function link_tick()
    if linkQuiet > 0 then linkQuiet = linkQuiet - 1 end
    for scope, left in pairs(linkCool) do
        if left <= 1 then linkCool[scope] = nil else linkCool[scope] = left - 1 end
    end
end

local function link_here(level, area, who)
    local at = harsh.level("linked")
    if at <= 0 then return false end
    local step = (harsh.BY_KEY.linked.levels or {})[at]
    if step == nil then return false end

    if step.link ~= "all" then
        local np = gNetworkPlayers[0]
        if np == nil then return false end
        if np.currLevelNum ~= math.floor(tonumber(level) or -1) then return false end
        if np.currAreaIndex ~= math.floor(tonumber(area) or -1) then return false end
    end

    local m = gMarioStates[0]
    if not harsh.allowed(m) then return false end

    if linkQuiet > 0 then return false end
    linkQuiet = LINK_QUIET

    local whoGlobal = math.floor(tonumber(who) or -1)
    local whoLocal = (whoGlobal >= 0 and whoGlobal < MAX_PLAYERS)
        and OF.util.local_from_global(whoGlobal) or nil
    local name = whoLocal ~= nil and gNetworkPlayers[whoLocal] ~= nil
        and gNetworkPlayers[whoLocal].name or nil
    if OF.util.asks(OF.notify, "show") then
        if name ~= nil then
            OF.notify.show("@ died, and you were linked to it", "bad", 4, name)
        else
            OF.notify.show("Somebody died, and you were linked to it", "bad", 4)
        end
    end

    return punish(m, "linked", step)
end

local function link_from(localIndex)
    if not OF.util.is_host() then return false end

    local at = harsh.level("linked")
    if at <= 0 then return false end
    local step = (harsh.BY_KEY.linked.levels or {})[at]
    if step == nil then return false end

    local np = gNetworkPlayers[localIndex]
    if np == nil or not np.connected then return false end

    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() then return false end
    if not OF.util.can_play(localIndex) then return false end

    local level = math.floor(tonumber(np.currLevelNum) or 0)
    local area = math.floor(tonumber(np.currAreaIndex) or 0)

    local scope = (step.link == "all") and "*" or (level .. ":" .. area)
    if (linkCool[scope] or 0) > 0 then return false end
    linkCool[scope] = LINK_QUIET

    local who = network_global_index_from_local(localIndex)
    OF.util.tell_all({ ofp = harsh.PACKET_LINK,
        lvl = level, ar = area, w = who })

    link_here(level, area, who)
    return true
end

local function link_announce()
    if harsh.level("linked") <= 0 then return false end

    if linkQuiet > 0 then return false end
    linkQuiet = LINK_QUIET

    if OF.util.is_host() then return link_from(0) end
    return OF.util.send_to_host({ ofp = harsh.PACKET_DIED }) == true
end

harsh.link_here = link_here
harsh.link_from = link_from

local function link_forget()
    linkQuiet = 0
end

hook_event(HOOK_ON_DEATH, function(m)
    if m == nil or m.playerIndex ~= 0 then return end

    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() then return end
    if not OF.util.can_play(0) then return end

    link_announce()

    local at = harsh.level("death")
    if at <= 0 then return end
    punish(m, "death", (harsh.BY_KEY.death.levels or {})[at])
end)

local function heartbeat(m)
    if m == nil or m.playerIndex ~= 0 then return end

    link_tick()

    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() then
        harsh.stand_down()
    end

    if not harsh.allowed(m) then
        dawdle_reset()
        lastHealth = nil
        lastAction = m.action

        mend_reset()
        deadlineFrames = 0
        hitMark = m.hurtCounter
        lastJumpAction = m.action
        return true
    end

    harder(m)

    dawdle(m)

    frail(m)
    nomend(m)

    flawless(m)
    bonk(m)
    jumps(m)

    deadline(m)

    hitMark = tonumber(m.hurtCounter) or 0
end

hook_event(HOOK_MARIO_UPDATE, heartbeat)

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil then return end

    if data.ofp == harsh.PACKET_INTRO then
        if not OF.util.from_host(data) then return end
        intro_start()
        return
    end

    if data.ofp == harsh.PACKET_LINK then
        if not OF.util.from_host(data) then return end
        link_here(data.lvl, data.ar, data.w)
        return
    end

    if data.ofp == harsh.PACKET_MINE then
        if not OF.util.from_host(data) then return end
        if data.what == "clearmine" then

            local had = harsh.mine_any()
            harsh.clear_mine()
            if had and OF.util.asks(OF.notify, "show") then
                OF.notify.show("The host cleared your own harsh settings",
                    "info", 4)
            end
        end
        return
    end

    if data.ofp == harsh.PACKET_DIED then
        local askerLocal = OF.util.asked_by(data)
        if askerLocal == nil then return end
        link_from(askerLocal)
        return
    end
end)

hook_event(HOOK_UPDATE, function()
    intro_watch()
end)

hook_event(HOOK_ON_LEVEL_INIT, function()
    dawdle_reset()
    lastHealth = nil
    lastAction = nil

    mend_reset()
    deadlineFrames = 0
    hitMark = nil
    lastJumpAction = nil

    link_forget()
end)

function harsh.two_box_row(panel, entry)
    local key = entry.key
    local dial = harsh.dial_steps(entry)
    local roomAt = harsh.lobby_at(key)
    local room = roomAt > 0
    local level, yours = harsh.in_force(key)
    local lit = level > 0

    local r, g, b = 255, 255, 255
    if lit then r, g, b = OF.util.gold().r, OF.util.gold().g, OF.util.gold().b end

    local title = OF.lang.t(entry.name)

    local press = harsh.press_steps(entry)
    local nextAt = (roomAt >= press) and 0 or (roomAt + 1)
    local inTheWay = harsh.in_the_way(key, nextAt)
    local helpLine = OF.lang.t(entry.blurb)
    if inTheWay ~= nil then
        helpLine = OF.lang.fill(
            "@ is on - the next stop would be a death loop",
            OF.lang.t(inTheWay.name))
    end

    if harsh.suspended(key) then
        helpLine = OF.lang.t("Put away until the round ends - your setting is kept.")
    end

    local stop = lit and harsh.stop_name_at(key, level) or nil
    if stop ~= nil then stop = OF.lang.t(stop) end
    if stop == nil and lit then stop = OF.lang.t("on") end

    if not harsh.can_be_mine(key) then
        local one = panel.with_help(
            panel.gated_row("rules", panel.tick(room, title), r, g, b,
                function() OF.util.report(harsh.cycle(key)) end),
            OF.lang.t(harsh.LOBBY_ONLY[key]))
        one = panel.with_right(one, stop or "")
        if dial > 1 then
            one = panel.with_slider(one, math.min(roomAt, dial), dial,
                function(wanted) OF.util.report(harsh.set(key, wanted)) end)
        end
        return one
    end

    local mine = harsh.mine_state(key)

    local built = panel.with_help(panel.two_box({
        lobbyOn = room,

        mineBox = panel.mine_shown(mine, room),
        name = title,

        lobbyNeed = "rules",
        mineNeed = "harsh_self",
        r = r, g = g, b = b,

        onLobby = function() OF.util.report(harsh.cycle(key)) end,

        onMine = function()
            local want = panel.next_mine_level(mine,
                harsh.mine_level(key), dial, roomAt)
            if want == nil then
                OF.util.report(harsh.set_mine(key, nil))
                return
            end
            OF.util.report(harsh.set_mine_level(key, want))
        end,
    }), helpLine)

    local nextStep = (entry.levels or {})[roomAt + 1]
    if roomAt < press and nextStep ~= nil and nextStep.wipes == true then
        built.r, built.g, built.b = 200, 120, 120
        built.help = OF.lang.t(nextStep.press)

        built = panel.with_confirm(built, "harsh" .. key)
    end

    local column = panel.two_box_level(stop, yours)
    if mine == false then

        column = panel.two_box_level(OF.lang.t("off"), true)
    end
    built = panel.with_right(built, column or "")

    if dial > 1 then

        local dialsRoom = (mine == nil) and panel.may("rules")
        local need = dialsRoom and "rules" or "harsh_self"
        local at = dialsRoom and roomAt or (mine == false and 0 or level)
        at = math.min(at, dial)
        if panel.may(need) then
            built = panel.with_slider(built, at, dial, function(wanted)
                if dialsRoom then
                    OF.util.report(harsh.set(key, wanted))
                else

                    OF.util.report(harsh.set_mine_level(key, wanted))
                end
            end)
        else

            built = panel.with_slider(built, at, dial, nil)
        end
    end

    return built
end

function harsh.build_page(panel)
    local rows = {}

    table.insert(rows, panel.with_help(
        panel.label_row(OF.lang.fill("On: @", harsh.label())),
        OF.lang.t("every harsh setting the lobby is playing under right now")))

    table.insert(rows, panel.with_help(panel.label_row(
        OF.lang.t("A ticks the lobby's box, Z ticks yours.")),
        OF.lang.t("what you set for yourself beats what the lobby set")))

    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() then
        table.insert(rows, panel.label_row(
            OF.lang.t("A round has the lobby - these are waiting for it to end.")))
    end

    table.insert(rows, panel.with_help(panel.gated_row("rules",
        OF.lang.t("Turn every harsh setting off"),
        255, 140, 90, function() OF.util.report(harsh.clear()) end),
        OF.lang.t("the lobby's half of the page back to nothing, in one press")))

    for _, entry in ipairs(harsh.LIST) do
        table.insert(rows, harsh.two_box_row(panel, entry))

    end

    for _, r in ipairs(OF.util.asks(OF.modifiers, "build_rows")
            and OF.modifiers.build_rows(panel, "harsh") or {}) do
        table.insert(rows, r)
    end

    table.insert(rows, panel.back_row())
    return rows
end

hook_event(HOOK_ON_MODS_LOADED, function()
    local panel = OF.panel
    if panel == nil or type(panel.PAGES) ~= "table" then return end
    if panel.PAGES.harsh ~= nil then return end

    panel.PAGES.harsh = {
        title = "What a mistake costs", tab = "room", up = "roomrules",
        build = function() return harsh.build_page(panel) end,
    }
end)

function harsh.report()
    local on = {}
    for _, entry in ipairs(harsh.LIST) do

        local at = harsh.lobby_at(entry.key)
        if at > 0 then
            table.insert(on, entry.key .. ":" .. at)
        end
    end
    return table.concat(on, " ")
end
