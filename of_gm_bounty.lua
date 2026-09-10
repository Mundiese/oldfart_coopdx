OF = OF or {}

local TAG_AT   = "ofBountyAt"
local TAG_TO   = "ofBountyTo"
local TAG_SEQ  = "ofBountySeq"
local TARGET_KEY = "ofBountyTarget"
local ROLE_HUNTING = "hunting"
local TAG_RANGE = 190
local TAG_LIFE = 12 * 30

local TAG_ARM = 20
local HIT_GRACE = 2 * 30
local TARGET_TAGS = 8

local BOUNTY_STEP = 3
local BOUNTY_MAX = 4

local tag = nil
local grace = 0
local gaveSeq = 0
local seenGave = {}

local seenWorth = {}

local function score_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    return (row ~= nil and row.ofScore) or 0
end

local function worth_of(localIndex)
    local extra = math.floor(score_of(localIndex) / BOUNTY_STEP)
    return math.floor(OF.util.clamp(1 + extra, 1, BOUNTY_MAX))
end

local function pack_point(spot)
    if spot == nil then return "" end
    return string.format("%.0f %.0f %.0f %.0f %.0f %.0f", spot.x, spot.y,
        spot.z, spot.level or 0, spot.area or 1, spot.worth or 1)
end

local function unpack_point(text)
    if type(text) ~= "string" or text == "" then return nil end
    local x, y, z, level, area, worth = text:match(
        "^(%-?[%d%.]+) (%-?[%d%.]+) (%-?[%d%.]+) (%-?[%d%.]+) (%-?[%d%.]+)"
        .. " (%-?[%d%.]+)$")
    if x == nil then return nil end
    return { x = tonumber(x), y = tonumber(y), z = tonumber(z),
             level = tonumber(level), area = tonumber(area),
             worth = tonumber(worth) or 1 }
end

local function hunters()
    local list = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_HUNTING)) do
        if OF.util.can_play(entry.localIndex) then table.insert(list, entry) end
    end
    return list
end

local function target_tags()
    local value = gGlobalSyncTable[TARGET_KEY]
    if type(value) ~= "number" or value <= 0 then return TARGET_TAGS end
    return value
end

local mode = {
    key = "bounty",

    name = "Kill Confirmed",
    blurb = "a knockdown drops a tag - pick it up, or deny your own",
    blurbTeams = "knock them down and hold the ground - most tags wins",
    how = "A knockdown scores you nothing on its own.\n"
        .. "It drops a tag worth a point to whoever takes it.\n"
        .. "Take your own tag back and nobody gets it.\n"
        .. "The further ahead you are, the more yours is worth.\n"
        .. "Nobody dies - a knockdown is the whole of it.\n"
        .. "First to the target wins; on the clock, the most.",
    minPlayers = 2,

    maps = OF.gamemodes.ARENA_SET,

    room = { sweep = { "cannons" }, rules = { waterheal = 1 } },
    defaultLimit = 300,
    music = SEQ_LEVEL_BOSS_KOOPA,
    teams = true,
    target = { name = "tags to win",
               asks = "How many tags win the round",
               default = TARGET_TAGS,
               min = 3, max = 25, step = 1 },
}

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_HUNTING)
    end
    OF.util.publish(TARGET_KEY, math.floor(tonumber(options ~= nil
        and options.target) or TARGET_TAGS))

    OF.util.report(OF.rules.lend("interactions", "bounty",
        PLAYER_INTERACTIONS_PVP))
end

function mode.late_join(localIndex)
    return ROLE_HUNTING
end

function mode.on_start()
    tag, grace, gaveSeq, seenGave, seenWorth = nil, 0, 0, {}, {}
    OF.util.publish_row(0, TAG_AT, "")
    OF.util.publish_row(0, TAG_TO, -1)
    OF.util.publish_row(0, TAG_SEQ, 0)
    OF.util.publish_row(0, "ofScore", 0)
end

