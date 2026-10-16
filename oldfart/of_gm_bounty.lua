OF = OF or {}

local TAG_AT  = "ofBountyAt"
local TAG_TO  = "ofBountyTo"
local TAG_SEQ = "ofBountySeq"
local TARGET_KEY = "ofBountyTarget"
local ROLE_FIGHT = "fighting"
local TAG_RANGE = 160

local TAG_LIFE = 30 * 30

local TAG_ARM = 10

local TAG_MOST = 3

local TAG_DROP_MOST = 2500

local DEFAULT_TARGET = 65

local SIDE_CODE = { red = 1, blue = 2 }
local SIDE_OF_CODE = { [1] = "red", [2] = "blue" }

local mine = {}
local dropped = 0
local gaveSeq = 0
local seenGave = {}

local GAVE_KEEP = 3
local gaveLog = {}
local seenFromStart = false

local lastGround = nil

local function score_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    return (row ~= nil and tonumber(row.ofScore)) or 0
end

local function target_confirms()
    local value = gGlobalSyncTable[TARGET_KEY]
    if type(value) ~= "number" or value <= 0 then return DEFAULT_TARGET end
    return value
end

local function pack_tags(list)
    local parts = {}
    for _, t in ipairs(list) do
        parts[#parts + 1] = string.format("%.0f %.0f %.0f %.0f %.0f %.0f %.0f", t.n, t.x,
            t.y, t.z, t.level or 0, t.area or 1, t.side or 0)
    end
    return table.concat(parts, ";")
end

local function unpack_tags(text)
    local out = {}
    if type(text) ~= "string" or text == "" then return out end
    for piece in string.gmatch(text, "[^;]+") do
        local n, x, y, z, level, area, side = piece:match(
            "^(%-?%d+) (%-?[%d%.]+) (%-?[%d%.]+) (%-?[%d%.]+) (%-?%d+) (%-?%d+) (%-?%d+)$")
        if n ~= nil then
            out[#out + 1] = { n = tonumber(n), x = tonumber(x), y = tonumber(y),
                z = tonumber(z), level = tonumber(level), area = tonumber(area),
                side = SIDE_OF_CODE[tonumber(side)] }
        end
    end
    return out
end

local function publish_mine()
    OF.util.publish_row(0, TAG_AT, pack_tags(mine))
end

local function may_pick(entry)
    if OF.gamemodes.role(entry.localIndex) ~= ROLE_FIGHT then return false end
    if not OF.util.can_play(entry.localIndex) then return false end
    local m = gMarioStates[entry.localIndex]
    if m == nil or m.pos == nil then return false end
    if OF.util.asks(OF.shooter, "dying") and OF.shooter.dying(m) then return false end
    return OF.util.action_group(m.action) ~= OF.util.action_group(ACT_GROUP_CUTSCENE)
end

local mode = {
    key = "bounty",

    tagRule = "shooter",

    noLeaderMark = true,

    name = "Kill Confirmed",
    blurb = "red against blue - take their tags to score, deny your own",
    blurbTeams = "red against blue - take their tags to score, deny your own",
    how = "Hold L to aim, press B to fire - one shot, one kill.\n"
        .. "Y throws a grenade - hold it longer to throw it further.\n"
        .. "X: a flash nut that blinds and stuns.\n"
        .. "Every death drops a tag in the victim's colour.\n"
        .. "Take an enemy tag: kill confirmed, your side scores.\n"
        .. "Take your own side's tag: kill denied, nobody scores.\n"
        .. "A tag nobody takes is gone after 30 seconds.\n"
        .. "First side to the target wins; on the clock, the most.",
    aims = { [ROLE_FIGHT] = "Take their tags. Save your own side's." },
    minPlayers = 2,
    sidesFrom = 2,
    teams = "always",

    kitFrom = "shooter",
    maps = "surveyed",
    surveyKeys = { "points" },

    spreadOpening = true,

    room = { sweep = { "cannons" }, rules = { bubble = 0, waterheal = 1 } },
    lobbyRules = { interactions = PLAYER_INTERACTIONS_PVP },

    cheatsGiven = { sniper = function() return 2 end },
    roundKills = true,
    shooterKit = true,

    defaultLimit = 240,
    music = SEQ_LEVEL_BOSS_KOOPA,

    target = { auto = function(n)
                   return OF.util.clamp(OF.gamemodes.round_to(5 * n + 5, 5), 15, 65)
               end,
               name = "confirms to win",
               min = 10, max = 100, step = 5 },
    options = {

        { key = "replay", name = "Replay at the end",
          help = "the seconds before the round was decided, again",
          choices = {
              { key = "short", name = "the last three seconds",
                help = "played inside the ending - no extra wait" },
              { key = "long", name = "the last six seconds",
                help = "the ending waits three seconds more" },
              { key = "off", name = "no replay",
                help = "the winner's line over the world, as before" },
          } },
    },
}

