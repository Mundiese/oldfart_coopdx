OF = OF or {}
OF.roundscope = OF.roundscope or {}

local roundscope = OF.roundscope

local function asks(from, name)
    return from ~= nil and from[name] ~= nil
end

local function connected(i)
    local np = gNetworkPlayers[i]
    return np ~= nil and np.connected == true
end

local function excluded(i)
    local speedrun = OF.speedrun
    return speedrun ~= nil and speedrun.is_excluded ~= nil
        and speedrun.is_excluded(i) == true
end

local function watching(i)
    local spectate = OF.spectate
    if not (spectate ~= nil and spectate.is_spectating ~= nil
        and spectate.is_spectating(i) == true) then
        return false
    end
    local harsh = OF.harsh
    return not (harsh ~= nil and harsh.is_permadead ~= nil
        and harsh.is_permadead(i) == true)
end

local function stepped_away(i)
    local idle = OF.idle
    return idle ~= nil and idle.left_out ~= nil and idle.left_out(i) == true
end

local function run_on()
    local speedrun = OF.speedrun
    return speedrun ~= nil and speedrun.is_running ~= nil
        and speedrun.is_running() == true
end

local function round_on()
    local modes = OF.gamemodes
    if modes == nil or modes.state == nil then return false end
    return modes.state() ~= modes.OFF
end

local function in_the_run(i)
    local speedrun = OF.speedrun
    if not (asks(speedrun, "refuses_latecomers") and speedrun.refuses_latecomers()) then
        return true
    end
    if i == 0 and asks(speedrun, "in_this_run") then
        local state = asks(speedrun, "state") and speedrun.state() or nil

        if state ~= nil and state == speedrun.COUNTDOWN then return true end
        return speedrun.in_this_run() == true
    end
    if asks(OF.util, "is_host") and OF.util.is_host()
        and asks(speedrun, "on_the_line") then
        return speedrun.on_the_line(i) == true
    end

    local row = gPlayerSyncTable[i]
    local line = row ~= nil and row.ofOnLine or nil
    if line == roundscope.LINE_ON then return true end
    if line == roundscope.LINE_OFF then return false end

    return true
end

local function in_the_round(i)
    local modes = OF.gamemodes

    if modes ~= nil and modes.left_out_of_this_round ~= nil
        and modes.left_out_of_this_round(i) then
        return "out"
    end

    local outseat = OF.outseat
    if i == 0 and outseat ~= nil and outseat.free_of_the_round ~= nil
        and outseat.free_of_the_round() then
        return "out"
    end
    local role = modes ~= nil and modes.role ~= nil and modes.role(i) or ""
    if role == modes.WAITING then return "out" end
    if role ~= nil and role ~= "" then return "in" end

    if modes.state() == modes.COUNTDOWN or modes.state() == modes.LOBBY
        or (asks(modes, "is_waiting") and modes.is_waiting()) then
        if asks(OF.util, "can_play") and not OF.util.can_play(i) then return "out" end
        return "in"
    end
    return "unknown"
end

roundscope.LOBBY = 0
roundscope.ROUND = 1
roundscope.RUN = 2

roundscope.SEPARATE_GROUPS = true

roundscope.LINE_NONE = 0
roundscope.LINE_ON = 1
roundscope.LINE_OFF = 2

local function excluded_as(i, kind)
    local speedrun = OF.speedrun
    return speedrun ~= nil and speedrun.is_excluded ~= nil
        and speedrun.is_excluded(i, kind) == true
end

local function kind_of(name)
    local speedrun = OF.speedrun
    return speedrun ~= nil and speedrun[name] or nil
end

function roundscope.round_dealt(i)
    if i == nil or not round_on() then return false end
    local modes = OF.gamemodes
    local role = modes.role ~= nil and modes.role(i) or ""
    return role ~= nil and role ~= "" and role ~= modes.WAITING
end

function roundscope.taken_by_run(i)
    if i == nil or not run_on() then return false end
    if not connected(i) then return false end
    if excluded_as(i, kind_of("KIND_RUN")) then return false end
    if roundscope.round_dealt(i) then return false end
    return in_the_run(i)
end

