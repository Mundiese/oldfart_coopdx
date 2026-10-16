OF = OF or {}

local ROLE_RACING = "racing"
local SILVERS = 5
local SET_POINTS = SILVERS + 1

local SILVER_SCALE = 0.7

local EXTRA_OUT = 420

local DEFAULT_TARGET = 3

local PTS_KEY = "ofSilverPts"
local SEED_KEY = "ofSilverSeed"
local TARGET_KEY = "ofSilverTo"
local GOT_ROW = "ofSilverGot"
local bannerAt = nil
local bannerBlink = -1
local bannerSet = nil

local lastBanked = nil

local hostNoPoints = false

local derivedFor, derived = nil, nil

local mode = {
    key = "silverfive",
    name = "Silver Five",
    blurb = "five silver stars of your own make a gold one",
    how = "Five silver stars of your own are out on the course.\n"
        .. "Nobody else sees yours, and nobody can take them.\n"
        .. "Take them all and your gold star comes out - touch it.\n"
        .. "Then a fresh set of silver stars appears somewhere else.\n"
        .. "First to the target, or the most gold stars at the clock.",
    aims = { [ROLE_RACING] = "Take your five silver stars, then your gold one." },
    minPlayers = 2,
    maps = "surveyed",
    surveyKeys = { "points" },
    openCourses = true,

    roomsOut = { { level = LEVEL_SL, area = 2 }, { level = LEVEL_THI, area = 3 },

        { level = LEVEL_TTC, area = 1 }, { level = LEVEL_RR, area = 1 },
        { level = LEVEL_BITDW, area = 1 }, { level = LEVEL_BITFS, area = 1 },
        { level = LEVEL_COTMC, area = 1 }, { level = LEVEL_LLL, area = 2 },
        { level = LEVEL_THI, area = 2 },

        { level = LEVEL_TTM, area = 1 },
    },
    room = { rules = { interactions = PLAYER_INTERACTIONS_NONE } },
    target = { name = "gold stars to win",
               asks = "How many gold stars win the round",
               default = DEFAULT_TARGET, min = 1, max = 5, step = 1 },
    defaultLimit = 180,
    music = SEQ_EVENT_POWERUP,
    teams = false,
}

local kit
do
    local STAR_LIFT, STAR_BOB, STAR_SPIN = 110, 25, 0x800
    local BANNER_FRAMES, BLINK_PERIOD, BLINK_ON = 90, 60, 50
    local own = {
        STAR_LIFT = STAR_LIFT,
        GRAB_RADIUS = 160,
        GRAB_HEIGHT = 250,
        POOL_WANT = 16,
        BANNER_FRAMES = BANNER_FRAMES,
    }

    function own.within(localIndex, spot, reach, height)
        local m = gMarioStates[localIndex]
        if m == nil or m.pos == nil or spot == nil then return nil end
        local dx, dz = m.pos.x - spot.x, m.pos.z - spot.z
        local flat = math.sqrt(dx * dx + dz * dz)
        if flat >= reach then return nil end
        if math.abs(m.pos.y - spot.y) >= (height or own.GRAB_HEIGHT) then return nil end
        return flat
    end

    local starScratch = { x = 0, y = 0, z = 0 }
    function own.draw_star(name, model, spot, phase, bounce, scale)
        local t = (OF.util.optional("get_global_timer", 0) or 0) / 30
        local lift = STAR_LIFT + math.abs(math.sin(t * 3 + (phase or 0))) * STAR_BOB
        if bounce then
            lift = STAR_LIFT + math.abs(math.sin(t * 6 + (phase or 0))) * 90
        end
        starScratch.x, starScratch.y, starScratch.z = spot.x, spot.y + lift, spot.z
        local token = OF.gamemodes.show_token(name, model, starScratch, STAR_SPIN)
        if token ~= nil and scale ~= nil then
            OF.util.optional("obj_scale", nil, token, scale)
        end
        return token
    end

    function own.banner_shows(elapsed)
        if elapsed == nil or elapsed < 0 or elapsed >= BANNER_FRAMES then return false end
        return (elapsed % BLINK_PERIOD) < BLINK_ON
    end

    function own.banner_blink(elapsed)
        if elapsed == nil or elapsed < 0 or elapsed >= BANNER_FRAMES then return nil end
        return math.floor(elapsed / BLINK_PERIOD)
    end
    kit = function() return own end
