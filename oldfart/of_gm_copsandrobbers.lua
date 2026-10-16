OF = OF or {}

local ROLE_COP = "cop"
local ROLE_ROBBER = "robber"
local CELL_RADIUS = 250
local CELL_HEIGHT = 250

local function rescue_reach()
    local width = OF.markers ~= nil and tonumber(OF.markers.RING_WIDTH) or 48
    return CELL_RADIUS + width / 2
end

local CONTAIN_SLACK = 0

local CELL_LIFT = 40

local COP_FRACTION = { balanced = 0.4, quarter = 0.25, third = 1 / 3, half = 0.5 }
local COPS_AT_LEAST = 2

local FREE_AFTER_SECONDS = 10
local FREE_AFTER = FREE_AFTER_SECONDS * 30

local COP_SIDE, ROBBER_SIDE = "blue", "red"
local function cop_count(total)
    local frac = COP_FRACTION[OF.gamemodes.option_now("cops")] or COP_FRACTION.balanced
    local n = math.floor(total * frac + 0.5)
    if total >= 4 then n = math.max(n, COPS_AT_LEAST) end
    return math.max(1, math.min(total - 1, n))
end

function OF.gm_copsandrobbers_cops_for(total)
    return cop_count(total)
end

local function release_needs_pound()
    return OF.gamemodes.option_now("release") == "pound"
end

local hostNoCell = false

local heldSince = {}
local hostTick = 0

local myHeldFor = 0

local wasHeld = false

local heldSeen = nil

local seenHeld = {}
local copWasClose = false
local COP_CLOSE = 600