local function on_pvp_attack(attacker, victim)
    if victim == nil or victim.playerIndex ~= 0 then return end
    if OF.gamemodes.current() ~= mode then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if not OF.util.can_play(0) then return end
    if grace > 0 then return end

    if OF.teams.in_play() and attacker ~= nil and attacker.playerIndex ~= nil
        and OF.teams.same(0, attacker.playerIndex) then
        return
    end
    grace = HIT_GRACE

    local m = gMarioStates[0]
    local np = gNetworkPlayers[0]
    if m == nil or m.pos == nil or np == nil then return end

    tag = { x = m.pos.x, y = m.pos.y + 40, z = m.pos.z,
            level = np.currLevelNum, area = np.currAreaIndex,
            frames = TAG_LIFE, arming = TAG_ARM, worth = worth_of(0) }
    OF.util.publish_row(0, TAG_AT, pack_point(tag))
    if tag.worth > 1 then
        OF.notify.show("You dropped a tag worth @ - stand on it to deny it",
            "warn", 5, tostring(tag.worth))
    else
        OF.notify.show("You dropped a tag - stand on it to deny it", "warn", 5)
    end
end

hook_event(HOOK_ON_PVP_ATTACK, on_pvp_attack)

local function step_the_grace()
    if grace > 0 then grace = grace - 1 end
end

function mode.scenery()
    step_the_grace()
    for _, entry in ipairs(OF.util.connected_players()) do
        local name = "bounty" .. entry.localIndex
        local spot = unpack_point(gPlayerSyncTable[entry.localIndex][TAG_AT])

        if not OF.util.can_play(entry.localIndex) then spot = nil end
        if spot == nil then
            OF.gamemodes.hide_token(name)
        else
            OF.gamemodes.mark_place(name, E_MODEL_STAR, spot, 0x400)
        end
    end
end

local FULL_HEALTH = 0x880

function mode.update()

    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    if OF.gamemodes.role(0) == ROLE_HUNTING and OF.util.can_play(0) then
        local m = gMarioStates[0]
        if m ~= nil then
            if (m.health or 0) < FULL_HEALTH then m.health = FULL_HEALTH end
            m.hurtCounter = 0
            if m.pos ~= nil then m.peakHeight = m.pos.y end
        end
    end

    if tag ~= nil then
        tag.frames = tag.frames - 1
        if tag.arming > 0 then
            tag.arming = tag.arming - 1
            return
        end

        local best, bestAt = nil, nil
        for _, entry in ipairs(hunters()) do
            local distance = OF.gamemodes.distance_to_place(tag, entry.localIndex)
            if distance ~= nil and distance <= TAG_RANGE
                and (bestAt == nil or distance < bestAt) then
                best, bestAt = entry, distance
            end
        end

        if best ~= nil then
            gaveSeq = gaveSeq + 1
            OF.util.publish_row(0, TAG_TO, best.np.globalIndex)
            OF.util.publish_row(0, TAG_SEQ, gaveSeq)
            OF.util.publish_row(0, TAG_AT, "")
            if best.localIndex == 0 then
                OF.notify.show("Denied - nobody gets that @", "good", 4,
                    tag.worth > 1 and OF.lang.fill("@-tag",
                        tostring(tag.worth)) or OF.lang.t("one"))
            end
            tag = nil
        elseif tag.frames <= 0 then

            OF.util.publish_row(0, TAG_AT, "")
            tag = nil
        end
    end

    for _, entry in ipairs(OF.util.connected_players()) do
        local index = entry.localIndex
        if index ~= 0 then
            local row = gPlayerSyncTable[index]

            local seq = row[TAG_SEQ] or 0
            if seq > 0 and seq ~= seenGave[index] then
                seenGave[index] = seq
                if row[TAG_TO] == gNetworkPlayers[0].globalIndex then
                    local won = seenWorth[index] or 1
                    OF.util.publish_row(0, "ofScore", score_of(0) + won)
                    OF.notify.show("Tag claimed - @ tag(s)", "good", 3,
                        tostring(won))
                    OF.sounds.play(SOUND_MENU_COLLECT_SECRET)
                end
                seenWorth[index] = nil
            end

            local spot = unpack_point(row[TAG_AT])
            if spot ~= nil then seenWorth[index] = spot.worth end
        end
    end