end

local function now_frame()
    return OF.util.optional("get_global_timer", 0) or 0
end

local function target_golds()
    local value = gGlobalSyncTable[TARGET_KEY]
    if type(value) ~= "number" or value <= 0 then return DEFAULT_TARGET end
    return value
end

local function golds_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    return math.floor((row ~= nil and tonumber(row.ofScore)) or 0)
end

local function mask_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    local value = row ~= nil and tonumber(row[GOT_ROW]) or nil
    if value == nil then return 0 end
    return math.floor(value) % 32
end

local function bit_set(mask, n)
    return math.floor(mask / (2 ^ (n - 1))) % 2 == 1
end

local function count_bits(mask)
    local count = 0
    for n = 1, SILVERS do if bit_set(mask, n) then count = count + 1 end end
    return count
end

local function silvers_of(localIndex)
    return count_bits(mask_of(localIndex))
end

local function pool()
    local text = gGlobalSyncTable[PTS_KEY]
    if type(text) ~= "string" or text == "" then return nil end
    if derivedFor == text then return derived end
    local points = OF.gamemodes.unpack_points(text)
    if points[1] == nil then return nil end
    local list = {}
    for i, p in ipairs(points) do list[i] = { x = p.x, y = p.y, z = p.z } end
    local base = #points
    local k = 0
    while #list < SET_POINTS do
        k = k + 1
        local from = points[((k - 1) % base) + 1]
        local angle = k * 2.4
        local x, z = from.x + math.sin(angle) * EXTRA_OUT, from.z + math.cos(angle) * EXTRA_OUT
        local y = from.y
        local floor = OF.util.optional("find_floor_height", nil, x, from.y + 300, z)
        if type(floor) == "number" and floor > from.y - 600 and floor < from.y + 300 then
            y = floor
        else
            x, z = from.x, from.z
        end
        table.insert(list, { x = x, y = y, z = z })
    end
    derivedFor, derived = text, list
    return list
end

function mode.set_points(globalIndex, set)
    local list = pool()
    if list == nil then return nil end
    local seed = math.floor(tonumber(gGlobalSyncTable[SEED_KEY]) or 1)
    local state = (seed * 7919 + (globalIndex or 0) * 104729 + (set or 0) * 1299709) % 2147483647
    local order = {}
    for i = 1, #list do order[i] = i end
    for i = #order, 2, -1 do
        state = (state * 48271) % 2147483647
        local j = (state % i) + 1
        order[i], order[j] = order[j], order[i]
    end
    local out = {}
    for n = 1, SET_POINTS do out[n] = list[order[n]] end
    return out
end

local function drawn_for()
    if OF.gamemodes.role(0) == ROLE_RACING and OF.util.can_play(0) then return 0 end
    local g = OF.spectate ~= nil and OF.spectate.target or nil
    if type(g) == "number" then
        local li = OF.util.local_from_global(g)
        if li ~= nil and OF.gamemodes.role(li) == ROLE_RACING then return li end
    end
    return nil
end

local function hide_all()
    for n = 1, SILVERS do OF.gamemodes.hide_token("silverstar" .. n) end
    OF.gamemodes.hide_token("silvergold")
end

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_RACING)
    end
    OF.util.publish(TARGET_KEY, options.target or DEFAULT_TARGET)
end

function mode.pin()
    hostNoPoints = false
    local here = OF.gamemodes.here_place(0)
    local points = here ~= nil and OF.gamemodes.surveyed_list(here, "points", kit().POOL_WANT) or nil
    if points == nil or points[1] == nil then
        hostNoPoints = true
        OF.util.publish(PTS_KEY, nil)
        return
    end
    OF.util.publish(PTS_KEY, OF.gamemodes.pack_points(points))
    OF.util.publish(SEED_KEY, math.random(1, 999999))
