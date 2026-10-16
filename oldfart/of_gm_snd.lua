OF = OF or {}

local STATE_KEY = "ofSdState"
local BOMB_KEY = "ofSdBomb"
local SPOTS_KEY = "ofSdSpots"
local ROLE_FIGHT = "fighting"
local ROLE_OUT = "out"
local WIN_ROUNDS = 4
local SWITCH_EVERY = 2

local BOMB_SECONDS = 30
local COUNT_SECONDS = 3
local OVER_SECONDS = 5
local SWITCH_SECONDS = 2
local PLANT_FRAMES = 5 * 30
local DEFUSE_FRAMES = math.floor(7.5 * 30)
local ROUND_STOPS = { two = 120, twohalf = 150, three = 180 }

local SITE_REACH = 330
local SITE_HEIGHT = 300
local PICK_REACH = 170
local CLAIM_SLACK = 500
local BLAST_KILL = 1100
local BLAST_SHAKE = 4500
local BOX_SCALE_Y = 0.5
local BOMB_LIFT = 140
local BOX_MESH = "metal_box_seg8_collision_08024C28"
local PHASE_COUNT, PHASE_LIVE, PHASE_PLANTED, PHASE_OVER = "count", "live", "planted", "over"
local FIRST_ATTACK = "blue"
local seen = { round = nil, phase = nil, killSeq = 0, nade = false, flash = false,
               bar = 0, defusing = false, asked = nil, watchAt = -1, heard = nil,
               boomSeen = nil, credited = nil }

local host = { scores = {}, lastKill = {}, defuseFrom = nil }

local DEFUSE_SLACK = 1.0
function OF.gm_snd_defuse_grace(defuserGlobal)
    local li = defuserGlobal ~= nil and OF.util.local_from_global(defuserGlobal) or nil
    local np = li ~= nil and gNetworkPlayers[li] or nil
    local ping = np ~= nil and tonumber(np.ping) or 0
    return math.min(1.0, ping / 1000 + 2 / 30)
end
local boxes = { objs = {}, soc = {} }

local function now()
    return OF.gamemodes.since_start()
end

local function other(side)
    return side == "red" and "blue" or "red"
end

local function side_of(localIndex)
    local key = OF.util.asks(OF.teams, "of") and OF.teams.of(localIndex) or nil
    if key == "red" or key == "blue" then return key end
    return nil
end

local function global_of(localIndex)
    local np = gNetworkPlayers[localIndex]
    return np ~= nil and np.globalIndex or -1
end

local function local_of(globalIndex)
    if type(globalIndex) ~= "number" or globalIndex < 0 then return nil end
    return OF.util.local_from_global(globalIndex)
end