local TARGET_ASKS = "How many confirmed kills win the round"
local TARGET_ASKS_AUTO = "How many confirmed kills win - auto"
setmetatable(mode.target, { __index = function(target, field)
    if field ~= "default" and field ~= "asks" then return nil end
    local auto = OF.gamemodes == nil or OF.gamemodes.targetChoice == nil
        or OF.gamemodes.targetChoice[mode.key] == nil
    if field == "asks" then return auto and TARGET_ASKS_AUTO or TARGET_ASKS end
    if not (OF.gamemodes ~= nil and OF.util.asks(OF.gamemodes, "participants")) then
        return DEFAULT_TARGET
    end
    return target.auto(math.max(1, #OF.gamemodes.participants()))
end })

mode.TAG_LIFE, mode.TAG_RANGE, mode.TAG_ARM = TAG_LIFE, TAG_RANGE, TAG_ARM
mode.pack_tags, mode.unpack_tags = pack_tags, unpack_tags
mode.target_confirms = target_confirms

function mode.setup(players, options)
    if options ~= nil then options.target = OF.gamemodes.auto_target(mode, players, options) end
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_FIGHT)
    end
    OF.util.publish(TARGET_KEY, math.floor(tonumber(options ~= nil
        and options.target) or DEFAULT_TARGET))

    OF.util.report(OF.rules.lend("interactions", "bounty",
        PLAYER_INTERACTIONS_PVP))
end

function mode.late_join(localIndex)
    if OF.teams.of(localIndex) == OF.teams.NONE and OF.util.asks(OF.teams, "add_late") then
        OF.teams.add_late(localIndex)
    end
    OF.gamemodes.set_role(localIndex, ROLE_FIGHT)
    return ROLE_FIGHT
end

function mode.on_start()
    mine, dropped, gaveSeq, seenGave, lastGround = {}, 0, 0, {}, nil
    gaveLog, seenFromStart = {}, true
    OF.shooter.kit_start()
    OF.util.publish_row(0, TAG_AT, "")
    OF.util.publish_row(0, TAG_TO, nil)
    OF.util.publish_row(0, TAG_SEQ, 0)
    OF.util.publish_row(0, "ofScore", 0)
end

function mode.team_home(side)
    return OF.shooter.side_point(side)
end

function mode.death_place(from)
    return OF.gamemodes.team_respawn(OF.teams.of(0), from, mode)
end

local function deadly(floor)
    return floor ~= nil and (floor.type == SURFACE_DEATH_PLANE
        or floor.type == SURFACE_VERTICAL_WIND)
end

function mode.note_ground(m)
    if m == nil or m.pos == nil or m.floor == nil or deadly(m.floor) then return end
    if type(m.floorHeight) ~= "number" or m.pos.y > m.floorHeight + 4 then return end
    local np = gNetworkPlayers[0]
    if np == nil then return end
    lastGround = { x = m.pos.x, y = m.floorHeight, z = m.pos.z,
        level = np.currLevelNum, area = np.currAreaIndex }
end

function mode.drop_tag(m)
    if m == nil or m.pos == nil then return nil end
    local np = gNetworkPlayers[0]
    local side = SIDE_CODE[OF.teams.of(0)]
    if np == nil or side == nil then return nil end
    local x, z = m.pos.x, m.pos.z
    local level, area = np.currLevelNum, np.currAreaIndex
    local floorY = OF.util.optional("find_floor_height", nil, x, m.pos.y + 100, z)
    if type(floorY) ~= "number" or floorY < m.pos.y - TAG_DROP_MOST or deadly(m.floor) then
        local g = lastGround
        if g == nil or g.level ~= level or g.area ~= area then return nil end
        x, floorY, z = g.x, g.y, g.z
    end
    dropped = dropped + 1
    local tag = { n = dropped, x = x, y = floorY, z = z,
        level = level, area = area, side = side,
        frames = TAG_LIFE, arming = TAG_ARM }
    mine[#mine + 1] = tag
    while #mine > TAG_MOST do table.remove(mine, 1) end
    publish_mine()
    return tag
end

hook_event(HOOK_ON_DEATH, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if OF.gamemodes.current() ~= mode then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if OF.gamemodes.role(0) ~= ROLE_FIGHT then return end
    mode.drop_tag(m)
end)

local function medal(word, tone)
    if not OF.util.asks(OF.hud, "banner") then return nil end
    return OF.hud.banner("medal", OF.lang.t(word), nil, { tone = tone })
end
mode.medal = medal

local function work_my_tags()
    if #mine == 0 then return end
    if not OF.util.can_play(0) then

        mine = {}
        publish_mine()
        return
    end
    local changed = false
    for at = #mine, 1, -1 do
        local tag = mine[at]
        tag.frames = tag.frames - 1
        if tag.arming > 0 then tag.arming = tag.arming - 1 end
        local best, bestAt = nil, nil
        if tag.arming <= 0 then
            for _, entry in ipairs(OF.util.connected_players()) do
                if may_pick(entry) then
                    local distance = OF.gamemodes.distance_to_place(tag, entry.localIndex)
                    if distance ~= nil and distance <= TAG_RANGE
                        and (bestAt == nil or distance < bestAt) then
                        best, bestAt = entry, distance
                    end
                end
            end
        end
        if best ~= nil then
            table.remove(mine, at)
            changed = true
            gaveSeq = gaveSeq + 1
            gaveLog[#gaveLog + 1] = gaveSeq .. ":" .. best.np.globalIndex
            while #gaveLog > GAVE_KEEP do table.remove(gaveLog, 1) end
            OF.util.publish_row(0, TAG_SEQ, mode.pack_gave(OF.packet_round(), gaveLog))

            if best.localIndex == 0 then
                medal("DENIED", "good")
                OF.gamemodes.cue("good")
            elseif OF.teams.same(0, best.localIndex) then
                medal("DENIED", "good")
            else
                medal("CONFIRMED", "bad")
                OF.gamemodes.cue("bad")
            end
        elseif tag.frames <= 0 then
            table.remove(mine, at)
            changed = true
        end
    end
    if changed then publish_mine() end
end

function mode.pack_gave(round, log)
    return tostring(round) .. "|" .. table.concat(log, ";")
end

function mode.unpack_gave(value, round)
    if type(value) ~= "string" then return nil end
    local r, list = string.match(value, "^(%-?%d+)|(.*)$")
    if r == nil or tonumber(r) ~= round then return nil end
    local out = {}
    for seq, to in string.gmatch(list, "(%d+):(%d+)") do
        out[#out + 1] = { seq = tonumber(seq), to = tonumber(to) }
    end
    return out
end

local function hear_my_claims()
    local me = gNetworkPlayers[0] ~= nil and gNetworkPlayers[0].globalIndex or nil
    local round = OF.packet_round()
    for _, entry in ipairs(OF.util.connected_players()) do
        local index = entry.localIndex
        if index ~= 0 then
            local row = gPlayerSyncTable[index]
            local events = mode.unpack_gave(row[TAG_SEQ], round)
            if events ~= nil and #events > 0 then
                local newest = events[#events].seq
                local seen = seenGave[index]
                if seen == nil and not seenFromStart then seen = newest end
                seen = seen or 0
                for _, ev in ipairs(events) do
                    if ev.seq > seen and me ~= nil and ev.to == me then
                        if OF.teams.same(0, index) then
                            medal("DENIED", "good")
                            OF.gamemodes.cue("good")
                        else
                            OF.util.publish_row(0, "ofScore", score_of(0) + 1)
                            medal("CONFIRMED", "good")
                        end
                    end
                end
                if newest > seen then seen = newest end
                seenGave[index] = seen
            end
        end
    end
end
mode.hear_my_claims = hear_my_claims

function mode.scenery()
    if OF.gamemodes.state() == OF.gamemodes.ACTIVE then
        work_my_tags()
        hear_my_claims()

        OF.gamemodes.hear_sides(OF.teams.score("red"), OF.teams.score("blue"))
    end

    for _, entry in ipairs(OF.util.connected_players()) do
        local tags = {}
        if OF.util.can_play(entry.localIndex) then
            tags = unpack_tags(gPlayerSyncTable[entry.localIndex][TAG_AT])
        end
        for k = 1, TAG_MOST do
            local name = "bounty" .. entry.localIndex .. "_" .. k
            local tag = tags[k]
            if tag == nil then
                OF.gamemodes.hide_token(name)
            else

                local model = E_MODEL_YELLOW_COIN
                if tag.side == "blue" then model = E_MODEL_BLUE_COIN
                elseif tag.side == "red" then model = E_MODEL_RED_COIN end
                local at = { x = tag.x, y = tag.y + 40, z = tag.z, level = tag.level, area = tag.area }
                if OF.gamemodes.in_place_room(at) then
                    OF.gamemodes.show_token(name, model, at, nil, nil, true)
                else
                    OF.gamemodes.hide_token(name)
                end
            end
        end
    end
end

function mode.may_attack(attacker, victim)
    local _ = attacker
    local _v = victim
    return false
end

function mode.update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if OF.gamemodes.role(0) ~= ROLE_FIGHT then return end
    if not OF.util.can_play(0) then return end
    local m = gMarioStates[0]
    if m == nil then return end
    mode.note_ground(m)

    OF.shooter.work_the_kit(m)
end

local targetList = {}
local targetPool = {}
function mode.targets(viewer)
    local _ = viewer
    for i = #targetList, 1, -1 do targetList[i] = nil end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return nil end
    local myself = OF.teams.of(0)
    for _, entry in ipairs(OF.util.connected_players()) do
        if OF.util.can_play(entry.localIndex) and entry.np ~= nil then
            for _, tag in ipairs(unpack_tags(gPlayerSyncTable[entry.localIndex][TAG_AT])) do
                if tag.side ~= nil and OF.gamemodes.in_place_room(tag) then
                    local slot = #targetList + 1
                    local t = targetPool[slot] or {}
                    targetPool[slot] = t
                    local ours = tag.side == myself
                    t.id = "tag:" .. entry.np.globalIndex .. ":" .. tag.n
                    t.pos = { x = tag.x, y = tag.y, z = tag.z }
                    t.tone = tag.side
                    t.label = ours and OF.lang.t("Deny") or OF.lang.t("Confirm")
                    t.priority = ours and 65 or 70
                    t.compass = "offscreen"
                    t.ring = { radius = TAG_RANGE }
                    targetList[slot] = t
                end
            end
        end
    end
    if #targetList == 0 then return nil end
    return targetList
end

function mode.hud()
    if #mine > 0 and OF.util.asks(OF.hud, "state_line") then
        OF.hud.state_line("tag", OF.lang.t("Tag down"), { prio = 60, tone = "warn" })
    end
    OF.shooter.kit_hud()
end

function mode.cluster()
    local out = OF.gamemodes.side_cluster(function(key) return OF.teams.score(key) end,
        target_confirms())
    if OF.util.asks(OF.shooter, "with_pips") then return OF.shooter.with_pips(out) end
    return out
end

function mode.pauseControls()
    return OF.shooter.kit_controls(mode)
end

function mode.host_update()
    local target = target_confirms()
    for _, team in ipairs(OF.teams.LIST) do
        if OF.teams.score(team.key) >= target then
            OF.gamemodes.finish(OF.teams.result_text(),
                OF.gamemodes.team_winner(team))
            return
        end
    end
end

function mode.still_winnable()
    if not (OF.util.asks(OF.teams, "in_play") and OF.teams.in_play()) then
        return true
    end
    local wearing = nil
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_FIGHT)) do
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
    OF.gamemodes.finish(OF.teams.result_text(),
        OF.gamemodes.team_winner(OF.teams.leader()))
end

function mode.terms()
    return OF.lang.fill("@ confirmed kills wins; a tag lasts @ seconds",
        tostring(target_confirms()), tostring(math.floor(TAG_LIFE / 30)))
end

function mode.cleanup()
    OF.rules.give_back("interactions", "bounty")
    OF.shooter.kit_stop()
    mine, dropped, gaveSeq, seenGave, lastGround = {}, 0, 0, {}, nil
    gaveLog, seenFromStart = {}, false
    for _, entry in ipairs(OF.util.connected_players()) do
        for k = 1, TAG_MOST do OF.gamemodes.hide_token("bounty" .. entry.localIndex .. "_" .. k) end
    end
    OF.util.publish_row(0, TAG_AT, nil)
    OF.util.publish_row(0, TAG_TO, nil)
    OF.util.publish_row(0, TAG_SEQ, nil)

    if OF.util.is_host() then OF.util.publish(TARGET_KEY, nil) end
end

mode.target_now = target_confirms

OF.gamemodes.register(mode)

if OF.shooter ~= nil and OF.util.asks(OF.shooter, "lend_kit") then OF.shooter.lend_kit(mode) end