end

function mode.on_start()
    bannerAt, bannerBlink, bannerSet = nil, -1, nil
    lastBanked = nil
    OF.util.publish_row(0, GOT_ROW, 0)

end

function mode.late_join(localIndex)
    OF.gamemodes.set_role(localIndex, ROLE_RACING)
    return ROLE_RACING
end

function mode.scenery()
    if OF.gamemodes.state() == OF.gamemodes.OFF then return end
    local li = drawn_for()
    local np = li ~= nil and gNetworkPlayers[li] or nil
    local set = (li ~= nil and np ~= nil) and mode.set_points(np.globalIndex, golds_of(li)) or nil
    if set == nil then
        hide_all()
        return
    end
    local mask = mask_of(li)
    for n = 1, SILVERS do
        if bit_set(mask, n) then
            OF.gamemodes.hide_token("silverstar" .. n)
        else
            kit().draw_star("silverstar" .. n, E_MODEL_TRANSPARENT_STAR, set[n], n, false,
                SILVER_SCALE)
        end
    end
    if count_bits(mask) >= SILVERS then
        kit().draw_star("silvergold", E_MODEL_STAR, set[SET_POINTS], 0, false)

        local key = tostring(np.globalIndex) .. ":" .. tostring(golds_of(li))
        if bannerSet ~= key then
            bannerSet, bannerAt, bannerBlink = key, now_frame(), -1
        end
    else
        OF.gamemodes.hide_token("silvergold")
    end
    if bannerAt ~= nil then
        local blink = kit().banner_blink(now_frame() - bannerAt)
        if blink == nil then
            bannerAt = nil
        elseif blink > bannerBlink then
            bannerBlink = blink
            OF.gamemodes.round_sound(OF.sounds.RECORD)
        end
    end
end

function mode.update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if OF.gamemodes.role(0) ~= ROLE_RACING or not OF.util.can_play(0) then return end
    local np = gNetworkPlayers[0]
    if np == nil then return end
    local golds = golds_of(0)
    if lastBanked ~= nil and golds < lastBanked then golds = lastBanked end
    local set = mode.set_points(np.globalIndex, golds)
    if set == nil then return end
    local mask = mask_of(0)
    local radius, height = kit().GRAB_RADIUS, kit().GRAB_HEIGHT

    if count_bits(mask) >= SILVERS then
        if kit().within(0, set[SET_POINTS], radius, height) ~= nil then
            lastBanked = golds + 1
            OF.util.publish_row(0, "ofScore", golds + 1)
            OF.util.publish_row(0, GOT_ROW, 0)
            OF.gamemodes.cue("good")

            if OF.util.asks(OF.hud, "banner") then
                OF.hud.banner("medal", OF.lang.t("BANKED"), nil, { quiet = true })
            end
        end
        return
    end
    for n = 1, SILVERS do
        if not bit_set(mask, n) and kit().within(0, set[n], radius, height) ~= nil then
            mask = mask + 2 ^ (n - 1)
            OF.util.publish_row(0, GOT_ROW, math.floor(mask))
            if count_bits(mask) >= SILVERS then

                if OF.util.asks(OF.hud, "banner") then
                    OF.hud.banner("objective", OF.lang.t("GOLD STAR"), OF.lang.t("Yours is out"))
                end
            else
                OF.gamemodes.cue("chime")
            end
        end
    end
end

function mode.host_update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if hostNoPoints then
        OF.gamemodes.abandon("No spread of points was found on this course.")
        return
    end
    local target = target_golds()
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_RACING)) do
        local golds = golds_of(entry.localIndex)
        if golds >= target and entry.np ~= nil then
            OF.gamemodes.finish("@ banked @ gold stars and won.",
                entry.np.name, entry.np.name, tostring(golds))
            return
        end
    end
end

function mode.still_winnable()
    return #OF.gamemodes.with_role(ROLE_RACING) >= 2
end

function mode.terms()
    return OF.lang.fill("first to @ gold stars, or most at the clock",
        tostring(target_golds()))
end

