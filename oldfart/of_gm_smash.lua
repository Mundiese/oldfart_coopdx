OF = OF or {}

local ROLE_FIGHT = "in the fight"
local ROLE_OUT = "out"
local function at_load(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if not ok then return nil end
    return result
end

local FLAG_STATIONARY = ACT_FLAG_STATIONARY or (1 << 9)
local FLAG_AIR = ACT_FLAG_AIR or (1 << 11)
local FLAG_ATTACKING = ACT_FLAG_ATTACKING or (1 << 23)

local SM_UPPUNCH = at_load("allocate_mario_action",
    (ACT_GROUP_AIRBORNE or (2 << 6)) | FLAG_AIR | FLAG_ATTACKING)

local SM_TORNADO = at_load("allocate_mario_action",
    (ACT_GROUP_AIRBORNE or (2 << 6)) | FLAG_AIR | FLAG_ATTACKING)

local SM_CHARGE = at_load("allocate_mario_action",
    (ACT_GROUP_STATIONARY or 0) | FLAG_STATIONARY)
local SM_SWING = at_load("allocate_mario_action",
    (ACT_GROUP_STATIONARY or 0) | FLAG_STATIONARY | FLAG_ATTACKING)

local PERCENT_CAP = 999

local MOVES = {
    punch = { d = 8, bkb = 10, kbg = 100 },
    kick = { d = 12, bkb = 20, kbg = 80 },
    jumpkick = { d = 12, bkb = 22, kbg = 85 },
    dive = { d = 10, bkb = 25, kbg = 75 },
    slidekick = { d = 11, bkb = 30, kbg = 70 },
    pound = { d = 16, bkb = 25, kbg = 75 },

    poundland = { d = 8, bkb = 40, kbg = 40 },

    smash = { d = 18, bkb = 25, kbg = 95 },

    uppunch = { d = 6, bkb = 40, kbg = 120, angle = 80 },

    tornado = { d = 10, bkb = 60, kbg = 90, angle = 75, away = true },

    bomb = { d = 20, bkb = 60, kbg = 80, away = true },

    upsmash = { d = 17, bkb = 32, kbg = 93, angle = 85 },
    downsmash = { d = 14, bkb = 25, kbg = 80, angle = 25, away = true },
    cape = { d = 7, bkb = 30, kbg = 40, turn = true },

    fthrow = { d = 8, bkb = 60, kbg = 60, angle = 40 },
    bthrow = { d = 11, bkb = 65, kbg = 75, angle = 42 },
    uthrow = { d = 7, bkb = 70, kbg = 50, angle = 88 },
    dthrow = { d = 6, bkb = 55, kbg = 30, angle = 72 },

    hammer = { d = 9, bkb = 35, kbg = 70 },
}

local SWING_KINDS = { [0] = "smash", [1] = "upsmash", [2] = "downsmash", [3] = "cape" }
function OF.gm_smash_swing_kind(arg)
    return SWING_KINDS[math.floor((tonumber(arg) or 0) / 100)] or "smash"
end

local KB_TO_SPEED = 0.7

local SPEED_CAP = 200

local KB_CAP = 2500

local SAKURAI_AIR = 43
local SAKURAI_GROUND = 42.5
local SAKURAI_SLIDE_BELOW = 32

local HITSTUN_PER_KB = 0.533 / 2

local SMASH_CHARGE_BONUS = 0.367

local SMASH_CHARGE_FRAMES = 30

local METAL_DAMAGE = 1.25

local VAMPIRE_PCT_RELIEF = 8

local ROUND_KNOCKBACK = 25

local AIR_STEER = 1.5
local AIR_TURN = 512

local RESPAWN_GRACE = 90

local STOCK_STOPS = { three = 3, one = 1, two = 2, four = 4, five = 5 }
local STOCKS_DEFAULT = 3

local TIME_STOPS = { auto = 2, two = 2, three = 3, five = 5, seven = 7 }
local MINUTES_DEFAULT = 2

local BLAST_RIM = 3072
local BLAST_SIDE = BLAST_RIM + 1000
local BLAST_TOP = 3000

local BLAST_STAGES = {
    [LEVEL_BOWSER_1] = { x = 0, z = 0, y = 307 },
    [LEVEL_BOWSER_2] = { x = 0, z = 0, y = 1229, lava = true, lavaY = -1023 },
    [LEVEL_BOWSER_3] = { x = 0, z = 0, y = 307 },
}

local LAVA_ABOVE = 300
local LAVA_UNDER_STAGE = 400
local lavaLines = {}
function OF.gm_smash_lava_line(level)
    local box = BLAST_STAGES[level]
    if box == nil or not box.lava then return nil end
    if lavaLines[level] ~= nil then return lavaLines[level] end
    local h = OF.util.optional("find_floor_height", nil, box.x + BLAST_RIM + 600, box.y + 200, box.z)

    if (type(h) ~= "number" or h < -10000 or h > box.y) and box.lavaY ~= nil then h = box.lavaY end
    if type(h) ~= "number" or h < -10000 or h > box.y then return nil end
    local line = math.min(h + LAVA_ABOVE, box.y - LAVA_UNDER_STAGE)
    lavaLines[level] = line
    return line
end
function OF.gm_smash_forget_lava() lavaLines = {} end
hook_event(HOOK_ON_LEVEL_INIT, function() lavaLines = {} end)

local WRAP_DROP = 2500

local HP_PER_PERCENT = 2.5

local HP_STOPS = { ["4"] = 400, ["1"] = 100, ["2"] = 200, ["3"] = 300, ["5"] = 500,
                   ["7"] = 750, ["9"] = 999 }
local HP_DEFAULT = 400

local WRAP_HP_COST = 20

local TURBO_WINDOW = 20

local TURBO_AT_PERCENT = { hi = 120, mid = 60, max = 200 }
local TURBO_AT_DEFAULT = 120

local FLAT_CAMERA_YAW = 0x4000

local FLAT_SEED_YAW = -0x8000

local FLAT_LINE_Z = 0

local FLAT_LINE_X = 0

local FLAT_SPAWN_GAP = 260
local FLAT_SPAWN_SPREAD = 1600

local FLAT_STAGES = {
    [LEVEL_BOWSER_1] = true,
    [LEVEL_BOWSER_2] = true,
    [LEVEL_BOWSER_3] = true,
}

OF.gm_smash_lanes = {
    { key = "castle_grounds:1", level = LEVEL_CASTLE_GROUNDS, area = 1, name = "Castle Grounds", shape = "flat",
      z = -6500, y = 2904, x0 = -2550, x1 = 2550, side = -1, camFar = 4600, floor = 5125,
      left = -3550, right = 3550, top = 5904, bottom = 2189,
      solid = { -2550, 2550 },
      spawns = { 0, 2905, -250, 2905, 250, 2904, -500, 2906, 500, 2904, -750, 2907, 750, 2904, -1000, 2907, 1000, 2904, -1250, 2908, 1250, 2904, -1500, 2908, 1500, 2904, -1750, 2909, 1750, 2904, -2000, 2910 },
      items = { -2100, 2910, -1500, 2908, -900, 2907, -300, 2905, 300, 2904, 900, 2904, 1500, 2904, 2100, 2904 } },
    { key = "castle_courtyard:1", level = LEVEL_CASTLE_COURTYARD, area = 1, name = "Castle Courtyard", shape = "flat",
      z = -3500, y = 0, x0 = -1325, x1 = 1325, side = 1, camFar = 1600, floor = 2675,
      left = -2325, right = 2325, top = 3000, bottom = -400,
      solid = { -1325, 1325 },
      spawns = { 0, 0, -250, 0, 250, 0, -500, 0, 500, 0, -750, 20, 750, 20, -1000, 0, 1000, 1, -125, 0, 125, 0, -375, 0, 375, 0, -625, 0, 625, 0, -875, 20 },
      items = { -1050, 0, -750, 20, -450, 0, -150, 0, 150, 0, 450, 0, 750, 20, 1050, 0 } },
    { key = "bob:1", level = LEVEL_BOB, area = 1, name = "Bob-omb Battlefield", shape = "edges",
      z = -5600, y = 4293, x0 = 1300, x1 = 4825, side = 1, camFar = 4600, floor = 3550,
      left = 300, right = 5825, top = 7293, bottom = 3892,
      solid = { 1300, 4825 },
      spawns = { 3050, 4293, 3300, 4293, 2800, 4293, 3550, 4293, 2550, 4293, 3800, 4294, 2300, 4293, 4050, 4294, 2050, 4293, 4300, 4294, 1800, 4293, 4550, 4294, 1550, 4293, 3175, 4293, 2925, 4293, 3425, 4293 },
      items = { 1650, 4293, 2050, 4293, 2450, 4293, 2850, 4293, 3275, 4293, 3675, 4293, 4075, 4294, 4475, 4294 } },
    { key = "wf:1", level = LEVEL_WF, area = 1, name = "Whomp's Fortress", shape = "edges",
      z = -500, y = 3584, x0 = -1000, x1 = 1525, side = 1, camFar = 4600, floor = 2550,
      left = -2000, right = 2525, top = 6584, bottom = 3184,
      solid = { -1000, 1525 },
      spawns = { 250, 3584, 500, 3584, 0, 3584, 750, 3584, -250, 3584, 1000, 3584, -500, 3584, 1250, 3584, -750, 3584, 375, 3584, 125, 3584, 625, 3584, -125, 3584, 875, 3584, -375, 3584, 1125, 3584 },
      items = { -725, 3584, -450, 3584, -150, 3584, 125, 3584, 400, 3584, 675, 3584, 975, 3584, 1250, 3584 } },
    { key = "jrb:1", level = LEVEL_JRB, area = 1, name = "Jolly Roger Bay", shape = "gaps",
      z = 7100, y = 1536, x0 = 425, x1 = 3775, side = -1, camFar = 3700, floor = 2875,
      left = -575, right = 4775, top = 4536, bottom = 1136,
      solid = { 425, 2925, 3450, 3775 },
      spawns = { 2100, 1536, 1850, 1536, 2350, 1536, 1600, 1536, 2600, 1536, 1350, 1536, 1100, 1536, 850, 1536, 600, 1536, 3600, 1536, 1975, 1536, 2225, 1536, 1725, 1536, 2475, 1536, 1475, 1536, 2725, 1536 },
      items = { 700, 1536, 1000, 1536, 1275, 1536, 1550, 1536, 1850, 1536, 2125, 1536, 2400, 1536, 2700, 1536 } },
    { key = "ccm:1", level = LEVEL_CCM, area = 1, name = "Cool, Cool Mountain", shape = "edges",
      z = 5300, y = -4607, x0 = 775, x1 = 4825, side = 1, camFar = 4600, floor = 4075,
      left = -225, right = 5825, top = -1607, bottom = -5007,
      solid = { 775, 4825 },
      spawns = { 2800, -4607, 2550, -4607, 3050, -4607, 2300, -4607, 3300, -4607, 2050, -4607, 3550, -4607, 1800, -4607, 3800, -4607, 1550, -4607, 4050, -4607, 1300, -4607, 4300, -4607, 1050, -4607, 4550, -4607, 2675, -4607 },
      items = { 1150, -4607, 1625, -4607, 2100, -4607, 2575, -4607, 3025, -4607, 3500, -4607, 3975, -4607, 4450, -4607 } },
    { key = "bbh:1", level = LEVEL_BBH, area = 1, name = "Big Boo's Haunt", shape = "edges",
      z = 200, y = 3277, x0 = -1725, x1 = 3050, side = 1, camFar = 4600, floor = 4800,
      left = -2725, right = 4050, top = 6277, bottom = 2877,
      solid = { -1725, 3050 },
      spawns = { 650, 3277, 900, 3277, 400, 3277, 1150, 3277, 150, 3277, 1400, 3277, -100, 3277, 1650, 3277, -350, 3277, 1900, 3277, -600, 3277, 2150, 3277, -850, 3277, 2400, 3277, -1100, 3277, 2650, 3277 },
      items = { -1300, 3277, -750, 3277, -175, 3277, 375, 3277, 950, 3277, 1500, 3277, 2075, 3277, 2625, 3277 } },
    { key = "sl:1", level = LEVEL_SL, area = 1, name = "Snowman's Land", shape = "edges",
      z = -2100, y = 1536, x0 = 900, x1 = 3375, side = -1, camFar = 4600, floor = 2500,
      left = -100, right = 4375, top = 4536, bottom = 1136,
      solid = { 900, 3375 },
      spawns = { 2125, 1536, 2375, 1536, 1875, 1536, 2625, 1536, 1625, 1536, 2875, 1536, 1375, 1536, 3125, 1540, 1125, 1536, 2250, 1536, 2000, 1536, 2500, 1536, 1750, 1536, 2750, 1536, 1500, 1536, 3000, 1536 },
      items = { 1175, 1536, 1450, 1536, 1725, 1536, 2000, 1536, 2275, 1536, 2550, 1536, 2825, 1536, 3100, 1537 } },
    { key = "wdw:1", level = LEVEL_WDW, area = 1, name = "Wet-Dry World", shape = "edges",
      z = 4600, y = 0, x0 = -3825, x1 = 3375, side = 1, camFar = 4600, floor = 7225,
      left = -4825, right = 4375, top = 3000, bottom = -400,
      solid = { -3825, 3375 },
      spawns = { -225, 0, -475, 0, 25, 0, -725, 0, 275, 0, -975, 0, 525, 0, -1225, 0, 775, 0, -1475, 0, 1025, 0, -1725, 0, 1275, 0, -1975, 0, 1525, 0, -2225, 0 },
      items = { -3250, 0, -2400, 0, -1525, 0, -650, 0, 200, 0, 1075, 0, 1950, 0, 2800, 0 } },
    { key = "ttm:1", level = LEVEL_TTM, area = 1, name = "Tall, Tall Mountain", shape = "edges",
      z = 6200, y = -4420, x0 = -1300, x1 = 1925, side = 1, camFar = 4600, floor = 3250,
      left = -2300, right = 2925, top = -1420, bottom = -4904,
      solid = { -1300, 1925 },
      spawns = { 300, -4414, 550, -4407, 50, -4418, 800, -4442, -200, -4422, 1050, -4422, -450, -4441, 1300, -4397, -700, -4459, 1550, -4372, -950, -4478, 425, -4410, 175, -4416, 675, -4424, -75, -4419, 925, -4434 },
      items = { -975, -4480, -600, -4452, -250, -4426, 125, -4417, 500, -4406, 875, -4439, 1225, -4404, 1600, -4367 } },
    { key = "thi:1", level = LEVEL_THI, area = 1, name = "Tiny-Huge Island (huge)", shape = "edges",
      z = 4000, y = -511, x0 = -5350, x1 = -1175, side = 1, camFar = 4600, floor = 4200,
      left = -6350, right = -175, top = 2489, bottom = -911,
      solid = { -5350, -1175 },
      spawns = { -3275, -511, -3025, -511, -3525, -511, -2775, -511, -3775, -511, -2525, -511, -4025, -511, -2275, -511, -4275, -511, -2025, -511, -4525, -511, -1775, -511, -4775, -511, -1525, -511, -5025, -511, -3150, -511 },
      items = { -4975, -511, -4475, -511, -4000, -511, -3500, -511, -3025, -511, -2525, -511, -2050, -511, -1550, -511 } },
}
OF.gm_smash_lanes_out = {
    { level = LEVEL_CASTLE, area = 1, why = "no camera side clear of walls far enough" },
    { level = LEVEL_CASTLE, area = 2, why = "no lane with all three blast lines open (a wall shuts the left blast line off at x=-2250)" },
    { level = LEVEL_CASTLE, area = 3, why = "no lane with all three blast lines open (a wall shuts the left blast line off at x=2600)" },
    { level = LEVEL_JRB, area = 2, why = "no long straight stretch of floor at one height" },
    { level = LEVEL_CCM, area = 2, why = "no long straight stretch of floor at one height" },
    { level = LEVEL_HMC, area = 1, why = "no lane with all three blast lines open (a wall shuts the left blast line off at x=-3600)" },
    { level = LEVEL_LLL, area = 1, why = "the only long enough floor is not drawn (a camera or boundary floor)" },
    { level = LEVEL_LLL, area = 2, why = "no long straight stretch of floor at one height" },
    { level = LEVEL_SSL, area = 1, why = "no lane with all three blast lines open (a wall shuts the left blast line off at x=-6625)" },
    { level = LEVEL_SSL, area = 2, why = "no lane with all three blast lines open (a wall shuts the left blast line off at x=-2775)" },
    { level = LEVEL_DDD, area = 1, why = "every long enough floor is under or beside water" },
    { level = LEVEL_SL, area = 2, why = "no long straight stretch of floor at one height" },
    { level = LEVEL_TTM, area = 2, why = "no long straight stretch of floor at one height" },
    { level = LEVEL_THI, area = 2, why = "no long straight stretch of floor at one height" },
    { level = LEVEL_THI, area = 3, why = "no camera side clear of walls far enough" },
    { level = LEVEL_TTC, area = 1, why = "no camera side clear of walls far enough" },
    { level = LEVEL_RR, area = 1, why = "the only long enough floor is not drawn (a camera or boundary floor)" },
}

local STAGE = { cache = {} }

function STAGE.pairs_of(flatList)
    local out = {}
    for i = 1, #(flatList or {}) - 1, 2 do
        table.insert(out, { x = flatList[i], y = flatList[i + 1] })
    end
    return out
end

function STAGE.of(level, area)
    if level == nil then return nil end
    area = area or 1
    local key = tostring(level) .. ":" .. tostring(area)
    local hit = STAGE.cache[key]
    if hit ~= nil then return hit or nil end
    local stage = false
    local box = BLAST_STAGES[level]
    if box ~= nil and FLAT_STAGES[level] and area == 1 then
        stage = {
            level = level, area = 1, x = box.x, y = box.y, z = box.z,
            x0 = box.x - BLAST_RIM, x1 = box.x + BLAST_RIM,
            left = box.x - BLAST_SIDE, right = box.x + BLAST_SIDE,
            top = box.y + BLAST_TOP, wrapBottom = box.y - WRAP_DROP,
            lava = box.lava, side = 1, lane = false,
        }
    elseif OF.util.asks(OF.venues, "at") and OF.venues.at(level, area) ~= nil then

        local key = OF.venues.at(level, area)
        local layout = OF.venues.LAYOUTS ~= nil and OF.venues.LAYOUTS[key] or nil
        local given = layout ~= nil and layout.blast or nil
        local mid = (given ~= nil and given) or (layout ~= nil and (layout.world
            or (layout.spawns ~= nil and layout.spawns[1]))) or { x = 0, y = 0, z = 0 }
        local cx, cy, cz = mid.x or 0, mid.y or 0, mid.z or 0
        local rim = given ~= nil and given.rim or nil
        if rim == nil and OF.util.asks(OF.ring, "plate_radius") then
            rim = OF.ring.plate_radius({ x = cx, y = cy, z = cz }, 8000)
        end
        if rim == nil or rim <= 0 then return nil end
        local stage = {
            level = level, area = area, x = cx, y = cy, z = cz,
            x0 = cx - rim, x1 = cx + rim,
            left = cx - rim - (BLAST_SIDE - BLAST_RIM), right = cx + rim + (BLAST_SIDE - BLAST_RIM),
            top = cy + ((given ~= nil and given.top) or BLAST_TOP), wrapBottom = cy - WRAP_DROP,
            side = 1, lane = false, venue = true,
        }
        STAGE.cache[key] = nil
        STAGE.cache[tostring(level) .. ":" .. tostring(area)] = stage
        return stage
    else
        for _, row in ipairs(OF.gm_smash_lanes or {}) do
            if row.level == level and (row.area or 1) == area then
                stage = {
                    level = level, area = area, name = row.name, shape = row.shape,
                    x = math.floor((row.x0 + row.x1) / 2), y = row.y, z = row.z,
                    x0 = row.x0, x1 = row.x1, left = row.left, right = row.right,
                    top = row.top, koBottom = row.bottom, wrapBottom = row.bottom,
                    side = row.side or 1, camFar = row.camFar, lane = true,
                    solid = STAGE.pairs_of(row.solid), spawns = STAGE.pairs_of(row.spawns),
                    items = STAGE.pairs_of(row.items),
                }
                break
            end
        end
    end
    STAGE.cache[key] = stage
    return stage or nil
end

function STAGE.here()
    local np = gNetworkPlayers[0]
    if np == nil then return nil end
    return STAGE.of(np.currLevelNum, np.currAreaIndex or 1)
end

function STAGE.z()
    local stage = STAGE.here()
    return stage ~= nil and stage.z or FLAT_LINE_Z
end

function STAGE.spawn(stage, slot, count)
    local points = stage.spawns
    if points == nil or #points == 0 then return nil end
    count = math.max(1, math.min(count, #points))
    local row = {}
    for i = 1, count do row[i] = points[i] end
    table.sort(row, function(a, b) return a.x < b.x end)
    return row[(slot % count) + 1]
end

function OF.gm_smash_stage(level, area)
    return STAGE.of(level, area)
end

local PCT_KEY = "ofSmashPct"
local KO_KEY = "ofSmashKOs"
local FALL_KEY = "ofSmashFall"
local percent = 0
local stocks = 0

local lost = 0
local kos = 0
local grace = 0

local hitBy = -1
local hitAgo = 0

local fallSeq = 0
local fallClaimed = false

local hitstun = 0
local lastKb = 0

local turboLeft = 0
local turboFrom = nil

local knock_out

local leave_the_moveset
local sd_on
local leave_sudden_death
local enter_sudden_death
local rain_on_the_line
local start_sudden_death
local read_the_moveset

local launch_the_victim

local cam_let_go

local lastEdge = nil

local seenFall = {}

local dealt = false

local FLAT_PLACE_WINDOW = 90
local placeDue = 0

local SD_KEY_NAME = "ofSmashSD"
local function am_out()
    return OF.gamemodes.role(0) == ROLE_OUT
end

local function parts(door, ...)
    local list = OF.gm_smash_parts
    if type(list) ~= "table" then return nil end
    for _, part in ipairs(list) do
        local fn = part[door]
        if type(fn) == "function" then
            local said = fn(...)
            if said ~= nil then return said end
        end
    end
    return nil
end

local function on_turbo()
    return OF.gamemodes.option_is("rule", "turbo")
end

local function on_hp()
    return on_turbo() or OF.gamemodes.option_is("rule", "hp")
end

local function on_coins()
    return OF.gamemodes.option_is("rule", "coin")
end

local function on_stocks()
    return OF.gamemodes.option_is("rule", "stock") or on_hp()
end

local function turbo_at()
    return TURBO_AT_PERCENT[OF.gamemodes.option_now("kb") or "hi"]
        or TURBO_AT_DEFAULT
end

function OF.gm_smash_launch_now(percentAfter, kind, weight)
    if on_hp() then return OF.gm_smash_launch(turbo_at(), kind, weight) end
    return OF.gm_smash_launch(percentAfter, kind, weight)
end

local function hp_wanted()
    return HP_STOPS[OF.gamemodes.option_now("hp") or "4"] or HP_DEFAULT
end

local function edges_wrap()
    local said = OF.gamemodes.option_now("e") or "auto"
    if said == "wr" then return true end
    if said == "bz" then return false end
    return on_turbo()
end

local function stocks_wanted()
    return STOCK_STOPS[OF.gamemodes.option_now("lv") or "three"]
        or STOCKS_DEFAULT
end

local function stocks_left()
    return math.max(0, stocks_wanted() - lost)
end

local function minutes_wanted(count)
    local said = OF.gamemodes.option_now("min") or "auto"
    if said == "auto" then
        if on_stocks() then return 5 end
        count = count or #OF.gamemodes.participants()
        return count >= 5 and 3 or 2
    end
    return TIME_STOPS[said] or MINUTES_DEFAULT
end
OF.gm_smash_minutes_wanted = minutes_wanted

local function flat_asked()
    return true
end

local function flat_stage()
    return STAGE.here() ~= nil
end

local function flat_on()
    return flat_asked() and flat_stage()
end

function OF.gm_smash_along_line(vx, vz, awayX)
    vx = tonumber(vx) or 0
    vz = tonumber(vz) or 0
    local mag = math.sqrt(vx * vx + vz * vz)
    if mag <= 0 then return 0, 0 end
    local sign = 1
    if vx < 0 then
        sign = -1
    elseif vx == 0 and (tonumber(awayX) or 0) < 0 then
        sign = -1
    end
    return sign * mag, 0
end

function OF.gm_smash_spawn_x(slot, count)
    slot = math.floor(tonumber(slot) or 0)
    count = math.floor(tonumber(count) or 1)
    if count < 1 then count = 1 end
    if slot < 0 then slot = 0 end
    if slot > count - 1 then slot = count - 1 end

    local stage = STAGE.here()
    local point = stage ~= nil and STAGE.spawn(stage, slot, count) or nil
    if point ~= nil then return point.x, point.y end
    if count == 1 then return FLAT_LINE_X end
    local gap = FLAT_SPAWN_GAP
    local widest = FLAT_SPAWN_SPREAD / (count - 1)
    if gap > widest then gap = widest end
    return FLAT_LINE_X + (slot - (count - 1) / 2) * gap
end

local function measured_stages()
    local out = {}
    local seen = {}
    for level in pairs(FLAT_STAGES) do seen[level] = true end
    for _, row in ipairs(OF.gm_smash_lanes or {}) do seen[row.level] = true end
    for level in pairs(seen) do table.insert(out, level) end
    table.sort(out)
    return out
end

function OF.gm_smash_flat()
    return { asked = flat_asked(), stage = flat_stage(), on = flat_on(),
             cameraYaw = FLAT_CAMERA_YAW, seedYaw = FLAT_SEED_YAW,
             lineZ = STAGE.z(), lineX = FLAT_LINE_X, stageNow = STAGE.here(),
             gap = FLAT_SPAWN_GAP, spread = FLAT_SPAWN_SPREAD,
             measured = measured_stages() }
end

local function percent_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    local said = row ~= nil and row[PCT_KEY] or 0
    if type(said) ~= "number" or said < 0 then return 0 end
    return math.floor(math.min(said, PERCENT_CAP))
end

local function kos_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    local said = row ~= nil and row[KO_KEY] or 0
    if type(said) ~= "number" or said < 0 then return 0 end
    return math.floor(said)
end

local function score_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    local said = row ~= nil and row.ofScore or 0
    if type(said) ~= "number" then return 0 end
    return said
end

local function hp_from(pct)
    local left = hp_wanted() - (tonumber(pct) or 0) * HP_PER_PERCENT
    if left <= 0 then return 0 end
    return math.ceil(left)
end

local function hp_of(localIndex)
    return hp_from(percent_of(localIndex))
end

local function percent_for_hp(hp)
    return (tonumber(hp) or 0) / HP_PER_PERCENT
end

function OF.gm_smash_charge_share(held)
    local share = ((tonumber(held) or 0) % 100) / SMASH_CHARGE_FRAMES
    if share < 0 then return 0 end
    if share > 1 then return 1 end
    return share
end

local WEIGHT_MULT = {}
local function weigh(ct, w)
    if ct ~= nil then WEIGHT_MULT[ct] = 200 / (w + 100) end
end

weigh(CT_MARIO or 0, 100)
weigh(CT_LUIGI or 1, 100)
weigh(CT_TOAD or 2, 85)
weigh(CT_WALUIGI or 3, 100)
weigh(CT_WARIO or 4, 107)

function OF.gm_smash_weight_of(ct)
    return WEIGHT_MULT[ct] or 1
end

function OF.gm_smash_weight()
    local scale = tonumber(parts("weight_scale")) or 1
    if OF.gamemodes.option_now("w") ~= "on" then return scale end
    local np = gNetworkPlayers[0]
    if np == nil then return scale end
    return OF.gm_smash_weight_of(np.modelIndex) * scale
end

function OF.gm_smash_start_percent()
    if on_hp() then return 0 end
    local said = OF.gamemodes.option_now("p")
    if said == "1" then return 100 end
    if said == "3" then return 300 end
    return 0
end

function OF.gm_smash_move(kind)
    return MOVES[kind] or MOVES.punch
end

function OF.gm_smash_kb(kind, percentAfter, weight, damage)
    local move = OF.gm_smash_move(kind)
    local p = tonumber(percentAfter) or 0
    if p < 0 then p = 0 end
    if p > PERCENT_CAP then p = PERCENT_CAP end
    local d = tonumber(damage) or move.d
    local w = tonumber(weight) or 1
    local kb = ((p / 10 + p * d / 20) * w * 1.4 + 18) * move.kbg / 100 + move.bkb
    if kb > KB_CAP then kb = KB_CAP end
    return kb
end

function OF.gm_smash_speed(kb)
    local speed = KB_TO_SPEED * (tonumber(kb) or 0)
    if speed > SPEED_CAP then speed = SPEED_CAP end
    if speed < 0 then speed = 0 end
    return speed
end

function OF.gm_smash_launch(percentAfter, kind, weight, damage)
    return OF.gm_smash_speed(OF.gm_smash_kb(kind, percentAfter, weight, damage))
end

function OF.gm_smash_hitstun(kb)
    return math.floor((tonumber(kb) or 0) * HITSTUN_PER_KB)
end

function OF.gm_smash_angle(kind, kb, grounded)
    local move = OF.gm_smash_move(kind)
    if move.angle ~= nil then return move.angle end
    if not grounded then return SAKURAI_AIR end
    if (tonumber(kb) or 0) < SAKURAI_SLIDE_BELOW then return nil end
    return SAKURAI_GROUND
end

function OF.gm_smash_forget_deal()
    dealt = false
    stocks = 0
end

function OF.gm_smash_state()
    return { percent = percent, stocks = stocks, kos = kos, grace = grace,
             hitBy = hitBy, hitAgo = hitAgo, fallSeq = fallSeq,
             hp = on_hp() and hp_from(percent) or nil,
             turboLeft = turboLeft, turboFrom = turboFrom,
             hitstun = hitstun, lastKb = lastKb,
             lastEdge = lastEdge, wraps = edges_wrap() }
end

local mode = {

    lobbyRules = { interactions = PLAYER_INTERACTIONS_PVP, knockback = ROUND_KNOCKBACK,
        bubble = 0 },
    key = "smash",

    name = "Knock Out",

    noLeaderMark = true,
    blurb = "the more you have taken, the further the next one sends you",

    blurbTeams = "the more you have taken, the further the next one sends you "
        .. "- your side's KOs and stocks are pooled",

    how = "No health is lost - the percentage is the damage.\n"
        .. "The higher your percent, the further a hit throws you.\n"
        .. "Past any edge - a side, the top or the bottom - is a KO.\n"
        .. "On stocks the last one left wins; on time, most KOs.\n"
        .. "On turbo, hit points drain; a landed hit cancels.\n"
        .. "A in the air jumps again; Up, Down and Side+B: specials.\n"
        .. "Stick and A together, held: charged strike, any way.\n"
        .. "Z shields on the ground, dodges in the air; A grabs items.",
    aims = { [ROLE_FIGHT] = "Raise their percent, then knock them off the stage." },
    minPlayers = 2,

    maps = { "bowser1", "bowser2", "bowser3" },

    mainCourses = true,
    levelsIn = (function()
        local out = {}
        for _, row in ipairs(OF.gm_smash_lanes or {}) do
            if row.level == LEVEL_CASTLE or row.level == LEVEL_CASTLE_GROUNDS
                or row.level == LEVEL_CASTLE_COURTYARD then
                table.insert(out, { level = row.level, area = row.area })
            end
        end
        return out
    end)(),
    roomsOut = OF.gm_smash_lanes_out or {},

    roomsNote = "The Plate is not offered here - this round needs the stage's own blast zone and its middle read off the level, and nothing here can read either from a level you built yourself.",

    room = { sweep = { "cannons", "enemies", "hazards", "bosses", "spawners", "projectiles" } },
    music = SEQ_LEVEL_BOSS_KOOPA,

    mods = "view=2",

    teams = true,

    saysOut = true,

    defaultLimit = 120,

    options = {
        { key = "rule", name = "How the round is decided",
          help = "what a KO is worth: a life spent, or a point scored",
          choices = {
              { key = "time", name = "time",
                help = "a KO is a point; a fall costs one; most points wins" },
              { key = "stock", name = "stocks",
                help = "the same lives each; the last one left wins" },

              { key = "turbo", name = "turbo",
                help = "hit points per stock; a landed hit cancels into the next" },

              { key = "coin", name = "coins",
                help = "a hit knocks coins out; a KO costs half; most coins wins" },
              { key = "hp", name = "stamina",
                help = "hit points per stock; empty or off the stage costs one" },
          } },

        { key = "hp", name = "Hit points each stock",
          shownIf = { rule = { "turbo", "hp" } },
          help = "only read on turbo and stamina; empty costs a stock",
          choices = {
              { key = "4", name = "400 hit points",
                help = "twenty-odd clean hits to empty" },
              { key = "1", name = "100 hit points",
                help = "a handful of hits - fast and brutal" },
              { key = "2", name = "200 hit points" },
              { key = "3", name = "300 hit points" },
              { key = "5", name = "500 hit points" },
              { key = "7", name = "750 hit points" },
              { key = "9", name = "999 hit points",
                help = "the display's own ceiling - a long war" },
          } },
        { key = "lv", name = "How many stocks each",
          shownIf = { rule = { "stock", "turbo", "hp" } },
          help = "only read on a stock round; the original's one to five",
          choices = {
              { key = "three", name = "three stocks",
                help = "the original's own default; what most rounds want" },
              { key = "one", name = "one stock",
                help = "sudden death - the first clean exchange settles it" },
              { key = "two", name = "two stocks",
                help = "one mistake forgiven rather than two" },
              { key = "four", name = "four stocks",
                help = "a long round for a small lobby" },
              { key = "five", name = "five stocks",
                help = "the original's own top stop - a war of attrition" },
          } },

        { key = "min", name = "How long the round runs",
          help = "the clock on a timed round; a backstop on a stock one",
          choices = {
              { key = "auto", name = "auto",
                help = "2 min on time up to four, 3 from five; 5 on stocks" },
              { key = "two", name = "two minutes",
                help = "Melee's own time battle - at a killing percent by the end" },
              { key = "three", name = "three minutes" },
              { key = "five", name = "five minutes",
                help = "a long round, for a small lobby" },
              { key = "seven", name = "seven minutes",
                help = "the length Ultimate's own rules use" },
          } },

        { key = "kb", name = "Knockback on hit-point rules",
          help = "turbo and stamina: the same throw at any hit points",
          shownIf = { rule = { "turbo", "hp" } },
          choices = {
              { key = "hi", name = "high",
                help = "fighters cross the edges often" },
              { key = "mid", name = "medium",
                help = "a fight that stays on the stage longer" },
              { key = "max", name = "wild",
                help = "the strongest throw this mode has" },
          } },

        { key = "e", name = "The edges of the stage",
          help = "what crossing the box around the stage does",
          choices = {
              { key = "auto", name = "blast zones, wrap on turbo",
                help = "the usual pairing - pick one below to force it" },
              { key = "bz", name = "blast zones",
                help = "past any side, the top or the bottom is a KO" },
              { key = "wr", name = "wrap around",
                help = "out one side, in the other - unless a hit threw you out" },
          } },

        { key = "w", name = "Heavier characters fly less",
          help = "the original's weights; small next to the percent",
          choices = {
              { key = "off", name = "no - everybody flies alike",
                help = "every character thrown the same" },
              { key = "on", name = "yes - by character",
                help = "Wario a little less, Toad a little further" },
          } },

        { key = "i", name = "Items",
          help = "dropped at random on the stage for anybody to grab",
          choices = {
              { key = "m", name = "medium",
                help = "about one every ten to twenty seconds for four players" },
              { key = "l", name = "low",
                help = "a rare item - worth fighting for" },
              { key = "h", name = "high",
                help = "a steady stream of them" },
              { key = "n", name = "off",
                help = "the bare fight - nothing but fists" },
          } },

        { key = "z", name = "Everybody's size",
          help = "Special Knock Out: giant hits harder, tiny flies further",
          choices = {
              { key = "n", name = "as they are" },
              { key = "g", name = "giant", mods = "giant=1",
                help = "everybody big; every hit does half as much again" },
              { key = "t", name = "tiny", mods = "tiny=1",
                help = "everybody small; every hit throws half as far again" },
          } },
        { key = "b", name = "Everybody's body",
          help = "Special Knock Out: a cap everybody wears all round",
          choices = {
              { key = "n", name = "as they are" },
              { key = "m", name = "metal",
                help = "hits harder and flies less - heavy as a Metal Cap" },
          } },
        { key = "s", name = "Everybody's status",
          help = "Special Knock Out: one more thing true of every fighter",
          choices = {
              { key = "n", name = "none" },

              { key = "b", name = "bunny", mods = "quick=1",
                help = "quicker on foot and every jump higher" },
              { key = "f", name = "flower",
                help = "a flower on every head - percent climbs every second" },
              { key = "w", name = "wing cap",
                help = "A held floats you down, A again lifts you" },
          } },
        { key = "g", name = "Gravity",
          help = "Special Knock Out: how hard everybody falls",
          choices = {
              { key = "n", name = "normal" },
              { key = "l", name = "light", mods = "lowgrav=1",
                help = "everybody hangs in the air" },
              { key = "h", name = "heavy", mods = "lowgrav=4",
                help = "everybody drops like a stone" },
          } },

        { key = "v", name = "Speed",
          help = "Special Knock Out: how fast everybody moves",
          choices = {
              { key = "n", name = "normal" },
              { key = "f", name = "fast", mods = "quick=2" },
              { key = "s", name = "slow", mods = "quick=4" },
          } },

        { key = "p", name = "Everybody starts at",
          help = "the percent each stock begins on",
          shownIf = { rule = { "time", "stock", "coin" } },
          choices = {
              { key = "0", name = "0%" },
              { key = "1", name = "100%",
                help = "every exchange already dangerous" },
              { key = "3", name = "300%",
                help = "Super Sudden Death - the first clean hit is a KO" },
          } },

        { key = "c", name = "Camera",
          help = "Special Knock Out: how the stage is watched",
          choices = {
              { key = "n", name = "follows the fight" },
              { key = "f", name = "fixed",
                help = "the whole stage at once, never moving" },
              { key = "a", name = "angled",
                help = "looking down on the stage from higher up" },
          } },

        { key = "t", name = "Teammates",
          help = "only read in sides: friendly hits and shared stocks",
          shownIf = function()
              local modes = OF.gamemodes
              return modes.wantSides == true
          end,
          choices = {
              { key = "n", name = "cannot hit each other",
                help = "teammates pass through each other's hits" },
              { key = "a", name = "team attack",
                help = "teammates hit each other for half" },
              { key = "s", name = "share stocks",
                help = "out? A and B together borrow a teammate's stock" },
              { key = "b", name = "both",
                help = "team attack, and stocks shared" },
          } },

        { key = "d", name = "Shield and dodges",
          help = "Z standing shields; flick the stick from it to dodge",
          choices = {
              { key = "y", name = "on" },
              { key = "n", name = "off",
                help = "Z crouches and ground pounds, as before" },
          } },

        { key = "vamp", name = "Vampire",
          help = "what landing a hit does for you",
          choices = {
              { key = "off", name = "off",
                help = "a hit takes nothing off your percent" },
              { key = "on", name = "on",
                help = "a landed hit takes a little percent off" },
          } },

        { key = "rag", name = "Knocked players go limp",
          help = "a hit throws the player as a ragdoll",
          choices = {
              { key = "off", name = "no",
                help = "the game's own tumble, as this mode shipped" },
              { key = "on", name = "yes - a ragdoll",
                help = "launched players fly limp and get up where they land" },
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

function mode.may_attack(attacker, victim)
    return parts("may_attack", attacker, victim)
end

function mode.friendlyFire()
    local said = OF.gamemodes.option_now("t")
    return said == "a" or said == "b"
end

function mode.ragdollOnKnock()
    return OF.gamemodes.option_now("rag") == "on"
end

function mode.terms()

    local flat = ""
    local rule = OF.gamemodes.option_showing("smash", "rule")
    if rule == "turbo" then
        local said = OF.gamemodes.option_showing("smash", "hp")
        return OF.lang.fill("turbo - @ hit points, @ stocks each",
            tostring(HP_STOPS[said] or HP_DEFAULT),
            tostring(STOCK_STOPS[OF.gamemodes.option_showing("smash", "lv")]
                or STOCKS_DEFAULT)) .. flat
    end
    if rule == "hp" then
        local said = OF.gamemodes.option_showing("smash", "hp")
        return OF.lang.fill("stamina - @ hit points, @ stocks each",
            tostring(HP_STOPS[said] or HP_DEFAULT),
            tostring(STOCK_STOPS[OF.gamemodes.option_showing("smash", "lv")]
                or STOCKS_DEFAULT)) .. flat
    end
    if rule == "stock" then
        local said = OF.gamemodes.option_showing("smash", "lv")
        return OF.lang.fill("@ stocks each",
            tostring(STOCK_STOPS[said] or STOCKS_DEFAULT)) .. flat
    end
    local said = OF.gamemodes.option_showing("smash", "min")
    if rule == "coin" then
        return OF.lang.fill("most coins in @ minutes",
            tostring(TIME_STOPS[said] or MINUTES_DEFAULT)) .. flat
    end
    return OF.lang.fill("most KOs in @ minutes",
        tostring(TIME_STOPS[said] or MINUTES_DEFAULT)) .. flat
end

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_FIGHT)
    end

    OF.util.report(OF.rules.lend("interactions", "smash",
        PLAYER_INTERACTIONS_PVP))

    OF.util.report(OF.rules.lend("knockback", "smash", ROUND_KNOCKBACK))

    OF.util.report(OF.rules.lend("bubble", "smash", 0))

    if gGlobalSyncTable[SD_KEY_NAME] ~= nil and gGlobalSyncTable[SD_KEY_NAME] ~= "" then
        OF.util.publish(SD_KEY_NAME, "")
    end

    if tonumber(options.limit) == nil then
        OF.util.publish("ofGmLimit", minutes_wanted(#players) * 60)
    end
end

function mode.late_join(localIndex)

    if sd_on() then return ROLE_OUT end
    return ROLE_FIGHT
end

local function deal_myself()
    dealt = true
    lost = 0
    stocks = on_stocks() and stocks_left() or 0

    placeDue = flat_asked() and FLAT_PLACE_WINDOW or 0
    if OF.gamemodes.role(0) ~= ROLE_FIGHT then return end

    percent = OF.gm_smash_start_percent()
    OF.util.publish_row(0, PCT_KEY, percent)
    OF.util.publish_row(0, KO_KEY, 0)
    OF.util.publish_row(0, "ofScore", on_stocks() and stocks or 0)
end

function mode.death_place(diedAt)
    local np = gNetworkPlayers[0]
    if np == nil then return nil end
    local level = diedAt ~= nil and diedAt.level or np.currLevelNum
    local area = diedAt ~= nil and diedAt.area or np.currAreaIndex
    local stage = STAGE.of(level, area)
    if stage == nil or not stage.lane then return nil end
    local slot, count = STAGE.my_slot()
    local point = STAGE.spawn(stage, slot or 0, math.max(1, count))
    if point == nil then return nil end
    return { level = level, area = area, x = point.x, y = point.y, z = stage.z }
end

function mode.on_start()
    percent = 0
    kos = 0
    grace = 0
    hitBy = -1
    hitAgo = 0

    fallSeq = 0
    fallClaimed = false
    hitstun = 0
    lastKb = 0
    turboLeft = 0
    turboFrom = nil
    lastEdge = nil
    seenFall = {}
    deal_myself()
    parts("on_start")

end

function mode.cleanup()

    OF.rules.give_back("interactions", "smash")
    OF.rules.give_back("knockback", "smash")
    OF.rules.give_back("bubble", "smash")

    percent = 0
    stocks = 0
    lost = 0
    kos = 0
    grace = 0
    hitBy = -1
    hitAgo = 0
    fallSeq = 0
    fallClaimed = false
    hitstun = 0
    lastKb = 0
    turboLeft = 0
    turboFrom = nil
    lastEdge = nil

    if cam_let_go ~= nil then cam_let_go() end

    if leave_the_moveset ~= nil then leave_the_moveset() end
    if leave_sudden_death ~= nil then leave_sudden_death() end

    parts("cleanup")

    dealt = false

    placeDue = 0

    seenFall = {}
end

local FULL_HEALTH = 0x880

local function hold_the_meter()
    if OF.gamemodes.role(0) ~= ROLE_FIGHT then return end
    if not OF.util.can_play(0) then return end
    local m = gMarioStates[0]
    if m == nil then return end
    if (m.health or 0) < FULL_HEALTH then m.health = FULL_HEALTH end
    m.hurtCounter = 0
    if m.pos ~= nil then m.peakHeight = m.pos.y end
end

local function steer_the_air(m)
    if m == nil or m.action == nil then return end
    if not OF.util.has_flag(m.action, ACT_FLAG_AIR) then return end
    if (m.knockbackTimer or 0) ~= 0 then return end
    local mag = (tonumber(m.intendedMag) or 0) / 32
    if mag <= 0 then return end
    if mag > 1 then mag = 1 end

    local dYaw = (m.intendedYaw or 0) - (m.faceAngle.y or 0)
    m.forwardVel = (m.forwardVel or 0) + AIR_STEER * mag * coss(dYaw)
    m.faceAngle.y = m.faceAngle.y + AIR_TURN * mag * sins(dYaw)
end

local function hold_the_camera(m)
    if OF.util.asks(OF.input, "poll") then OF.input.poll(m) end
    OF.input.take(m, L_CBUTTONS)
    OF.input.take(m, R_CBUTTONS)

    if OF.util.binding("center_rom_hack_camera") == nil then return end
    local was = m.intendedYaw

    local stage = STAGE.here()
    m.intendedYaw = (stage ~= nil and stage.side == -1) and 0 or FLAT_SEED_YAW
    OF.util.optional("center_rom_hack_camera", nil)
    m.intendedYaw = was
end

local function flatten_the_stick(m)
    local c = m.controller
    if c == nil then return end

    if OF.util.menu_has_screen() then return end
    c.stickY = 0
    local x = tonumber(c.stickX) or 0
    if x < 0 then x = -x end
    c.stickMag = x
end

local function hold_the_line(m)
    local z = STAGE.z()
    if m.pos ~= nil then m.pos.z = z end
    if m.vel ~= nil then m.vel.z = 0 end
    m.slideVelZ = 0
    if m.marioObj ~= nil then
        m.marioObj.oPosZ = z
        if m.marioObj.header ~= nil and m.marioObj.header.gfx ~= nil
            and m.marioObj.header.gfx.pos ~= nil then
            m.marioObj.header.gfx.pos.z = z
        end
    end
end

function STAGE.my_slot()
    local np = gNetworkPlayers[0]
    if np == nil or type(np.globalIndex) ~= "number" then return nil, 0 end
    local order = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        local other = gNetworkPlayers[entry.localIndex]
        if other ~= nil and type(other.globalIndex) == "number" then
            table.insert(order, other.globalIndex)
        end
    end
    table.sort(order)
    local slot = 0
    for at, globalIndex in ipairs(order) do
        if globalIndex == np.globalIndex then slot = at - 1 end
    end
    return slot, #order
end

local function place_on_the_line()
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return end
    local slot, count = STAGE.my_slot()
    if slot == nil then return end
    local x, y = OF.gm_smash_spawn_x(slot, count)
    m.pos.x = x

    if y ~= nil then
        m.pos.y = y
        if m.vel ~= nil then m.vel.y = 0 end
        m.peakHeight = y
    end
    m.pos.z = STAGE.z()
    if m.vel ~= nil then m.vel.x, m.vel.z = 0, 0 end
    m.forwardVel = 0
    hold_the_line(m)
end

local CAM_PITCH = 0x0800

local CAM_TAN_HALF_FOV = 0.4142

local CAM_MIN_DIST = 1600

local CAM_VIEW_HALF = BLAST_SIDE

local CAM_PAD_X = 700
local CAM_PAD_Y = 500

local CAM_PAN_EASE = 0.12
local CAM_ZOOM_EASE = 0.06

local ENGINE_POS_H, ENGINE_POS_V = 0.3, 0.3
local ENGINE_FOC_H, ENGINE_FOC_V = 0.8, 0.3

local camAt = nil
local camDriving = false

local function cam_aspect()
    local w = tonumber(OF.util.optional("djui_hud_get_screen_width", 0)) or 0
    local h = tonumber(OF.util.optional("djui_hud_get_screen_height", 0)) or 0
    if w <= 0 or h <= 0 then return 16 / 9 end
    return w / h
end

local function cam_max_dist(aspect, viewHalf, far)
    local dist = (viewHalf or CAM_VIEW_HALF) / (CAM_TAN_HALF_FOV * aspect)

    if far ~= nil and dist > far then dist = far end
    if far ~= nil and dist < CAM_MIN_DIST then dist = CAM_MIN_DIST end
    return dist
end

function OF.gm_smash_frame(points, floorY, aspect, stage)
    aspect = tonumber(aspect) or 16 / 9
    floorY = tonumber(floorY) or 0

    local midX = stage ~= nil and (stage.left + stage.right) / 2 or 0
    local viewHalf = stage ~= nil and (stage.right - stage.left) / 2 or CAM_VIEW_HALF
    local minX, maxX, minY, maxY = nil, nil, nil, nil
    for _, p in ipairs(points or {}) do
        local x, y = tonumber(p.x), tonumber(p.y)
        if x ~= nil and y ~= nil then
            minX = minX == nil and x or math.min(minX, x)
            maxX = maxX == nil and x or math.max(maxX, x)
            minY = minY == nil and y or math.min(minY, y)
            maxY = maxY == nil and y or math.max(maxY, y)
        end
    end
    if minX == nil then
        minX, maxX, minY, maxY = 0, 0, floorY, floorY
    end
    local halfW = (maxX - minX) / 2 + CAM_PAD_X
    local halfH = (maxY - minY) / 2 + CAM_PAD_Y
    local dist = math.max(halfW / (CAM_TAN_HALF_FOV * aspect),
                          halfH / CAM_TAN_HALF_FOV)
    local far = cam_max_dist(aspect, viewHalf, stage ~= nil and stage.camFar or nil)
    if dist < CAM_MIN_DIST then dist = CAM_MIN_DIST end
    if dist > far then dist = far end
    local showsHalf = dist * CAM_TAN_HALF_FOV * aspect
    local cx = (minX + maxX) / 2
    local room = viewHalf - showsHalf
    if room < 0 then room = 0 end
    if cx > midX + room then cx = midX + room end
    if cx < midX - room then cx = midX - room end

    local cy = (minY + maxY) / 2 + CAM_PAD_Y / 2
    if cy < floorY then cy = floorY end
    return cx, cy, dist, showsHalf
end

local function cam_points()
    local out = {}
    local np0 = gNetworkPlayers[0]
    if np0 == nil then return out end
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_FIGHT)) do
        local m = gMarioStates[entry.localIndex]
        local np = gNetworkPlayers[entry.localIndex]

        if m ~= nil and m.pos ~= nil and np ~= nil
            and (entry.localIndex == 0 or OF.util.same_world(entry.localIndex))
            and OF.util.optional("is_player_active", 1, m) ~= 0 then
            table.insert(out, { x = m.pos.x, y = m.pos.y })
        end
    end
    return out
end

cam_let_go = function()
    if not camDriving then return false end
    camDriving = false
    camAt = nil
    local s = gLakituState
    if s == nil then return false end
    local drags = OF.util.asks(OF.modifiers, "hold_camlag")
        and OF.modifiers.hold_camlag() == true
    if not drags then
        s.posHSpeed, s.posVSpeed = ENGINE_POS_H, ENGINE_POS_V
        s.focHSpeed, s.focVSpeed = ENGINE_FOC_H, ENGINE_FOC_V
    end
    OF.util.optional("skip_camera_interpolation", nil)
    return true
end

local function cam_put(vec, x, y, z)
    if vec == nil then return end
    vec.x, vec.y, vec.z = x, y, z
end

local function hold_the_smash_camera()
    local s = gLakituState
    local np0 = gNetworkPlayers[0]
    local box = np0 ~= nil and STAGE.here() or nil
    local want = s ~= nil and s.pos ~= nil and box ~= nil
        and OF.gamemodes.state() == OF.gamemodes.ACTIVE
        and OF.gamemodes.role(0) == ROLE_FIGHT and OF.util.can_play(0)
        and flat_on() and OF.util.hands_on() == nil
    if not want then
        cam_let_go()
        return
    end

    local aspect = cam_aspect()
    local cx, cy, dist = OF.gm_smash_frame(cam_points(), box.y, aspect, box)

    local style = OF.gamemodes.option_now("c")
    local pitch = CAM_PITCH
    if style == "f" then
        cx, cy = (box.left + box.right) / 2, box.y + CAM_PAD_Y
        dist = cam_max_dist(aspect, (box.right - box.left) / 2, box.camFar)
    elseif style == "a" then
        pitch = CAM_PITCH * 3
    end
    if camAt == nil then
        camAt = { x = cx, y = cy, dist = dist }
        OF.util.optional("skip_camera_interpolation", nil)
    else
        camAt.x = camAt.x + (cx - camAt.x) * CAM_PAN_EASE
        camAt.y = camAt.y + (cy - camAt.y) * CAM_PAN_EASE
        camAt.dist = camAt.dist + (dist - camAt.dist) * CAM_ZOOM_EASE
    end

    local fx, fy, fz = camAt.x, camAt.y, box.z
    local px = fx
    local py = fy + camAt.dist * sins(pitch)
    local pz = fz + (box.side or 1) * camAt.dist * coss(pitch)
    cam_put(s.pos, px, py, pz)
    cam_put(s.curPos, px, py, pz)
    cam_put(s.goalPos, px, py, pz)
    cam_put(s.focus, fx, fy, fz)
    cam_put(s.curFocus, fx, fy, fz)
    cam_put(s.goalFocus, fx, fy, fz)
    s.posHSpeed, s.posVSpeed = 0, 0
    s.focHSpeed, s.focVSpeed = 0, 0

    s.yaw = atan2s(pz - fz, px - fx)
    camDriving = true
end

function OF.gm_smash_camera()
    return { driving = camDriving,
             x = camAt and camAt.x or nil, y = camAt and camAt.y or nil,
             dist = camAt and camAt.dist or nil,
             minDist = CAM_MIN_DIST, maxDist = cam_max_dist(cam_aspect()),
             side = (STAGE.here() or {}).side,
             viewHalf = CAM_VIEW_HALF, sideLine = BLAST_SIDE,
             topLine = BLAST_TOP, dropLine = WRAP_DROP }
end

local AIR_KB_FOR = {}
local BACKWARD_KB = {}
local function kb_pair(ground, air, backward)
    if ground == nil or air == nil then return end
    AIR_KB_FOR[ground] = air
    if backward then BACKWARD_KB[ground] = true BACKWARD_KB[air] = true end
end
kb_pair(ACT_SOFT_BACKWARD_GROUND_KB, ACT_BACKWARD_AIR_KB, true)
kb_pair(ACT_BACKWARD_GROUND_KB, ACT_BACKWARD_AIR_KB, true)
kb_pair(ACT_HARD_BACKWARD_GROUND_KB, ACT_HARD_BACKWARD_AIR_KB, true)
kb_pair(ACT_SOFT_FORWARD_GROUND_KB, ACT_FORWARD_AIR_KB, false)
kb_pair(ACT_FORWARD_GROUND_KB, ACT_FORWARD_AIR_KB, false)
kb_pair(ACT_HARD_FORWARD_GROUND_KB, ACT_HARD_FORWARD_AIR_KB, false)
if ACT_BACKWARD_AIR_KB ~= nil then BACKWARD_KB[ACT_BACKWARD_AIR_KB] = true end
if ACT_HARD_BACKWARD_AIR_KB ~= nil then BACKWARD_KB[ACT_HARD_BACKWARD_AIR_KB] = true end

function OF.gm_smash_hit_of(attacker)
    if attacker == nil then return "punch", MOVES.punch.d end
    local kind = OF.gm_smash_attack_kind(attacker.action, attacker.actionArg)
    if MOVES[kind] == nil then
        kind = OF.util.has_flag(attacker.flags or 0, MARIO_KICKING or 0x00200000)
            and "kick" or "punch"
    end

    local carried = parts("hit_kind", attacker, kind)
    if carried ~= nil and MOVES[carried] ~= nil then kind = carried end
    local d = MOVES[kind].d
    if kind == "smash" then
        d = d * (1 + SMASH_CHARGE_BONUS * OF.gm_smash_charge_share(attacker.actionArg))
    end
    if OF.util.has_flag(attacker.flags or 0, MARIO_METAL_CAP or 0x00000004) then
        d = d * METAL_DAMAGE
    end
    return kind, d
end

launch_the_victim = function(attacker, victim, kind, percentAfter, damage)
    if victim == nil or victim.vel == nil or attacker == nil then return nil end
    if OF.util.has_flag(victim.action or 0, ACT_FLAG_SWIMMING or 0x00002000)
        or OF.util.has_flag(victim.action or 0, ACT_FLAG_METAL_WATER or 0x00004000) then
        return nil
    end
    local move = OF.gm_smash_move(kind)
    local weight = OF.gm_smash_weight()
    local kb
    if on_hp() then
        kb = OF.gm_smash_kb(kind, turbo_at(), weight, damage)
    else
        kb = OF.gm_smash_kb(kind, percentAfter, weight, damage)
    end
    local speed = OF.gm_smash_speed(kb)

    local yaw = 0
    if attacker.faceAngle ~= nil then yaw = attacker.faceAngle.y or 0 end
    if move.away and victim.pos ~= nil and attacker.pos ~= nil then
        local dx = victim.pos.x - attacker.pos.x
        local dz = victim.pos.z - attacker.pos.z
        if dx * dx + dz * dz > 1 then yaw = atan2s(dz, dx) end
    end

    local air = AIR_KB_FOR[victim.action]
    local grounded = air ~= nil
        or not OF.util.has_flag(victim.action or 0, ACT_FLAG_AIR)
    local angle = OF.gm_smash_angle(kind, kb, grounded)
    local across, up = speed, 0
    if angle ~= nil then
        local r = math.rad(angle)
        across, up = speed * math.cos(r), speed * math.sin(r)
        if air ~= nil then
            OF.util.optional("set_mario_action", nil, victim, air, victim.actionArg or 0)
        end
    end
    victim.vel.x = across * sins(yaw)
    victim.vel.z = across * coss(yaw)
    victim.vel.y = up
    victim.slideVelX, victim.slideVelZ = victim.vel.x, victim.vel.z

    victim.forwardVel = BACKWARD_KB[victim.action] and -across or across

    if move.turn and victim.faceAngle ~= nil then
        local yaw2 = (victim.faceAngle.y or 0) + 0x8000
        if yaw2 > 0x7FFF then yaw2 = yaw2 - 0x10000 end
        victim.faceAngle.y = yaw2
    end
    return kb
end

local function on_pvp_attack(attacker, victim, interaction)
    if attacker == nil or attacker.marioObj == nil then return end
    if OF.gamemodes.current() ~= mode then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    if victim ~= nil and victim.playerIndex == 0
        and OF.gamemodes.role(0) == ROLE_FIGHT

        and grace <= 0 then

        local kind, damage = OF.gm_smash_hit_of(attacker)

        damage = damage * (tonumber(parts("damage_scale", attacker, victim)) or 1)

        damage = damage * (tonumber(parts("taken_scale", kind)) or 1)
        percent = math.min(PERCENT_CAP, percent + damage)
        OF.util.publish_row(0, PCT_KEY, percent)

        local kb = launch_the_victim(attacker, victim, kind, percent, damage)
        if kb == nil then

            local scale = 1 + percent / 100
            if victim.vel ~= nil then
                victim.vel.x = victim.vel.x * scale
                victim.vel.y = victim.vel.y * scale
                victim.vel.z = victim.vel.z * scale
            end
            victim.forwardVel = (victim.forwardVel or 0) * scale
            victim.slideVelX = (victim.slideVelX or 0) * scale
            victim.slideVelZ = (victim.slideVelZ or 0) * scale
        else

            hitstun = OF.gm_smash_hitstun(kb)
            lastKb = kb
        end

        if flat_on() and victim.vel ~= nil then
            local awayX = 0
            if victim.pos ~= nil and attacker.pos ~= nil then
                awayX = victim.pos.x - attacker.pos.x
            end
            local vx, vz = OF.gm_smash_along_line(victim.vel.x, victim.vel.z,
                awayX)
            victim.vel.x, victim.vel.z = vx, vz
            local sx, sz = OF.gm_smash_along_line(victim.slideVelX,
                victim.slideVelZ, awayX)
            victim.slideVelX, victim.slideVelZ = sx, sz
        end

        local np = gNetworkPlayers[attacker.playerIndex]
        if np ~= nil and np.connected and type(np.globalIndex) == "number" then
            hitBy = np.globalIndex
            hitAgo = 0
        end

        parts("hit_taken", damage, hitBy)

        if on_hp() and hp_from(percent) <= 0 then
            knock_out(victim, "hp")
        end
    end

    if on_turbo() and attacker.playerIndex == 0
        and OF.gamemodes.role(0) == ROLE_FIGHT then
        turboLeft = TURBO_WINDOW
        turboFrom = OF.gm_smash_attack_kind(attacker.action, attacker.actionArg)
    end

    if OF.gamemodes.role(0) == ROLE_FIGHT and grace <= 0
        and OF.laststanding.vampire_lands(mode, attacker) then
        percent = math.max(0, percent - VAMPIRE_PCT_RELIEF)
        OF.util.publish_row(0, PCT_KEY, percent)
    end
end

hook_event(HOOK_ON_PVP_ATTACK, on_pvp_attack)

local function claim_the_fall()
    local function fell(sub)
        if not OF.util.asks(OF.hud, "banner") then return nil end

        return OF.hud.banner("out", OF.lang.t("FALL"), sub, { quiet = true })
    end
    fallClaimed = true
    fallSeq = fallSeq + 1

    local killer = hitBy
    local np = gNetworkPlayers[0]
    if np ~= nil and killer == np.globalIndex then killer = -1 end

    OF.util.publish_row(0, FALL_KEY,
        tostring(killer) .. ":" .. tostring(fallSeq))

    percent = OF.gm_smash_start_percent()
    hitBy = -1
    hitAgo = 0
    grace = RESPAWN_GRACE
    hitstun = 0
    OF.util.publish_row(0, PCT_KEY, percent)

    OF.gamemodes.give_full_health()

    parts("stock_lost", killer)

    if on_coins() then

        local held = math.max(0, score_of(0))
        local cost = math.min(100, math.floor(held / 2))
        OF.util.publish_row(0, "ofScore", held - cost)
        fell(OF.lang.plural(cost, "1 coin gone", "@ coins gone"))
        if sd_on() then
            OF.gamemodes.set_role(0, ROLE_OUT)
            OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
        end
        return
    end

    if not on_stocks() then

        OF.util.publish_row(0, "ofScore", score_of(0) - 1)
        fell(OF.lang.t("A fall costs a point"))

        if sd_on() then
            OF.gamemodes.set_role(0, ROLE_OUT)
            OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
        end
        return
    end

    lost = lost + 1
    stocks = stocks_left()
    OF.util.publish_row(0, "ofScore", stocks)
    if stocks > 0 then
        fell(OF.lang.plural(stocks, "1 stock left", "@ stocks left"))

        OF.gamemodes.cue("bad")
        return
    end

    OF.gamemodes.set_role(0, ROLE_OUT)

    OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())

end

function OF.gm_smash_edge(x, y, z, level, area)
    local box = STAGE.of(level, area)
    if box == nil then return nil end
    x, y, z = tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0
    local up = nil

    local bottom = OF.gm_smash_lava_line(level) or box.wrapBottom
    if box.lane then bottom = box.koBottom end
    if y > box.top then
        up = "top"
    elseif bottom ~= nil and y < bottom then
        up = "bottom"
    end
    local side = nil
    if x > box.right then
        side = "right"
    elseif x < box.left then
        side = "left"
    end
    if up ~= nil and side ~= nil then return up .. "-" .. side end
    return up or side
end

local function my_box()
    local np = gNetworkPlayers[0]
    if np == nil then return nil, nil end
    return STAGE.here(), np.currLevelNum, np.currAreaIndex
end

knock_out = function(m, edge)
    if fallClaimed or grace > 0 then return false end
    lastEdge = edge
    if OF.util.asks(OF.gamemodes, "mark_died_inside") then
        OF.gamemodes.mark_died_inside()
    end
    claim_the_fall()
    local left = OF.util.optional("level_trigger_warp", 0, m, WARP_OP_WARP_FLOOR)

    if left == 20 and OF.gamemodes.hears_round() then
        play_character_sound(m, CHAR_SOUND_WAAAOOOW)
    end

    if left ~= 0 and ACT_DISAPPEARED ~= nil and m ~= nil then
        set_mario_action(m, ACT_DISAPPEARED, 0)
    end
    return true
end

local function wrap_across(m, edge, box)
    if m == nil or m.pos == nil or box == nil then return end
    lastEdge = edge
    local left, right = box.left, box.right

    local top, bottom = box.top, box.wrapBottom or (box.y - WRAP_DROP)
    local width, span = right - left, top - bottom

    if m.pos.x > right then
        m.pos.x = m.pos.x - width
    elseif m.pos.x < left then
        m.pos.x = m.pos.x + width
    end
    if m.pos.y > top then
        m.pos.y = m.pos.y - span
    elseif m.pos.y < bottom then
        m.pos.y = m.pos.y + span
    elseif edge == "bottom" then

        m.pos.y = top - 1
    end
    m.peakHeight = m.pos.y
    if m.marioObj ~= nil then
        m.marioObj.oPosX, m.marioObj.oPosY, m.marioObj.oPosZ =
            m.pos.x, m.pos.y, m.pos.z
        if m.marioObj.header ~= nil and m.marioObj.header.gfx ~= nil
            and m.marioObj.header.gfx.pos ~= nil then
            local g = m.marioObj.header.gfx.pos
            g.x, g.y, g.z = m.pos.x, m.pos.y, m.pos.z
        end
    end
end

local function cross_the_edge(m, edge, box)
    if box ~= nil and box.lane and box.wrapBottom == nil
        and string.find(edge, "top", 1, true) ~= nil then
        knock_out(m, edge)
        return "ko"
    end
    if not edges_wrap() then
        knock_out(m, edge)
        return "ko"
    end
    if on_hp() then
        wrap_across(m, edge, box)
        percent = math.min(PERCENT_CAP, percent + percent_for_hp(WRAP_HP_COST))
        OF.util.publish_row(0, PCT_KEY, percent)
        if hp_from(percent) <= 0 then
            knock_out(m, edge)
            return "ko"
        end
        return "wrap"
    end
    if (m.knockbackTimer or 0) > 0 then
        knock_out(m, edge)
        return "ko"
    end
    wrap_across(m, edge, box)
    return "wrap"
end

local function watch_the_edges(m)
    if m == nil or m.pos == nil then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if fallClaimed then return end
    local box, level, area = my_box()
    if box == nil then return end
    local edge = OF.gm_smash_edge(m.pos.x, m.pos.y, m.pos.z, level, area)
    if edge == nil then return end

    if edge == "bottom" and not edges_wrap() and not box.lane
        and OF.gm_smash_lava_line(level) == nil then
        return
    end
    cross_the_edge(m, edge, box)
end

local function on_death(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if OF.gamemodes.current() ~= mode then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if OF.gamemodes.role(0) ~= ROLE_FIGHT then return end
    if not OF.util.can_play(0) then return end
    if fallClaimed then return end

    local box = my_box()
    if edges_wrap() and box ~= nil then
        if m.vel ~= nil and (m.vel.y or 0) > 0 then return false end
        if cross_the_edge(m, "bottom", box) == "wrap" then return false end
        return
    end

    if grace > 0 then return end
    lastEdge = "bottom"
    claim_the_fall()
end

hook_event(HOOK_ON_DEATH, on_death)

local function watch_for_the_respawn(m)
    if not fallClaimed then return end
    if m == nil or m.action == nil then return end
    if OF.util.has_flag(m.action, ACT_FLAG_AIR) then return end
    fallClaimed = false
end

local function read_the_claims()
    local np = gNetworkPlayers[0]
    if np == nil or type(np.globalIndex) ~= "number" then return end

    for _, entry in ipairs(OF.util.connected_players()) do
        local who = entry.localIndex
        if who ~= 0 then
            local row = gPlayerSyncTable[who]
            local said = row ~= nil and row[FALL_KEY] or nil
            if type(said) == "string" then
                local killer, count = string.match(said, "^(-?%d+):(%d+)$")
                killer = tonumber(killer)
                count = tonumber(count)
                if killer ~= nil and count ~= nil then
                    if seenFall[who] == nil then
                        seenFall[who] = count
                    elseif count > seenFall[who] then
                        seenFall[who] = count
                        if killer == np.globalIndex then
                            kos = kos + 1
                            OF.util.publish_row(0, KO_KEY, kos)

                            if not on_stocks() and not on_coins() then
                                OF.util.publish_row(0, "ofScore",
                                    score_of(0) + 1)
                            end
                            if OF.util.asks(OF.hud, "banner") then
                                OF.hud.banner("medal", OF.lang.t("KO!"), nil, { tone = "good" })
                            end

                            OF.gamemodes.cue("good")
                        end
                    end
                end
            end
        end
    end
end

function mode.update()
    if OF.gamemodes.state() == OF.gamemodes.ACTIVE then hold_the_meter() end

    if am_out() then return end
    if OF.gamemodes.role(0) ~= ROLE_FIGHT then return end

    if not dealt then deal_myself() end

    if on_stocks() then
        stocks = stocks_left()
        if score_of(0) ~= stocks then OF.util.publish_row(0, "ofScore", stocks) end
    end

    local m = gMarioStates[0]
    if m == nil then return end

    if placeDue > 0 then
        placeDue = placeDue - 1
        if flat_on() then
            placeDue = 0
            place_on_the_line()
        elseif placeDue == 0 then

            OF.notify.show("This stage has not been measured - no line to fight on",
                "warn", 6)
        end
    end

    parts("update", m)
    steer_the_air(m)
    watch_for_the_respawn(m)

    if flat_on() then hold_the_line(m) end

    watch_the_edges(m)
end

function OF.gm_smash_attack_kind(action, actionArg)
    if action == ACT_PUNCHING or action == ACT_MOVE_PUNCHING then
        if (tonumber(actionArg) or 0) >= 6 then return "kick" end
        return "punch"
    end
    if action == ACT_JUMP_KICK then return "jumpkick" end

    if action ~= nil then
        if action == SM_UPPUNCH then return "uppunch" end
        if action == SM_TORNADO then return "tornado" end
        if action == SM_SWING then return OF.gm_smash_swing_kind(actionArg) end
    end
    if action == ACT_DIVE or action == ACT_DIVE_SLIDE then return "dive" end
    if action == ACT_GROUND_POUND then return "pound" end

    if action == ACT_GROUND_POUND_LAND then return "poundland" end
    if action == ACT_SLIDE_KICK or action == ACT_SLIDE_KICK_SLIDE then
        return "slidekick"
    end
    return tostring(action)
end

local function spend_the_turbo(m)
    if turboLeft <= 0 then return end
    turboLeft = turboLeft - 1
    if (m.knockbackTimer or 0) ~= 0 then
        turboLeft = 0
        return
    end
    local c = m.controller
    if c == nil then return end
    local pressed = tonumber(c.buttonPressed) or 0
    local air = OF.util.has_flag(m.action or 0, ACT_FLAG_AIR)

    local nextAction, arg = nil, 0
    if OF.util.has_flag(pressed, B_BUTTON) then
        if air then
            nextAction = turboFrom == "jumpkick" and ACT_DIVE or ACT_JUMP_KICK
        else
            nextAction = ACT_PUNCHING
            if turboFrom == "punch" then arg = 6 end
        end
    elseif OF.util.has_flag(pressed, Z_TRIG) and air and turboFrom ~= "pound" then
        nextAction = ACT_GROUND_POUND
    elseif OF.util.has_flag(pressed, A_BUTTON) then
        nextAction = air and ACT_DOUBLE_JUMP or ACT_JUMP
    end
    if nextAction == nil then return end

    if OF.gm_smash_attack_kind(nextAction, arg) == turboFrom then return end

    turboLeft = 0
    turboFrom = nil
    set_mario_action(m, nextAction, arg)
end

local AIR_KB_ACTIONS = {}
for _, act in ipairs({ ACT_BACKWARD_AIR_KB, ACT_FORWARD_AIR_KB,
                       ACT_HARD_BACKWARD_AIR_KB, ACT_HARD_FORWARD_AIR_KB }) do
    if act ~= nil then AIR_KB_ACTIONS[act] = true end
end

local moves_refreshed
local function come_out_of_hitstun(m)
    if hitstun <= 0 then return false end
    if not AIR_KB_ACTIONS[m.action] then

        hitstun = 0
        return false
    end
    hitstun = hitstun - 1
    if hitstun > 0 then return false end
    local vx, vy, vz = m.vel.x or 0, m.vel.y or 0, m.vel.z or 0
    local across = math.sqrt(vx * vx + vz * vz)
    if across > 1 then m.faceAngle.y = atan2s(vz, vx) end
    set_mario_action(m, ACT_FREEFALL, 0)
    m.forwardVel = across
    m.vel.x, m.vel.y, m.vel.z = vx, vy, vz
    if moves_refreshed ~= nil then moves_refreshed() end
    return true
end

do

local MV = {

    MOVE_STICK = 40,

    SMASH_NEUTRAL = 24,
    SMASH_FLICK = 4,

    SWING_FRAMES = 14,
    SWING_HIT_FROM = 2,
    SWING_HIT_TO = 6,

    UPPUNCH_RISE = 72,
    UPPUNCH_FRAMES = 19,
    UPPUNCH_BUNNY = 1.3,

    TORNADO_FRAMES = 40,
    TORNADO_SPEED = 24,
    TORNADO_HOP = 20,
    TORNADO_LIFT = 14,
    TORNADO_LIFTS = 4,
    TORNADO_FALL = 12,
    TORNADO_SPIN = 0x2000,

    ANIM_RISE = MARIO_ANIM_DOUBLE_JUMP_RISE or 0x50,
    ANIM_KICK = MARIO_ANIM_GROUND_KICK or 0x66,
    ANIM_TWIRL = MARIO_ANIM_TWIRL or 0x94,
    ANIM_CROUCH = MARIO_ANIM_CROUCHING or 0x98,
    SPARKLES = PARTICLE_SPARKLES or (1 << 3),
}

local ms = {
    airJumpUsed = false,
    upUsed = false,
    spinUsed = false,
    helpless = false,
    tornadoLifts = 0,
    stickAway = 99,

    stickUpAway = 99,
    wasUp = false,
}

moves_refreshed = function()
    ms.airJumpUsed = false
    ms.upUsed = false
    ms.spinUsed = false
    ms.helpless = false
    ms.tornadoLifts = 0
end

local OUR_ACTIONS = {}
for _, act in ipairs({ SM_UPPUNCH, SM_TORNADO, SM_CHARGE, SM_SWING }) do
    if act ~= nil then OUR_ACTIONS[act] = true end
end

local AIR_JUMP_FROM = {}
for _, act in ipairs({ ACT_JUMP, ACT_DOUBLE_JUMP, ACT_TRIPLE_JUMP,
                       ACT_FREEFALL, ACT_SIDE_FLIP, ACT_BACKFLIP,
                       ACT_LONG_JUMP, ACT_WALL_KICK_AIR }) do
    if act ~= nil then AIR_JUMP_FROM[act] = true end
end

local function busy(m)
    local act = m.action or 0
    if hitstun > 0 or AIR_KB_ACTIONS[act] or AIR_KB_FOR[act] ~= nil then
        return true
    end
    if OUR_ACTIONS[act] then return true end
    if OF.util.has_flag(act, FLAG_ATTACKING) then return true end
    if m.heldObj ~= nil then return true end
    if OF.util.has_flag(act, ACT_FLAG_SWIMMING or 0x00002000) then return true end
    if OF.util.has_flag(act, ACT_FLAG_INTANGIBLE or 0x80000000) then return true end
    local group = act & (ACT_GROUP_MASK or 0x1C0)
    if group == (ACT_GROUP_CUTSCENE or 0x100)
        or group == (ACT_GROUP_AUTOMATIC or 0x140) then
        return true
    end
    return false
end

local function stick_yaw(m, sx, sy)
    local camYaw = 0
    if m.area ~= nil and m.area.camera ~= nil then camYaw = m.area.camera.yaw or 0 end
    return atan2s(-sy, sx) + camYaw
end

read_the_moveset = function(m)
    local c = m.controller
    if c == nil or m.action == nil then return nil end
    local sx = tonumber(c.stickX) or 0
    local sy = tonumber(c.stickY) or 0
    if math.abs(sx) < MV.SMASH_NEUTRAL then ms.stickAway = 0
    elseif ms.stickAway < 99 then ms.stickAway = ms.stickAway + 1 end
    if math.abs(sy) < MV.SMASH_NEUTRAL then ms.stickUpAway = 0
    elseif ms.stickUpAway < 99 then ms.stickUpAway = ms.stickUpAway + 1 end

    local upNow = sy >= MV.MOVE_STICK and sy >= math.abs(sx)
    local flickedUp = upNow and not ms.wasUp and ms.stickUpAway <= MV.SMASH_FLICK
    ms.wasUp = upNow

    local air = OF.util.has_flag(m.action, FLAG_AIR)
    if not air and not AIR_KB_FOR[m.action] then moves_refreshed() end

    local pressed = tonumber(c.buttonPressed) or 0

    if ms.helpless and air then
        if OF.util.asks(OF.input, "poll") then OF.input.poll(m) end
        OF.input.take(m, B_BUTTON)
        OF.input.take(m, Z_TRIG)

        if OF.util.has_flag(c.buttonPressed or 0, A_BUTTON) then
            c.buttonPressed = c.buttonPressed - A_BUTTON
        end
        return nil
    end
    if busy(m) then return nil end

    local up = upNow
    local down = sy <= -MV.MOVE_STICK and -sy >= math.abs(sx)
    local group = m.action & (ACT_GROUP_MASK or 0x1C0)
    local flat = flat_on()

    local side = math.abs(sx) >= MV.MOVE_STICK and math.abs(sx) > math.abs(sy)
    if OF.util.has_flag(pressed, B_BUTTON) and side and not air and SM_SWING ~= nil
        and (group == (ACT_GROUP_STATIONARY or 0) or group == (ACT_GROUP_MOVING or 0x40)) then
        if OF.util.asks(OF.input, "poll") then OF.input.poll(m) end
        OF.input.take(m, B_BUTTON)
        m.faceAngle.y = stick_yaw(m, sx, 0)
        set_mario_action(m, SM_SWING, 300)
        return SM_SWING
    end

    local upSmash = up and ms.stickUpAway <= MV.SMASH_FLICK
    local downSmash = down and ms.stickUpAway <= MV.SMASH_FLICK
    if OF.util.has_flag(pressed, A_BUTTON) and not air and SM_CHARGE ~= nil
        and (upSmash or downSmash)
        and (group == (ACT_GROUP_STATIONARY or 0) or group == (ACT_GROUP_MOVING or 0x40)) then
        if OF.util.asks(OF.input, "poll") then OF.input.poll(m) end
        OF.input.take(m, A_BUTTON)
        set_mario_action(m, SM_CHARGE, upSmash and 1 or 2)
        return SM_CHARGE
    end

    if OF.util.has_flag(pressed, B_BUTTON) then
        local move = nil
        if up and not ms.upUsed and SM_UPPUNCH ~= nil then
            move = SM_UPPUNCH
            ms.upUsed = true
        elseif down and SM_TORNADO ~= nil and not (air and ms.spinUsed) then
            move = SM_TORNADO
            if air then ms.spinUsed = true end
        end
        if move ~= nil then
            if OF.util.asks(OF.input, "poll") then OF.input.poll(m) end
            OF.input.take(m, B_BUTTON)
            set_mario_action(m, move, air and 0 or 1)
            return move
        end
    end

    if flat and flickedUp then
        if air then
            if not ms.airJumpUsed and AIR_JUMP_FROM[m.action] then
                ms.airJumpUsed = true
                set_mario_action(m, ACT_DOUBLE_JUMP, 0)
                return ACT_DOUBLE_JUMP
            end
        elseif group == (ACT_GROUP_STATIONARY or 0)
            or group == (ACT_GROUP_MOVING or 0x40) then
            set_mario_action(m, ACT_JUMP, 0)
            return ACT_JUMP
        end
    end

    if OF.util.has_flag(pressed, A_BUTTON) then
        if not air and SM_CHARGE ~= nil
            and math.abs(sx) >= MV.MOVE_STICK and ms.stickAway <= MV.SMASH_FLICK
            and (group == (ACT_GROUP_STATIONARY or 0)
                or group == (ACT_GROUP_MOVING or 0x40)) then
            if OF.util.asks(OF.input, "poll") then OF.input.poll(m) end
            OF.input.take(m, A_BUTTON)
            m.faceAngle.y = stick_yaw(m, sx, 0)
            set_mario_action(m, SM_CHARGE, 0)
            return SM_CHARGE
        end
        if air and not ms.airJumpUsed and AIR_JUMP_FROM[m.action] then
            ms.airJumpUsed = true
            set_mario_action(m, ACT_DOUBLE_JUMP, 0)
            return ACT_DOUBLE_JUMP
        end
    end
    return nil
end

local function act_smash_charge(m)
    m.forwardVel = 0
    if m.vel ~= nil then m.vel.x, m.vel.z = 0, 0 end
    OF.util.optional("stationary_ground_step", nil, m)
    OF.util.optional("set_mario_animation", nil, m, MV.ANIM_CROUCH)
    m.particleFlags = (m.particleFlags or 0) | MV.SPARKLES
    m.actionTimer = (m.actionTimer or 0) + 1
    if m.playerIndex ~= 0 then return false end
    local held = m.controller ~= nil
        and OF.util.has_flag(m.controller.buttonDown or 0, A_BUTTON)

    if m.actionTimer >= SMASH_CHARGE_FRAMES or (m.actionTimer > 1 and not held) then

        set_mario_action(m, SM_SWING, math.min(m.actionTimer, SMASH_CHARGE_FRAMES)
            + 100 * math.floor((m.actionArg or 0) % 100))
        return true
    end
    return false
end

local function act_smash_swing(m)
    m.forwardVel = 0
    if m.vel ~= nil then m.vel.x, m.vel.z = 0, 0 end
    OF.util.optional("stationary_ground_step", nil, m)
    OF.util.optional("set_mario_animation", nil, m, MV.ANIM_KICK)
    local t = m.actionTimer or 0
    m.actionTimer = t + 1
    if t == 0 then
        OF.util.optional("play_character_sound", nil, m, CHAR_SOUND_PUNCH_HOO)
    end
    local kind = OF.gm_smash_swing_kind(m.actionArg)
    if t >= MV.SWING_HIT_FROM and t <= MV.SWING_HIT_TO then
        if kind == "cape" then
            m.flags = (m.flags or 0) | (MARIO_PUNCHING or 0x00100000)
        else
            m.flags = (m.flags or 0) | (MARIO_KICKING or 0x00200000)
        end
    end

    if kind == "downsmash" and t == math.floor((MV.SWING_HIT_FROM + MV.SWING_HIT_TO) / 2) then
        local yaw2 = (m.faceAngle.y or 0) + 0x8000
        if yaw2 > 0x7FFF then yaw2 = yaw2 - 0x10000 end
        m.faceAngle.y = yaw2
    end
    if m.playerIndex == 0 and t >= MV.SWING_FRAMES then
        set_mario_action(m, ACT_IDLE, 0)
        return true
    end
    return false
end

local function act_uppunch(m)
    local t = m.actionTimer or 0
    m.actionTimer = t + 1
    if t == 0 then
        m.vel.y = MV.UPPUNCH_RISE
        if OF.gamemodes.option_now("s") == "b" then m.vel.y = m.vel.y * MV.UPPUNCH_BUNNY end
        m.forwardVel = (m.forwardVel or 0) * 0.3
        OF.util.optional("play_character_sound", nil, m, CHAR_SOUND_HOOHOO)
    end
    OF.util.optional("set_mario_animation", nil, m, MV.ANIM_RISE)
    OF.util.optional("update_air_without_turn", nil, m)
    local stepped = OF.util.optional("perform_air_step", nil, m, 0)
    if m.playerIndex ~= 0 then return false end
    if stepped == AIR_STEP_LANDED then
        set_mario_action(m, ACT_FREEFALL_LAND, 0)
        return true
    end
    if stepped == AIR_STEP_GRABBED_LEDGE then
        set_mario_action(m, ACT_LEDGE_GRAB, 0)
        return true
    end
    if (m.vel.y or 0) <= 0 or t >= MV.UPPUNCH_FRAMES then
        ms.helpless = true
        set_mario_action(m, ACT_FREEFALL, 0)
        return true
    end
    return false
end

local function act_tornado(m)
    local t = m.actionTimer or 0
    m.actionTimer = t + 1
    if t == 0 then
        if (m.actionArg or 0) == 1 then m.vel.y = MV.TORNADO_HOP end
        ms.tornadoLifts = 0
        OF.util.optional("play_character_sound", nil, m, CHAR_SOUND_YAHOO)
    end
    OF.util.optional("set_mario_animation", nil, m, MV.ANIM_TWIRL)
    local mag = (tonumber(m.intendedMag) or 0) / 32
    if mag > 1 then mag = 1 end
    if mag > 0.1 then m.faceAngle.y = m.intendedYaw or m.faceAngle.y end
    local want = MV.TORNADO_SPEED * mag
    local fwd = m.forwardVel or 0
    if fwd < want then fwd = math.min(want, fwd + 3) else fwd = math.max(want, fwd - 3) end
    m.forwardVel = fwd
    m.vel.x = fwd * sins(m.faceAngle.y)
    m.vel.z = fwd * coss(m.faceAngle.y)
    if m.playerIndex == 0 and m.controller ~= nil
        and OF.util.has_flag(m.controller.buttonPressed or 0, B_BUTTON)
        and ms.tornadoLifts < MV.TORNADO_LIFTS then
        ms.tornadoLifts = ms.tornadoLifts + 1
        m.vel.y = math.min(2 * MV.TORNADO_LIFT, math.max(m.vel.y or 0, 0) + MV.TORNADO_LIFT)
    end
    local stepped = OF.util.optional("perform_air_step", nil, m, 0)
    if (m.vel.y or 0) < -MV.TORNADO_FALL then m.vel.y = -MV.TORNADO_FALL end
    if stepped == AIR_STEP_LANDED then m.vel.y = 0 end
    local gfx = m.marioObj ~= nil and m.marioObj.header ~= nil
        and m.marioObj.header.gfx or nil
    if gfx ~= nil and gfx.angle ~= nil then
        gfx.angle.y = (m.faceAngle.y or 0) + t * MV.TORNADO_SPIN
    end
    if m.playerIndex ~= 0 then return false end
    if t >= MV.TORNADO_FRAMES then
        if stepped == AIR_STEP_LANDED then
            set_mario_action(m, ACT_FREEFALL_LAND, 0)
        else
            set_mario_action(m, ACT_FREEFALL, 0)
        end
        return true
    end
    return false
end

if SM_CHARGE ~= nil then at_load("hook_mario_action", SM_CHARGE, { every_frame = act_smash_charge }) end
if SM_SWING ~= nil then at_load("hook_mario_action", SM_SWING, { every_frame = act_smash_swing }) end
if SM_UPPUNCH ~= nil then
    at_load("hook_mario_action", SM_UPPUNCH, { every_frame = act_uppunch },
        INT_PUNCH or (1 << 1))
end
if SM_TORNADO ~= nil then
    at_load("hook_mario_action", SM_TORNADO, { every_frame = act_tornado },
        INT_KICK or (1 << 2))
end

function OF.gm_smash_note_stick(m)
    local c = m.controller
    local sx = c ~= nil and (tonumber(c.stickX) or 0) or 0
    local sy = c ~= nil and (tonumber(c.stickY) or 0) or 0
    ms.stickVert = 0
    if math.abs(sy) >= MV.MOVE_STICK and math.abs(sy) >= math.abs(sx) then
        ms.stickVert = sy > 0 and 1 or -1
    end
end

function OF.gm_smash_plain_b(m)
    if (ms.stickVert or 0) ~= 0 then return false end
    if m ~= nil and OUR_ACTIONS[m.action or 0] then return false end
    return true
end

leave_the_moveset = function()
    moves_refreshed()
    ms.stickAway = 99
    local m = gMarioStates[0]
    if m == nil or m.action == nil or not OUR_ACTIONS[m.action] then return false end
    if OF.util.has_flag(m.action, FLAG_AIR) then
        set_mario_action(m, ACT_FREEFALL, 0)
    else
        set_mario_action(m, ACT_IDLE, 0)
    end
    return true
end

function OF.gm_smash_moveset()
    return { uppunch = SM_UPPUNCH, tornado = SM_TORNADO, charge = SM_CHARGE,
             swing = SM_SWING, airJumpUsed = ms.airJumpUsed, upUsed = ms.upUsed,
             spinUsed = ms.spinUsed, helpless = ms.helpless,
             run = { charge = act_smash_charge, swing = act_smash_swing,
                     uppunch = act_uppunch, tornado = act_tornado } }
end
end

function mode.before_mario_update(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if OF.gamemodes.role(0) ~= ROLE_FIGHT then return end
    if not OF.util.can_play(0) then return end

    spend_the_turbo(m)
    come_out_of_hitstun(m)

    OF.gm_smash_note_stick(m)
    if not parts("before_moveset", m) then read_the_moveset(m) end
    if not flat_on() then return end
    hold_the_camera(m)
    flatten_the_stick(m)
end

mode.leadPin = {
    keys = {},
    heard = function(tag, facts)
        if tag == "bombs" and OF.smashitems ~= nil then
            OF.smashitems.toldBombs = math.max(0, math.floor(tonumber(facts.n) or 0))
        end
    end,
}
local BOMBS_TOLD_EVERY = 30
local bombsTold = 0

function mode.scenery()

    if OF.gamemodes.state() == OF.gamemodes.ACTIVE and not OF.util.is_host()
        and OF.gamemodes.room_by_global() ~= nil and OF.gamemodes.asks_the_room()
        and OF.util.asks(OF.smashitems, "bombs") then
        bombsTold = bombsTold + 1
        if bombsTold >= BOMBS_TOLD_EVERY then
            bombsTold = 0
            OF.gamemodes.lead_tell("bombs", { n = #OF.smashitems.bombs() })
        end
    end
    if grace > 0 then grace = grace - 1 end
    if hitBy >= 0 then hitAgo = hitAgo + 1 end

    if OF.gamemodes.state() == OF.gamemodes.ACTIVE then
        read_the_claims()

        enter_sudden_death()
        rain_on_the_line()
        OF.gm_smash_bombs_frame()
    end

    hold_the_smash_camera()

    parts("scenery")
end

local function contenders()
    local list = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_FIGHT)) do
        if OF.util.can_play(entry.localIndex) then
            table.insert(list, entry)
        end
    end
    return list
end

do

local SD = {

    SD_PERCENT = 300,
    SD_SECONDS = 60,

    SD_BOMBS_AFTER = 20 * 30,
    SD_BOMB_EVERY = 25,
    SD_BOMB_MOST = 6,
    SD_BOMB_LEAD = 12,
    SD_BOMB_SPREAD = 120,

    SD_BOMB_LIFE = 450,

    SD_BOMB_MARK = 0x4F460200,
    SD_KEY = SD_KEY_NAME,
}

local sd = {
    seen = false,
    frames = 0,
    bombWait = 0,
}

local function sd_list()
    local said = gGlobalSyncTable[SD.SD_KEY]
    if type(said) ~= "string" or said == "" then return nil end
    local set, any = {}, false
    for g in string.gmatch(said, "%d+") do
        set[tonumber(g)] = true
        any = true
    end
    if not any then return nil end
    return set
end

sd_on = function()
    return sd_list() ~= nil
end

start_sudden_death = function(bestScore)
    if OF.teams.in_play() or on_hp() then return false end
    local tied = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_FIGHT)) do
        if score_of(entry.localIndex) == bestScore and OF.util.can_play(entry.localIndex)
            and entry.np ~= nil and type(entry.np.globalIndex) == "number" then
            table.insert(tied, tostring(entry.np.globalIndex))
        end
    end
    if #tied < 2 then return false end
    OF.util.publish(SD_KEY_NAME, table.concat(tied, ","))
    OF.util.publish("ofGmLimit", (gGlobalSyncTable.ofGmLimit or 0) + SD.SD_SECONDS)
    OF.notify.send_all("Sudden death! The tied fight on at 300%, one life", "warn", 5)
    return true
end

enter_sudden_death = function()
    if sd_list() == nil then
        sd.seen = false
        sd.frames = 0
        return false
    end
    sd.frames = sd.frames + 1
    if sd.seen then return false end
    sd.seen = true
    if OF.gamemodes.role(0) ~= ROLE_FIGHT then return false end
    local np = gNetworkPlayers[0]
    if np ~= nil and sd_list()[np.globalIndex] then
        percent = SD.SD_PERCENT
        OF.util.publish_row(0, PCT_KEY, percent)
        if on_stocks() then
            lost = stocks_wanted() - 1
            stocks = stocks_left()
            OF.util.publish_row(0, "ofScore", stocks)
        end
        OF.notify.show("Sudden death - 300%, one life", "warn", 5)
    else
        OF.gamemodes.set_role(0, ROLE_OUT)
        OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
        OF.notify.show("Sudden death - the tied players fight it out", "info", 5)
    end
    return true
end

local function sd_bombs()
    local found = {}
    if id_bhvBobomb == nil then return found end
    local o = OF.util.optional("obj_get_first_with_behavior_id", nil, id_bhvBobomb)
    local guard = 0
    while o ~= nil and guard < 512 do
        guard = guard + 1
        local ok, mark = pcall(function() return o.oBehParams end)
        if ok and mark == SD.SD_BOMB_MARK then table.insert(found, o) end
        o = OF.util.optional("obj_get_next_with_same_behavior_id", nil, o)
    end
    return found
end

local function clear_sd_bombs()
    local gone = 0
    for _, o in ipairs(sd_bombs()) do
        OF.util.optional("obj_mark_for_deletion", nil, o)
        gone = gone + 1
    end
    return gone
end

function OF.gm_smash_bomb_spot(m, jitterX, jitterZ)
    if m == nil or m.pos == nil then return nil end
    local vel = m.vel or { x = 0, z = 0 }
    local x = m.pos.x + (vel.x or 0) * SD.SD_BOMB_LEAD + (jitterX or 0)
    local z = m.pos.z + (vel.z or 0) * SD.SD_BOMB_LEAD + (jitterZ or 0)
    if flat_on() then z = STAGE.z() end
    if not OF.util.asks(OF.modifiers, "rain_floor") then return nil end
    local ground = OF.modifiers.rain_floor(x, z, m)
    if ground == nil then return nil end
    return x, ground, z
end

rain_on_the_line = function()
    if not sd_on() then return false end
    for _, o in ipairs(sd_bombs()) do
        local held, age = o.oHeldState, o.oTimer
        if (held == nil or held == 0) and type(age) == "number" and age > SD.SD_BOMB_LIFE then
            OF.util.optional("obj_mark_for_deletion", nil, o)
        end
    end
    if sd.frames < SD.SD_BOMBS_AFTER then return false end
    if sd.bombWait > 0 then
        sd.bombWait = sd.bombWait - 1
        return false
    end
    sd.bombWait = SD.SD_BOMB_EVERY
    if not OF.util.asks(OF.modifiers, "bomb_mine_to_drop")
        or not OF.modifiers.bomb_mine_to_drop() then return false end
    if #sd_bombs() >= SD.SD_BOMB_MOST then return false end

    local me = gNetworkPlayers[0]
    local targets = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_FIGHT)) do
        local np = entry.np
        local m = gMarioStates[entry.localIndex]

        if np ~= nil and me ~= nil and m ~= nil and m.pos ~= nil
            and (entry.localIndex == 0 or OF.util.same_world(entry.localIndex)) then
            table.insert(targets, m)
        end
    end
    if #targets == 0 then return false end
    local m = targets[OF.util.random_int(1, #targets)]
    local x, ground, z = OF.gm_smash_bomb_spot(m,
        OF.util.random_int(-SD.SD_BOMB_SPREAD, SD.SD_BOMB_SPREAD),
        OF.util.random_int(-SD.SD_BOMB_SPREAD, SD.SD_BOMB_SPREAD))
    if x == nil then return false end
    local fall = OF.modifiers.bomb_drop(x, ground, z)
    if fall == nil then return false end
    local made = OF.util.optional("spawn_sync_object", nil,
        id_bhvBobomb, E_MODEL_BLACK_BOBOMB, x, ground + fall, z,
        function(o)
            o.oBehParams = SD.SD_BOMB_MARK
            o.oAction = BOBOMB_ACT_LAUNCHED
            o.oVelY = 0
            o.oForwardVel = 0
        end)
    return made ~= nil
end

local function sd_bomb_init(o)
    if o == nil then return end
    local ok, mark = pcall(function() return o.oBehParams end)
    if not ok or mark ~= SD.SD_BOMB_MARK then return end
    local fall = nil
    if OF.util.asks(OF.modifiers, "bomb_drop") then
        fall = OF.modifiers.bomb_drop(o.oPosX, o.oPosY, o.oPosZ)
    end
    if fall == nil then
        OF.util.optional("obj_mark_for_deletion", nil, o)
        return
    end
    o.oPosY = o.oPosY + fall
    o.oAction = BOBOMB_ACT_LAUNCHED
    o.oVelY = 0
    o.oForwardVel = 0
end

if id_bhvBobomb ~= nil then
    at_load("hook_behavior", id_bhvBobomb, OBJ_LIST_DESTRUCTIVE or 2, false,
        sd_bomb_init, nil)
end

local function on_interact(m, o, interactType)
    if m == nil or m.playerIndex ~= 0 or o == nil then return end
    if OF.gamemodes.current() ~= mode then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if OF.gamemodes.role(0) ~= ROLE_FIGHT or grace > 0 then return end
    if interactType ~= (INTERACT_DAMAGE or (1 << 3)) then return end
    if id_bhvExplosion == nil
        or OF.util.optional("obj_has_behavior_id", 0, o, id_bhvExplosion) ~= 1 then
        return
    end
    if AIR_KB_FOR[m.action] == nil and not AIR_KB_ACTIONS[m.action] then return end
    local d = MOVES.bomb.d * (tonumber(parts("taken_scale", "bomb")) or 1)
    percent = math.min(PERCENT_CAP, percent + d)
    OF.util.publish_row(0, PCT_KEY, percent)
    local blast = { pos = { x = o.oPosX or 0, y = o.oPosY or 0, z = o.oPosZ or 0 },
                    faceAngle = { y = 0 }, flags = 0 }
    local kb = launch_the_victim(blast, m, "bomb", percent, d)
    if kb ~= nil then
        hitstun = OF.gm_smash_hitstun(kb)
        lastKb = kb
    end

    local by = tonumber(parts("blame", o))
    local me = gNetworkPlayers[0]
    if by ~= nil and by >= 0 and (me == nil or by ~= me.globalIndex) then
        hitBy = by
        hitAgo = 0
    end
    parts("hit_taken", d, hitBy)
    if on_hp() and hp_from(percent) <= 0 then knock_out(m, "hp") end
    if flat_on() and m.vel ~= nil then
        local vx, vz = OF.gm_smash_along_line(m.vel.x, m.vel.z, m.pos.x - blast.pos.x)
        m.vel.x, m.vel.z = vx, vz
        m.slideVelX, m.slideVelZ = vx, vz
    end
end

hook_event(HOOK_ON_INTERACT, on_interact)

local BOMB_TOUCH, BOMB_SAFE = 110, 20
local leftMyHands = {}
function OF.gm_smash_bombs_frame()
    if id_bhvBobomb == nil then return 0 end
    local flat = flat_on()
    local m = gMarioStates[0]
    local mine = m ~= nil and m.pos ~= nil and OF.gamemodes.role(0) == ROLE_FIGHT
        and OF.util.can_play(0) and grace <= 0
    local lifting = nil
    if m ~= nil and ACT_PICKING_UP ~= nil and m.action == ACT_PICKING_UP then
        lifting = m.usedObj
    end
    local blown = 0
    local seen = {}
    local o = OF.util.optional("obj_get_first_with_behavior_id", nil, id_bhvBobomb)
    local guard = 0
    while o ~= nil and guard < 256 do
        guard = guard + 1
        seen[o] = true
        local mineNow = lifting ~= nil and o == lifting
        local held = (o.oHeldState or 0) ~= 0 or mineNow
        if flat and not held then
            o.oPosZ = STAGE.z()
            local yaw = o.oMoveAngleYaw or 0
            local along = math.sin(yaw * math.pi / 0x8000) >= 0 and 0x4000 or -0x4000
            o.oMoveAngleYaw, o.oFaceAngleYaw = along, along
        end
        if mineNow or (held and o.heldByPlayerIndex == 0) then
            leftMyHands[o] = 0
        elseif leftMyHands[o] ~= nil then
            leftMyHands[o] = leftMyHands[o] + 1
        end
        if mine and not held and o.oAction ~= (BOBOMB_ACT_EXPLODE or 3)
            and (leftMyHands[o] == nil or leftMyHands[o] > BOMB_SAFE) then
            local dx, dy, dz = m.pos.x - o.oPosX, m.pos.y - o.oPosY, m.pos.z - o.oPosZ
            if dx * dx + dz * dz <= BOMB_TOUCH * BOMB_TOUCH and math.abs(dy) <= 160 then
                o.oAction = BOBOMB_ACT_EXPLODE or 3
                blown = blown + 1
            end
        end
        o = OF.util.optional("obj_get_next_with_same_behavior_id", nil, o)
    end
    for k in pairs(leftMyHands) do
        if not seen[k] then leftMyHands[k] = nil end
    end
    return blown
end

function OF.gm_smash_sudden_death()
    return { on = sd_on(), list = sd_list(), frames = sd.frames,
             bombs = #sd_bombs(), seen = sd.seen,
             rain = rain_on_the_line, enter = enter_sudden_death }
end

leave_sudden_death = function()
    sd.seen = false
    sd.frames = 0
    sd.bombWait = 0
    clear_sd_bombs()
    if OF.util.is_host() and gGlobalSyncTable[SD.SD_KEY] ~= nil
        and gGlobalSyncTable[SD.SD_KEY] ~= "" then
        OF.util.publish(SD_KEY_NAME, "")
    end
end
end

function mode.host_update()

    if OF.gamemodes.state() == OF.gamemodes.ACTIVE then parts("host_update") end

    if sd_on() and not OF.teams.in_play() then
        local left = contenders()
        if #left == 1 then
            OF.gamemodes.finish("@ won the sudden death.",
                left[1].np.name, left[1].np.name)
        elseif #left == 0 then
            OF.gamemodes.finish(OF.gamemodes.NO_CONTEST)
        end
        return
    end
    if not on_stocks() then return end

    if OF.teams.in_play() then

        local side = OF.teams.last_side_standing(function(localIndex)
            return OF.gamemodes.role(localIndex) == ROLE_FIGHT
                and OF.util.can_play(localIndex)
        end)
        if side ~= nil then
            OF.gamemodes.finish(OF.teams.survival_text(side),
                OF.gamemodes.team_winner(side))
        end
        return
    end

    local left = contenders()
    if #left == 1 then
        OF.gamemodes.finish("@ won.",
            left[1].np.name, left[1].np.name)
        return
    end
    if #left == 0 then

        OF.gamemodes.finish(OF.gamemodes.NO_CONTEST)
    end
end

function mode.on_timeout()

    if OF.teams.in_play() then
        local winner = OF.teams.leader()
        OF.gamemodes.finish(OF.teams.result_text(),
            OF.gamemodes.team_winner(winner))
        return
    end

    if sd_on() then
        local left = contenders()
        if #left == 1 then
            OF.gamemodes.finish("@ won the sudden death.",
                left[1].np.name, left[1].np.name)
        else
            OF.gamemodes.finish("Sudden death ran out - a draw.")
        end
        return
    end

    local bestScore, names = OF.gamemodes.best_of(
        OF.gamemodes.with_role(ROLE_FIGHT),
        function(entry) return score_of(entry.localIndex) end)

    if bestScore == nil then
        OF.gamemodes.finish(OF.gamemodes.NO_CONTEST)
    elseif #names > 1 then

        if start_sudden_death(bestScore) then return end
        OF.gamemodes.finish("Time - a draw at @ each.", nil, bestScore)
    elseif on_stocks() then
        OF.gamemodes.finish(bestScore == 1 and "@ won with 1 stock." or "@ won with @ stocks.",
            names[1], names[1], bestScore)
    elseif on_coins() then
        OF.gamemodes.finish(bestScore == 1 and "@ wins with 1 coin." or "@ wins with @ coins.",
            names[1], names[1], bestScore)
    else
        OF.gamemodes.finish(bestScore == 1 and "@ wins on 1 point." or "@ wins on @ points.",
            names[1], names[1], bestScore)
    end
end

function mode.standing(localIndex)
    if OF.gamemodes.role(localIndex) == ROLE_OUT then return "OUT" end
    return nil
end

local PERCENT_LIFT = 250

local percentAt = { x = 0, y = 0, z = 0 }

local percentFrom = { x = 0, y = 0, z = 0 }

function OF.gm_smash_percent_here(who)
    return who == 0 or OF.util.same_world(who)
end

local function draw_the_percents()
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_FIGHT)) do
        local who = entry.localIndex
        local m = gMarioStates[who]
        local np = gNetworkPlayers[who]

        if m ~= nil and m.pos ~= nil and np ~= nil and OF.gm_smash_percent_here(who) then
            local at = percentFrom
            at.x, at.y, at.z = m.pos.x, m.pos.y + PERCENT_LIFT, m.pos.z
            if OF.util.world_screen(at, percentAt) then
                local r, g, b = 255, 255, 255
                if who == 0 then r, g, b = 255, 215, 0 end

                local label = tostring(percent_of(who)) .. "%"
                if on_hp() then
                    label = OF.lang.fill("@ HP", tostring(hp_of(who)))
                end
                OF.util.world_label(percentAt.x, percentAt.y,
                    label, 1.0, r, g, b, 255)
            end
        end
    end
end

function OF.gm_smash_board()
    local board = OF.gamemodes.score_board(ROLE_FIGHT, score_of,
        function(_, entry)
            if on_hp() then
                return OF.lang.fill("@ HP", tostring(hp_of(entry.localIndex)))
                    .. "   " .. tostring(kos_of(entry.localIndex))
            end

            if on_coins() then
                return tostring(percent_of(entry.localIndex)) .. "%   "
                    .. tostring(math.max(0, score_of(entry.localIndex)))
            end
            return tostring(percent_of(entry.localIndex)) .. "%   "
                .. tostring(kos_of(entry.localIndex))
        end)
    for _, entry in ipairs(OF.gamemodes.score_board(ROLE_OUT, score_of,
        function(_, out)
            return OF.lang.t("OUT") .. "   " .. tostring(kos_of(out.localIndex))
        end)) do
        table.insert(board, entry)
    end
    return board
end

local boxFrom = { x = 0, y = 0, z = 0 }
local boxTo = { x = 0, y = 0, z = 0 }
local BOX_R, BOX_G, BOX_B, BOX_A = 255, 70, 60, 150

local function draw_the_box()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false end
    if edges_wrap() then return false end
    local box = my_box()
    if box == nil then return false end
    local left, right = box.left, box.right
    local top = box.top
    local low = box.koBottom or box.wrapBottom or (box.y - WRAP_DROP)
    if flat_on() then
        local z = box.z
        boxFrom.x, boxFrom.y, boxFrom.z = left, low, z
        boxTo.x, boxTo.y, boxTo.z = left, top, z
        OF.util.world_line(boxFrom, boxTo, 3, BOX_R, BOX_G, BOX_B, BOX_A)
        boxFrom.x, boxTo.x = right, right
        OF.util.world_line(boxFrom, boxTo, 3, BOX_R, BOX_G, BOX_B, BOX_A)
        boxFrom.x, boxFrom.y, boxTo.x, boxTo.y = left, top, right, top
        OF.util.world_line(boxFrom, boxTo, 3, BOX_R, BOX_G, BOX_B, BOX_A)

        if box.lane and box.koBottom ~= nil then
            boxFrom.x, boxFrom.y, boxTo.x, boxTo.y = left, low, right, low
            OF.util.world_line(boxFrom, boxTo, 3, BOX_R, BOX_G, BOX_B, BOX_A)
        end
        return true
    end

    return false
end

function OF.gm_smash_box_drawn()
    return draw_the_box()
end

function mode.controls_lines()
    return parts("controls")
end

function mode.hud()
    draw_the_box()
    draw_the_percents()

    if am_out() then

        OF.gamemodes.out_banner(nil, parts("out_offer"))
        return
    end

    local state = OF.util.asks(OF.hud, "state_line") and OF.hud.state_line or function() end
    if grace > 0 then
        state("safe", OF.lang.t("Safe"), { prio = 60, tone = "good" })
    end
    local under = parts("under_line")
    if under ~= nil then
        state("part", under, { prio = 20, tone = "ink2" })
    end
    parts("hud")
end

function mode.cluster()
    if OF.util.asks(OF.teams, "in_play") and OF.teams.in_play() then return nil end
    if not OF.util.asks(OF.gamemodes, "ffa_cluster") then return nil end
    local out = OF.gamemodes.ffa_cluster(mode)
    if out == nil or out.you == nil or out.you.localIndex ~= 0 then return out end
    out.you.label = on_hp() and OF.lang.fill("@ HP", tostring(hp_from(percent)))
        or (tostring(percent) .. "%")
    if on_stocks() then
        out.you.lives, out.you.livesMax = stocks_left(), stocks_wanted()
    end
    return out
end

function mode.out_cause() return "That was your last stock" end

mode.presets = {
    { key = "classic", name = "Classic", help = "the usual round", sets = {} },
    { key = "stock", name = "Classic stock", help = "three stocks, seven minutes",
      sets = { rule = "stock", lv = "three", min = "seven" } },
    { key = "time2", name = "Time 2 min", help = "most points in two minutes",
      sets = { rule = "time", min = "two" } },
    { key = "sudden", name = "Sudden death", help = "one stock, everybody at 300%",
      sets = { rule = "stock", lv = "one", p = "3" } },
    { key = "turbo", name = "Turbo", help = "hit points, and a hit cancels into the next",
      sets = { rule = "turbo" } },
    { key = "stamina", name = "Stamina", help = "hit points each stock",
      sets = { rule = "hp" } },
}

do
local api = {
    mode = mode,
    MOVES = MOVES,
    ROLE_FIGHT = ROLE_FIGHT,
    ROLE_OUT = ROLE_OUT,
    PCT_KEY = PCT_KEY,
    LINE_Z = FLAT_LINE_Z,
    LINE_X = FLAT_LINE_X,
    RIM = BLAST_RIM,
}

function api.fighting()
    return OF.gamemodes.current() == mode
        and OF.gamemodes.state() == OF.gamemodes.ACTIVE
        and OF.gamemodes.role(0) == ROLE_FIGHT and OF.util.can_play(0)
end

function api.plain_b(m) return OF.gm_smash_plain_b(m) end

function api.percent() return percent end
function api.grace() return grace end
function api.hitstun() return hitstun end
function api.on_hp() return on_hp() end
function api.on_coins() return on_coins() end
function api.on_stocks() return on_stocks() end
function api.on_turbo() return on_turbo() end
function api.flat_on() return flat_on() end
function api.stocks_left() return stocks_left() end
function api.box() return my_box() end

function api.stage_of(level, area) return STAGE.of(level, area) end
function api.score_of(localIndex) return score_of(localIndex) end
function api.percent_of(localIndex) return percent_of(localIndex) end

function api.set_score(n)
    OF.util.publish_row(0, "ofScore", math.max(0, math.floor(tonumber(n) or 0)))
end

function api.set_percent(p)
    p = tonumber(p) or 0
    if p < 0 then p = 0 end
    if p > PERCENT_CAP then p = PERCENT_CAP end
    percent = p
    OF.util.publish_row(0, PCT_KEY, math.floor(percent))

    if on_hp() and hp_from(percent) <= 0 and knock_out ~= nil then
        knock_out(gMarioStates[0], "hp")
    end
    return percent
end

function api.take_hit(from, kind, damage, byGlobal)
    local m = gMarioStates[0]
    if m == nil or m.vel == nil or not api.fighting() or grace > 0 then return nil end
    if from == nil then from = { pos = m.pos, faceAngle = { y = 0 }, flags = 0 } end
    if parts("blocks", kind, damage, from) then return nil end
    damage = tonumber(damage) or OF.gm_smash_move(kind).d
    damage = damage * (tonumber(parts("taken_scale", kind)) or 1)
    percent = math.min(PERCENT_CAP, percent + damage)
    OF.util.publish_row(0, PCT_KEY, math.floor(percent))

    if AIR_KB_FOR[m.action] == nil and not AIR_KB_ACTIONS[m.action] then
        local facing = true
        if from.pos ~= nil and m.pos ~= nil then
            local toward = atan2s(from.pos.z - m.pos.z, from.pos.x - m.pos.x)
            local diff = (toward - (m.faceAngle.y or 0) + 0x8000) % 0x10000 - 0x8000
            facing = math.abs(diff) < 0x4000
        end
        OF.util.optional("set_mario_action", nil, m,
            facing and ACT_BACKWARD_AIR_KB or ACT_FORWARD_AIR_KB, 0)
    end
    local kb = launch_the_victim(from, m, kind, percent, damage)
    if kb ~= nil then
        hitstun = OF.gm_smash_hitstun(kb)
        lastKb = kb
    end
    if flat_on() and from.pos ~= nil then
        local vx, vz = OF.gm_smash_along_line(m.vel.x, m.vel.z, m.pos.x - from.pos.x)
        m.vel.x, m.vel.z = vx, vz
        m.slideVelX, m.slideVelZ = vx, vz
    end
    local me = gNetworkPlayers[0]
    byGlobal = tonumber(byGlobal)
    if byGlobal ~= nil and byGlobal >= 0 and (me == nil or byGlobal ~= me.globalIndex) then
        hitBy = byGlobal
        hitAgo = 0
    end
    parts("hit_taken", damage, hitBy)
    if on_hp() and hp_from(percent) <= 0 then knock_out(m, "hp") end
    return kb or 0
end

function api.lend_stock()
    if not on_stocks() or stocks_left() < 2 then return false end
    lost = lost + 1
    stocks = stocks_left()
    OF.util.publish_row(0, "ofScore", stocks)
    return true
end

function api.borrow_stock()
    if not on_stocks() or OF.gamemodes.role(0) ~= ROLE_OUT then return false end
    lost = stocks_wanted() - 1
    stocks = stocks_left()
    percent = OF.gm_smash_start_percent()
    grace = RESPAWN_GRACE
    hitBy, hitAgo, hitstun = -1, 0, 0
    fallClaimed = false

    if OF.util.asks(OF.spectate, "is_active") and OF.spectate.is_active() then
        OF.spectate.stop()
    end
    OF.gamemodes.set_role(0, ROLE_FIGHT)
    OF.util.publish_row(0, "ofGmTime", 0)
    OF.util.publish_row(0, PCT_KEY, percent)
    OF.util.publish_row(0, "ofScore", stocks)
    placeDue = FLAT_PLACE_WINDOW
    return true
end

OF.gm_smash_api = api
end

OF.gamemodes.register(mode)
