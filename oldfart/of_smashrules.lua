OF = OF or {}
OF.smashrules = OF.smashrules or {}
local rules = OF.smashrules

rules.GIANT_DAMAGE = 1.5

rules.TINY_THROW = 1.5

rules.METAL_THROW = 0.7

rules.TEAM_DAMAGE = 0.5

rules.BUNNY_JUMP = 1.3

rules.SMASH_JUMP = 1.6

rules.SMASH_AIR_JUMP_VEL = 62

rules.SHORT_HOP = 0.55
rules.SHORT_HOP_FRAMES = 4
rules.JUMP_CUT_FLAG = MARIO_UNKNOWN_08 or 0x00000100

rules.FLOWER_EVERY = 30

rules.SPILL_PER_DAMAGE = 4
rules.SPILL_ROOM_BASE = 40
rules.SPILL_ROOM_EACH = 5

local part = {}
OF.gm_smash_parts = OF.gm_smash_parts or {}
table.insert(OF.gm_smash_parts, part)

local function api()
    return OF.gm_smash_api
end

local function fighting()
    local a = api()
    return a ~= nil and a.fighting()
end

local function option(key)
    return OF.gamemodes.option_now(key)
end

local worn = {}

local function wear(m, flag)
    if m == nil or flag == nil then return false end
    if not OF.util.has_flag(m.flags or 0, flag) then
        m.flags = OF.util.add_flag(m.flags or 0, flag)
    end
    local head = MARIO_CAP_ON_HEAD or 0x00000010
    if not OF.util.has_flag(m.flags or 0, head) then
        m.flags = OF.util.add_flag(m.flags or 0, head)
    end
    worn[flag] = true
    return true
end

local function unwear(m, flag)
    if m == nil or flag == nil or not worn[flag] then return false end
    worn[flag] = nil
    if OF.util.has_flag(m.flags or 0, flag) then m.flags = m.flags - flag end
    return true
end

rules.wear = wear
rules.unwear = unwear

function rules.metal_row() return option("b") == "m" end
function rules.wing_row() return option("s") == "w" end

local function take_everything_off()
    local m = gMarioStates[0]
    for flag in pairs(worn) do unwear(m, flag) end
    worn = {}
end

local flowerClock = 0

function part.damage_scale(attacker, victim)
    local scale = 1
    if option("z") == "g" then scale = scale * rules.GIANT_DAMAGE end
    if attacker ~= nil and victim ~= nil and OF.teams.in_play()
        and OF.teams.same(attacker.playerIndex, victim.playerIndex) then
        scale = scale * rules.TEAM_DAMAGE
    end
    if scale == 1 then return nil end
    return scale
end

function part.weight_scale()
    local scale = 1
    if option("z") == "t" then scale = scale * rules.TINY_THROW end
    local m = gMarioStates[0]
    if m ~= nil and OF.util.has_flag(m.flags or 0, MARIO_METAL_CAP or 0x00000004) then
        scale = scale * rules.METAL_THROW
    end
    if scale == 1 then return nil end
    return scale
end

function part.update(m)
    if m == nil or not fighting() then return nil end
    rules.short_hop(m)
    if rules.metal_row() then wear(m, MARIO_METAL_CAP) end
    if rules.wing_row() then wear(m, MARIO_WING_CAP) end
    if option("s") == "f" then
        local a = api()
        flowerClock = flowerClock + 1
        if flowerClock >= rules.FLOWER_EVERY then
            flowerClock = 0
            if a.grace() <= 0 then a.set_percent(a.percent() + 1) end
        end
    end
    return nil
end

function part.stock_lost()
    take_everything_off()
    flowerClock = 0
    return nil
end

function part.on_start()
    flowerClock = 0
    rules.shareSeen = {}
    rules.shareAsked = nil
    return nil
end

function part.cleanup()
    take_everything_off()
    rules.reach_frame(true)
    rules.hop = nil
    flowerClock = 0
    rules.coinsDown = rules.coinsDown or {}
    OF.util.coin_sweep(rules.coinsDown)
    rules.coinsDown = {}
    rules.shareSeen = {}
    rules.shareAsked = nil
    return nil
end

local JUMPS = {}
for _, act in ipairs({ ACT_JUMP, ACT_DOUBLE_JUMP, ACT_TRIPLE_JUMP,
                       ACT_BACKFLIP, ACT_SIDE_FLIP, ACT_LONG_JUMP,
                       ACT_WALL_KICK_AIR }) do
    if act ~= nil then JUMPS[act] = true end
end

