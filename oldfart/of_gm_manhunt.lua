OF = OF or {}

local ROLE_RUNNER = "the runner"
local ROLE_HUNTER = "hunting"
local RUNNER_KEY = "ofMhRunner"
local TAGS_ROW = "ofMhDied"
local CARD_ROW = "ofMhCard"
local GOAL_X     = "ofHillX"
local GOAL_Y     = "ofHillY"
local GOAL_Z     = "ofHillZ"
local GOAL_LEVEL = "ofHillLevel"
local GOAL_AREA  = "ofHillArea"
local GOAL_HERE = { level = LEVEL_BITS, area = 1, x = 351, y = 6652, z = -6030 }

local GOAL_STOPS = { fifteen = 15, eight = 8, thirty = 30, fifty = 50, seventy = 70 }
local TAG_STOPS = { one = 1, two = 2, three = 3 }

local TAG_AUTO_FROM = 9
local BOWSER_BACKSTOP = 40 * 60

local HEAD_BASE, HEAD_PER, HEAD_FROM = 15, 2, 6
local PULSE_EVERY, PULSE_SHOWN = 12, 2
local TAG_GRACE_FRAMES = 3 * 30
local CLIMB_BAND = 150
local METAL = MODEL_STATE_METAL or 0x200

local here = { head = HEAD_BASE, tagSafeUntil = -1, counted = {}, keys = 0,
               card = nil, tookGrand = false, pulseSeen = -1 }

local function now_frame()
    return OF.util.optional("get_global_timer", 0) or 0
end

local function runner_global()
    local value = gGlobalSyncTable[RUNNER_KEY]
    if type(value) ~= "number" then return -1 end
    return value
end

local function runner_local()
    local target = runner_global()
    if target < 0 then return nil end
    return OF.util.local_from_global(target)
end

local function am_runner()
    local np = gNetworkPlayers[0]
    return np ~= nil and np.globalIndex == runner_global()
        and OF.gamemodes.role(0) == ROLE_RUNNER
end

local function bowser_hunt()
    return OF.gamemodes.option_now("hunt") == "bowser"
end

local function star_goal()
    return GOAL_STOPS[OF.gamemodes.option_now("goal") or "fifteen"] or GOAL_STOPS.fifteen
end

local function tags_wanted()
    local pick = OF.gamemodes.option_now("tags") or "one"
    if pick == "auto" then
        return #OF.gamemodes.with_role(ROLE_HUNTER) >= TAG_AUTO_FROM and 2 or 1
    end
    return TAG_STOPS[pick] or TAG_STOPS.one
end

local function row_number(localIndex, key)
    local row = localIndex ~= nil and gPlayerSyncTable[localIndex] or nil
    local value = row ~= nil and tonumber(row[key]) or nil
    if value == nil or value < 0 then return 0 end
    return math.floor(value)
end

local function stars_of(localIndex) return row_number(localIndex, "ofScore") end
local function tags_of(localIndex) return row_number(localIndex, TAGS_ROW) end

local function card_of(localIndex)
    local row = localIndex ~= nil and gPlayerSyncTable[localIndex] or nil
    local text = row ~= nil and row[CARD_ROW] or nil
    local keys, coins = string.match(type(text) == "string" and text or "", "^(%d+) (%d+)$")
    return tonumber(keys) or 0, tonumber(coins) or 0
end

local function backstop(variant, goal)
    if variant == "bowser" then return BOWSER_BACKSTOP end
    return 360 + 60 * (goal or GOAL_STOPS.fifteen)
end

local function head_for(hunters)
    return HEAD_BASE + HEAD_PER * math.max(0, (hunters or 0) - HEAD_FROM)
end

local function head_start_left()
    if not OF.gamemodes.is_running() then return 0 end
    return math.max(0, here.head - OF.gamemodes.elapsed())
end

local function pulse_on(since)
    since = since or OF.gamemodes.since_start()
    local after = since - here.head
    if after < 0 then return false end
    return (after % PULSE_EVERY) < PULSE_SHOWN
end

