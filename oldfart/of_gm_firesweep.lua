OF = OF or {}
OF.ring = OF.ring or {}
OF.PARTY_ARENAS = OF.PARTY_ARENAS or {
    "bowser1", "bowser2", "bowser3", "the_plate",
}

local TWO_PI = math.pi * 2
local SEED_KEY = "ofFsSeed"
local STARS_KEY = "ofFsStars"
local HITS_ROW = "ofFsHits"
local START_RADIUS = 1300
local WIDEST_RADIUS = 1700

local FIRST_ROW = 3.0
local STAR_RESPAWN = 1.5
local PLAYERS_PER_STAR = 4
local STAR_MARGIN = 450
local STAR_APART = 800
local GRAB_RADIUS, GRAB_HEIGHT = 160, 250
local CLAIM_SLACK = 600

local FLAME_SCALE = 3.5
local FLAME_DRAW = 30
local FLAME_SPACING = 70
local FLAME_HALF_WIDE = 10 * FLAME_SCALE
local FLAME_REACH_UP = 20 * FLAME_SCALE
local MARIO_RADIUS = 37
local MARIO_TALL, MARIO_SHORT = 160, 100
local ROW_BODY = FLAME_HALF_WIDE + MARIO_RADIUS
local BEADS_MOST = 56

local STUN_FRAMES = 60
local IMMUNE_FRAMES = 90

local HIT_COST = 3

local PARTNER_TURN, PARTNER_SPREAD = math.pi / 2, math.pi / 3

local PACES = {
    normal = { from = 4.0, to = 2.0, ramp = 90, cross = 3.0, blueCross = 1.6,
               blueFrom = 45 },
    gentle = { from = 4.5, to = 2.6, ramp = 100, cross = 3.4, blueCross = 1.8,
               blueFrom = 60 },
    fierce = { from = 3.5, to = 1.6, ramp = 75, cross = 2.6, blueCross = 1.5,
               blueFrom = 30 },
}
local LENGTHS = { two = 120, ninety = 90, three = 180 }
local LAST_STRETCH = 30

local ROLE_IN = "sweeping"
local plan = { seed = nil, pace = nil, limit = nil, rows = {} }
local rowObjs = {}

local me = { stunUntil = -1, immuneUntil = -1, lastD = {}, asked = {},
             credited = {}, frame = 0, heardRow = 0 }

local host = { slots = nil, lastAt = {}, respawnAt = {} }

hook_event(HOOK_ON_LEVEL_INIT, function()
    for k in pairs(rowObjs) do rowObjs[k] = nil end
end)

local function now_frame()
    return OF.util.optional("get_global_timer", 0) or 0
end

local function pace()
    return PACES[OF.gamemodes.option_now("pace") or "normal"] or PACES.normal
end

local function lcg(state)
    state = (state * 48271) % 2147483647
    return state, state / 2147483647
end

local function limit_now()
    local limit = tonumber(gGlobalSyncTable.ofGmLimit) or 0
    if limit <= 0 then return LENGTHS.two end
    return limit
end