local mode = {
    key = "copsandrobbers",
    name = "Cops and Robbers",
    blurb = "cops catch robbers with a touch - a free robber breaks them out",

    how = "A touch from a cop sends a robber to the cell.\n"
        .. "After ten seconds, a free robber at the cell frees you.\n"
        .. "Cops cannot open the cell themselves.\n"
        .. "Cops win once the cell holds every robber.\n"
        .. "Robbers win if the clock runs out first.\n"
        .. "How many cops, and how the cell opens, are dials.",
    aims = {
        [ROLE_COP] = "Tag robbers into the cell, and guard it - only you cannot open it.",
        [ROLE_ROBBER] = "Stay free, or reach the cell to free everybody held in it.",
    },

    minPlayers = 3,
    maps = "surveyed",
    surveyKeys = { "points" },
    openCourses = true,

    roomsOut = {
        { level = LEVEL_RR, area = 1 }, { level = LEVEL_BITDW, area = 1 },
        { level = LEVEL_BITFS, area = 1 }, { level = LEVEL_TTC, area = 1 },

        { level = LEVEL_SL, area = 2 }, { level = LEVEL_THI, area = 3 },

        { level = LEVEL_LLL, area = 1 }, { level = LEVEL_COTMC, area = 1 },

        { level = LEVEL_TTM, area = 1 }, { level = LEVEL_THI, area = 2 },
    },
    room = { rules = { interactions = PLAYER_INTERACTIONS_PVP } },

    defaultLimit = 180,
    music = SEQ_LEVEL_KOOPA_ROAD,
    teams = false,

    sideNames = { blue = "Cops", red = "Robbers" },

    surveyOverrides = { "cvrCell" },

    catchers = { [ROLE_COP] = true },

    cheatsGiven = OF.gamemodes.water_rule("chase"),

    caps = { tiebreak = false },
    options = {
        { key = "cops", name = "How many cops",
          help = "the share of the lobby dealt cops rather than robbers",
          choices = {
              { key = "balanced", name = "two in five",
                help = "two against three at five, six against ten at sixteen" },
              { key = "quarter", name = "a quarter", help = "4 cops at 16" },
              { key = "third", name = "a third", help = "a smaller robber side, a shorter hunt" },
              { key = "half", name = "half", help = "an even split - the hardest the cell ever has it" },
          } },
        { key = "release", name = "How the cell opens",
          help = "what a free robber has to do at the cell to open it",
          choices = {
              { key = "touch", name = "touch it", help = "the simpler shape - reach it, and everybody is free" },
              { key = "pound", name = "ground-pound it",
                help = "a free robber must ground-pound the cell" },
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

local open_the_cell, claim_the_cell

local CELL_KEY = "ofCrCellAt"
local HELD_KEY = "ofCrHeld"
function OF.gm_copsandrobbers_cell_from(place)
    if place == nil then return nil end
    local own = OF.gamemodes.surveyed(place, "cvrCell")
    if type(own) == "table" and own.x ~= nil then
        return { x = own.x, y = own.y, z = own.z }
    end
    local points = OF.gamemodes.surveyed_list(place, "points", 3)
    if points == nil or points[1] == nil then return nil end
    return points[1]
end

local function cell_spot()
    local text = gGlobalSyncTable[CELL_KEY]
    if type(text) ~= "string" or text == "" then return nil end
    local list = OF.gamemodes.unpack_points(text)
    return list[1]
end

local function within(localIndex, spot, reach)
    local m = gMarioStates[localIndex]
    if m == nil or m.pos == nil or spot == nil then return nil end
    local dx, dz = m.pos.x - spot.x, m.pos.z - spot.z
    local flat = math.sqrt(dx * dx + dz * dz)
    if flat >= reach then return nil end
    if math.abs(m.pos.y - spot.y) >= CELL_HEIGHT then return nil end
    return flat
end

local function is_held(localIndex)
    local row = gPlayerSyncTable[localIndex]
    return row ~= nil and row.ofCrHeld == true
end

local function active(role)
    local out = {}
    for _, entry in ipairs(OF.gamemodes.with_role(role)) do
        if OF.util.can_play(entry.localIndex) then table.insert(out, entry) end
    end
    return out
end

function mode.clock_for(total)
    local robbers = math.max(0, total - cop_count(total))
    return OF.util.clamp(OF.gamemodes.round_to(90 + 18 * robbers, 30), 150, 270)
end

function mode.setup(players, options)
    if options == nil or tonumber(options.limit) == nil then
        OF.util.publish("ofGmLimit", mode.clock_for(#players))
    end
    local count = cop_count(#players)
    local picked = OF.gamemodes.deal_it(players, count, false)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex,
            picked[entry.localIndex] and ROLE_COP or ROLE_ROBBER)

        OF.util.publish_row(entry.localIndex, "ofCrHeld", nil)
    end

    OF.util.publish("ofTeamsOn", true)
    for _, entry in ipairs(players) do
        OF.util.publish_row(entry.localIndex, "ofTeam",
            picked[entry.localIndex] and COP_SIDE or ROBBER_SIDE)
    end
end

function mode.pin()
    hostNoCell = false
    local here = OF.gamemodes.here_place(0)
    if here == nil then
        hostNoCell = true
        OF.util.publish(CELL_KEY, nil)
        return
    end
    local cell = OF.gm_copsandrobbers_cell_from(here)
    if cell == nil then
        hostNoCell = true
        OF.util.publish(CELL_KEY, nil)
        return
    end
    OF.util.publish(CELL_KEY, OF.gamemodes.pack_points({ cell }))
end

function mode.side_place(side)
    if side ~= nil then return nil end
    local place = OF.gamemodes.round_place()
    if place == nil then
        local np = gNetworkPlayers[0]
        if np == nil or not np.currAreaSyncValid then return nil end
        place = { level = np.currLevelNum, area = np.currAreaIndex }
    end
    local at = nil
    if OF.gamemodes.role(0) == ROLE_COP then
        at = cell_spot() or OF.gm_copsandrobbers_cell_from(place)
    else
        local points = OF.gamemodes.surveyed_list(place, "points", 3)
        at = points ~= nil and (points[2] or points[1]) or nil
    end
    if at == nil then return nil end
    return { x = at.x, y = at.y, z = at.z, level = place.level,
             area = place.area }
end

function mode.on_start()
    wasHeld = false
    seenHeld = {}
    copWasClose = false
    heldSince = {}
    hostTick = 0
    myHeldFor = 0
    heldSeen = nil

end

function mode.late_join(localIndex)

    OF.gamemodes.set_role(localIndex, ROLE_ROBBER)
    OF.util.publish_row(localIndex, "ofCrHeld", nil)

    if OF.util.is_host() then
        OF.util.publish_row(localIndex, "ofTeam", ROBBER_SIDE)
    end
    return ROLE_ROBBER
end

function mode.scenery() end

local function hear_the_cell()
    local asked = 0
    local freed = 0
    for i = 0, MAX_PLAYERS - 1 do
        local robber = OF.gamemodes.role(i) == ROLE_ROBBER
        local held = robber and is_held(i)
        if robber and seenHeld[i] and not held then freed = freed + 1 end
        if held and not seenHeld[i] then
            local m = gMarioStates[i]
            OF.gamemodes.cue("out", m ~= nil and m.marioObj or nil, "crcell" .. i)
            if i == 0 then
                OF.gamemodes.cue("bad")
            elseif OF.gamemodes.catcher_of(i) == 0 then
                OF.gamemodes.cue("good")
            end
            asked = asked + 1
        end
        seenHeld[i] = held
    end

    if freed > 0 then
        local mine = OF.gamemodes.role(0)
        if mine == ROLE_ROBBER then
            OF.gamemodes.cue("good", nil, "crfree")
            asked = asked + 1
        elseif mine == ROLE_COP then
            OF.gamemodes.cue("bad", nil, "crfree")
            asked = asked + 1
        end
    end

    if OF.gamemodes.role(0) == ROLE_ROBBER and not is_held(0) then
        local close = false
        for _, entry in ipairs(OF.gamemodes.with_role(ROLE_COP)) do
            local d = OF.gamemodes.distance(0, entry.localIndex)
            if d ~= nil and d <= COP_CLOSE then close = true break end
        end
        if close and not copWasClose then
            OF.gamemodes.cue("hazard")
            asked = asked + 1
        end
        copWasClose = close
    else
        copWasClose = false
    end
    return asked
end
OF.gm_copsandrobbers_hear = hear_the_cell

function mode.update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    hear_the_cell()
    if OF.gamemodes.role(0) ~= ROLE_ROBBER then return end
    if not OF.util.can_play(0) then return end

    local held = is_held(0)
    local cell = cell_spot()
    claim_the_cell()

    if held and not wasHeld then
        if cell ~= nil and OF.util.asks(OF.net, "snap_to") then
            OF.net.snap_to(cell.x, cell.y + CELL_LIFT, cell.z, nil)

            OF.util.camera_behind_soon()
        end

        if OF.util.asks(OF.hud, "banner") then
            OF.hud.banner("out", OF.lang.t("CAUGHT"), OF.lang.t("To the cell"))
        end
    end
    wasHeld = held
    if held then myHeldFor = myHeldFor + 1 else myHeldFor = 0 end

    if held and cell ~= nil then
        OF.util.wall_in(gMarioStates[0], cell.x, cell.z, CELL_RADIUS + CONTAIN_SLACK)
    end
end

function mode.on_tag(aIndex, vIndex)
    if not OF.util.is_host() then return false end
    if OF.gamemodes.current() ~= mode then return false end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false end
    if aIndex == nil or vIndex == nil or aIndex == vIndex then return false end
    if OF.gamemodes.role(aIndex) ~= ROLE_COP then return false end
    if OF.gamemodes.role(vIndex) ~= ROLE_ROBBER then return false end
    if is_held(vIndex) then return false end

    OF.util.publish_row(vIndex, "ofCrHeld", true)
    heldSince[vIndex] = hostTick
    if OF.util.asks(OF.lobbytalk, "feed") then OF.lobbytalk.feed(aIndex, vIndex) end
    return true
end

open_the_cell = function(freer, heldList)
    if #heldList == 0 then return 0 end
    for _, li in ipairs(heldList) do
        OF.util.publish_row(li, "ofCrHeld", nil)
        heldSince[li] = nil
    end

    if freer ~= nil and OF.util.asks(OF.lobbytalk, "feed") then
        OF.lobbytalk.feed(freer, heldList[1], 2)
    end
    return #heldList
end

local function freeable()
    local out = {}

    if not OF.util.is_host() then return out end
    for _, entry in ipairs(active(ROLE_ROBBER)) do
        local li = entry.localIndex
        if is_held(li) and heldSince[li] ~= nil and hostTick - heldSince[li] >= FREE_AFTER then
            table.insert(out, li)
        end
    end
    return out
end

local CLAIM_SLACK = 2
function mode.on_claim(li, what)
    if what ~= "cell" or not OF.util.is_host() then return false end
    if OF.gamemodes.role(li) ~= ROLE_ROBBER or is_held(li) then return false end
    if not OF.util.can_play(li) then return false end
    local cell = cell_spot()
    if cell == nil or within(li, cell, rescue_reach() * CLAIM_SLACK) == nil then return false end
    local list = freeable()
    if #list == 0 then return false end
    return open_the_cell(li, list) > 0
end

local claimWait = 0
claim_the_cell = function()
    if claimWait > 0 then claimWait = claimWait - 1 return false end
    if OF.gamemodes.role(0) ~= ROLE_ROBBER or is_held(0) then return false end
    local anyHeld = false
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_ROBBER)) do
        if is_held(entry.localIndex) then anyHeld = true break end
    end
    if not anyHeld then return false end
    local cell = cell_spot()
    if cell == nil or within(0, cell, rescue_reach()) == nil then return false end
    local m = gMarioStates[0]
    if release_needs_pound() and (m == nil or m.action ~= ACT_GROUND_POUND) then return false end
    claimWait = 30
    return OF.gamemodes.claim("cell")
end
OF.gm_copsandrobbers_claim_the_cell = claim_the_cell
mode.rescue_reach = rescue_reach

local MARK_CLOSE = 1500
local function robber_marked(localIndex)
    if OF.gamemodes.role(0) ~= ROLE_COP then return false end
    if OF.gamemodes.role(localIndex) ~= ROLE_ROBBER or is_held(localIndex) then return false end
    local d = OF.gamemodes.distance(0, localIndex)
    return d ~= nil and d <= MARK_CLOSE
end

function mode.host_update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    hostTick = hostTick + 1

    if hostNoCell then
        OF.gamemodes.abandon("No spot for the cell was found on this course.")
        return
    end

    local cops = active(ROLE_COP)
    local robbers = active(ROLE_ROBBER)

    if #cops == 0 then
        OF.gamemodes.abandon("The last cop left.")
        return
    end
    if #robbers == 0 then
        OF.gamemodes.abandon("Every robber left.")
        return
    end

    local heldList = {}
    for _, entry in ipairs(robbers) do
        local li = entry.localIndex
        if is_held(li) then
            if heldSince[li] == nil then heldSince[li] = hostTick end
            if hostTick - heldSince[li] >= FREE_AFTER then
                table.insert(heldList, li)
            end
        else
            heldSince[li] = nil
        end
    end
    if #heldList > 0 then
        local needsPound = release_needs_pound()
        local freer = nil
        for _, entry in ipairs(robbers) do
            if not is_held(entry.localIndex) then
                local d = within(entry.localIndex, cell_spot(), rescue_reach())
                if d ~= nil then
                    local m = gMarioStates[entry.localIndex]
                    if not needsPound or (m ~= nil and m.action == ACT_GROUND_POUND) then
                        freer = entry.localIndex
                        break
                    end
                end
            end
        end
        if freer ~= nil then open_the_cell(freer, heldList) end
    end

    local stillHeld = 0
    for _, entry in ipairs(robbers) do
        if is_held(entry.localIndex) then stillHeld = stillHeld + 1 end
    end
    if stillHeld == #robbers then
        local names = {}
        for _, entry in ipairs(cops) do
            if entry.np ~= nil then table.insert(names, entry.np.name) end
        end
        OF.gamemodes.finish("The cell holds every robber - the cops win.",
            { names = names })
    end
end

function mode.still_winnable()
    return #active(ROLE_COP) > 0 and #active(ROLE_ROBBER) > 0
end

function mode.terms()

    if release_needs_pound() then
        return "every robber in the cell - a pound frees them"
    end
    return "every robber in the cell - a touch frees them"
end

function mode.on_timeout()
    local robbers = OF.gamemodes.with_role(ROLE_ROBBER)
    local names = {}
    for _, entry in ipairs(robbers) do
        if entry.np ~= nil then table.insert(names, entry.np.name) end
    end
    if #names == 0 then
        OF.gamemodes.finish("Time - no robbers were left to credit.")
        return
    end
    OF.gamemodes.finish("Time - the robbers stayed free and win.", { names = names })
end

function mode.robber_pips()
    local items = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_ROBBER)) do
        items[#items + 1] = { icon = "pip", tone = "runner", empty = not is_held(entry.localIndex) }
    end
    return items
end

function mode.hud()
    local state = OF.util.asks(OF.hud, "state_line") and OF.hud.state_line or function() end
    local held = 0
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_ROBBER)) do
        if is_held(entry.localIndex) then held = held + 1 end
    end
    if heldSeen ~= nil and heldSeen > 0 and held == 0 and OF.util.asks(OF.hud, "banner") then
        OF.hud.banner("objective", OF.lang.t("JAILBREAK"), nil,
            { side = OF.gamemodes.role(0) == ROLE_ROBBER and "us" or "them" })
    end
    heldSeen = held
    if OF.gamemodes.role(0) == ROLE_COP then
        state("robbers", nil, { prio = 50, icons = mode.robber_pips() })
    elseif OF.gamemodes.role(0) == ROLE_ROBBER then
        if is_held(0) then
            local wait = math.ceil((FREE_AFTER - myHeldFor) / 30)
            state("held", OF.lang.t("Held"), { prio = 70, tone = "bad", colour = true,
                figure = wait > 0 and wait or nil })
        else
            state("free", OF.lang.t("Free"), { prio = 30, tone = "good" })
        end
    end

    local cell = cell_spot()
    if cell ~= nil then
        local ringR, ringG, ringB = 255, 210, 60
        if OF.gamemodes.role(0) == ROLE_ROBBER and is_held(0) then
            ringR, ringG, ringB = 255, 120, 120
        end
        OF.util.zone_ring(cell, CELL_RADIUS, 40, 4, ringR, ringG, ringB, 200)
    end
end

function mode.cluster()
    if not OF.util.asks(OF.hunt, "role_cluster") or OF.gamemodes.is_waiting() then return nil end
    local free = 0
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_ROBBER)) do
        if not is_held(entry.localIndex) then free = free + 1 end
    end
    return OF.hunt.role_cluster("Cops", #OF.gamemodes.with_role(ROLE_COP), "hunter",
        "Free", free, "runner")
end

function mode.cleanup()
    if OF.util.is_host() then
        OF.util.publish(CELL_KEY, nil)
        for _, entry in ipairs(OF.gamemodes.with_role(ROLE_ROBBER)) do
            OF.util.publish_row(entry.localIndex, "ofCrHeld", nil)
        end
    end
    hostNoCell = false
    wasHeld = false
    seenHeld = {}
    copWasClose = false
    heldSince = {}
    myHeldFor = 0
    return true
end

local robberTargets = {}
local robberList = {}
function mode.targets(viewer)
    local _ = viewer
    for i = #robberList, 1, -1 do robberList[i] = nil end
    for _, entry in ipairs(OF.util.connected_players()) do
        local index = entry.localIndex
        if index ~= 0 and robber_marked(index) then
            local t = robberTargets[index] or { label = "robber", tone = "runner",
                priority = 70, compass = "offscreen" }
            robberTargets[index] = t
            t.id = "robber:" .. tostring(index)
            t.player = index
            robberList[#robberList + 1] = t
        end
    end
    return robberList
end

OF.gamemodes.register(mode)