local function pulse_in(since)
    since = since or OF.gamemodes.since_start()
    local after = since - here.head
    if after < 0 then return math.ceil(-after) end
    return math.ceil(PULSE_EVERY - (after % PULSE_EVERY))
end

local function goal()
    local x = gGlobalSyncTable[GOAL_X]
    if type(x) ~= "number" then return nil end
    return { x = x, y = gGlobalSyncTable[GOAL_Y] or 0, z = gGlobalSyncTable[GOAL_Z] or 0,
             level = gGlobalSyncTable[GOAL_LEVEL], area = gGlobalSyncTable[GOAL_AREA] }
end

local function climb_sign(at)
    local m = gMarioStates[0]
    if at == nil or m == nil or m.pos == nil then return 0 end
    local up = (tonumber(at.y) or 0) - (tonumber(m.pos.y) or 0)
    if up >= CLIMB_BAND then return 1 end
    if up <= -CLIMB_BAND then return -1 end
    return 0
end

local function bearing_to(at)
    local m = gMarioStates[0]
    if at == nil or m == nil or m.pos == nil then return nil end
    if gLakituState == nil or gLakituState.pos == nil then return nil end
    local toTarget = OF.util.optional("atan2s", nil,
        (tonumber(at.z) or 0) - m.pos.z, (tonumber(at.x) or 0) - m.pos.x)
    local toCamera = OF.util.optional("atan2s", nil,
        m.pos.z - gLakituState.pos.z, m.pos.x - gLakituState.pos.x)
    if toTarget == nil or toCamera == nil then return nil end
    return toTarget - toCamera
end

local function draw_needle(cx, cy, radius, ticks, r, g, b, alpha, climb)
    if djui_hud_render_line == nil or djui_hud_set_color == nil then return false end
    local angle = ticks * math.pi / 0x8000
    local tipX, tipY = cx + math.sin(angle) * radius, cy - math.cos(angle) * radius
    djui_hud_set_color(OF.util.byte(r), OF.util.byte(g), OF.util.byte(b), OF.util.byte(alpha))
    djui_hud_render_line(cx, cy, tipX, tipY, 4)
    local ux, uy = (tipX - cx) / radius, (tipY - cy) / radius
    for _, turn in ipairs({ 0.6, -0.6 }) do
        local cosT, sinT = math.cos(turn), math.sin(turn)
        local bx, by = -ux * cosT + uy * sinT, -uy * cosT - ux * sinT
        djui_hud_render_line(tipX, tipY, tipX + bx * radius * 0.35, tipY + by * radius * 0.35, 4)
    end
    if climb ~= nil and climb ~= 0 then
        local markX, reach = cx + radius * 1.15, radius * 0.30
        local tip = cy - reach * climb
        for _, side in ipairs({ -1, 1 }) do
            djui_hud_render_line(markX, tip, markX + reach * 0.7 * side, tip + reach * climb, 4)
        end
    end
    if djui_hud_set_rotation ~= nil then djui_hud_set_rotation(0, 0, 0) end
    return true
end