local function place(i)
    if i == nil then i = 0 end
    if type(i) ~= "number" or i < 0 or i >= MAX_PLAYERS then return "out", 0 end
    if not connected(i) then return "out", 0 end
    local run, round = run_on(), round_on()
    if not run and not round then return "out", 0 end

    if watching(i) then return "out", 0 end
    if stepped_away(i) then return "out", 0 end

    if not run then

        if excluded(i) then return "out", 0 end
        local answer = in_the_round(i)
        return answer, answer == "out" and 0 or 1
    end
    if not round then
        if excluded(i) then return "out", 0 end
        if in_the_run(i) then return "in", 2 end
        return "out", 0
    end

    if roundscope.round_dealt(i) and not excluded_as(i, kind_of("KIND_MODE")) then
        return "in", 1
    end
    if roundscope.taken_by_run(i) then return "in", 2 end
    if excluded_as(i, kind_of("KIND_MODE")) then return "out", 0 end
    local answer = in_the_round(i)
    return answer, answer == "out" and 0 or 1
end

function roundscope.standing(i)
    local answer = place(i)
    return answer
end

function roundscope.group(i)
    local _, group = place(i)
    return group
end

function roundscope.inside(i)
    return roundscope.standing(i) ~= "out"
end

function roundscope.dealt(i)
    return roundscope.standing(i) == "in"
end

function roundscope.about(i)
    local here = roundscope.inside(0) or roundscope.held_here()
    if i == nil or i == 0 then return here end
    return here or roundscope.inside(i)
end

function roundscope.held_here()
    local lockdown = OF.lockdown
    return lockdown ~= nil and lockdown.watching_the_round ~= nil
        and lockdown.watching_the_round() == true
end

function roundscope.apart(a, b)
    if a == nil or b == nil or a == b then return false end
    if not (run_on() or round_on()) then return false end
    if not roundscope.SEPARATE_GROUPS then
        return roundscope.inside(a) ~= roundscope.inside(b)
    end
    return roundscope.group(a) ~= roundscope.group(b)
end

function roundscope.shares_room_with_round()
    if roundscope.inside(0) then return false end
    local me = gNetworkPlayers[0]
    if me == nil then return false end
    for j = 1, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[j]
        if np ~= nil and np.connected
            and np.currLevelNum == me.currLevelNum
            and np.currAreaIndex == me.currAreaIndex
            and np.currActNum == me.currActNum
            and roundscope.inside(j) then
            return true
        end
    end
    return false
end