end

function mode.host_update()
    local target = target_tags()

    if OF.teams.in_play() then
        for _, team in ipairs(OF.teams.LIST) do
            if OF.teams.score(team.key) >= target then
                OF.gamemodes.finish(OF.teams.result_text(),
                    OF.gamemodes.team_winner(team))
                return
            end
        end
        return
    end

    for _, entry in ipairs(hunters()) do
        if score_of(entry.localIndex) >= target then
            OF.gamemodes.finish("@ collected @ tags.", entry.np.name,
                entry.np.name, tostring(score_of(entry.localIndex)))
            return
        end
    end
end

function mode.still_winnable()
    if not (OF.util.asks(OF.teams, "in_play") and OF.teams.in_play()) then
        return true
    end

    local wearing = nil
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_HUNTING)) do
        if OF.gamemodes.in_contention(entry.localIndex) then
            local side = OF.teams.of(entry.localIndex)
            if side == OF.teams.NONE then return true end
            if wearing == nil then
                wearing = side
            elseif wearing ~= side then
                return true
            end
        end
    end
    return false
end

function mode.on_timeout()
    if OF.teams.in_play() then
        OF.gamemodes.finish(OF.teams.result_text(),
            OF.gamemodes.team_winner(OF.teams.leader()))
        return
    end

    local best, names = OF.gamemodes.best_of(
        OF.gamemodes.with_role(ROLE_HUNTING),
        function(entry) return score_of(entry.localIndex) end)
    if best == nil or best <= 0 then
        OF.gamemodes.finish("Nobody claimed a tag.")
    elseif #names > 1 then
        OF.gamemodes.finish("Time - a draw at @ tags.", nil, tostring(best))
    else
        OF.gamemodes.finish("@ took @ tags.", names[1], names[1], tostring(best))
    end
end

function mode.terms()
    return OF.lang.fill("first to @ tags - a leader's tag is worth up to @",
        tostring(target_tags()), tostring(BOUNTY_MAX))
end

function mode.cleanup()

    OF.rules.give_back("interactions", "bounty")
    tag, grace, gaveSeq, seenGave, seenWorth = nil, 0, 0, {}, {}
    OF.util.publish_row(0, TAG_AT, nil)
    OF.util.publish_row(0, TAG_TO, nil)
    OF.util.publish_row(0, TAG_SEQ, nil)

    if OF.util.is_host() then OF.util.publish(TARGET_KEY, nil) end
end

function mode.hud()
    local mine = score_of(0)
    local price = worth_of(0)

    local under = nil
    if price > 1 then
        under = { text = OF.lang.fill(
            "You are ahead - your tag is worth @ to whoever takes it",
            tostring(price)), scale = 0.8 }
    end

    if tag ~= nil then
        local away = OF.gamemodes.distance_to_place(tag)

        OF.util.banner(OF.lang.fill(
            "Your @-tag is out - @",
            tostring(tag.worth or 1),
            OF.lang.fill("@ units back   -   @",
                string.format("%.0f", away or 0),
                OF.lang.fill("@ / @ tags", tostring(mine),
                    tostring(target_tags())))),
            1.0, 255, 180, 120, 255, { under = under })
    else
        OF.util.banner(OF.lang.fill("@ / @ tags", tostring(mine),
            tostring(target_tags())), 1.0, 255, 255, 255, 255,
            { under = under })
    end

    local board = OF.gamemodes.score_board(ROLE_HUNTING, score_of,
        function(score, entry)
            local head = worth_of(entry.localIndex)
            if head <= 1 then return tostring(score) end
            return OF.lang.fill("@ (@)", tostring(score), tostring(head))
        end)
    OF.util.board(djui_hud_get_screen_width() * 0.03,
        djui_hud_get_screen_height() * 0.24,
        OF.lang.t("Tags"), board, { width = 190, column = 120 })
end

OF.gamemodes.register(mode)