local mode = {
    key = "manhunt",

    noLeaderMark = true,
    name = "Manhunt",
    clockRuns = true,
    collectsStars = true,
    shellRides = true,
    blurb = "one Runner plays the game, everybody else hunts them",
    aims = {
        [ROLE_RUNNER] = "Reach your goal before the Hunters tag you.",
        [ROLE_HUNTER] = "Tag the Runner before they reach their goal.",
    },
    how = "One Runner plays the game; everybody else hunts.\n"
        .. "Star Hunt: the Runner wins on the stars set below.\n"
        .. "Bowser Hunt: the Runner wins on the Grand Star.\n"
        .. "The Hunters start blind while the Runner runs.\n"
        .. "Tag: a hit, or a touch on a pole or in water.\n"
        .. "A Runner who dies respawns; only a tag counts.\n"
        .. "Only the Runner takes stars, coins and keys.\n"
        .. "The compass shows the Runner every 12 seconds.",
    minPlayers = 2,
    maps = "own",
    wholeGame = true,
    cheatsGiven = OF.gamemodes.water_rule("chase", { nodialog = 1, nodance = 1 }),
    startPlace = { level = LEVEL_CASTLE_GROUNDS, area = 1, act = 0 },
    wingCap = true,
    realActs = true,
    fightsBosses = true,
    room = { rules = { interactions = PLAYER_INTERACTIONS_NONE } },
    music = SEQ_LEVEL_BOSS_KOOPA_FINAL,
    defaultLimit = backstop("stars", GOAL_STOPS.fifteen),
    teams = false,

    caps = { tiebreak = false },

    noMatchPoint = true,
    roleNoun = { [ROLE_RUNNER] = "Runner", [ROLE_HUNTER] = "Hunter" },
    options = {
        { key = "hunt", name = "What the Runner plays for",
          help = "a number of stars, or the whole game to the Grand Star",
          choices = {
              { key = "stars", name = "Star Hunt",
                help = "any stars count; star doors as the game has them" },
              { key = "bowser", name = "Bowser Hunt",
                help = "the Grand Star; star doors and stairs open" },
          } },

        { key = "goal", name = "Stars the Runner needs",
          help = "Star Hunt's goal; Hunters win when the time runs out",
          shownIf = { hunt = "stars" },
          choices = {
              { key = "fifteen", name = "15 stars", help = "Hunters win after 21 minutes" },
              { key = "eight", name = "8 stars", help = "a short hunt - Hunters win after 14 minutes" },
              { key = "thirty", name = "30 stars", help = "a long hunt - Hunters win after 36 minutes" },
              { key = "fifty", name = "50 stars", help = "Hunters win after 56 minutes" },
              { key = "seventy", name = "70 stars", help = "Hunters win after 76 minutes" },
          } },
        { key = "tags", name = "Tags to catch the Runner",
          help = "how many tags the Hunters need",
          choices = {
              { key = "one", name = "one tag", help = "one touch and it is over" },
              { key = "auto", name = "auto", help = "one tag up to 8 Hunters, two from 9" },
              { key = "two", name = "two tags", help = "one escape forgiven" },
              { key = "three", name = "three tags", help = "a long chase" },
          } },
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

mode.presets = {
    { key = "classic", name = "Classic", help = "15 stars, one tag", sets = {} },
    { key = "quick", name = "Quick hunt", help = "8 stars, one tag", sets = { goal = "eight" } },
    { key = "long", name = "Long chase", help = "30 stars, two tags",
      sets = { goal = "thirty", tags = "two" } },
    { key = "bowser", name = "Bowser race", help = "the Grand Star, two tags",
      sets = { hunt = "bowser", tags = "two" } },
}

mode.backstop, mode.head_for = backstop, head_for
mode.pulse_on, mode.pulse_in = pulse_on, pulse_in
mode.draw_needle = draw_needle
mode.PULSE_EVERY, mode.PULSE_SHOWN, mode.TAG_GRACE_FRAMES = PULSE_EVERY, PULSE_SHOWN, TAG_GRACE_FRAMES
mode.ROLE_RUNNER, mode.ROLE_HUNTER = ROLE_RUNNER, ROLE_HUNTER

function mode.head_seconds()
    return here.head
end

local function bowser_spot()
    if not bowser_hunt() or not am_runner() then return nil end
    local at = goal()
    if at == nil or not OF.gamemodes.in_place_room(at) then return nil end
    at.label = "the way to Bowser"
    local gold = OF.util.gold()
    at.r, at.g, at.b = gold.r, gold.g, gold.b
    return at
end

local goalTarget = { id = "bowser", label = "Bowser", tone = "target",
    priority = 90, compass = "offscreen" }
local goalList = { goalTarget }
function mode.targets(viewer)
    local _ = viewer
    local at = bowser_spot()
    if at == nil then return nil end
    goalTarget.pos = at
    return goalList
end

function OF.gm_manhunt_goal()
    return OF.gamemodes.tokens["mhgoal"]
end

function mode.terms()
    local tags = TAG_STOPS[OF.gamemodes.option_showing(mode.key, "tags") or "one"] or 1
    local hunt = OF.gamemodes.option_showing(mode.key, "hunt") or "stars"
    local tagged = tags == 1 and OF.lang.t("one tag catches")
        or OF.lang.fill("@ tags catch", tostring(tags))
    if hunt == "bowser" then
        return OF.lang.fill("the Grand Star for the Runner, @", tagged)
    end
    local stars = GOAL_STOPS[OF.gamemodes.option_showing(mode.key, "goal") or "fifteen"] or 15
    return OF.lang.fill("@ stars for the Runner, @", tostring(stars), tagged)
end

function mode.standing(localIndex)
    if OF.gamemodes.role(localIndex) == ROLE_RUNNER then
        if bowser_hunt() then return tostring(stars_of(localIndex)) end
        return tostring(stars_of(localIndex)) .. "/" .. tostring(star_goal())
    end
    return "HUNT"
end

function mode.sideTitle(role)
    if role == ROLE_RUNNER then return "Runner" end
    if role == ROLE_HUNTER then return "Hunters" end
    return nil
end

function mode.setup(players, options)
    local it = OF.gamemodes.deal_it(players, 1, false)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex,
            it[entry.localIndex] and ROLE_RUNNER or ROLE_HUNTER)
        if it[entry.localIndex] and entry.np ~= nil then
            OF.util.publish(RUNNER_KEY, entry.np.globalIndex)
        end
    end
    local variant = OF.gamemodes.option_now("hunt") or "stars"
    if options == nil or tonumber(options.limit) == nil then
        OF.util.publish("ofGmLimit", backstop(variant, star_goal()))
    end
    if variant == "bowser" then
        OF.util.publish(GOAL_LEVEL, GOAL_HERE.level)
        OF.util.publish(GOAL_AREA, GOAL_HERE.area)
        OF.util.publish(GOAL_X, GOAL_HERE.x)
        OF.util.publish(GOAL_Y, GOAL_HERE.y)
        OF.util.publish(GOAL_Z, GOAL_HERE.z)
        OF.util.report(OF.rules.lend("stardoors", "manhunt", 1))
        OF.util.report(OF.rules.lend("stairs", "manhunt", 0))
    end
end

function mode.late_join(localIndex)
    return ROLE_HUNTER
end

function mode.on_start()
    here.head = head_for(#OF.gamemodes.with_role(ROLE_HUNTER))
    here.tagSafeUntil, here.counted, here.keys = -1, {}, 0
    here.card, here.tookGrand, here.pulseSeen = nil, false, -1
    here.seen = {}
    if am_runner() then
        OF.util.publish_row(0, TAGS_ROW, 0)
        OF.util.publish_row(0, "ofScore", 0)
    end

end

function mode.cleanup()
    if OF.util.asks(OF.rules, "give_back") then
        OF.rules.give_back("stardoors", "manhunt")
        OF.rules.give_back("stairs", "manhunt")
    end
    OF.util.hud_hide(HUD_DISPLAY_FLAG_STAR_COUNT or 0x0004, "manhunt", false)
    here.tagSafeUntil, here.counted, here.keys = -1, {}, 0
    here.card, here.tookGrand, here.pulseSeen = nil, false, -1
    local row = gPlayerSyncTable[0]
    if row ~= nil and row[CARD_ROW] ~= nil then OF.util.publish_row(0, CARD_ROW, nil) end
    if OF.util.is_host() then
        OF.util.publish(RUNNER_KEY, -1)
        OF.util.publish(GOAL_LEVEL, nil)
        OF.util.publish(GOAL_AREA, nil)
        OF.util.publish(GOAL_X, nil)
        OF.util.publish(GOAL_Y, nil)
        OF.util.publish(GOAL_Z, nil)
        if OF.util.asks(OF.net, "undo_warp") and OF.net.can_undo() then
            OF.util.report(OF.net.undo_warp(true))
        end
    end
end

function mode.before_mario_update(m)
    if OF.gamemodes.role(0) ~= ROLE_HUNTER then return end
    if head_start_left() <= 0 then return end
    OF.input.hold(m)
end

function mode.blind()
    return OF.gamemodes.role(0) == ROLE_HUNTER and OF.util.can_play(0)
        and OF.gamemodes.state() == OF.gamemodes.ACTIVE and head_start_left() > 0
end

function mode.wear_metal(m)
    if m == nil or OF.gamemodes.current() ~= mode or not OF.gamemodes.is_running() then
        return false
    end
    if OF.gamemodes.role(m.playerIndex) ~= ROLE_HUNTER then return false end
    local body = m.marioBodyState
    if body == nil or type(body.modelState) ~= "number" then return false end
    if not OF.util.has_flag(body.modelState, METAL) then
        body.modelState = body.modelState + METAL
    end
    return true
end
hook_event(HOOK_MARIO_UPDATE, mode.wear_metal)

function mode.tagged_by()
    if not am_runner() or not OF.util.can_play(0) then return nil end
    if head_start_left() > 0 or now_frame() < here.tagSafeUntil then return nil end
    local reach = (OF.hunt ~= nil and OF.hunt.CATCH_RANGE) or 170
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_HUNTER)) do
        local li = entry.localIndex
        if li ~= 0 and OF.util.can_play(li) and OF.gamemodes.tag_lands(li, 0, reach) then
            return entry
        end
    end
    return nil