function roundscope.out_of_reach(list)
    local kept = {}
    for _, globalIndex in ipairs(list or {}) do
        local li = nil
        if asks(OF.util, "local_from_global") then
            li = OF.util.local_from_global(globalIndex)
        end
        if li == nil or not roundscope.inside(li) then
            kept[#kept + 1] = globalIndex
        end
    end
    return kept
end

local function round_thing(interactType)
    local a, b, c = INTERACT_COIN, INTERACT_STAR_OR_KEY, INTERACT_CAP
    local d, e, f = INTERACT_GRABBABLE, INTERACT_BREAKABLE, INTERACT_KOOPA_SHELL
    if a == nil then return false end
    if interactType == a then return true end
    if b == nil then return false end
    if interactType == b then return true end
    if c == nil then return false end
    if interactType == c then return true end
    if d == nil then return false end
    if interactType == d then return true end
    if e == nil then return false end
    if interactType == e then return true end
    if f == nil then return false end
    return interactType == f
end

function roundscope.refuses_taking(m, interactType)
    if m == nil or m.playerIndex ~= 0 then return false end
    if not round_thing(interactType) then return false end
    return roundscope.shares_room_with_round()
end

function roundscope.refuses_touch(m, o, interactType)
    if m == nil or o == nil then return false end
    if roundscope.refuses_taking(m, interactType) then return true end

    if m.playerIndex == 0 and roundscope.ghosts(o) then return true end
    if interactType ~= INTERACT_PLAYER then return false end

    for j = 0, MAX_PLAYERS - 1 do
        local other = gMarioStates[j]
        if other ~= nil and other.marioObj == o then
            return roundscope.apart(m.playerIndex, j)
        end
    end
    return false
end

hook_event(HOOK_ALLOW_INTERACT, function(m, o, interactType)
    if roundscope.refuses_touch(m, o, interactType) then return false end
end)

roundscope.wasInside = false

roundscope.wasWatchingCopy = false

function roundscope.watch()
    local now = roundscope.inside(0)
    local lockdown = OF.lockdown
    local copy = lockdown ~= nil and lockdown.watching_the_round ~= nil
        and lockdown.watching_the_round() == true
    if now == roundscope.wasInside and copy == roundscope.wasWatchingCopy then
        return false
    end
    local insideChanged = now ~= roundscope.wasInside
    roundscope.wasInside = now
    roundscope.wasWatchingCopy = copy

    if insideChanged and now then
        if asks(OF.panel, "remember_before_round") then OF.panel.remember_before_round() end
    elseif insideChanged then
        if asks(OF.panel, "restore_after_round") then OF.panel.restore_after_round() end
    end
    if asks(OF.cheats, "room_changed") then OF.cheats.room_changed() end
    if asks(OF.rules, "apply") then OF.rules.apply() end
    if asks(OF.panel, "mark_dirty") then OF.panel.mark_dirty() end
    return true
end

roundscope.MARK_FIELD = "oOfMark"
roundscope.MARK_LOBBY = 0x4F460001

roundscope.MARK_ROUND = 0x4F460002
roundscope.MARK_RUN = 0x4F460003

roundscope.marking = false
function roundscope.registered(answer)
    return answer ~= nil and answer ~= false and answer ~= 0
end
do
    local define = rawget(_G, "define_custom_obj_fields")
    if type(define) == "function" then
        roundscope.marking = roundscope.registered(define({ oOfMark = "u32" }))
    end
end

function roundscope.is_lobby_thing(o)
    if o == nil or not roundscope.marking then return false end
    return o[roundscope.MARK_FIELD] == roundscope.MARK_LOBBY
end

function roundscope.placed_by(o)
    if o == nil or not roundscope.marking then return nil end
    local mark = o[roundscope.MARK_FIELD]
    if mark == roundscope.MARK_LOBBY then return roundscope.LOBBY end
    if mark == roundscope.MARK_ROUND then return roundscope.ROUND end
    if mark == roundscope.MARK_RUN then return roundscope.RUN end
    return nil
end

local MARK_OF = {}
local function mark_for(group)
    if next(MARK_OF) == nil then
        MARK_OF[roundscope.LOBBY] = roundscope.MARK_LOBBY
        MARK_OF[roundscope.ROUND] = roundscope.MARK_ROUND
        MARK_OF[roundscope.RUN] = roundscope.MARK_RUN
    end
    return MARK_OF[group]
end

function roundscope.lobby_setup(fn, always)
    return function(o)
        if o ~= nil and roundscope.marking then
            if always or not ((run_on() or round_on()) and roundscope.inside(0)) then
                o[roundscope.MARK_FIELD] = roundscope.MARK_LOBBY
            elseif roundscope.SEPARATE_GROUPS then

                o[roundscope.MARK_FIELD] = mark_for(roundscope.group(0))
                    or roundscope.MARK_LOBBY
            end
        end
        if fn ~= nil then return fn(o) end
    end
end

function roundscope.round_audience()
    if roundscope.inside(0) or roundscope.held_here() then return true end
    local modes = OF.gamemodes
    return modes ~= nil and modes.is_out ~= nil and modes.is_out(0) == true
end

function roundscope.secret_round()
    if not round_on() then return false end
    local mode = asks(OF.gamemodes, "current") and OF.gamemodes.current() or nil
    return mode ~= nil and (mode.noNametags == true or mode.secret == true)
end

function roundscope.secret_from_me(i)
    if i == nil or i == 0 then return false end
    if not roundscope.secret_round() then return false end
    if roundscope.round_audience() then return false end
    if not roundscope.inside(i) then return false end
    local modes = OF.gamemodes
    return not (modes.is_out ~= nil and modes.is_out(i) == true)
end

function roundscope.out_vanishes(i)
    if i == nil or i == 0 or not round_on() then return false end
    local modes = OF.gamemodes
    if not asks(modes, "current") or not asks(modes, "is_out") then return false end
    local mode = modes.current()
    if mode == nil or mode.outVanishes ~= true then return false end
    if not modes.is_out(i) or modes.is_out(0) then return false end
    return roundscope.dealt(0)
end

function roundscope.hides_body(i)
    if i == nil or i == 0 then return false end
    if not (run_on() or round_on()) then return false end
    if not connected(i) then return false end
    if roundscope.out_vanishes(i) then return true end
    if not roundscope.SEPARATE_GROUPS then
        if roundscope.round_audience() then return not roundscope.inside(i) end
        return roundscope.secret_from_me(i)
    end
    return roundscope.group(i) ~= roundscope.screen_group()
end

function roundscope.screen_group()
    local mine = roundscope.group(0)
    if mine ~= roundscope.LOBBY then return mine end
    local spectate = OF.spectate
    if spectate ~= nil and spectate.target ~= nil and watching(0)
        and asks(OF.util, "local_from_global") then
        local at = OF.util.local_from_global(spectate.target)
        if at ~= nil and at ~= 0 then return roundscope.group(at) end
    end
    return mine
end

function roundscope.may_watch(i)
    return not roundscope.secret_from_me(i)
end

local function node_of(o)
    local header = o.header
    local gfx = header ~= nil and header.gfx or nil
    return gfx ~= nil and gfx.node or nil
end

roundscope.PARTICLES_HELD = 0x7FFFFFFF
local GRAPH_INVISIBLE = GRAPH_RENDER_INVISIBLE or 16
local heldParticles = {}

local heldIntangible = {}
roundscope.heldIntangible = heldIntangible

function roundscope.hide_body(m)
    if m == nil or m.marioObj == nil or m.playerIndex == 0 then return false end
    local i = m.playerIndex
    local o = m.marioObj
    if roundscope.hides_body(i) then
        local node = node_of(o)
        if node ~= nil and not OF.util.has_flag(node.flags, GRAPH_INVISIBLE) then
            node.flags = node.flags + GRAPH_INVISIBLE
        end
        o.oActiveParticleFlags = roundscope.PARTICLES_HELD
        heldParticles[i] = true
        if roundscope.SEPARATE_GROUPS then
            o.oIntangibleTimer = -1
            heldIntangible[i] = true
        end
        return true
    end
    if heldParticles[i] then
        heldParticles[i] = nil

        o.oActiveParticleFlags = 0
    end
    if heldIntangible[i] then
        heldIntangible[i] = nil

        if o.oIntangibleTimer == -1 and OF.util.same_world(i) then
            o.oIntangibleTimer = 0
        end
    end
    return false
end

function roundscope.hides_reflection(playerIndex)
    if playerIndex == nil or playerIndex == 0 then return false end
    return roundscope.hides_body(playerIndex)
end

function roundscope.mutes_voice(m)
    if m == nil or m.playerIndex == nil or m.playerIndex == 0 then return false end
    return roundscope.hides_body(m.playerIndex)
end

roundscope.ghostingNow = false

roundscope.ghostGroup = 0
roundscope.lobbyKept = false

function roundscope.ghosting()
    if not roundscope.marking then return false end
    if not (run_on() or round_on()) then return false end
    if not roundscope.SEPARATE_GROUPS then
        if not roundscope.round_audience() then return false end
    end
    local forge = OF.forge
    if forge ~= nil and forge.racer_round_here ~= nil and forge.racer_round_here()
        and roundscope.round_audience() then
        return false
    end
    return true
end

function roundscope.ghosts(o)
    if not roundscope.ghostingNow then return false end
    if not roundscope.SEPARATE_GROUPS then return roundscope.is_lobby_thing(o) end
    local by = roundscope.placed_by(o)
    return by ~= nil and by ~= roundscope.ghostGroup
end

local ghosted = {}
roundscope.ghosted = ghosted
local sweepIn = 0
roundscope.SWEEP_FRAMES = 10

local SWEPT_LISTS = { "OBJ_LIST_EXT", "OBJ_LIST_DESTRUCTIVE", "OBJ_LIST_GENACTOR",
    "OBJ_LIST_PUSHABLE", "OBJ_LIST_LEVEL", "OBJ_LIST_DEFAULT", "OBJ_LIST_SURFACE",
    "OBJ_LIST_POLELIKE", "OBJ_LIST_SPAWNER", "OBJ_LIST_UNIMPORTANT" }

local drawnHidden = {}
roundscope.drawnHidden = drawnHidden

local function let_go(o, kept)
    ghosted[o] = nil
    if o.activeFlags == 0 or roundscope.placed_by(o) == nil then return end
    o.oCollisionDistance = kept.dist
    if kept.hook ~= nil then o.hookRender = kept.hook end
end

local function hold(o)
    local kept = ghosted[o]
    if kept == nil then
        kept = { dist = o.oCollisionDistance, hook = o.hookRender }
        ghosted[o] = kept
    end

    o.oCollisionDistance = 0
    if o.hookRender ~= 1 then o.hookRender = 1 end
end

function roundscope.on_object_render(o)
    if o == nil or not roundscope.ghostingNow or ghosted[o] == nil then return end
    local node = node_of(o)
    if node ~= nil and not OF.util.has_flag(node.flags, GRAPH_INVISIBLE) then
        node.flags = node.flags + GRAPH_INVISIBLE
        drawnHidden[o] = true
    end
end

function roundscope.undraw_hidden()
    if next(drawnHidden) == nil then return end
    for o in pairs(drawnHidden) do
        drawnHidden[o] = nil
        local node = o.activeFlags ~= 0 and node_of(o) or nil
        if node ~= nil and OF.util.has_flag(node.flags, GRAPH_INVISIBLE) then
            node.flags = node.flags - GRAPH_INVISIBLE
        end
    end
end

function roundscope.ghost_frame()
    roundscope.undraw_hidden()
    local on = roundscope.ghosting()
    roundscope.ghostingNow = on
    if on then roundscope.ghostGroup = roundscope.screen_group() end
    if not on then
        if next(ghosted) ~= nil then
            for o, kept in pairs(ghosted) do let_go(o, kept) end
        end
        sweepIn = 0
        return 0
    end
    if sweepIn <= 0 and obj_get_first ~= nil then
        sweepIn = roundscope.SWEEP_FRAMES
        for _, name in ipairs(SWEPT_LISTS) do
            local list = rawget(_G, name)
            local o = list ~= nil and obj_get_first(list) or nil
            while o ~= nil do
                if roundscope.ghosts(o) then hold(o) end
                o = obj_get_next(o)
            end
        end
    end
    sweepIn = sweepIn - 1
    local count = 0
    for o in pairs(ghosted) do
        if o.activeFlags == 0 or roundscope.placed_by(o) == nil then

            ghosted[o] = nil
        elseif not roundscope.ghosts(o) then

            let_go(o, ghosted[o])
        else
            hold(o)
            count = count + 1
        end
    end
    return count
end

roundscope.MUTED_SOUND = 15 << 28

local function camera_spot(o)
    local header = o ~= nil and o.header or nil
    local gfx = header ~= nil and header.gfx or nil
    return gfx ~= nil and gfx.cameraToObject or nil
end

local function same_place(pos, at)
    return at ~= nil and pos.x == at.x and pos.y == at.y and pos.z == at.z
end

function roundscope.mutes_sound(pos)
    if pos == nil or not (run_on() or round_on()) then return nil end

    if pos.x == 0 and pos.y == 0 and pos.z == 0 then return nil end
    for i = 1, MAX_PLAYERS - 1 do

        if heldParticles[i] and roundscope.hides_body(i) then
            local m = gMarioStates[i]
            local o = m ~= nil and m.marioObj or nil
            if same_place(pos, camera_spot(o)) then
                return roundscope.MUTED_SOUND
            end
        end
    end
    for o in pairs(ghosted) do
        if same_place(pos, camera_spot(o)) then
            return roundscope.MUTED_SOUND
        end
    end
    return nil
end

function roundscope.keep_watch_fair()
    local spectate = OF.spectate
    if spectate == nil or spectate.target == nil or spectate.stop == nil then return false end
    local li = asks(OF.util, "local_from_global") and OF.util.local_from_global(spectate.target) or nil
    if li == nil or roundscope.may_watch(li) then return false end
    spectate.stop()
    if asks(OF.notify, "show") then
        OF.notify.show("A hide round is on - you cannot watch its players",
            "warn", 4)
    end
    return true
end

function roundscope.keeps_whereabouts()
    if not roundscope.secret_round() then return false end
    return not roundscope.round_audience()
end

roundscope.wasKeepingWhereabouts = false

function roundscope.castle_frame()
    roundscope.ghost_frame()
    roundscope.keep_watch_fair()
    local keep = roundscope.keeps_whereabouts()
    if keep ~= roundscope.wasKeepingWhereabouts then
        roundscope.wasKeepingWhereabouts = keep
        if asks(OF.rules, "apply") then OF.rules.apply() end
    end
end

roundscope.NOTICE_FRAMES = 150

local noticeLeft = 0
local noticeState = nil
local noticePosted = false

function roundscope.outside_the_round()
    local modes = OF.gamemodes
    if modes == nil or modes.state == nil or modes.hears_round == nil then
        return false
    end
    if modes.state() == modes.OFF then return false end
    return modes.hears_round() ~= true
end

local function round_name()
    local modes = OF.gamemodes
    local mode = asks(modes, "current") and modes.current() or nil
    if mode == nil or type(mode.name) ~= "string" or mode.name == "" then return nil end
    return mode.name
end

function roundscope.outsider_line()
    if not roundscope.outside_the_round() then return nil end
    local modes = OF.gamemodes
    local state = modes.state()
    if state ~= modes.COUNTDOWN and not (state == modes.ACTIVE and noticeLeft > 0) then
        return nil
    end
    local name = round_name()
    if name == nil then return OF.lang.t("A round has started") end
    return OF.lang.fill("A round of @ has started", name)
end

function roundscope.notice_tick()
    local modes = OF.gamemodes
    if modes == nil or modes.state == nil then return end
    local state = modes.state()
    if state ~= noticeState then

        if state == modes.COUNTDOWN or state == modes.OFF
            or (state == modes.ACTIVE and noticeState ~= modes.COUNTDOWN) then
            noticePosted = false
        end
        noticeState = state
        if state == modes.ACTIVE then noticeLeft = roundscope.NOTICE_FRAMES end
    end
    if noticeLeft > 0 then noticeLeft = noticeLeft - 1 end
    if noticePosted then return end
    local text = roundscope.outsider_line()
    if text == nil or not asks(OF.notify, "line_note") then return end
    local name = round_name()

    local covers = name ~= nil and OF.lang.fill("started @", OF.lang.t(name)) or nil
    OF.notify.line_note(text, covers)
    noticePosted = true
end

function roundscope.line_now()
    if not run_on() then return roundscope.LINE_NONE end
    if excluded_as(0, kind_of("KIND_RUN")) or watching(0) or stepped_away(0) then
        return roundscope.LINE_OFF
    end
    if roundscope.round_dealt(0) then return roundscope.LINE_OFF end
    return in_the_run(0) and roundscope.LINE_ON or roundscope.LINE_OFF
end

function roundscope.publish_line()
    local row = gPlayerSyncTable[0]
    if row == nil then return false end
    local want = roundscope.line_now()
    if row.ofOnLine == want then return false end
    OF.util.publish_row(0, "ofOnLine", want)
    return true
end

roundscope.SKIPPED_ROUND = "You are in the speedrun - this round goes on without you."
roundscope.SKIPPED_RUN = "You are in the round - this speedrun goes on without you."
local sawRound, sawRun = false, false

function roundscope.skip_notice()
    local round, run = round_on(), run_on()
    local said = nil
    if round and not sawRound and run and roundscope.taken_by_run(0)
        and not excluded_as(0, kind_of("KIND_MODE")) then
        said = roundscope.SKIPPED_ROUND
    elseif run and not sawRun and round and roundscope.round_dealt(0)
        and not excluded_as(0, kind_of("KIND_RUN")) then
        said = roundscope.SKIPPED_RUN
    end
    sawRound, sawRun = round, run
    if said ~= nil and asks(OF.notify, "show") then
        OF.notify.show(OF.lang.t(said), "info", 6)
    end
    return said
end

function roundscope.render_outsider()
    return roundscope.outside_the_round()
end

hook_event(HOOK_UPDATE, function()
    roundscope.watch()
    roundscope.publish_line()
    roundscope.skip_notice()
    roundscope.notice_tick()
    roundscope.castle_frame()
end)

hook_event(HOOK_ON_OBJECT_RENDER, roundscope.on_object_render)