function mode.on_timeout()
    local best, names = OF.gamemodes.best_of(OF.gamemodes.with_role(ROLE_RACING),
        function(entry) return golds_of(entry.localIndex) end, false,
        function(entry) return silvers_of(entry.localIndex) end)
    if best == nil then
        OF.gamemodes.finish("Nobody took a silver star.")
    elseif best <= 0 and #names > 1 then
        OF.gamemodes.finish("Time - nobody banked a gold star.")
    elseif #names > 1 then
        OF.gamemodes.finish(OF.lang.fill("Time - a draw at @ gold stars.", tostring(best)))
    else
        OF.gamemodes.finish("@ won - the most gold stars.", names[1], names[1])
    end
end

function mode.hud()

    local li = drawn_for()
    if li ~= nil and OF.util.asks(OF.hud, "state_line") then
        if silvers_of(li) >= SILVERS and li == 0 then
            OF.hud.state_line("gold", OF.lang.t("Gold star out"), { prio = 60, tone = "target" })
        end
        OF.hud.state_line("stars", nil, { prio = 50, icons = mode.star_icons(li) })
    end

    local board = OF.gamemodes.score_board(ROLE_RACING, golds_of,
        function(score, entry)
            return tostring(score) .. " + " .. tostring(silvers_of(entry.localIndex))
        end)

    if OF.util.asks(OF.gamemodes, "board_cap") then
        board = OF.gamemodes.board_cap(board, OF.gamemodes.SIDE_BOARD_ROWS or 4)
    end
    OF.util.board(djui_hud_get_screen_width() * 0.03,
        djui_hud_get_screen_height() * 0.24, OF.lang.t("Gold + silver"), board,
        { width = 200, column = 130 })
end

function mode.star_icons(li)
    local items = {}
    local mask = mask_of(li)
    for n = 1, SILVERS do
        items[n] = { icon = "star", tone = "silver", empty = not bit_set(mask, n) }
    end
    items[#items + 1] = { icon = "star", tone = "target", empty = silvers_of(li) < SILVERS }
    return items
end

mode.mask_of = mask_of
mode.silvers_of = silvers_of
mode.pool = pool

function mode.cleanup()
    hide_all()
    if OF.util.is_host() then
        OF.util.publish(PTS_KEY, nil)
        OF.util.publish(SEED_KEY, nil)
        OF.util.publish(TARGET_KEY, nil)
    end
    local row = gPlayerSyncTable[0]
    if row ~= nil and row[GOT_ROW] ~= nil then OF.util.publish_row(0, GOT_ROW, nil) end
    bannerAt, bannerBlink, bannerSet = nil, -1, nil
    lastBanked = nil
    hostNoPoints = false
    derivedFor, derived = nil, nil
    return true
end

local starTarget = { id = "star", compass = "offscreen", lift = 110 }
local starList = { starTarget }
function mode.targets(viewer)
    local _ = viewer
    if drawn_for() ~= 0 then return nil end
    local np = gNetworkPlayers[0]
    local m = gMarioStates[0]
    if np == nil or m == nil or m.pos == nil then return nil end
    local set = mode.set_points(np.globalIndex, golds_of(0))
    if set == nil then return nil end
    if silvers_of(0) >= SILVERS then
        starTarget.pos = set[SET_POINTS]
        starTarget.id, starTarget.label, starTarget.tone = "star:gold", "gold star", "gold"
        starTarget.priority = 90
        return starList
    end
    local mask = mask_of(0)
    local best, bestD = nil, nil
    for n = 1, SILVERS do
        local spot = set[n]
        if spot ~= nil and not bit_set(mask, n) then
            local dx, dz = spot.x - m.pos.x, spot.z - m.pos.z
            local d = dx * dx + dz * dz
            if bestD == nil or d < bestD then best, bestD = n, d end
        end
    end
    if best == nil then return nil end
    starTarget.pos = set[best]
    starTarget.id = "star:silver:" .. tostring(best)
    starTarget.label, starTarget.tone = "silver star", { 200, 220, 235 }
    starTarget.priority = 80
    return starList
end

OF.gamemodes.register(mode)