end

local function claim_tags()
    if OF.gamemodes.role(0) ~= ROLE_HUNTER or head_start_left() > 0 then return end
    if not OF.gamemodes.tag_move(0) then return end
    local runner = runner_local()
    if runner == nil or runner == 0 then return end
    local d = OF.gamemodes.distance(runner, 0)
    local reach = (OF.hunt ~= nil and OF.hunt.CATCH_RANGE) or 170
    if d ~= nil and d < reach then OF.gamemodes.send_hit_claim(runner) end
end

local function publish_card(m)
    local coins = m ~= nil and math.floor(tonumber(m.numCoins) or 0) or 0
    local text = tostring(here.keys) .. " " .. tostring(coins)
    if text ~= here.card then
        here.card = text
        OF.util.publish_row(0, CARD_ROW, text)
    end
end

function mode.update()
    OF.gamemodes.count_the_hold(head_start_left())
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    claim_tags()
    if OF.gamemodes.role(0) == ROLE_HUNTER and head_start_left() <= 0 then
        local beat = math.floor((OF.gamemodes.since_start() - here.head) / PULSE_EVERY)
        if pulse_on() and beat ~= here.pulseSeen then
            here.pulseSeen = beat
            OF.gamemodes.cue("chime")
        end
    end
    if not am_runner() or not OF.util.can_play(0) then return end
    local m = gMarioStates[0]
    publish_card(m)
    if here.tookGrand and (gPlayerSyncTable[0].ofGmTime or 0) <= 0 then
        here.tookGrand = false
        OF.util.publish_row(0, "ofGmTime", math.max(0.001, OF.gamemodes.since_start()))
    end
    local hunter = mode.tagged_by()
    if hunter ~= nil then
        local tags = tags_of(0) + 1
        here.tagSafeUntil = now_frame() + TAG_GRACE_FRAMES
        OF.util.publish_row(0, TAGS_ROW, tags)
        if m ~= nil then m.invincTimer = TAG_GRACE_FRAMES end
        if OF.util.asks(OF.lobbytalk, "feed") then
            OF.lobbytalk.feed(hunter.localIndex, 0)
        end

        OF.gamemodes.cue("bad")
    end