local stateText, stateRead = nil, nil
local function read_state()
    local text = gGlobalSyncTable[STATE_KEY]
    if type(text) ~= "string" or text == "" then return nil end
    if text == stateText then return stateRead end
    local f = {}
    for word in string.gmatch(text, "%S+") do f[#f + 1] = word end
    if #f < 10 then return nil end
    stateText = text
    stateRead = { round = tonumber(f[1]), phase = f[2], at = tonumber(f[3]),
        ends = tonumber(f[4]), wins = { red = tonumber(f[5]) or 0, blue = tonumber(f[6]) or 0 },
        first = f[7], winner = f[8], reason = f[9], decider = tonumber(f[10]) or -1 }
    return stateRead
end

local function pack_state(s)
    return string.format("%.0f %s %.2f %.2f %.0f %.0f %s %s %s %.0f", s.round, s.phase, s.at,
        s.ends, s.wins.red, s.wins.blue, s.first, s.winner or "-", s.reason or "-",
        s.decider or -1)
end

local function attack_side(round, first)
    local block = math.floor(((round or 1) - 1) / SWITCH_EVERY)
    if block % 2 == 0 then return first end
    return other(first)
end

local function switches_after(round)
    return (round or 1) % SWITCH_EVERY == 0
end

local function my_job(st)
    st = st or read_state()
    local side = side_of(0)
    if st == nil or side == nil then return nil end
    return side == attack_side(st.round, st.first) and "attack" or "defend"
end

local function sees_loose_bomb(st)
    return my_job(st) == "attack"
end

local bombText, bombRead = nil, nil
local function read_bomb()
    local text = gGlobalSyncTable[BOMB_KEY]
    if type(text) ~= "string" or text == "" then return nil end
    if text == bombText then return bombRead end
    local f = {}
    for word in string.gmatch(text, "%S+") do f[#f + 1] = word end
    if #f < 9 then return nil end
    local victims = {}
    if f[10] ~= nil and f[10] ~= "-" then
        for g in string.gmatch(f[10], "%-?%d+") do victims[#victims + 1] = tonumber(g) end
    end
    bombText = text
    bombRead = { state = f[1], x = tonumber(f[2]), y = tonumber(f[3]), z = tonumber(f[4]),
        carrier = tonumber(f[5]) or -1, planter = tonumber(f[6]) or -1,
        defuser = tonumber(f[7]) or -1, site = f[8], serial = tonumber(f[9]) or 0,
        victims = victims }
    return bombRead
end

local function pack_bomb(b)
    local victims = (b.victims ~= nil and #b.victims > 0) and table.concat(b.victims, ",") or "-"
    return string.format("%s %.0f %.0f %.0f %.0f %.0f %.0f %s %.0f %s", b.state, b.x or 0, b.y or 0,
        b.z or 0, b.carrier or -1, b.planter or -1, b.defuser or -1, b.site or "-",
        b.serial or 0, victims)
end

local spotsText, spotsRead = nil, nil
local function spots()
    local text = gGlobalSyncTable[SPOTS_KEY]
    if type(text) ~= "string" or text == "" then return nil end
    if text == spotsText then return spotsRead end
    local parts = {}
    for part in string.gmatch(text, "[^;]+") do parts[#parts + 1] = part end
    if #parts < 5 then return nil end
    local level, area = string.match(parts[1], "^(%-?%d+) (%-?%d+)$")
    local function point(t)
        local x, y, z = string.match(t or "", "^(%-?[%d%.]+) (%-?[%d%.]+) (%-?[%d%.]+)$")
        if x == nil then return nil end
        return { x = tonumber(x), y = tonumber(y), z = tonumber(z),
                 level = tonumber(level), area = tonumber(area) }
    end
    local out = { defend = point(parts[2]), attack = point(parts[3]),
                  A = point(parts[4]), B = point(parts[5]) }
    if out.defend == nil or out.attack == nil or out.A == nil or out.B == nil then return nil end
    spotsText, spotsRead = text, out
    return out
end

local function dist2(a, b)
    return (a.x - b.x) ^ 2 + (a.z - b.z) ^ 2
end

local function floor_near(x, y, z)
    local f = OF.util.optional("find_floor_height", nil, x, y + 400, z)
    if type(f) ~= "number" or f < y - 800 then return nil end
    return f
end

local function derive_spots(pool, red, blue)
    if (red == nil or blue == nil) and (pool == nil or #pool < 2) then return nil end
    local def, atk = red, blue
    if def == nil or atk == nil then
        local best = -1
        for i = 1, #pool do
            for j = i + 1, #pool do
                local d = dist2(pool[i], pool[j])
                if d > best then best, def, atk = d, pool[i], pool[j] end
            end
        end
    end
    local D = math.sqrt(dist2(def, atk))
    local cands = {}
    for _, p in ipairs(pool or {}) do
        local dd, da = math.sqrt(dist2(p, def)), math.sqrt(dist2(p, atk))
        if dd >= 0.15 * D and dd <= 0.55 * D and da >= 0.5 * D then cands[#cands + 1] = p end
    end
    local A, B, apart = nil, nil, -1
    for i = 1, #cands do
        for j = i + 1, #cands do
            local d = dist2(cands[i], cands[j])
            if d > apart then apart, A, B = d, cands[i], cands[j] end
        end
    end
    if A == nil or math.sqrt(apart) < 0.2 * D then
        local ux, uz = (atk.x - def.x) / math.max(D, 1), (atk.z - def.z) / math.max(D, 1)
        local px, pz = def.x + ux * D * 0.3, def.z + uz * D * 0.3
        local half = math.max(400, D * 0.25)
        local made = {}
        for k, sign in ipairs({ 1, -1 }) do
            local x, z = px - uz * half * sign, pz + ux * half * sign
            local y = floor_near(x, def.y, z)
            if y == nil then
                local nearest, nd = nil, nil
                for _, p in ipairs(pool or {}) do
                    local d = (p.x - x) ^ 2 + (p.z - z) ^ 2
                    if p ~= def and p ~= atk and (nd == nil or d < nd) then nearest, nd = p, d end
                end
                made[k] = nearest or { x = px, y = def.y, z = pz }
            else
                made[k] = { x = x, y = y, z = z }
            end
        end
        A, B = made[1], made[2]
    end
    return { defend = def, attack = atk, A = A, B = B }
end

local SITE_FLAT_RISE = 120
local WAY_PROBE = 700
local WAY_RISE = 260

local function site_flat(p)
    local half = 400
    for _, d in ipairs({ { half, half }, { -half, half }, { half, -half }, { -half, -half },
                         { half, 0 }, { -half, 0 }, { 0, half }, { 0, -half } }) do
        local y = floor_near(p.x + d[1], p.y, p.z + d[2])
        if y == nil or math.abs(y - p.y) > SITE_FLAT_RISE then return false end
    end
    return true
end

local function site_ways_in(p)
    local open = {}
    for k = 0, 7 do
        local a = k * math.pi / 4
        local x, z = p.x + math.sin(a) * WAY_PROBE, p.z + math.cos(a) * WAY_PROBE
        local y = floor_near(x, p.y, z)
        open[k] = y ~= nil and math.abs(y - p.y) <= WAY_RISE
    end
    local ways, all = 0, true
    for k = 0, 7 do
        if not open[k] then all = false end
        if open[k] and not open[(k + 7) % 8] then ways = ways + 1 end
    end
    if all then return 8 end
    return ways
end

local function site_fit(p)
    local fit = 0
    if site_flat(p) then fit = fit + 2 end
    local ways = site_ways_in(p)
    if ways >= 2 then fit = fit + 2 end
    if ways >= 2 and ways <= 3 then fit = fit + 1 end
    return fit
end

local function sites_from_points(dom)
    if dom == nil or dom[1] == nil or dom[2] == nil or dom[3] == nil then return nil end
    local three = { dom[1], dom[2], dom[3] }
    local fits = { site_fit(three[1]), site_fit(three[2]), site_fit(three[3]) }
    local best, bestFit, bestFar = nil, -1, -1
    for k = 1, 3 do
        local i, j = (k % 3) + 1, ((k + 1) % 3) + 1
        if i > j then i, j = j, i end
        local fit = fits[i] + fits[j]
        local far = math.min(dist2(three[k], three[i]), dist2(three[k], three[j]))
        if fit > bestFit or (fit == bestFit and far > bestFar) then
            best, bestFit, bestFar = { atk = k, A = i, B = j }, fit, far
        end
    end
    local atk, A, B = three[best.atk], three[best.A], three[best.B]

    local midX, midZ = (A.x + B.x) / 2, (A.z + B.z) / 2
    local midY = (A.y + B.y) / 2
    local dx, dz = midX - atk.x, midZ - atk.z
    local d = math.max(1, math.sqrt(dx * dx + dz * dz))
    local back = OF.util.clamp(d * 0.3, 400, 1500)
    local def = nil
    for _, c in ipairs({ { midX + dx / d * back, midZ + dz / d * back }, { midX, midZ },
                         { A.x + dx / d * 400, A.z + dz / d * 400 },
                         { B.x + dx / d * 400, B.z + dz / d * 400 } }) do
        local y = floor_near(c[1], midY, c[2])
        local clear = dist2({ x = c[1], z = c[2] }, A) > SITE_REACH * SITE_REACH * 2
            and dist2({ x = c[1], z = c[2] }, B) > SITE_REACH * SITE_REACH * 2
        if y ~= nil and clear then def = { x = c[1], y = y, z = c[2] }; break end
    end
    def = def or { x = A.x, y = A.y, z = A.z }
    return { defend = def, attack = atk, A = A, B = B, from = { best.A, best.B, best.atk } }
end

local function pack_spots(level, area, s)
    local function p(v) return string.format("%.0f %.0f %.0f", v.x, v.y, v.z) end
    return string.format("%.0f %.0f;%s;%s;%s;%s", level or 0, area or 1, p(s.defend), p(s.attack),
        p(s.A), p(s.B))
end

local function bomb_home(s)
    local dx, dz = s.defend.x - s.attack.x, s.defend.z - s.attack.z
    local d = math.max(1, math.sqrt(dx * dx + dz * dz))
    local x, z = s.attack.x + dx / d * 250, s.attack.z + dz / d * 250
    return x, floor_near(x, s.attack.y, z) or s.attack.y, z
end

local function spawn_for(localIndex, st)
    local s = spots()
    local side = side_of(localIndex)
    if s == nil or side == nil or st == nil then return nil end
    local job = side == attack_side(st.round, st.first) and "attack" or "defend"
    local centre = job == "attack" and s.attack or s.defend
    local facing = job == "attack" and s.defend or s.attack
    local mates = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        if side_of(entry.localIndex) == side then mates[#mates + 1] = global_of(entry.localIndex) end
    end
    table.sort(mates)
    local k = 0
    for i, g in ipairs(mates) do if g == global_of(localIndex) then k = i - 1 end end
    local x, y, z = centre.x, centre.y, centre.z
    if k > 0 then
        local ringIndex = math.floor((k - 1) / 6)
        local a = (k - 1) * math.pi / 3 + ringIndex * 0.5
        local r = 180 + 140 * ringIndex
        local tx, tz = centre.x + math.sin(a) * r, centre.z + math.cos(a) * r
        local ty = floor_near(tx, centre.y, tz)
        if ty ~= nil and math.abs(ty - centre.y) < 300 then x, y, z = tx, ty, tz end
    end
    local yaw = atan2s ~= nil and atan2s(facing.z - z, facing.x - x) or 0
    return x, y, z, yaw
end

local function fighters(side)
    local out = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_FIGHT)) do
        if side_of(entry.localIndex) == side and OF.util.can_play(entry.localIndex) then
            out[#out + 1] = entry
        end
    end
    return out
end

local function sided(side)
    local out = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        local role = OF.gamemodes.role(entry.localIndex)
        if (role == ROLE_FIGHT or role == ROLE_OUT) and side_of(entry.localIndex) == side then
            out[#out + 1] = entry
        end
    end
    return out
end

local function round_seconds(count)
    local pick = OF.gamemodes.option_now("round") or "auto"
    if ROUND_STOPS[pick] ~= nil then return ROUND_STOPS[pick] end
    return (count or 0) >= 9 and ROUND_STOPS.twohalf or ROUND_STOPS.two
end

local function kills_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    return math.floor((row ~= nil and tonumber(row.ofScore)) or 0)
end

local mode = {
    key = "snd",

    tagRule = "shooter",
    name = "Search and Destroy",
    blurb = "plant the bomb or stop it - one life a round, first to four",
    blurbTeams = "plant the bomb or stop it - one life a round, first to four",
    how = "One side attacks, one defends; swap every two rounds.\n"
        .. "Attackers carry the bomb to site A or B.\n"
        .. "Hold B at the box 5 seconds to plant; letting go resets it.\n"
        .. "A planted bomb beeps faster; it goes off in 30 seconds.\n"
        .. "One at a time, defenders hold B 7.5 seconds to defuse.\n"
        .. "Down is out until the next round; watch your side.\n"
        .. "Wipe them out, or defend until the clock runs out.\n"
        .. "One grenade (Y), one flash nut (X) a round.\n"
        .. "No friendly fire. First side to four rounds wins.",
    aims = { [ROLE_FIGHT] = "Plant the bomb, or stop them planting it." },
    minPlayers = 2,
    sidesFrom = 2,
    teams = "always",
    maps = "surveyed",
    surveyKeys = { "points" },
    spotKeys = { "sdDefend", "sdAttack", "sdSiteA", "sdSiteB" },
    venueFamily = "objective",
    venueNeeds = {
        keys = { sdDefend = 8, sdAttack = 8, sdSiteA = 1, sdSiteB = 1 },
        attackToSiteSeconds = { 12, 18 }, siteGapShare = 0.10,
        defendToSiteSeconds = { 4, 7 }, rotationShare = 0.70,
        siteFlat = 800, siteWaysIn = { 2, 3 }, siteCover = { 150, 300, 400, 800 },
        siteHiddenFromAttack = true, sightlineMost = 6000, lanes = 3,
    },

    surveyOut = OF.gamemodes.BY_KEY ~= nil and OF.gamemodes.BY_KEY.domination ~= nil
        and OF.gamemodes.BY_KEY.domination.surveyOut or nil,
    room = { sweep = { "cannons" }, rules = { bubble = 0 } },
    lobbyRules = { interactions = PLAYER_INTERACTIONS_PVP },
    cheatsGiven = { sniper = function() return 2 end },
    roundKills = true,
    shooterKit = true,
    noFriendlyFire = true,
    noNametags = true,
    symmetric = true,

    caps = { tiebreak = false },

    outWord = "Down",
    rolesDiffer = true,
    roleNoun = function()
        local job = my_job(read_state())
        if job == "attack" then return "Attack" end
        if job == "defend" then return "Defend" end
        return nil
    end,

    defaultLimit = (WIN_ROUNDS * 2 - 1)
        * (ROUND_STOPS.three + BOMB_SECONDS + COUNT_SECONDS + OVER_SECONDS + SWITCH_SECONDS) + 60,
    music = SEQ_LEVEL_KOOPA_ROAD,
    options = {
        { key = "round", name = "How long a round runs",
          help = "the clock each round is played against",
          choices = {
              { key = "auto", name = "for the lobby",
                help = "two minutes, two and a half from nine players" },
              { key = "two", name = "two minutes",
                help = "most fights are settled inside a minute" },
              { key = "twohalf", name = "two and a half minutes",
                help = "more time to work round to a site" },
              { key = "three", name = "three minutes",
                help = "a slow, careful attack" },
          } },
        { key = "replay", name = "Replay at each round's end",
          help = "the seconds before the round was decided, again",
          choices = {
              { key = "short", name = "the last three seconds",
                help = "played while the next round waits" },
              { key = "long", name = "the last six seconds",
                help = "a longer look at how it was won" },
              { key = "off", name = "no replay",
                help = "straight on to the next round" },
          } },
    },
}

mode.ROLE_FIGHT, mode.ROLE_OUT = ROLE_FIGHT, ROLE_OUT
mode.WIN_ROUNDS, mode.BOMB_SECONDS = WIN_ROUNDS, BOMB_SECONDS
mode.PLANT_FRAMES, mode.DEFUSE_FRAMES = PLANT_FRAMES, DEFUSE_FRAMES

mode.BOX_TOP = 307 * BOX_SCALE_Y

mode.HOVER_GAP, mode.HOVER_BOB, mode.HOVER_SPIN = 45, 10, 0x200

function mode.hover_y(top, frame)
    return top + mode.HOVER_GAP + mode.HOVER_BOB * math.sin((frame or 0) / 8)
end
mode.SITE_REACH, mode.CLAIM_SLACK = SITE_REACH, CLAIM_SLACK

mode.crates = boxes
mode.read_state, mode.read_bomb, mode.spots = read_state, read_bomb, spots
mode.attack_side, mode.derive_spots, mode.round_seconds = attack_side, derive_spots, round_seconds
mode.sites_from_points = sites_from_points
mode.my_job, mode.spawn_for = my_job, spawn_for

function mode.backstop(seconds)
    local rounds = WIN_ROUNDS * 2 - 1
    return rounds * (seconds + BOMB_SECONDS + COUNT_SECONDS + OVER_SECONDS + SWITCH_SECONDS) + 60
end

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_FIGHT)
    end
    if options == nil or tonumber(options.limit) == nil then
        OF.util.publish("ofGmLimit", mode.backstop(round_seconds(#players)))
    end
    host.scores, host.lastKill = {}, {}
end

function mode.pin()
    local here = OF.gamemodes.here_place(0)
    if here == nil then return end
    local function one(key)
        local list = OF.gamemodes.surveyed_list(here, key)
        return list ~= nil and list[1] or nil
    end
    local own = { defend = one("sdDefend"), attack = one("sdAttack"),
                  A = one("sdSiteA"), B = one("sdSiteB") }
    local s = own
    if own.defend == nil or own.attack == nil or own.A == nil or own.B == nil then

        s = sites_from_points(OF.gamemodes.surveyed_list(here, "points"))
        if s == nil then
            s = derive_spots(OF.gamemodes.surveyed_list(here, "points", 16),
                one("ctfRed"), one("ctfBlue"))
        end
    end
    if s == nil then
        OF.util.publish(SPOTS_KEY, nil)
        return
    end
    OF.util.publish(SPOTS_KEY, pack_spots(here.level, here.area, s))
end

function mode.late_join(localIndex)
    if side_of(localIndex) == nil and OF.util.asks(OF.teams, "add_late") then
        OF.teams.add_late(localIndex)
    end
    OF.gamemodes.set_role(localIndex, ROLE_OUT)
    return ROLE_OUT
end

function mode.on_start()
    seen.round, seen.phase, seen.killSeq = nil, nil, OF.shooter.kill_seq()
    seen.nade, seen.flash, seen.bar, seen.defusing = false, false, 0, false
    seen.asked, seen.watchAt, seen.heard, seen.boomSeen, seen.credited = nil, -1, nil, nil, nil
    OF.util.publish_row(0, "ofScore", 0)
end

local function publish_state(s) OF.util.publish(STATE_KEY, pack_state(s)) end

local function new_bomb(serial)
    local s = spots()
    local x, y, z = bomb_home(s)
    return { state = "base", x = x, y = y, z = z, carrier = -1, planter = -1, defuser = -1,
             site = "-", serial = serial or 0, victims = {} }
end

local function start_round(st)

    for _, entry in ipairs(OF.util.connected_players()) do
        local role = OF.gamemodes.role(entry.localIndex)
        if side_of(entry.localIndex) ~= nil and (role == ROLE_FIGHT or role == ROLE_OUT) then
            OF.gamemodes.set_role(entry.localIndex, ROLE_FIGHT)
        end
    end
    if st.round == 1 then
        st.phase, st.at = PHASE_LIVE, now()
        st.ends = now() + round_seconds(#OF.gamemodes.participants())
    else
        st.phase, st.at, st.ends = PHASE_COUNT, now(), now() + COUNT_SECONDS
    end
    st.winner, st.reason, st.decider = "-", "-", -1
    publish_state(st)
    local b = read_bomb()
    OF.util.publish(BOMB_KEY, pack_bomb(new_bomb((b ~= nil and b.serial or 0) + 1)))
end

local function end_round(st, winner, reason, decider)
    st.wins[winner] = (st.wins[winner] or 0) + 1
    st.phase, st.at = PHASE_OVER, now()
    st.ends = now() + OVER_SECONDS + (switches_after(st.round) and SWITCH_SECONDS or 0)
    st.winner, st.reason, st.decider = winner, reason, decider or -1
    publish_state(st)
end

local function host_note_kills()
    for _, entry in ipairs(OF.gamemodes.participants()) do
        local g, k = global_of(entry.localIndex), kills_of(entry.localIndex)
        local was = host.scores[g]
        if was ~= nil and k > was then
            local side = side_of(entry.localIndex)
            if side ~= nil then host.lastKill[side] = g end
        end
        host.scores[g] = k
    end
end

local function blow(st, b)
    local victims = {}
    local planterSide = attack_side(st.round, st.first)
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_FIGHT)) do
        local m = gMarioStates[entry.localIndex]
        if m ~= nil and m.pos ~= nil
            and (m.pos.x - b.x) ^ 2 + (m.pos.y - b.y) ^ 2 + (m.pos.z - b.z) ^ 2
                < BLAST_KILL * BLAST_KILL then

            victims[#victims + 1] = global_of(entry.localIndex)
        end
    end
    b.state, b.victims, b.defuser = "boom", victims, -1
    OF.util.publish(BOMB_KEY, pack_bomb(b))
    end_round(st, planterSide, "boom", b.planter)
end

function mode.host_update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if spots() == nil then
        OF.gamemodes.abandon("There is no room here for two sides and two bomb sites.")
        return
    end
    local st = read_state()
    if st == nil then

        st = { round = 1, wins = { red = 0, blue = 0 }, first = FIRST_ATTACK }
        start_round(st)
        return
    end
    st = { round = st.round, phase = st.phase, at = st.at, ends = st.ends,
           wins = { red = st.wins.red, blue = st.wins.blue }, first = st.first,
           winner = st.winner, reason = st.reason, decider = st.decider }
    host_note_kills()
    local t = now()
    local atk = attack_side(st.round, st.first)
    local def = other(atk)
    local b = read_bomb()
    if st.phase == PHASE_COUNT then
        if t >= st.ends then
            st.phase, st.at = PHASE_LIVE, t
            st.ends = t + round_seconds(#OF.gamemodes.participants())
            publish_state(st)
        end
        return
    end
    if st.phase == PHASE_OVER then
        if t < st.ends then return end
        if st.wins.red >= WIN_ROUNDS or st.wins.blue >= WIN_ROUNDS then
            local side = st.wins.red >= WIN_ROUNDS and "red" or "blue"
            OF.gamemodes.finish(OF.lang.fill("@ won the match, @.",
                OF.teams.side_name(side), st.wins[side] .. "-" .. st.wins[other(side)]),
                OF.gamemodes.team_winner(OF.teams.find(side)))
            return
        end
        st.round = st.round + 1
        start_round(st)
        return
    end
    if b ~= nil then
        local changed = false
        if b.state == "carried" then
            local li = local_of(b.carrier)
            if li == nil or OF.gamemodes.role(li) ~= ROLE_FIGHT or not OF.util.can_play(li)
                or side_of(li) ~= atk then
                local m = li ~= nil and gMarioStates[li] or nil
                if m ~= nil and m.pos ~= nil then
                    b.x, b.z = m.pos.x, m.pos.z
                    b.y = floor_near(m.pos.x, m.pos.y, m.pos.z) or m.pos.y
                end
                b.state, b.carrier = "dropped", -1
                changed = true
            end
        elseif b.state == "planted" and b.defuser >= 0 then
            local li = local_of(b.defuser)
            local m = li ~= nil and gMarioStates[li] or nil
            if li == nil or OF.gamemodes.role(li) ~= ROLE_FIGHT or not OF.util.can_play(li)
                or m == nil or m.pos == nil
                or (m.pos.x - b.x) ^ 2 + (m.pos.z - b.z) ^ 2 > CLAIM_SLACK * CLAIM_SLACK then
                b.defuser = -1
                changed = true
            end
        end
        if changed then OF.util.publish(BOMB_KEY, pack_bomb(b)) end
    end
    local planted = st.phase == PHASE_PLANTED
    if planted and t >= st.ends and b ~= nil
        and not (b.defuser >= 0 and t < st.ends + OF.gm_snd_defuse_grace(b.defuser)) then
        blow(st, b)
        return
    end
    if #fighters(def) == 0 and #sided(def) > 0 then
        end_round(st, atk, "wipe", host.lastKill[atk])
        return
    end
    if not planted and #fighters(atk) == 0 and #sided(atk) > 0 then
        end_round(st, def, "wipe", host.lastKill[def])
        return
    end
    if t >= st.ends then
        end_round(st, def, "time", host.lastKill[def] or host.lastKill[atk])
    end
end

function mode.claim_reach(kind)
    return (kind == "pick" and PICK_REACH or SITE_REACH) + CLAIM_SLACK
end

function mode.on_claim(senderLocal, what)
    if not OF.util.is_host() then return false end
    local st, b, s = read_state(), read_bomb(), spots()
    if st == nil or b == nil or s == nil then return false end
    if OF.gamemodes.role(senderLocal) ~= ROLE_FIGHT or not OF.util.can_play(senderLocal) then
        return false
    end
    local m = gMarioStates[senderLocal]
    if m == nil or m.pos == nil then return false end
    local g = global_of(senderLocal)
    local atk = attack_side(st.round, st.first)
    local mine = side_of(senderLocal)
    local function near(p, reach)
        return (m.pos.x - p.x) ^ 2 + (m.pos.z - p.z) ^ 2 <= reach * reach
    end
    b = { state = b.state, x = b.x, y = b.y, z = b.z, carrier = b.carrier, planter = b.planter,
          defuser = b.defuser, site = b.site, serial = b.serial, victims = {} }
    if what == "pick" then
        if st.phase ~= PHASE_LIVE or mine ~= atk then return false end
        if b.state ~= "base" and b.state ~= "dropped" then return false end
        if not near(b, mode.claim_reach("pick")) then return false end
        b.state, b.carrier = "carried", g
    elseif what == "plant A" or what == "plant B" then
        local site = what == "plant A" and "A" or "B"
        if st.phase ~= PHASE_LIVE or b.state ~= "carried" or b.carrier ~= g then return false end
        if not near(s[site], mode.claim_reach("plant")) then return false end
        b.state, b.carrier, b.planter, b.site = "planted", -1, g, site

        b.x, b.y, b.z = s[site].x, s[site].y + mode.BOX_TOP, s[site].z
        st = { round = st.round, phase = PHASE_PLANTED, at = now(), ends = now() + BOMB_SECONDS,
               wins = st.wins, first = st.first, winner = "-", reason = "-", decider = -1 }
        OF.util.publish(BOMB_KEY, pack_bomb(b))
        publish_state(st)
        return true
    elseif what == "defuse" then
        if st.phase ~= PHASE_PLANTED or mine == atk or b.state ~= "planted" then return false end
        if b.defuser >= 0 and b.defuser ~= g then return false end
        if not near(b, mode.claim_reach("defuse")) then return false end
        if b.defuser ~= g then host.defuseFrom = now() end
        b.defuser = g
    elseif what == "release" then
        if b.defuser ~= g then return false end
        b.defuser = -1
    elseif what == "defused" then
        if st.phase ~= PHASE_PLANTED or b.state ~= "planted" or b.defuser ~= g then return false end
        if host.defuseFrom == nil or now() - host.defuseFrom < DEFUSE_FRAMES / 30 - DEFUSE_SLACK then
            return false
        end
        b.state, b.defuser = "defused", -1
        OF.util.publish(BOMB_KEY, pack_bomb(b))
        local copy = { round = st.round, phase = st.phase, at = st.at, ends = st.ends,
            wins = { red = st.wins.red, blue = st.wins.blue }, first = st.first }
        end_round(copy, other(atk), "defuse", g)
        return true
    else
        return false
    end
    OF.util.publish(BOMB_KEY, pack_bomb(b))
    return true
end

function mode.kit_allows(kind)
    local st = read_state()
    if st == nil or (st.phase ~= PHASE_LIVE and st.phase ~= PHASE_PLANTED) then return false end
    if OF.gamemodes.role(0) ~= ROLE_FIGHT then return false end
    if kind == "grenade" then return not seen.nade end
    if kind == "flash" then return not seen.flash end
    return true
end

function mode.kit_spent(kind)
    if kind == "grenade" then seen.nade = true end
    if kind == "flash" then seen.flash = true end
end

local function at_site(m, site)
    local s = spots()
    local p = s ~= nil and s[site] or nil
    if p == nil or m == nil or m.pos == nil then return false end
    return (m.pos.x - p.x) ^ 2 + (m.pos.z - p.z) ^ 2 <= SITE_REACH * SITE_REACH
        and math.abs(m.pos.y - p.y) < SITE_HEIGHT
end

mode.at_site = at_site
mode.sees_loose_bomb = sees_loose_bomb

local function bar_job(m, st, b)
    if m == nil or m.controller == nil or st == nil or b == nil then return nil end
    if OF.gamemodes.role(0) ~= ROLE_FIGHT or not OF.util.can_play(0) then return nil end
    local pad = m.controller
    if not OF.util.has_flag(pad.buttonDown or 0, B_BUTTON) then return nil end
    if OF.util.has_flag(pad.buttonDown or 0, L_TRIG) then return nil end
    local me = global_of(0)
    if st.phase == PHASE_LIVE and b.state == "carried" and b.carrier == me then
        if at_site(m, "A") then return "plant A" end
        if at_site(m, "B") then return "plant B" end
    elseif st.phase == PHASE_PLANTED and b.state == "planted" and my_job(st) == "defend"
        and at_site(m, b.site) then
        return "defuse"
    end
    return nil
end
mode.bar_job = bar_job

function mode.bar_share()
    local job = seen.barJob
    if job == nil then return nil end
    local full = job == "defuse" and DEFUSE_FRAMES or PLANT_FRAMES
    return OF.util.clamp(seen.bar / full, 0, 1)
end

function mode.bar_words()
    local job = seen.barJob
    if job == nil then return nil end
    local full = job == "defuse" and DEFUSE_FRAMES or PLANT_FRAMES
    local left = string.format("%.1f", math.max(0, full - seen.bar) / 30)
    return OF.lang.fill(job == "defuse" and "Defusing... @ s" or "Planting... @ s", left)
end

function mode.prompt_now()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return nil end
    if OF.gamemodes.role(0) ~= ROLE_FIGHT or not OF.util.can_play(0) then return nil end
    local st, b, m = read_state(), read_bomb(), gMarioStates[0]
    if st == nil or b == nil or m == nil then return nil end
    local me = global_of(0)
    local word = nil
    if st.phase == PHASE_LIVE and b.state == "carried" and b.carrier == me
        and (at_site(m, "A") or at_site(m, "B")) then
        word = "Plant"
    elseif st.phase == PHASE_PLANTED and b.state == "planted" and my_job(st) == "defend"
        and at_site(m, b.site) and (b.defuser < 0 or b.defuser == me) then
        word = "Defuse"
    end
    if word == nil then return nil end
    local share = nil
    if seen.barJob ~= nil then share = mode.bar_share() end
    return "attack", word, share
end

function mode.before_mario_update(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    mode.follow_the_round(m)
    local st = read_state()
    if st == nil then return end
    if st.phase == PHASE_COUNT and OF.gamemodes.role(0) == ROLE_FIGHT then
        OF.input.hold(m)
        return
    end

    local job = bar_job(m, st, read_bomb())
    seen.padJob = job
    if job ~= nil then
        OF.input.hold(m)
        OF.input.take(m, B_BUTTON)
    end
end

local function new_round_here(st)
    seen.nade, seen.flash, seen.bar, seen.barJob, seen.defusing = false, false, 0, nil, false
    seen.asked, seen.watchAt, seen.boomSeen = nil, -1, nil
    if OF.util.asks(OF.spectate, "is_active") and OF.spectate.is_active() then
        OF.spectate.stop()
    end
    local m = gMarioStates[0]
    if m ~= nil then
        m.health = 0x880
        m.hurtCounter = 0
    end
    local x, y, z, yaw = spawn_for(0, st)
    if x ~= nil and OF.util.asks(OF.net, "snap_to") then
        OF.net.snap_to(x, y + 60, z, yaw)
        OF.util.camera_behind_soon()
    end

end

local function say(kind, word, sub, side)
    if not OF.util.asks(OF.hud, "banner") then return nil end
    return OF.hud.banner(kind, word, sub, { side = side })
end
mode.say = say

local function wins_sub(st)
    if OF.util.asks(OF.gamemodes, "score_sub") then
        return OF.gamemodes.score_sub(st.wins.red or 0, st.wins.blue or 0)
    end
    return tostring(st.wins.red or 0) .. " - " .. tostring(st.wins.blue or 0)
end

local function round_over_here(st)
    local job = my_job(st)
    local mine = side_of(0)
    local won = mine == st.winner

    if mine == "red" or mine == "blue" then
        say("point", won and OF.lang.t("ROUND WON") or OF.lang.t("ROUND LOST"), wins_sub(st),
            won and "us" or "them")
    else
        say("point", OF.lang.fill("@ TAKE IT", string.upper(OF.lang.t(OF.teams.side_name(st.winner)))),
            wins_sub(st))
    end
    OF.gamemodes.cue(won and "good" or "bad")
    if switches_after(st.round) and st.wins.red < WIN_ROUNDS and st.wins.blue < WIN_ROUNDS then
        OF.gamemodes.round_sound(OF.sounds.CHIME)
    end
    if not OF.gamemodes.option_is("replay", "off") and OF.util.asks(OF.replay, "start_ending")
        and job ~= nil then
        OF.replay.start_ending()
    end
end

mode.BEEP_SOUND = SOUND_GENERAL_WATER_LEVEL_TRIG
mode.DEFUSE_SOUND = SOUND_GENERAL2_PURPLE_SWITCH
mode.BEEP_SLOW, mode.BEEP_FAST = 1.0, 0.3
mode.BEEP_RUSH, mode.BEEP_DOUBLE = 15, 3
mode.BEEP_ECHO = 0.1

function mode.beep_gap(left)
    if left <= mode.BEEP_DOUBLE then return mode.BEEP_FAST, true end
    if left >= mode.BEEP_RUSH then return mode.BEEP_SLOW, false end
    local share = (left - mode.BEEP_DOUBLE) / (mode.BEEP_RUSH - mode.BEEP_DOUBLE)
    return mode.BEEP_FAST + (mode.BEEP_SLOW - mode.BEEP_FAST) * share, false
end

function mode.bomb_source()
    local token = OF.gamemodes.tokens ~= nil and OF.gamemodes.tokens.sdbomb or nil
    if token == nil or token.activeFlags == 0 then return nil end
    return token
end

function mode.hear_the_bomb(b, st)
    if b == nil or st == nil then return nil end
    if b.state == "defused" then
        if seen.defuseHeard == b.serial then return nil end
        seen.defuseHeard, seen.beepNext, seen.beepEcho = b.serial, nil, nil
        return OF.gamemodes.round_sound_from(mode.bomb_source(), mode.DEFUSE_SOUND)
    end
    if st.phase ~= PHASE_PLANTED or b.state ~= "planted" then
        seen.beepNext, seen.beepEcho = nil, nil
        return nil
    end
    local t = now()
    local left = st.ends - t
    if left <= 0 then return nil end
    if seen.beepSerial ~= b.serial then
        seen.beepSerial, seen.beepNext, seen.beepEcho = b.serial, t, nil
    end
    local due = false
    if seen.beepEcho ~= nil and t >= seen.beepEcho then
        seen.beepEcho, due = nil, true
    end
    if seen.beepNext ~= nil and t >= seen.beepNext then
        local gap, double = mode.beep_gap(left)
        seen.beepNext = t + gap
        if double then seen.beepEcho = t + mode.BEEP_ECHO end
        due = true
    end
    if not due then return nil end
    return OF.gamemodes.round_sound_throttled("sdbeep", 2, mode.BEEP_SOUND,
        mode.bomb_source())
end

function mode.blast_takes_me(b)
    local m = gMarioStates[0]
    if b == nil or m == nil or m.pos == nil then return false end
    if OF.gamemodes.role(0) ~= ROLE_FIGHT or not OF.util.can_play(0) then return false end
    if (m.pos.x - b.x) ^ 2 + (m.pos.y - b.y) ^ 2 + (m.pos.z - b.z) ^ 2 >= BLAST_KILL * BLAST_KILL then
        return false
    end
    if OF.util.action_group(m.action) == OF.util.action_group(ACT_GROUP_CUTSCENE) then return false end
    if not OF.util.asks(OF.powerups, "apply") then return false end
    OF.powerups.apply("standing", { q = 1 })
    return true
end

local function hear_the_blast(b, st)
    if b == nil or b.state ~= "boom" or seen.boomSeen == b.serial then return end
    seen.boomSeen = b.serial
    for k = 0, 4 do
        local a = k * math.pi * 2 / 5
        local o = OF.util.optional("spawn_non_sync_object", nil, id_bhvExplosion,
            E_MODEL_EXPLOSION, b.x + math.sin(a) * 250 * math.min(k, 1), b.y + 80,
            b.z + math.cos(a) * 250 * math.min(k, 1), nil)
        if o ~= nil then OF.util.optional("obj_scale", nil, o, 3.5) end
    end
    OF.gamemodes.round_sound(SOUND_GENERAL2_BOBOMB_EXPLOSION)
    mode.blast_takes_me(b)
    local m = gMarioStates[0]
    if m ~= nil and m.pos ~= nil
        and (m.pos.x - b.x) ^ 2 + (m.pos.z - b.z) ^ 2 < BLAST_SHAKE * BLAST_SHAKE then
        OF.util.optional("set_environmental_camera_shake", nil, SHAKE_ENV_EXPLOSION)
    end
    if b.planter == global_of(0) and seen.credited ~= b.serial then
        seen.credited = b.serial
        local defender = other(attack_side(st.round, st.first))
        local taken = 0
        for _, g in ipairs(b.victims) do
            local li = local_of(g)
            if li ~= nil and side_of(li) == defender then taken = taken + 1 end
        end
        if taken > 0 then
            OF.util.publish_row(0, "ofScore", kills_of(0) + taken)

            say("medal", "+" .. tostring(taken))
        end
    end
end

local function watch_side(m)
    if not OF.util.asks(OF.spectate, "start") then return end
    local side = side_of(0)
    local alive = side ~= nil and fighters(side) or {}
    local frame = OF.util.optional("get_global_timer", 0) or 0
    local wanted = false
    if OF.util.asks(OF.input, "pressed") and not OF.util.menu_has_screen() then
        OF.input.poll(m)
        wanted = OF.input.pressed(L_JPAD)
    end
    local target = OF.spectate.target
    local watching = OF.spectate.is_active()
    local stillGood = false
    if watching and type(target) == "number" then
        local li = local_of(target)
        stillGood = li ~= nil and OF.gamemodes.role(li) == ROLE_FIGHT and side_of(li) == side
    end
    if #alive == 0 then
        if watching then OF.spectate.stop() end
        return
    end
    if seen.watchAt < 0 then seen.watchAt = frame + 60 end
    if (not stillGood and frame >= seen.watchAt) or wanted then
        local pick = alive[1]
        if wanted and stillGood then
            for i, entry in ipairs(alive) do
                if global_of(entry.localIndex) == target then
                    pick = alive[(i % #alive) + 1]
                end
            end
        end
        OF.spectate.start(global_of(pick.localIndex))
    end
end

function mode.follow_the_round(m)
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    local st = read_state()
    if st == nil then return end
    local b = read_bomb()
    if st.round ~= seen.round then
        seen.round = st.round
        seen.phase = nil
    end
    if st.phase ~= seen.phase then
        local was = seen.phase
        seen.phase = st.phase
        if st.phase == PHASE_COUNT then new_round_here(st)
        elseif st.phase == PHASE_LIVE and was == PHASE_COUNT then OF.gamemodes.sound_go()
        elseif st.phase == PHASE_PLANTED then

            say("objective", OF.lang.t("BOMB PLANTED"),
                OF.lang.fill("Site @", b ~= nil and b.site or "?"),
                my_job(st) == "attack" and "us" or (my_job(st) == "defend" and "them" or nil))
        elseif st.phase == PHASE_OVER then round_over_here(st) end
    end

    if b ~= nil and b.state == "defused" and seen.defusedSaid ~= b.serial then
        seen.defusedSaid = b.serial
        say("objective", OF.lang.t("DEFUSED"), nil,
            my_job(st) == "defend" and "us" or (my_job(st) == "attack" and "them" or nil))
    end

    if st.phase == PHASE_OVER and switches_after(st.round)
        and st.wins.red < WIN_ROUNDS and st.wins.blue < WIN_ROUNDS
        and now() >= st.ends - SWITCH_SECONDS - 1 and seen.switchSaid ~= st.round then
        seen.switchSaid = st.round
        local next = attack_side(st.round + 1, st.first) == side_of(0)
        say("sideswitch", nil, side_of(0) ~= nil
            and (next and OF.lang.t("You attack now") or OF.lang.t("You defend now")) or nil)
    end
    hear_the_blast(b, st)
    mode.hear_the_bomb(b, st)
    if st.phase == PHASE_COUNT then
        local left = math.ceil(st.ends - now())
        if left >= 1 and left ~= seen.heard then
            seen.heard = left
            OF.gamemodes.round_sound(OF.gamemodes.count_sound(left))
        end
        return
    end
    seen.heard = nil

    if st.phase == PHASE_LIVE then
        OF.gamemodes.cue("tick", nil, "sdclock", math.ceil(st.ends - now()))
    end
    if m ~= nil and OF.gamemodes.role(0) == ROLE_OUT then
        watch_side(m)
    else
        seen.watchAt = -1
    end
end

function mode.update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    local st = read_state()
    if st == nil then return end
    local b = read_bomb()
    local m = gMarioStates[0]
    if m == nil or OF.gamemodes.role(0) ~= ROLE_FIGHT then return end
    if not OF.util.can_play(0) then return end
    if st.phase ~= PHASE_LIVE and st.phase ~= PHASE_PLANTED then return end
    local shooter = OF.shooter
    shooter.work_the_sprint(m)
    if shooter.watch_the_bolt() then
        shooter.shot_feedback(m)
        m.invincTimer = 0
    end
    shooter.throw_flash(m)
    shooter.hear_the_grenades(m)
    shooter.work_the_fuse(m)
    shooter.watch_the_air()
    local seq = shooter.kill_seq()
    if seq > seen.killSeq then
        OF.util.publish_row(0, "ofScore", kills_of(0) + (seq - seen.killSeq))
        seen.killSeq = seq
    end
    if b == nil then return end
    local me = global_of(0)
    if st.phase == PHASE_LIVE and my_job(st) == "attack"
        and (b.state == "base" or b.state == "dropped")
        and (m.pos.x - b.x) ^ 2 + (m.pos.z - b.z) ^ 2 < PICK_REACH * PICK_REACH
        and math.abs(m.pos.y - b.y) < 250 and seen.asked ~= "pick" .. b.serial .. b.state then
        seen.asked = "pick" .. b.serial .. b.state
        OF.gamemodes.claim("pick")
    end
    local job = seen.padJob
    seen.padJob = nil
    if job ~= seen.barJob then
        if seen.barJob == "defuse" and b.defuser == me then OF.gamemodes.claim("release") end
        seen.barJob, seen.bar = job, 0
        if job == "defuse" then OF.gamemodes.claim("defuse") end
    end
    if job == nil then return end
    if job == "defuse" and b.defuser ~= me then
        seen.bar = 0
        return
    end
    seen.bar = seen.bar + 1
    local full = job == "defuse" and DEFUSE_FRAMES or PLANT_FRAMES
    OF.gamemodes.round_sound_throttled("sdbar", 10, SOUND_GENERAL_SWITCH_TICK_FAST or OF.sounds.COUNT)
    if seen.bar >= full then
        seen.bar = 0
        OF.gamemodes.claim(job == "defuse" and "defused" or job)
    end
end

hook_event(HOOK_ON_DEATH, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if OF.gamemodes.current() ~= mode then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    local st = read_state()
    if st == nil or (st.phase ~= PHASE_LIVE and st.phase ~= PHASE_PLANTED) then return end
    if OF.gamemodes.role(0) ~= ROLE_FIGHT then return end
    mode.go_down()
end)

function mode.go_down()
    OF.gamemodes.set_role(0, ROLE_OUT)
    seen.bar, seen.barJob = 0, nil

end

function mode.out_cause()
    return "Until the next round"
end

function mode.may_attack(attacker, victim)
    local _, _ = attacker, victim
    return false
end

function mode.side_place(side)
    local s = spots()
    if s == nil or (side ~= "red" and side ~= "blue") then return nil end
    local at = side == FIRST_ATTACK and s.attack or s.defend
    return { x = at.x, y = at.y, z = at.z, level = at.level, area = at.area }
end

function mode.death_place()
    local x, y, z = spawn_for(0, read_state())
    if x == nil then return nil end
    return { x = x, y = y, z = z }
end

function mode.fuse_stage(left)
    left = tonumber(left) or 0
    if left <= mode.BEEP_DOUBLE then return "last", "bad" end
    if left < mode.BEEP_RUSH then return "rush", "bad" end
    return "slow", "warn"
end

function mode.fuse_share()
    local st = read_state()
    if st == nil or st.phase ~= PHASE_PLANTED then return nil end
    return OF.util.clamp((st.ends - now()) / BOMB_SECONDS, 0, 1), st.ends - now()
end

function mode.clock_face()
    local st = read_state()
    if st == nil then return nil end
    if st.phase == PHASE_OVER then return { timer = 0 } end
    if st.phase == PHASE_PLANTED then

        local _, tone = mode.fuse_stage(st.ends - now())
        return { text = "        ", tint = OF.hud ~= nil and OF.hud.C ~= nil and OF.hud.C[tone] or nil }
    end
    return { timer = math.max(0, st.ends - now()) }
end

local function chip_box()
    local H = OF.hud
    if H == nil or type(H.cluster_layout) ~= "function" then return nil end
    local lineY = OF.gamemodes.stateLineY
    if type(lineY) ~= "number" then return nil end
    local lineH = type(H.state_line_height) == "function" and H.state_line_height() or 0
    local top = nil
    for _, c in ipairs(OF.util.hudClaims or {}) do
        if top == nil and math.abs(c.y + c.height - lineH - lineY) < 2 then top = c.y end
    end
    if top == nil then return nil end
    local L = H.cluster_layout({ clockText = "        " })
    return L.chipX, top, L.chipW, H.CHIP_H
end

function mode.draw_fuse()
    local share, left = mode.fuse_share()
    if share == nil or not OF.util.asks(OF.hud, "icon") then return false end
    local x, y, w, h = chip_box()
    if x == nil then return false end
    local H = OF.hud
    local stage, tone = mode.fuse_stage(left)
    local alpha = 255
    if stage == "last" then alpha = 255 * (0.55 + 0.45 * H.pulse(H.now(), 12)) end
    local size = h * 0.55
    H.icon("bomb", x + 10 + size / 2, y + h / 2, size, tone, alpha)
    local bx = x + 16 + size
    local bw = w - (bx - x) - 10
    H.rect(bx, y + h / 2 - 3, bw, 6, H.C.shade, 200)
    H.rect(bx, y + h / 2 - 3, bw * share, 6, tone, alpha)
    seen.fuseDrawn = { stage = stage, share = share }
    return true
end

function mode.cluster()
    local st = read_state()
    local out = OF.gamemodes.side_cluster(function(key)
        return st ~= nil and st.wins[key] or 0
    end, WIN_ROUNDS)
    if out == nil then return nil end
    for _, side in ipairs({ out.left, out.right }) do
        if side ~= nil and side.key ~= nil then
            side.pips = { alive = #fighters(side.key), total = #sided(side.key) }
        end
    end
    return out
end

function mode.sideHeading(key)
    local st = read_state()
    if st == nil then return nil end
    local job = key == attack_side(st.round, st.first) and "Attack" or "Defense"
    return OF.lang.fill("@ - @", OF.lang.t(job) .. " (" .. OF.lang.t(OF.teams.side_name(key)) .. ")",
        tostring(st.wins[key] or 0))
end

function mode.standing(localIndex)
    local kills = tostring(kills_of(localIndex))
    if OF.gamemodes.role(localIndex) == ROLE_OUT then
        return OF.lang.fill("@ (down)", kills)
    end
    return kills
end

function mode.replayDecider()
    local st = read_state()
    return st ~= nil and local_of(st.decider) or nil
end

local siteTargets = { A = { id = "site:A", label = "Site A" },
                      B = { id = "site:B", label = "Site B" } }
local siteRing = { radius = SITE_REACH }
local bombTarget = { id = "bomb", label = "Bomb", tone = "target",
    ring = { radius = PICK_REACH } }
local plantedTarget = { id = "bomb:planted", label = "Bomb", tone = { 255, 60, 60 },
    urgent = true, priority = 95, compass = "offscreen", ring = siteRing, contested = true }
local sndList = {}
function mode.targets(viewer)
    local _ = viewer
    for i = #sndList, 1, -1 do sndList[i] = nil end
    local s, b, st = spots(), read_bomb(), read_state()
    if s == nil or st == nil then return nil end
    local job = my_job(st)
    local live = b ~= nil and b.state == "planted"
    local carrying = b ~= nil and b.state == "carried" and b.carrier == global_of(0)
    if live then
        local at = s[b.site] or s.A
        plantedTarget.pos = { x = b.x, y = b.y, z = b.z, level = at.level, area = at.area }
        sndList[1] = plantedTarget
        return sndList
    end
    for _, site in ipairs({ "A", "B" }) do
        local t = siteTargets[site]
        t.pos = s[site]
        t.ring = siteRing
        t.tone = { 235, 210, 120 }
        t.urgent = false
        t.compass = "offscreen"
        if carrying then
            t.priority = 90
        elseif job == "defend" then
            t.priority = 60
        else
            t.priority = 50
        end
        sndList[#sndList + 1] = t
    end
    if b ~= nil and (b.state == "base" or b.state == "dropped") and sees_loose_bomb(st) then
        bombTarget.pos = { x = b.x, y = b.y, z = b.z, level = s.A.level, area = s.A.area }
        bombTarget.priority = 92
        bombTarget.compass = "offscreen"
        sndList[#sndList + 1] = bombTarget
    end
    return sndList
end

local function box_init(o)
    if o == nil then return end
    local data = _G["gGlobalObjectCollisionData"]
    o.collisionData = data ~= nil and data[BOX_MESH] or nil
    if o.collisionData ~= nil then
        local handle = OF.util.optional("load_static_object_collision", nil)
        if handle ~= nil then boxes.soc[#boxes.soc + 1] = handle end
    end
end

local BOX_BHV = nil
do
    local fn = _G["hook_behavior"]
    if type(fn) == "function" then
        local ok, id = pcall(fn, nil, OBJ_LIST_SURFACE, false, box_init, nil, "of snd box")
        if ok then BOX_BHV = id end
    end
end

local function clear_boxes()
    for k, handle in pairs(boxes.soc) do
        OF.util.optional("remove_static_object_collision", nil, handle)
        boxes.soc[k] = nil
    end
    for k, o in pairs(boxes.objs) do
        if o ~= nil and o.activeFlags ~= 0 then
            OF.util.optional("obj_mark_for_deletion", nil, o)
        end
        boxes.objs[k] = nil
    end
end

hook_event(HOOK_ON_LEVEL_INIT, function()
    boxes.objs, boxes.soc = {}, {}
end)

function mode.boxes_off(s)
    for _, site in ipairs({ "A", "B" }) do
        local o, p = boxes.objs[site], s[site]
        if o ~= nil and o.activeFlags ~= 0 and p ~= nil
            and ((o.oPosX - p.x) ^ 2 + (o.oPosY - p.y) ^ 2 + (o.oPosZ - p.z) ^ 2) > 1 then
            return true
        end
    end
    return false
end
local function draw_boxes(s)
    if mode.boxes_off(s) then clear_boxes() end
    for _, site in ipairs({ "A", "B" }) do
        local o = boxes.objs[site]
        if (o == nil or o.activeFlags == 0) and BOX_BHV ~= nil and OF.gamemodes.in_place_room(s[site]) then
            local p = s[site]
            boxes.objs[site] = OF.util.optional("spawn_non_sync_object", nil, BOX_BHV,
                E_MODEL_METAL_BOX, p.x, p.y, p.z, function(obj)
                    OF.util.optional("obj_scale_xyz", nil, obj, 1, BOX_SCALE_Y, 1)
                end)
        end
    end
end

function mode.scenery()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    if not OF.util.round_screen() then
        clear_boxes()
        OF.gamemodes.hide_token("sdbomb")
        return
    end
    local s, b, st = spots(), read_bomb(), read_state()
    if s == nil then return end
    draw_boxes(s)
    if b == nil or st == nil then
        OF.gamemodes.hide_token("sdbomb")
        return
    end
    local at, carrier, spin, anim = nil, nil, nil, OF.gamemodes.BOBOMB_WALK
    if b.state == "carried" then
        local li = local_of(b.carrier)
        local m = li ~= nil and gMarioStates[li] or nil
        local np = li ~= nil and gNetworkPlayers[li] or nil
        if m ~= nil and m.pos ~= nil and np ~= nil and my_job(st) == "attack" then
            at = { x = m.pos.x, y = m.pos.y + BOMB_LIFT, z = m.pos.z,
                   level = np.currLevelNum, area = np.currAreaIndex }
            carrier, anim = m, OF.gamemodes.BOBOMB_CARRIED
        end
    elseif b.state == "planted" then

        local t = OF.util.optional("get_global_timer", 0) or 0
        at = { x = b.x, y = mode.hover_y(b.y, t), z = b.z, level = s.A.level, area = s.A.area }
        spin = mode.HOVER_SPIN
    elseif (b.state == "base" or b.state == "dropped") and not sees_loose_bomb(st) then
        at = nil
    elseif b.state == "base" or b.state == "dropped" or b.state == "defused" then

        at = { x = b.x, y = b.y, z = b.z, level = s.A.level, area = s.A.area }
    end
    if at == nil then
        OF.gamemodes.hide_token("sdbomb")
        return
    end
    local token = OF.gamemodes.mark_place("sdbomb", E_MODEL_BLACK_BOBOMB, at, spin)
    OF.gamemodes.pose_bobomb(token, anim, anim == OF.gamemodes.BOBOMB_CARRIED and 1.0 or 0.5)
    if token ~= nil and carrier ~= nil and carrier.faceAngle ~= nil then
        token.oFaceAngleYaw = carrier.faceAngle.y
    end
end

function mode.hud()
    local st, b, s = read_state(), read_bomb(), spots()
    if st == nil then return end

    local ownRings = not OF.util.asks(OF.markers, "ring")
    if ownRings and b ~= nil and (b.state == "base" or b.state == "dropped") and s ~= nil
        and sees_loose_bomb(st) then
        OF.util.zone_ring({ x = b.x, y = b.y + 4, z = b.z }, PICK_REACH, 32, 3,
            255, 200, 80, 200)
    end
    if ownRings and s ~= nil and not (b ~= nil and b.state == "planted") then
        for _, site in ipairs({ "A", "B" }) do
            OF.util.zone_ring(s[site], SITE_REACH, 32, 3, 255, 210, 120, 180)
        end
    elseif ownRings and s ~= nil and b ~= nil and s[b.site] ~= nil then

        local breath = 0.5 + 0.5 * math.sin(now() * 2 * math.pi / 3)
        OF.util.zone_ring(s[b.site], SITE_REACH, 32, 3, 255, 60, 60, math.floor(200 * (1 - 0.3 * breath)))
    end
    if st.phase == PHASE_COUNT then
        local left = math.max(1, math.ceil(st.ends - now()))
        local bottom = OF.gamemodes.draw_count_title(OF.lang.fill("Round @", tostring(st.round)))
        OF.gamemodes.draw_count_digit(left, 0, bottom)
    end
    mode.draw_fuse()

    if st.phase == PHASE_OVER then return end

    if OF.gamemodes.role(0) == ROLE_OUT then return end
    local job = my_job(st)
    local me = global_of(0)

    local state = OF.util.asks(OF.hud, "state_line") and OF.hud.state_line or function() end
    if st.phase == PHASE_PLANTED and b ~= nil then
        state("planted", OF.lang.fill("Bomb planted @", b.site), { prio = 60,
            tone = job == "attack" and "good" or "bad", colour = job == "defend" })
    elseif b ~= nil and b.state == "carried" and b.carrier == me then
        state("carry", OF.lang.t("You have the bomb"), { prio = 50, tone = "target" })
    end

    local action, word, held = mode.prompt_now()
    local prompted = action ~= nil and OF.util.asks(OF.hud, "prompt")
    if prompted then
        OF.hud.prompt(action, OF.lang.t(word), word == "Plant" and held or nil,
            { id = "snd", tone = "target" })
    end
    local share = mode.bar_share()
    if share ~= nil and seen.barJob == "defuse" and b ~= nil and b.defuser == me then
        state("defusing", OF.lang.t("Defusing"), { prio = 80, tone = "good",
            figure = tostring(math.floor(share * 100)) .. "%" })
        mode.draw_defuse_bar(share)
    elseif share ~= nil and not prompted then
        local w, h = 160, 8
        local x = djui_hud_get_screen_width() * 0.5 - w * 0.5
        local y = djui_hud_get_screen_height() * 0.62
        if OF.util.asks(OF.hud, "meter") then
            OF.hud.meter(x, y, w, share, "target", { h = h })
        end
    elseif b ~= nil and b.state == "planted" and job == "defend" and b.defuser >= 0
        and b.defuser ~= me then
        state("defusing", OF.lang.t("Defusing"), { prio = 70, tone = "good" })
    end
    if OF.util.asks(OF.shooter, "draw_crosshair") then OF.shooter.draw_crosshair() end
    if OF.util.asks(OF.shooter, "draw_throw_bar") then OF.shooter.draw_throw_bar() end
end

function mode.draw_defuse_bar(share)
    if not OF.util.asks(OF.hud, "meter") then return nil end
    local sw, sh = djui_hud_get_screen_width(), djui_hud_get_screen_height()
    local w, h = 200, 8
    local x = sw * 0.5 - w / 2
    local P = OF.hud.PROMPT
    local y = sh * ((P ~= nil and P.y) or 0.64) + ((P ~= nil and (P.chip + P.pad * 2)) or 44) + 10
    local bx, by, bw, bh = OF.hud.meter(x, y, w, share, "good", { h = h })
    bx, by, bw, bh = bx or x, by or y, bw or w, bh or h
    OF.hud.rect(bx + bw / 2 - 1, by - 3, 2, bh + 6, OF.hud.C.ink, 230)
    seen.defuseBar = { share = share, mark = 0.5 }
    return seen.defuseBar
end

function mode.still_winnable()
    return #sided("red") > 0 and #sided("blue") > 0
end

function mode.on_timeout()
    local st = read_state()
    if st == nil or st.wins.red == st.wins.blue then
        OF.gamemodes.finish("Time - the match is drawn.")
        return
    end
    local side = st.wins.red > st.wins.blue and "red" or "blue"
    OF.gamemodes.finish(OF.lang.fill("@ won the match, @.", OF.teams.side_name(side),
        st.wins[side] .. "-" .. st.wins[other(side)]),
        OF.gamemodes.team_winner(OF.teams.find(side)))
end

function mode.terms()
    local pick = OF.gamemodes.option_showing(mode.key, "round") or "auto"
    local seconds = ROUND_STOPS[pick] or ROUND_STOPS.two
    return OF.lang.fill("first side to four rounds - @ a round",
        OF.gamemodes.clock(seconds))
end

function mode.cleanup()
    clear_boxes()
    OF.gamemodes.hide_token("sdbomb")
    if OF.util.is_host() then
        OF.util.publish(STATE_KEY, nil)
        OF.util.publish(BOMB_KEY, nil)
        OF.util.publish(SPOTS_KEY, nil)
    end
    if OF.util.asks(OF.spectate, "is_active") and OF.spectate.is_active() then
        OF.spectate.stop()
    end
    seen.round, seen.phase, seen.bar, seen.barJob = nil, nil, 0, nil
    seen.nade, seen.flash, seen.asked, seen.boomSeen, seen.credited = false, false, nil, nil, nil
    host.scores, host.lastKill = {}, {}
    stateText, stateRead, bombText, bombRead, spotsText, spotsRead = nil, nil, nil, nil, nil, nil
    return true
end

OF.gamemodes.register(mode)