local function rows()
    local seed = math.floor(tonumber(gGlobalSyncTable[SEED_KEY]) or 0)
    local p = pace()
    local limit = limit_now()
    if plan.seed == seed and plan.pace == p and plan.limit == limit then return plan.rows end
    local list = {}
    local state = (seed % 2147483646) + 1
    local t, lastAngle, sinceBlue = FIRST_ROW, nil, 0
    while t < limit do
        local r1, r2
        state, r1 = lcg(state)
        state, r2 = lcg(state)
        local angle = r1 * TWO_PI
        if lastAngle ~= nil then
            local diff = math.abs(((angle - lastAngle + math.pi) % TWO_PI) - math.pi)
            if diff < 0.6 then angle = (angle + math.pi / 2) % TWO_PI end
        end
        lastAngle = angle
        local blue = false
        if t >= limit - LAST_STRETCH then
            blue = sinceBlue >= 2
        elseif t >= p.blueFrom then
            blue = r2 < 0.25 and sinceBlue >= 2
        end
        sinceBlue = blue and 0 or sinceBlue + 1
        local lead = { t0 = t, angle = angle, blue = blue,
            cross = blue and p.blueCross or p.cross,
            nx = math.sin(angle), nz = math.cos(angle) }

        local turn = PARTNER_TURN + (((r1 * 7919.0) % 1) - 0.5) * PARTNER_SPREAD
        local pa = (angle + turn) % TWO_PI
        lead.partner = { t0 = t, angle = pa, blue = blue, cross = lead.cross,
            nx = math.sin(pa), nz = math.cos(pa) }
        list[#list + 1] = lead
        local share = math.min(t / p.ramp, 1)
        t = t + p.from + (p.to - p.from) * share
    end
    plan.seed, plan.pace, plan.limit, plan.rows = seed, p, limit, list
    return list
end

local function row_offset(row, t, radius)
    if t < row.t0 then return nil end
    local s = -radius + (t - row.t0) * (2 * radius / row.cross)
    if s > radius then return nil end
    return s
end

local function floor_under(x, z, at)
    local y = OF.util.optional("find_floor_height", nil, x, at.y + 400, z)
    if type(y) ~= "number" or y < at.y - 600 then return at.y end
    return y
end

local function live_rows(t, radius)
    local out = {}
    for index, row in ipairs(rows()) do
        if row.t0 > t then break end
        local s = row_offset(row, t, radius)
        if s ~= nil then
            out[#out + 1] = { index = index, row = row, s = s }
            if row.partner ~= nil then
                out[#out + 1] = { index = -index, row = row.partner, s = s }
            end
        end
    end
    return out
end

local function drop_row(index)
    local list = rowObjs[index]
    if list == nil then return end
    for i, obj in pairs(list) do
        if obj ~= nil and obj.activeFlags ~= 0 then
            OF.util.optional("obj_mark_for_deletion", nil, obj)
        end
        list[i] = nil
    end
    rowObjs[index] = nil
end

local function clear_rows()
    for index in pairs(rowObjs) do drop_row(index) end
end

local function draw_rows(at, t)
    if at == nil or OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then
        clear_rows()
        return
    end
    local radius = OF.ring.radius()
    local live = live_rows(t, radius)
    local keep = {}
    for _, item in ipairs(live) do
        keep[item.index] = true
        local row, s = item.row, item.s
        local half = math.sqrt(math.max(0, radius * radius - s * s))
        local beads = math.min(BEADS_MOST, math.max(1, math.ceil(2 * half / FLAME_SPACING)))
        local list = rowObjs[item.index] or {}
        rowObjs[item.index] = list
        for i = beads + 1, BEADS_MOST do
            local extra = list[i]
            if extra ~= nil and extra.activeFlags ~= 0 then
                OF.util.optional("obj_mark_for_deletion", nil, extra)
            end
            list[i] = nil
        end
        local model = row.blue and E_MODEL_BLUE_FLAME or E_MODEL_RED_FLAME
        for i = 1, beads do
            local u = beads == 1 and 0 or (-half + (i - 1) * (2 * half / (beads - 1)))
            local x = at.x + row.nx * s + row.nz * u
            local z = at.z + row.nz * s - row.nx * u
            local y = floor_under(x, z, at) + FLAME_DRAW
            local obj = list[i]
            if obj == nil or obj.activeFlags == 0 then
                obj = OF.util.optional("spawn_non_sync_object", nil,
                    id_bhvStaticObject, model, x, y, z, nil)
                list[i] = obj
                if obj ~= nil then
                    OF.util.optional("obj_set_billboard", nil, obj)
                    OF.util.optional("obj_scale", nil, obj, FLAME_SCALE)
                end
            end
            if obj ~= nil then
                obj.oPosX, obj.oPosY, obj.oPosZ = x, y, z
                obj.oAnimState = (math.floor(t * 15) + i) % 8
            end
        end
    end
    for index in pairs(rowObjs) do
        if not keep[index] then drop_row(index) end
    end
end

local function body_meets(m, flameY)
    local tall = MARIO_TALL
    if m.action ~= nil and OF.util.has_flag(m.action, ACT_FLAG_SHORT_HITBOX or 0x40000) then
        tall = MARIO_SHORT
    end
    return m.pos.y < flameY + FLAME_REACH_UP and m.pos.y + tall > flameY - FLAME_REACH_UP
end

local function row_hit(m, at, t)
    if m == nil or m.pos == nil or at == nil then return nil end
    local radius = OF.ring.radius()
    local dx, dz = m.pos.x - at.x, m.pos.z - at.z
    local hit = nil
    local seen = {}
    for _, item in ipairs(live_rows(t, radius)) do
        local row = item.row
        local d = dx * row.nx + dz * row.nz - item.s
        local u = dx * row.nz - dz * row.nx
        local half = math.sqrt(math.max(0, radius * radius - item.s * item.s))
        local before = me.lastD[item.index]
        seen[item.index] = d
        local crossed = before ~= nil and ((before < 0) ~= (d < 0))
            and math.abs(before - d) < radius
        if hit == nil and math.abs(u) <= half + MARIO_RADIUS
            and (math.abs(d) < ROW_BODY or crossed) then
            local flameY = floor_under(m.pos.x, m.pos.z, at) + FLAME_DRAW
            if body_meets(m, flameY) then hit = row end
        end
    end
    me.lastD = seen
    return hit
end

local function score_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    return math.floor((row ~= nil and tonumber(row.ofScore)) or 0)
end

local function hits_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    return math.floor((row ~= nil and tonumber(row[HITS_ROW])) or 0)
end

local function pack_slots(slots)
    local parts = {}
    for i, s in ipairs(slots) do
        if s.x == nil then
            parts[i] = string.format("%.0f - - - %.0f %.0f", s.gen, s.lastGen, s.lastBy)
        else
            parts[i] = string.format("%.0f %.0f %.0f %.0f %.0f %.0f", s.gen, s.x, s.y, s.z,
                s.lastGen, s.lastBy)
        end
    end
    return table.concat(parts, "|")
end

local slotText, slotParsed = nil, {}
local function slots()
    local text = gGlobalSyncTable[STARS_KEY]
    if type(text) ~= "string" or text == "" then return {} end
    if text == slotText then return slotParsed end
    local out = {}
    for part in string.gmatch(text, "[^|]+") do
        local g, x, y, z, lg, lb = string.match(part,
            "^(%-?%d+) (%S+) (%S+) (%S+) (%-?%d+) (%-?%d+)$")
        if g ~= nil then
            out[#out + 1] = { gen = tonumber(g), x = tonumber(x), y = tonumber(y),
                z = tonumber(z), lastGen = tonumber(lg), lastBy = tonumber(lb) }
        end
    end
    slotText, slotParsed = text, out
    return out
end

local function stars_wanted(count)
    return math.max(1, math.ceil((tonumber(count) or 0) / PLAYERS_PER_STAR))
end

local mode = {
    key = "firesweep",
    name = "Fire Sweep",
    blurb = "rows of fire sweep the ring - jump them and grab the stars",
    how = "Rows of fire sweep across the ring in crossing pairs.\n"
        .. "Jump each row as it reaches you.\n"
        .. "Stars appear inside the ring - touch one for a point.\n"
        .. "A row that catches you stuns you and costs three stars.\n"
        .. "The rows come quicker as the round goes on.\n"
        .. "Blue rows are faster - watch for them late on.\n"
        .. "Most stars at the clock wins; fewer hits break a tie.",
    aims = { [ROLE_IN] = "Grab the stars and jump the rows of fire." },
    minPlayers = 2,
    maps = OF.PARTY_ARENAS,
    venueFamily = "party",
    room = { sweep = { "cannons" },
             rules = { interactions = PLAYER_INTERACTIONS_NONE } },
    defaultLimit = 120,
    music = SEQ_LEVEL_HOT,
    teams = false,
    symmetric = true,

    keepsScore = true,
    boardTitle = "Stars",
    options = {
        { key = "length", name = "Round length",
          help = "the clock the stars are counted at",
          choices = {
              { key = "two", name = "two minutes",
                help = "a party round; the rows reach full pace" },
              { key = "ninety", name = "a minute and a half",
                help = "short and busy" },
              { key = "three", name = "three minutes",
                help = "a long round, most of it at full pace" },
          } },
        { key = "pace", name = "Fire",
          help = "how often the rows come and how fast they cross",
          choices = {
              { key = "normal", name = "normal",
                help = "a row every four seconds, every two by the end" },
              { key = "gentle", name = "gentle",
                help = "fewer, slower rows - a lobby learning it" },
              { key = "fierce", name = "fierce",
                help = "more rows sooner, and blue ones from the start" },
          } },
    },
}

mode.stars_wanted = stars_wanted
mode.rows = rows
mode.row_offset = row_offset
mode.row_hit = row_hit
mode.slots = slots
mode.pack_slots = pack_slots
mode.STUN_FRAMES = STUN_FRAMES
mode.STAR_RESPAWN = STAR_RESPAWN
mode.PACES = PACES
mode.LENGTHS = LENGTHS
mode.ROLE_IN = ROLE_IN
mode.HIT_COST = HIT_COST
mode.live_rows = live_rows

function mode.clock_for(choice)
    return LENGTHS[choice or "two"] or LENGTHS.two
end

function mode.setup(players, options)
    if options == nil or tonumber(options.limit) == nil then
        OF.util.publish("ofGmLimit", mode.clock_for(OF.gamemodes.option_now("length")))
    end
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_IN)
    end
    OF.ring.set_opening(OF.ring.opening_for(START_RADIUS, #players, WIDEST_RADIUS))
    OF.util.publish(SEED_KEY, math.random(1, 999999))
    host.slots = nil
end

function mode.pin()
    OF.ring.pin()
end

function mode.on_start()
    OF.ring.on_start()
    me.stunUntil, me.immuneUntil = -1, -1
    me.lastD, me.asked, me.credited = {}, {}, {}
    me.heardRow = 0
    host.slots, host.lastAt, host.respawnAt = nil, {}, {}
    if OF.gamemodes.role(0) == ROLE_IN then
        OF.util.publish_row(0, "ofScore", 0)
        OF.util.publish_row(0, HITS_ROW, 0)
    end
end

function mode.late_join(localIndex)
    OF.gamemodes.set_role(localIndex, ROLE_IN)
    return ROLE_IN
end

function mode.stunned()
    return now_frame() < me.stunUntil
end

function mode.before_mario_update(m)

    if OF.util.round_screen() then
        draw_rows(OF.ring.at(), OF.gamemodes.since_start())
    else
        clear_rows()
    end
    if m ~= nil and m.playerIndex == 0 and mode.stunned() then
        OF.input.freeze(m)
    end
end

local function stun(m, row)
    local frame = now_frame()
    me.stunUntil = frame + STUN_FRAMES
    me.immuneUntil = frame + IMMUNE_FRAMES
    OF.util.publish_row(0, "ofScore", math.max(0, score_of(0) - HIT_COST))
    OF.util.publish_row(0, HITS_ROW, hits_of(0) + 1)
    if m.faceAngle ~= nil and atan2s ~= nil then
        m.faceAngle.y = atan2s(-row.nz, -row.nx)
    end
    local air = OF.util.has_flag(m.action or 0, ACT_FLAG_AIR or 0x800)
    local kb = air and ACT_BACKWARD_AIR_KB or ACT_BACKWARD_GROUND_KB
    if kb ~= nil then OF.util.optional("set_mario_action", nil, m, kb, 0) end
    m.invincTimer = IMMUNE_FRAMES
    OF.gamemodes.round_sound_from(m.marioObj, SOUND_MARIO_ON_FIRE)
    OF.gamemodes.cue("bad")

end

local function star_reach(m, s)
    if m == nil or m.pos == nil or s.x == nil then return false end
    local dx, dz = m.pos.x - s.x, m.pos.z - s.z
    if dx * dx + dz * dz >= GRAB_RADIUS * GRAB_RADIUS then return false end
    return math.abs(m.pos.y - s.y) < GRAB_HEIGHT
end

function mode.update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if OF.gamemodes.role(0) ~= ROLE_IN or not OF.util.can_play(0) then return end
    local at = OF.ring.at()
    local m = gMarioStates[0]
    if at == nil or m == nil then return end
    local np = gNetworkPlayers[0]
    local mine = np ~= nil and np.globalIndex or -1
    for k, s in ipairs(slots()) do
        if s.lastBy == mine and s.lastGen >= 0 and me.credited[k] ~= s.lastGen then
            me.credited[k] = s.lastGen
            OF.util.publish_row(0, "ofScore", score_of(0) + 1)
            OF.gamemodes.cue("good")
        end
    end
    local t = OF.gamemodes.since_start()
    local count = #live_rows(t, OF.ring.radius())
    if count > me.heardRow then
        OF.gamemodes.round_sound_throttled("fsrow", 20, SOUND_OBJ_FLAME_BLOWN)
    end
    me.heardRow = count
    local frame = now_frame()
    local row = row_hit(m, at, t)
    if row ~= nil and frame >= me.immuneUntil then
        stun(m, row)
        return
    end
    if mode.stunned() then return end
    for k, s in ipairs(slots()) do
        if s.x ~= nil and me.asked[k] ~= s.gen and star_reach(m, s) then
            me.asked[k] = s.gen
            OF.gamemodes.claim("fs " .. k .. " " .. s.gen)
        end
    end
end

local function place_star(at, k, state)
    local radius = OF.ring.radius()
    local inner = math.max(100, radius - math.min(STAR_MARGIN, radius * 0.35))
    local apart = math.min(STAR_APART, radius * 0.66)
    local best, bestGap = nil, -1
    for _ = 1, 12 do
        local a = math.random() * TWO_PI
        local d = math.sqrt(math.random()) * inner
        local x, z = at.x + math.sin(a) * d, at.z + math.cos(a) * d
        local gap = math.huge
        local last = host.lastAt[k]
        if last ~= nil then gap = math.sqrt((x - last.x) ^ 2 + (z - last.z) ^ 2) end

        for j, s in ipairs(state) do
            if j ~= k and s.x ~= nil then
                gap = math.min(gap, 2 * math.sqrt((x - s.x) ^ 2 + (z - s.z) ^ 2))
            end
        end
        if gap >= apart then best = { x = x, z = z }; break end
        if gap > bestGap then best, bestGap = { x = x, z = z }, gap end
    end
    best.y = floor_under(best.x, best.z, at)
    host.lastAt[k] = best
    return best
end

local function publish_slots()
    OF.util.publish(STARS_KEY, pack_slots(host.slots))
end

function mode.on_claim(senderLocal, what)
    if not OF.util.is_host() or host.slots == nil then return false end
    local k, gen = string.match(what or "", "^fs (%d+) (%d+)$")
    k, gen = tonumber(k), tonumber(gen)
    local s = k ~= nil and host.slots[k] or nil
    if s == nil or s.x == nil or s.gen ~= gen then return false end
    if OF.gamemodes.role(senderLocal) ~= ROLE_IN or not OF.util.can_play(senderLocal) then
        return false
    end
    local m = gMarioStates[senderLocal]
    local np = gNetworkPlayers[senderLocal]
    if m == nil or m.pos == nil or np == nil then return false end
    local dx, dz = m.pos.x - s.x, m.pos.z - s.z
    if dx * dx + dz * dz > CLAIM_SLACK * CLAIM_SLACK then return false end
    s.x, s.y, s.z = nil, nil, nil
    s.lastGen, s.lastBy = gen, np.globalIndex
    host.respawnAt[k] = now_frame() + math.floor(STAR_RESPAWN * 30)
    publish_slots()
    return true
end

function mode.host_update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    local at = OF.ring.at()
    if at == nil then return end
    if host.slots == nil then
        host.slots = {}
        local want = mode.stars_wanted(#OF.gamemodes.with_role(ROLE_IN))
        for k = 1, want do
            local spot = place_star(at, k, host.slots)
            host.slots[k] = { gen = 1, x = spot.x, y = spot.y, z = spot.z,
                lastGen = -1, lastBy = -1 }
        end
        publish_slots()
        return
    end
    local frame, changed = now_frame(), false
    for k, s in ipairs(host.slots) do
        if s.x == nil and frame >= (host.respawnAt[k] or 0) then
            local spot = place_star(at, k, host.slots)
            s.gen = s.gen + 1
            s.x, s.y, s.z = spot.x, spot.y, spot.z
            changed = true
        end
    end
    if changed then publish_slots() end
end

function mode.still_winnable()
    return #OF.gamemodes.with_role(ROLE_IN) >= 2
end

function mode.on_timeout()
    local best, names = OF.gamemodes.best_of(OF.gamemodes.with_role(ROLE_IN),
        function(entry) return score_of(entry.localIndex) end, false,
        function(entry) return -hits_of(entry.localIndex) end)
    if best == nil or best <= 0 then
        OF.gamemodes.finish("Time - nobody kept a star.")
    elseif #names > 1 then
        OF.gamemodes.finish(OF.lang.fill("Time - a draw at @ stars.", tostring(best)))
    else
        OF.gamemodes.finish("@ won with @ stars.", names[1], names[1], tostring(best))
    end
end

function mode.terms()
    local length = OF.gamemodes.option_showing(mode.key, "length") or "two"
    return OF.lang.fill("most stars in @ - a hit costs three",
        OF.gamemodes.clock(mode.clock_for(length)))
end

function mode.standing(localIndex)
    if not OF.util.can_play(localIndex) then return "AWAY" end
    return tostring(score_of(localIndex))
end

function mode.scenery()
    local state = OF.gamemodes.state()
    for k = 1, 8 do
        local s = slots()[k]
        if state == OF.gamemodes.ACTIVE and s ~= nil and s.x ~= nil then
            local t = now_frame() / 30
            local spot = { x = s.x, y = s.y + 110 + math.abs(math.sin(t * 3 + k)) * 25, z = s.z }
            OF.gamemodes.show_token("fsstar" .. k, E_MODEL_STAR, spot, 0x800)
        else
            OF.gamemodes.hide_token("fsstar" .. k)
        end
    end
end

function mode.hud()
    local at = OF.ring.at()
    if at ~= nil then
        OF.util.zone_ring(at, OF.ring.radius(), 48, 4, 255, 150, 60, 220, "edge")
    end

    if mode.stunned() and OF.util.asks(OF.hud, "state_line") then
        OF.hud.state_line("stunned", OF.lang.t("Stunned"), { prio = 70, tone = "bad" })
    end
end

function mode.cleanup()
    clear_rows()
    for k = 1, 8 do OF.gamemodes.hide_token("fsstar" .. k) end
    if OF.util.is_host() then
        OF.util.publish(SEED_KEY, nil)
        OF.util.publish(STARS_KEY, nil)
    end
    local row = gPlayerSyncTable[0]
    if row ~= nil and row[HITS_ROW] ~= nil then OF.util.publish_row(0, HITS_ROW, nil) end
    me.stunUntil, me.immuneUntil = -1, -1
    me.lastD, me.asked, me.credited = {}, {}, {}
    host.slots, host.lastAt, host.respawnAt = nil, {}, {}
    plan.seed = nil
    slotText, slotParsed = nil, {}
    OF.ring.let_go()
    return true
end

OF.gamemodes.register(mode)