end

function mode.refuses_pickup(m, interactType)
    if m == nil or m.playerIndex ~= 0 then return false end
    if interactType ~= INTERACT_STAR_OR_KEY and interactType ~= INTERACT_COIN then return false end
    if not OF.gamemodes.is_running() or OF.gamemodes.current() ~= mode then return false end
    return OF.gamemodes.role(0) ~= ROLE_RUNNER
end

hook_event(HOOK_ALLOW_INTERACT, function(m, o, interactType)
    if mode.refuses_pickup(m, interactType) then return false end
end)

local function has_bhv(o, name)
    local id = _G[name]
    return id ~= nil and OF.util.optional("obj_has_behavior_id", 0, o, id) ~= 0
end

function mode.took(o)
    if o == nil then return nil end
    if has_bhv(o, "id_bhvGrandStar") then
        here.tookGrand = true
        return "grand"
    end
    if has_bhv(o, "id_bhvBowserKey") then
        here.keys = math.min(2, here.keys + 1)
        publish_card(gMarioStates[0])
        return "key"
    end
    local np = gNetworkPlayers[0]
    local index = math.floor((tonumber(o.oBehParams) or 0) / 0x1000000) % 0x20
    local key = tostring(np ~= nil and np.currLevelNum or 0) .. ":" .. tostring(index)
    if here.counted[key] then return nil end
    here.counted[key] = true
    OF.util.publish_row(0, "ofScore", stars_of(0) + 1)
    return "star"