function rules.bunny_jump(m)
    if m == nil or m.playerIndex ~= 0 or m.vel == nil then return false end
    if not JUMPS[m.action] then return false end
    if OF.gamemodes.current() == nil or OF.gamemodes.current().key ~= "smash" then
        return false
    end
    if not fighting() then return false end
    if (m.vel.y or 0) <= 0 then return false end

    if type(m.flags) == "number" then m.flags = m.flags & ~rules.JUMP_CUT_FLAG end
    local c = m.controller
    rules.hop = nil
    if m.action == ACT_JUMP and c ~= nil
        and OF.util.has_flag(tonumber(c.buttonDown) or 0, A_BUTTON) then
        rules.hop = rules.SHORT_HOP_FRAMES
    end
    local scale = 1
    if m.action == ACT_JUMP then
        scale = rules.SMASH_JUMP
    elseif m.action == ACT_DOUBLE_JUMP then

        m.vel.y = rules.SMASH_AIR_JUMP_VEL
    end
    if option("s") == "b" then scale = scale * rules.BUNNY_JUMP end
    if scale == 1 then return m.action == ACT_DOUBLE_JUMP end
    m.vel.y = m.vel.y * scale
    return true
end

hook_event(HOOK_ON_SET_MARIO_ACTION, function(m)
    rules.bunny_jump(m)
end)

function rules.short_hop(m)
    if rules.hop == nil or m == nil or m.vel == nil then return false end
    if m.action ~= ACT_JUMP then
        rules.hop = nil
        return false
    end
    local c = m.controller
    if c ~= nil and not OF.util.has_flag(tonumber(c.buttonDown) or 0, A_BUTTON) then
        rules.hop = nil
        if (m.vel.y or 0) > 0 then
            m.vel.y = m.vel.y * rules.SHORT_HOP
            return true
        end
        return false
    end
    rules.hop = rules.hop - 1
    if rules.hop <= 0 then rules.hop = nil end
    return false
end

rules.REACH_ATTACK = 1.6
rules.REACH_SMASH = 2.0
rules.reachBase = {}

function rules.reach_scale(m)
    if m == nil or m.action == nil then return 1 end
    if not OF.util.has_flag(m.action, ACT_FLAG_ATTACKING or (1 << 23)) then return 1 end
    if rules.swingAct == nil and OF.util.asks(OF, "gm_smash_moveset") then
        rules.swingAct = OF.gm_smash_moveset().swing or false
    end
    if rules.swingAct and m.action == rules.swingAct then
        local held = math.min(30, math.max(0, (tonumber(m.actionArg) or 0) % 100))
        return rules.REACH_ATTACK + (rules.REACH_SMASH - rules.REACH_ATTACK) * held / 30
    end
    return rules.REACH_ATTACK
end

function rules.reach_frame(allBack)
    local a = api()
    for i = 0, (MAX_PLAYERS or 16) - 1 do
        local m = gMarioStates[i]
        local np = gNetworkPlayers[i]
        local o = m ~= nil and m.marioObj or nil
        if o ~= nil then
            local scale = 1
            if not allBack and a ~= nil and np ~= nil and np.connected
                and OF.gamemodes.role(i) == a.ROLE_FIGHT then
                scale = rules.reach_scale(m)
            end
            if scale > 1 then
                if rules.reachBase[i] == nil then rules.reachBase[i] = o.hitboxRadius or 37 end
                o.hitboxRadius = rules.reachBase[i] * scale
            elseif rules.reachBase[i] ~= nil then
                o.hitboxRadius = rules.reachBase[i]
                rules.reachBase[i] = nil
            end
        end
    end
end

rules.NO_TRIPLE = {}
local function swap(from, to)
    if from ~= nil and to ~= nil then rules.NO_TRIPLE[from] = to end
end
swap(ACT_TRIPLE_JUMP, ACT_JUMP)
swap(ACT_FLYING_TRIPLE_JUMP, ACT_JUMP)
swap(ACT_SPECIAL_TRIPLE_JUMP, ACT_JUMP)
swap(ACT_FLYING, ACT_FREEFALL)

function rules.no_triple(m, action)
    if m == nil or m.playerIndex ~= 0 then return nil end
    local to = rules.NO_TRIPLE[action]
    if to == nil then return nil end
    if OF.gamemodes.current() == nil or OF.gamemodes.current().key ~= "smash" then
        return nil
    end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return nil end
    return to
end

hook_event(HOOK_BEFORE_SET_MARIO_ACTION, function(m, action)
    return rules.no_triple(m, action)
end)

rules.coinsDown = {}