end

hook_event(HOOK_ON_INTERACT, function(m, obj, interactType, interacted)
    if m == nil or m.playerIndex ~= 0 or interacted ~= true then return end
    if interactType ~= INTERACT_STAR_OR_KEY then return end
    if not OF.gamemodes.is_running() or OF.gamemodes.current() ~= mode then return end
    if not am_runner() then return end
    mode.took(obj)
end)

local function hunters_win(reason)
    local names = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_HUNTER)) do
        if entry.np ~= nil and entry.np.name ~= nil then table.insert(names, entry.np.name) end
    end
    if #names == 0 then
        OF.gamemodes.finish(reason)
        return
    end
    OF.gamemodes.finish(reason, { names = names })
end

function mode.host_update()
    local runner = runner_local()
    if runner == nil or not OF.util.can_play(runner)
        or OF.gamemodes.role(runner) ~= ROLE_RUNNER then
        OF.gamemodes.abandon("The Runner is gone.")
        return
    end
    if tags_of(runner) >= tags_wanted() then
        hunters_win("The Hunters tagged the Runner.")
        return
    end
    local np = gNetworkPlayers[runner]
    if bowser_hunt() then
        local said = gPlayerSyncTable[runner].ofGmTime or 0
        if said > 0 and np ~= nil and np.currLevelNum == LEVEL_BOWSER_3 then
            OF.gamemodes.finish("@ won - took the Grand Star.", np.name, np.name)
        end
        return
    end
    if stars_of(runner) >= star_goal() and np ~= nil then
        OF.gamemodes.finish("@ won - @ stars.", np.name, np.name, tostring(stars_of(runner)))
    end
end

function mode.paint(localIndex)
    local role = OF.gamemodes.role(localIndex)
    local key = role == ROLE_RUNNER and "blue" or role == ROLE_HUNTER and "red" or nil
    if key == nil or not OF.util.asks(OF.teams, "find") then return nil end
    local team = OF.teams.find(key)
    if team == nil then return nil end
    return { key = "manhunt " .. key, r = team.r, g = team.g, b = team.b }
end

function mode.on_timeout()
    hunters_win("The Hunters won - the Runner ran out of time.")
end

function mode.replayDecider()
    return runner_local()
end

function mode.chip_figure()
    local runner = runner_local()
    local stars = runner ~= nil and stars_of(runner) or 0
    if bowser_hunt() then return tostring(stars) end
    return tostring(stars) .. " / " .. tostring(star_goal())
end

mode.CHIP_ROW = { leadGap = 10, keyGap = 4, tagGap = 3 }

local rowItems = {}
function mode.tracker_icons()
    for i = #rowItems, 1, -1 do rowItems[i] = nil end
    local R = mode.CHIP_ROW
    local runner = runner_local()
    local keys, coins = card_of(runner)
    local function add(item) rowItems[#rowItems + 1] = item end
    add({ icon = "star", text = mode.chip_figure(), gap = R.leadGap })
    add({ icon = "coin", count = coins })
    add({ divider = true })
    for k = 1, 2 do
        add({ icon = "key", tone = "target", empty = keys < k, gap = R.keyGap })
    end
    if bowser_hunt() then
        local grand = runner ~= nil and (gPlayerSyncTable[runner].ofGmTime or 0) > 0
        add({ icon = "grand", tone = "target", empty = not grand })
    end
    add({ divider = true })
    local tags = runner ~= nil and tags_of(runner) or 0
    for t = 1, tags_wanted() do
        add({ icon = "tag", tone = "hunter", empty = tags < t, gap = R.tagGap })
    end
    return rowItems
end

mode.ROW_OPTS = { digits = "heading" }

function mode.runner_board_wanted()
    if OF.gamemodes.role(0) ~= ROLE_HUNTER or head_start_left() > 0 then return false end
    local runner = runner_local()
    local np, me = runner ~= nil and gNetworkPlayers[runner] or nil, gNetworkPlayers[0]
    if np == nil or me == nil or np.currLevelNum == nil then return false end

    return np.currLevelNum ~= me.currLevelNum
end
local runnerEntry = { { localIndex = 0 } }
function mode.draw_runner_board()
    if not mode.runner_board_wanted() then return false end
    if not OF.util.asks(OF.hunt, "hiding_board")
        or type(OF.gm_hideseek_places_of) ~= "function" then return false end
    runnerEntry[1].localIndex = runner_local()
    local below = nil
    if OF.util.asks(OF.gamemodes, "side_board") then
        OF.gamemodes.side_board()
        if OF.util.asks(OF.gamemodes, "side_bottom") then below = OF.gamemodes.side_bottom() end
    end
    return OF.hunt.hiding_board(below, OF.gm_hideseek_places_of(runnerEntry), "The Runner is in")
end
local function runner_level_name()
    local runner = runner_local()
    local np = runner ~= nil and gNetworkPlayers[runner] or nil
    if np == nil then return nil, nil end
    local name = OF.util.asks(OF.util, "concealed_level_name")
        and OF.util.concealed_level_name(np.currLevelNum, np.currAreaIndex)
        or OF.lang.t("somewhere")
    return name, tostring(np.currLevelNum) .. ":" .. tostring(np.currAreaIndex)
end

function mode.watch(now)
    local seen = here.seen or {}
    here.seen = seen
    local runner = runner_local()
    if runner == nil then return end
    local stars, tags = stars_of(runner), tags_of(runner)
    local keys = card_of(runner)
    local runnerSide = am_runner() and "us" or "them"
    local hunterSide = am_runner() and "them" or "us"
    local banner = OF.util.asks(OF.hud, "banner") and OF.hud.banner or function() end
    if seen.stars ~= nil and stars > seen.stars then
        banner("objective", OF.lang.t("STAR"), mode.chip_figure(), { side = runnerSide })
    end
    if seen.keys ~= nil and keys > seen.keys then
        banner("objective", OF.lang.t("KEY"), OF.lang.fill("@/2", tostring(keys)), { side = runnerSide })
    end
    if seen.tags ~= nil and tags > seen.tags then
        local left = math.max(0, tags_wanted() - tags)
        banner("point", OF.lang.t("TAGGED"),
            left > 0 and OF.lang.plural(left, "1 more to catch", "@ more to catch") or nil,
            { side = hunterSide })
    end
    local held = head_start_left()
    if seen.held ~= nil and seen.held > 0 and held <= 0 then
        banner("objective", OF.lang.t("HUNTERS OUT"), nil)
        seen.levelAt = now
    end
    local _, room = runner_level_name()
    if seen.room ~= nil and room ~= seen.room then seen.levelAt = now end
    seen.stars, seen.tags, seen.keys, seen.held, seen.room = stars, tags, keys, held, room
end

function mode.hud()
    OF.util.hud_hide(HUD_DISPLAY_FLAG_STAR_COUNT or 0x0004, "manhunt", true)
    local now = OF.util.asks(OF.hud, "now") and OF.hud.now() or now_frame()
    local held = head_start_left()
    if mode.blind() then
        if OF.util.asks(OF.hunt, "draw_curtain") then OF.hunt.draw_curtain() end

        if OF.util.asks(OF.hunt, "blind_number") then OF.hunt.blind_number(held) end
    end
    mode.watch(now)
    local state = OF.util.asks(OF.hud, "state_line") and OF.hud.state_line or nil
    if state == nil then return end

    state("tracker", nil, { prio = 50, icons = mode.tracker_icons(), iconOpts = mode.ROW_OPTS })
    if held > 0 and am_runner() then
        state("run", OF.lang.t("Run!"), { prio = 70, figure = held, urgent = true, tone = "runner" })
    elseif held <= 0 and OF.gamemodes.role(0) == ROLE_HUNTER then
        mode.draw_runner_board()

        local at, kind, areaName = mode.needle_target()
        if at ~= nil then
            local ticks = bearing_to(at)
            if ticks ~= nil and mode.needle_shown() then
                draw_needle(djui_hud_get_screen_width() * 0.5, djui_hud_get_screen_height() * 0.80,
                    djui_hud_get_screen_height() * 0.07, ticks, 255, 90, 90, 235,
                    climb_sign(at))
            end
        elseif areaName ~= nil then
            state("runnerarea", OF.lang.fill("Runner: in @", areaName), { prio = 45, tone = "runner" })
        end
    end
end

local wayCache = { key = nil, at = nil, frame = -100 }
local function way_toward(level, area)
    local me = gNetworkPlayers[0]
    local m = gMarioStates[0]
    if me == nil or m == nil or m.pos == nil then return nil end
    local now = OF.util.optional("get_global_timer", 0) or 0
    local key = tostring(level) .. ":" .. tostring(me.currAreaIndex) .. ">" .. tostring(area)
    if wayCache.key == key and now - wayCache.frame < 30 then return wayCache.at end
    local probe = OF.util.binding("area_get_warp_node")
    local best, bestD = nil, nil
    if probe ~= nil then
        for id = 0, 0xFF do
            local w = probe(id)
            local node = w ~= nil and w.node or nil
            local o = w ~= nil and w.object or nil
            if node ~= nil and o ~= nil and (node.destLevel or 0) % 0x80 == level
                and node.destArea == area and o.oPosX ~= nil then
                local dx, dz = o.oPosX - m.pos.x, o.oPosZ - m.pos.z
                local d = dx * dx + dz * dz
                if bestD == nil or d < bestD then
                    best, bestD = { x = o.oPosX, y = o.oPosY, z = o.oPosZ }, d
                end
            end
        end
    end
    wayCache.key, wayCache.at, wayCache.frame = key, best, now
    return best
end
mode.way_toward = way_toward

local arrival = { key = nil, at = nil }
function mode.needle_shown(since)
    since = since or OF.gamemodes.since_start()
    local runner = runner_local()
    local np, me = runner ~= nil and gNetworkPlayers[runner] or nil, gNetworkPlayers[0]
    local key = nil
    if np ~= nil and me ~= nil and np.currLevelNum == me.currLevelNum then
        key = tostring(me.currLevelNum) .. ":" .. tostring(me.currAreaIndex) .. ">"
            .. tostring(np.currAreaIndex)
    end
    if key ~= arrival.key then
        arrival.key = key
        arrival.at = key ~= nil and since or nil
    end
    if arrival.at ~= nil and since - arrival.at >= 0 and since - arrival.at < PULSE_SHOWN then
        return true
    end
    return pulse_on(since)
end

function mode.needle_target()
    local runner = runner_local()
    local np, me = runner ~= nil and gNetworkPlayers[runner] or nil, gNetworkPlayers[0]
    local rm = runner ~= nil and gMarioStates[runner] or nil
    if np == nil or me == nil or rm == nil or rm.pos == nil then return nil end
    if np.currLevelNum ~= me.currLevelNum then return nil end
    if np.currAreaIndex == me.currAreaIndex then
        if OF.gamemodes.distance(0, runner) ~= nil then return rm.pos, "runner" end
        return nil
    end
    local way = way_toward(np.currLevelNum, np.currAreaIndex)
    if way ~= nil then return way, "way" end
    local name = OF.util.asks(OF.util, "concealed_level_name")
        and OF.util.concealed_level_name(np.currLevelNum, np.currAreaIndex) or nil
    return nil, nil, name
end

function mode.scenery()
    if bowser_hunt() and am_runner() then
        OF.gamemodes.mark_place("mhgoal", E_MODEL_STAR, goal(), 0x0400)
    else
        OF.gamemodes.hide_token("mhgoal")
    end
end

mode.roundKeys = { "ofMhRunner" }
OF.gamemodes.register(mode)