function rules.spill_room()
    local n = math.max(1, #OF.util.connected_players())
    local total = rules.SPILL_ROOM_BASE + rules.SPILL_ROOM_EACH * n
    return math.max(8, math.ceil(total / n))
end

function rules.spill_of(d, held)
    local want = math.floor((tonumber(d) or 0) / rules.SPILL_PER_DAMAGE) + 1
    return math.max(0, math.min(want, math.floor(tonumber(held) or 0)))
end

function part.hit_taken(damage)
    local a = api()
    if a == nil or not a.on_coins() then return nil end
    local held = math.max(0, a.score_of(0))
    local spill = rules.spill_of(damage, held)
    if spill <= 0 then return nil end
    a.set_score(held - spill)
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return nil end
    local room = rules.spill_room() - OF.util.coin_live(rules.coinsDown)
    for _ = 1, math.min(spill, room) do
        OF.util.coin_put(rules.coinsDown,
            m.pos.x + OF.util.random_int(-60, 60), m.pos.y + 120,
            a.flat_on() and a.LINE_Z or (m.pos.z + OF.util.random_int(-60, 60)))
    end
    return nil
end

function rules.on_coin(m, obj, interactType)
    if m == nil or m.playerIndex ~= 0 then return false end
    if interactType ~= INTERACT_COIN then return false end
    local a = api()
    if a == nil or not a.on_coins() or not fighting() then return false end
    a.set_score(math.max(0, a.score_of(0)) + OF.util.coin_worth(obj))
    OF.gamemodes.cue("good", nil, "smashcoin")
    return true
end

hook_event(HOOK_ON_INTERACT, function(m, obj, interactType)
    rules.on_coin(m, obj, interactType)
end)

rules.SHARE_KEY = "ofSmashShare"
rules.shareSeen = {}
rules.shareAsked = nil
local shareSeq = 0

local function sharing()
    local said = option("t")
    return (said == "s" or said == "b") and OF.teams.in_play()
end

function rules.share_donor()
    local a = api()
    if a == nil then return nil end
    local best, bestStocks = nil, 1
    for _, entry in ipairs(OF.gamemodes.with_role(a.ROLE_FIGHT)) do
        local who = entry.localIndex
        if who ~= 0 and OF.teams.same(0, who) and OF.util.can_play(who) then
            local left = a.score_of(who)
            if left > bestStocks and entry.np ~= nil then
                best, bestStocks = entry, left
            end
        end
    end
    return best
end

local function my_global()
    local np = gNetworkPlayers[0]
    return np ~= nil and np.globalIndex or nil
end

function rules.ask_for_a_stock()
    local a = api()
    if a == nil or not sharing() or not a.on_stocks() then return false end
    if OF.gamemodes.role(0) ~= a.ROLE_OUT or rules.shareAsked ~= nil then return false end
    local donor = rules.share_donor()
    if donor == nil then return false end
    shareSeq = shareSeq + 1
    rules.shareAsked = shareSeq
    OF.util.publish_row(0, rules.SHARE_KEY,
        "ask:" .. tostring(donor.np.globalIndex) .. ":" .. tostring(shareSeq))
    return true
end

function rules.read_the_shares()
    local a = api()
    local me = my_global()
    if a == nil or me == nil then return false end
    for _, entry in ipairs(OF.util.connected_players()) do
        local who = entry.localIndex
        local row = who ~= 0 and gPlayerSyncTable[who] or nil

        local said = row ~= nil and row[rules.SHARE_KEY] or ""
        if said == nil then said = "" end
        if type(said) == "string" then
            local first = rules.shareSeen[who] == nil
            if said ~= rules.shareSeen[who] then
                rules.shareSeen[who] = said
                local word, target, n = string.match(said, "^(%a+):(%d+):(%d+)$")
                if not first and tonumber(target) == me then
                    if word == "ask" and OF.gamemodes.role(0) == a.ROLE_FIGHT
                        and sharing() and a.lend_stock() then
                        OF.util.publish_row(0, rules.SHARE_KEY, "give:"
                            .. tostring(entry.np ~= nil and entry.np.globalIndex or -1)
                            .. ":" .. tostring(n))
                        OF.notify.show("A teammate took one of your stocks", "info", 4)
                    elseif word == "give" and rules.shareAsked ~= nil
                        and tonumber(n) == rules.shareAsked then
                        rules.shareAsked = nil
                        if a.borrow_stock() then
                            OF.notify.show("Back in on a teammate's stock", "good", 4)
                            OF.gamemodes.cue("good")
                        end
                    end
                end
            end
        end
    end
    return true
end

local askAge = 0

function part.scenery()
    local a = api()
    if a == nil or OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then
        rules.reach_frame(true)
        return nil
    end
    rules.reach_frame(false)
    rules.read_the_shares()

    if rules.shareAsked ~= nil then
        askAge = askAge + 1
        if askAge > 90 then rules.shareAsked = nil end
    else
        askAge = 0
    end
    local m = gMarioStates[0]
    local c = m ~= nil and m.controller or nil
    if c ~= nil and OF.gamemodes.role(0) == a.ROLE_OUT then
        local down = tonumber(c.buttonDown) or 0
        local pressed = tonumber(c.buttonPressed) or 0
        if OF.util.has_flag(down, A_BUTTON) and OF.util.has_flag(down, B_BUTTON)
            and (OF.util.has_flag(pressed, A_BUTTON) or OF.util.has_flag(pressed, B_BUTTON)) then
            rules.ask_for_a_stock()
        end
    end
    return nil
end

function part.out_offer()
    local a = api()
    if a == nil or not sharing() or not a.on_stocks() then return nil end
    if rules.share_donor() == nil then return nil end
    return "A and B together borrow a teammate's stock"
end

function rules.ready()
    return part.damage_scale ~= nil and rules.on_coin ~= nil
        and rules.read_the_shares ~= nil
end
