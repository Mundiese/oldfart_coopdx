OF = OF or {}
OF.shuffle = OF.shuffle or {}

local shuffle = OF.shuffle

shuffle.SEED_KEY = "ofShuffleSeed"
function shuffle.seed()
    local value = gGlobalSyncTable[shuffle.SEED_KEY]
    if type(value) ~= "number" then return 0 end
    return value
end

function shuffle.is_on()
    return shuffle.seed() > 0
end

function shuffle.stands_down()
    return OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() == true
end

local function step_of(state)
    return (1103515245 * state + 12345) % 2147483648
end

local function legacy_map(seed)
    local map = {}
    if seed <= 0 then return map end

    local order = {}
    for _, course in ipairs(OF.COURSES or {}) do
        table.insert(order, course.level)
    end

    local state = seed % 2147483648
    for index = #order, 2, -1 do
        state = step_of(state)
        local pick = (state % (index - 1)) + 1
        order[index], order[pick] = order[pick], order[index]
    end

    for index, course in ipairs(OF.COURSES or {}) do
        map[course.level] = order[index]
    end
    return map
end

local CASTLE = { [LEVEL_CASTLE] = true }
local COURTYARD = { [LEVEL_CASTLE_COURTYARD] = true }
local GROUNDS = { [LEVEL_CASTLE_GROUNDS] = true }

local function out_of(level, area, win, die)
    return { level = level, area = area, win = win, die = die }
end

shuffle.ENTRANCES = {
    { key = "bob", level = LEVEL_BOB, kind = "course", floor = 1, from = CASTLE,
      exit = out_of(LEVEL_CASTLE, 1, 0x32, 0x64), painting = "bob_painting" },
    { key = "wf",  level = LEVEL_WF,  kind = "course", floor = 1, from = CASTLE,
      exit = out_of(LEVEL_CASTLE, 1, 0x34, 0x66), painting = "wf_painting" },
    { key = "jrb", level = LEVEL_JRB, kind = "course", floor = 1, from = CASTLE,
      exit = out_of(LEVEL_CASTLE, 1, 0x35, 0x67), painting = "jrb_painting" },
    { key = "ccm", level = LEVEL_CCM, kind = "course", floor = 1, from = CASTLE,
      exit = out_of(LEVEL_CASTLE, 1, 0x33, 0x65), painting = "ccm_painting" },
    { key = "bbh", level = LEVEL_BBH, kind = "course", floor = 1, from = COURTYARD,
      exit = out_of(LEVEL_CASTLE_COURTYARD, 1, 0x0A, 0x0B) },
    { key = "hmc", level = LEVEL_HMC, kind = "course", floor = 2, from = CASTLE,
      exit = out_of(LEVEL_CASTLE, 3, 0x34, 0x66), painting = "hmc_painting" },
    { key = "lll", level = LEVEL_LLL, kind = "course", floor = 2, from = CASTLE,
      exit = out_of(LEVEL_CASTLE, 3, 0x32, 0x64), painting = "lll_painting" },
    { key = "ssl", level = LEVEL_SSL, kind = "course", floor = 2, from = CASTLE,
      exit = out_of(LEVEL_CASTLE, 3, 0x33, 0x65), painting = "ssl_painting" },
    { key = "ddd", level = LEVEL_DDD, kind = "course", floor = 2, from = CASTLE,
      exit = out_of(LEVEL_CASTLE, 3, 0x35, 0x67), painting = "ddd_painting" },
    { key = "sl",  level = LEVEL_SL,  kind = "course", floor = 3, from = CASTLE,
      exit = out_of(LEVEL_CASTLE, 2, 0x36, 0x68), painting = "sl_painting" },
    { key = "wdw", level = LEVEL_WDW, kind = "course", floor = 3, from = CASTLE,
      exit = out_of(LEVEL_CASTLE, 2, 0x32, 0x64), painting = "wdw_painting" },
    { key = "ttm", level = LEVEL_TTM, kind = "course", floor = 3, from = CASTLE,
      exit = out_of(LEVEL_CASTLE, 2, 0x34, 0x66), painting = "ttm_painting" },

    { key = "thi", level = LEVEL_THI, area = 1, kind = "course", floor = 3, from = CASTLE,
      exit = out_of(LEVEL_CASTLE, 2, 0x37, 0x69), painting = "thi_huge_painting",
      name = "Tiny-Huge Island (huge)" },
    { key = "ttc", level = LEVEL_TTC, kind = "course", floor = 3, from = CASTLE,
      exit = out_of(LEVEL_CASTLE, 2, 0x35, 0x67), painting = "ttc_painting" },

    { key = "rr",  level = LEVEL_RR,  kind = "course", floor = 3, from = CASTLE,
      exit = out_of(LEVEL_CASTLE, 2, 0x3A, 0x6C), at = { 2, -3412, 2816, 5886 } },

    { key = "thitiny", level = LEVEL_THI, area = 2, kind = "course", floor = 3,
      from = CASTLE, split = true,
      exit = out_of(LEVEL_CASTLE, 2, 0x33, 0x65), painting = "thi_tiny_painting",
      name = "Tiny-Huge Island (tiny)" },

    { key = "pss",   level = LEVEL_PSS,   kind = "secret", floor = 1, from = CASTLE,
      exit = out_of(LEVEL_CASTLE, 1, 0x26, 0x23), at = { 1, 2013, 768, -2014 } },
    { key = "sa",    level = LEVEL_SA,    kind = "secret", floor = 1, from = CASTLE,
      exit = out_of(LEVEL_CASTLE, 1, 0x27, 0x28), at = { 1, 1963, 819, 1280 } },
    { key = "totwc", level = LEVEL_TOTWC, kind = "secret", floor = 1, from = CASTLE,
      exit = out_of(LEVEL_CASTLE, 1, 0x26, 0x23) },
    { key = "moat", level = LEVEL_VCUTM, kind = "secret", floor = 1, from = GROUNDS,
      exit = out_of(LEVEL_CASTLE_GROUNDS, 1, 0x08, 0x06) },
    { key = "cotmc", level = LEVEL_COTMC, kind = "secret", floor = 2,
      from = { [LEVEL_HMC] = true },
      exit = out_of(LEVEL_CASTLE, 3, 0x34, 0x66) },
    { key = "wmotr", level = LEVEL_WMOTR, kind = "secret", floor = 3, from = CASTLE,
      exit = out_of(LEVEL_CASTLE, 2, 0x38, 0x6D), at = { 2, 3002, 2816, 5886 } },

    { key = "bitdw", level = LEVEL_BITDW, kind = "bowser", floor = 1, from = CASTLE,
      exit = out_of(LEVEL_CASTLE, 1, nil, 0x25), at = { 1, -5513, 512, -4324 } },
    { key = "bitfs", level = LEVEL_BITFS, kind = "bowser", floor = 2, from = CASTLE,
      exit = out_of(LEVEL_CASTLE, 3, nil, 0x68), at = { 3, 4147, -1280, 1997 } },
    { key = "bits",  level = LEVEL_BITS,  kind = "bowser", floor = 3, from = CASTLE,
      exit = out_of(LEVEL_CASTLE, 2, nil, 0x6B), at = { 2, -230, 4813, -3352 } },
}

shuffle.BY_KEY = {}
for _, entry in ipairs(shuffle.ENTRANCES) do
    shuffle.BY_KEY[entry.key] = entry
    entry.from = entry.from or CASTLE
end

function shuffle.entrance_name(entry)
    if entry == nil then return "Unknown" end
    if entry.name ~= nil then return entry.name end
    return OF.util.level_name(entry.level)
end

shuffle.SHORT = {
    thi = "Tiny-Huge (huge)", thitiny = "Tiny-Huge (tiny)",
    pss = "The secret slide", sa = "The secret aquarium",
    totwc = "The Wing Cap tower", moat = "The Vanish Cap moat",
    cotmc = "The Metal Cap cavern", wmotr = "Over the rainbow",
    bitdw = "Bowser: Dark World", bitfs = "Bowser: Fire Sea",
    bits = "Bowser: the Sky",
}

function shuffle.short_name(entry)
    if entry ~= nil and shuffle.SHORT[entry.key] ~= nil then
        return shuffle.SHORT[entry.key]
    end
    return shuffle.entrance_name(entry)
end

shuffle.POOLS = {
    { name = "The courses" },
    { name = "The courses, Tiny-Huge Island's two paintings apart" },
    { name = "The courses and the secret stages" },
    { name = "Everything, Bowser's stages too" },
}

shuffle.LABELS = { "truth", "blind", "lies" }

shuffle.SHAPE_KEY = "ofShuffleShape"
shuffle.EXITS = { "back", "third" }

local function shape()
    local value = gGlobalSyncTable[shuffle.SHAPE_KEY]
    if type(value) ~= "number" or value < 0 then return 0, 0, 0, 0 end
    value = math.floor(value)
    local pool = value % 10
    local labels = math.floor(value / 10) % 10
    local exits = math.floor(value / 100) % 10
    if pool > #shuffle.POOLS - 1 then pool = 0 end
    if labels > #shuffle.LABELS - 1 then labels = 0 end
    if exits > #shuffle.EXITS - 1 then exits = 0 end
    return pool, labels, exits
end

function shuffle.pool() local pool = shape(); return pool end
function shuffle.labels()
    local _, labels = shape()
    return shuffle.LABELS[labels + 1]
end
function shuffle.exits()
    local _, _, exits = shape()
    return shuffle.EXITS[exits + 1]
end

function shuffle.set_shape(pool, labels, exits)
    if not OF.util.is_host() then return false, "Only the host." end
    if shuffle.stands_down() then
        return false, "A round or a run has the castle out on loan."
    end
    pool = math.floor(tonumber(pool) or 0)
    labels = math.floor(tonumber(labels) or 0)
    exits = math.floor(tonumber(exits) or 0)
    if pool < 0 or pool > #shuffle.POOLS - 1 then return false, "No such draw." end
    if labels < 0 or labels > #shuffle.LABELS - 1 then return false, "No such draw." end
    if exits < 0 or exits > #shuffle.EXITS - 1 then return false, "No such draw." end
    OF.util.publish(shuffle.SHAPE_KEY, pool + 10 * labels + 100 * exits)
    return true
end

local function pool_entries(pool)
    local list = {}
    for _, entry in ipairs(shuffle.ENTRANCES) do
        local kind = entry.kind
        local wanted = (kind == "course" and (not entry.split or pool >= 1))
            or (kind == "secret" and pool >= 2)
            or (kind == "bowser" and pool >= 3)
        if wanted then list[#list + 1] = entry end
    end
    return list
end
shuffle.pool_entries = pool_entries

local function keeps_rules(list, dealt)
    for index, entry in ipairs(list) do
        local to = dealt[index]
        if entry.key == "bob" and to.kind ~= "course" then return false end
        if entry.key == "cotmc" and to.level == LEVEL_HMC then return false end
        if entry.key == "bitfs" and to.level == LEVEL_DDD then return false end
        if to.kind == "bowser" and entry.floor < to.floor then return false end
    end
    return true
end

local function deal_pool(seed, pool)
    local list = pool_entries(pool)
    local state = (seed * 7 + pool) % 2147483648
    for _ = 1, 200 do
        local order = {}
        for index = 1, #list do order[index] = index end
        for index = #order, 2, -1 do
            state = step_of(state)
            local pick = (state % (index - 1)) + 1
            order[index], order[pick] = order[pick], order[index]
        end
        local dealt = {}
        for index = 1, #list do dealt[index] = list[order[index]] end
        if keeps_rules(list, dealt) then
            local byKey = {}
            for index, entry in ipairs(list) do byKey[entry.key] = dealt[index] end
            return byKey
        end
        state = step_of(state + 1)
    end
    if pool > 1 then return deal_pool(seed, 1) end
    return {}
end

local function deal_for(seed, pool)
    if seed <= 0 then return {} end
    if pool <= 0 then
        local byLevel = {}
        for _, entry in ipairs(shuffle.ENTRANCES) do
            if entry.kind == "course" and not entry.split then
                byLevel[entry.level] = entry
            end
        end
        local byKey = {}
        for from, to in pairs(legacy_map(seed)) do
            local entry = byLevel[from]
            if entry ~= nil then byKey[entry.key] = byLevel[to] end
        end
        if byKey.thi ~= nil then byKey.thitiny = byKey.thi end
        return byKey
    end
    return deal_pool(seed, pool)
end

local dealtFor = { seed = -1, pool = -1, byKey = {} }
function shuffle.deal()
    local seed, pool = shuffle.seed(), shuffle.pool()
    if dealtFor.seed ~= seed or dealtFor.pool ~= pool then
        dealtFor = { seed = seed, pool = pool, byKey = deal_for(seed, pool) }
    end
    return dealtFor.byKey
end

function shuffle.map()
    local map = {}
    for key, to in pairs(shuffle.deal()) do
        local entry = shuffle.BY_KEY[key]
        if entry ~= nil and not entry.split then map[entry.level] = to.level end
    end
    return map
end

function shuffle.behind(levelNum)
    local to = shuffle.map()[levelNum]
    if to == nil then return nil end
    return OF.util.level_name(to)
end

function shuffle.spoiler()
    local rows = {}
    local byKey = shuffle.deal()
    for _, entry in ipairs(pool_entries(shuffle.pool())) do
        local to = byKey[entry.key]
        if to ~= nil then
            rows[#rows + 1] = { from = shuffle.short_name(entry),
                                to = shuffle.short_name(to) }
        end
    end
    return rows
end

local function entrance_of(here, destLevel, destArea, pool)
    for _, entry in ipairs(shuffle.ENTRANCES) do
        if entry.level == destLevel and entry.from[here] then
            if entry.area == nil or pool == 0 then
                if not entry.split then return entry end
            elseif entry.area == destArea then
                return entry
            end
        end
    end
    return nil
end

local entered = nil

function shuffle.entered() return entered end
function shuffle.forget_entered() entered = nil end

local function exit_kind(here, destLevel, destArea, destWarpNode)
    for _, entry in ipairs(shuffle.ENTRANCES) do
        local exit = entry.exit
        if entry.level == here and exit.level == destLevel and exit.area == destArea then
            if exit.win ~= nil and destWarpNode == exit.win then return "win" end
            if destWarpNode == exit.die then return "die" end
        end
    end
    return nil
end

local function castle_level(level)
    return level == LEVEL_CASTLE or level == LEVEL_CASTLE_GROUNDS
        or level == LEVEL_CASTLE_COURTYARD
end

function shuffle.redirect(here, destLevel, destArea, destWarpNode)
    if not shuffle.is_on() or shuffle.stands_down() then
        entered = nil
        return nil
    end
    local pool = shuffle.pool()

    local from = entrance_of(here, destLevel, destArea, pool)
    if from ~= nil then
        local to = shuffle.deal()[from.key]
        if to == nil or to == from then return nil end

        local area = 1
        if pool >= 1 and to.area ~= nil then area = to.area end
        entered = { to = to.level, toKey = to.key, exit = from.exit }
        return { destLevel = to.level, destArea = area, destWarpNode = 0x0A }
    end

    if entered ~= nil and castle_level(destLevel) then
        local was = entered
        entered = nil
        if here ~= was.to then return nil end
        local kind = exit_kind(here, destLevel, destArea, destWarpNode)
        if kind == nil then return nil end
        local exit = was.exit

        if shuffle.exits() == "third" and was.toKey ~= nil then
            local third = shuffle.deal()[was.toKey]
            if third ~= nil and third.exit ~= nil then exit = third.exit end
        end
        local node = exit.die
        if kind == "win" and exit.win ~= nil then node = exit.win end
        if exit.level == destLevel and exit.area == destArea and node == destWarpNode then
            return nil
        end
        return { destLevel = exit.level, destArea = exit.area, destWarpNode = node }
    end
    return nil
end

local PLATE_SCALE = 0.5
local PLATE_FADE = 5000
local plateWorld = { x = 0, y = 0, z = 0 }
local plateScreen = { x = 0, y = 0, z = 0 }

function shuffle.painting_middle(painting)
    if painting == nil then return nil end
    local size = painting.size or 614
    local half = size * 0.5
    local yaw = math.rad(painting.yaw or 0)
    return painting.posX + half * math.cos(yaw),
        painting.posY + half,
        painting.posZ - half * math.sin(yaw)
end

function shuffle.drawn_at(x, y, z)
    if not OF.util.asks(OF.warp, "picture_scaled") then return x, y, z end
    local scaled, fx, fy, fz = OF.warp.picture_scaled()
    if not scaled then return x, y, z end
    return x * fx, y * fy, z * fz
end

function shuffle.plates()
    local plates = {}
    if not shuffle.is_on() or shuffle.stands_down() then return plates end
    local labels = shuffle.labels()
    if labels == "blind" then return plates end
    local np = gNetworkPlayers[0]
    if np == nil or np.currLevelNum ~= LEVEL_CASTLE then return plates end
    local area = np.currAreaIndex
    local byKey = shuffle.deal()
    if labels == "lies" then
        byKey = deal_for((shuffle.seed() % 9000) + 1001, shuffle.pool())
    end
    for _, entry in ipairs(pool_entries(3)) do
        local to = byKey[entry.key]
        if to ~= nil then
            local x, y, z = nil, nil, nil
            if entry.painting ~= nil and gPaintingValues ~= nil then
                local painting = gPaintingValues[entry.painting]
                if painting ~= nil and painting.posX ~= nil
                    and shuffle.PAINTING_AREA[entry.painting] == area then
                    x, y, z = shuffle.painting_middle(painting)
                end
            elseif entry.at ~= nil and entry.at[1] == area then
                x, y, z = entry.at[2], entry.at[3] + 160, entry.at[4]
            end
            if x ~= nil then
                x, y, z = shuffle.drawn_at(x, y, z)
                plates[#plates + 1] = { entry = entry, x = x, y = y, z = z,
                                        text = shuffle.entrance_name(to) }
            end
        end
    end
    return plates
end

shuffle.PAINTING_AREA = {
    bob_painting = 1, ccm_painting = 1, wf_painting = 1, jrb_painting = 1,
    wdw_painting = 2, thi_tiny_painting = 2, ttm_painting = 2, ttc_painting = 2,
    sl_painting = 2, thi_huge_painting = 2,
    lll_painting = 3, ssl_painting = 3, hmc_painting = 3, ddd_painting = 3,
}

local function render_plates()
    if not shuffle.is_on() then return end
    if OF.util.menu_has_screen() then return end
    local me = gMarioStates[0]
    if me == nil or me.pos == nil then return end
    local plates = shuffle.plates()
    if #plates == 0 then return end
    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)
    for _, plate in ipairs(plates) do
        local dx, dy, dz = plate.x - me.pos.x, plate.y - me.pos.y, plate.z - me.pos.z
        local off = math.sqrt(dx * dx + dy * dy + dz * dz)
        if off < PLATE_FADE then
            plateWorld.x, plateWorld.y, plateWorld.z = plate.x, plate.y, plate.z
            if OF.util.world_screen(plateWorld, plateScreen) then
                local alpha = math.floor(255 * (1 - off / PLATE_FADE))

                local H = OF.hud
                if H ~= nil and type(H.plate) == "function" and type(H.measure) == "function"
                    and type(H.menu_text_mid) == "function" then
                    local w, h = (H.measure(plate.text, "caption") or 0) + 16, 22
                    H.plate(plateScreen.x - w * 0.5, plateScreen.y - h * 0.5, w, h,
                        { alpha = alpha / 255, lit = true })
                    H.menu_text_mid(plate.text, plateScreen.x, plateScreen.y, "caption",
                        "gold", alpha, "center")
                else
                    local width, height = OF.util.text_size(plate.text, PLATE_SCALE)
                    OF.util.plate(plateScreen.x - width * 0.5 - 4,
                        plateScreen.y - height * 0.5 - 2, width + 8, height + 4,
                        { alpha = alpha })
                    OF.util.text(plate.text, plateScreen.x - width * 0.5,
                        plateScreen.y - height * 0.5, PLATE_SCALE, 255, 230, 120, alpha)
                end
            end
        end
    end
end

hook_event(HOOK_ON_HUD_RENDER, render_plates)

shuffle.FACES = {}

for _, key in ipairs({ "bob", "ccm", "wf", "jrb", "lll", "ssl", "wdw", "ttm", "ttc", "sl" }) do
    shuffle.FACES[key] = { top = "of_pnt_" .. key .. "_top",
                           bottom = "of_pnt_" .. key .. "_bottom",
                           env = "of_pnt_" .. key .. "_env" }
end

for _, pair in ipairs({
    { "bbh", "bbh" }, { "hmc", "hmc" }, { "ddd", "ddd" }, { "rr", "rr" },
    { "pss", "pss" }, { "sa", "sa" }, { "totwc", "wc" }, { "moat", "vc" },
    { "cotmc", "cotmc" }, { "wmotr", "wmotr" },
    { "bitdw", "bitdw" }, { "bitfs", "bitfs" }, { "bits", "bits" },
    { "thi", "thihuge" }, { "thitiny", "thitiny" },
}) do
    local entranceKey, fileKey = pair[1], pair[2]
    shuffle.FACES[entranceKey] = { top = "of_pnt_" .. fileKey .. "_top",
                                   bottom = "of_pnt_" .. fileKey .. "_bottom",
                                   env = "of_pnt_" .. fileKey .. "_env" }
end

shuffle.FACE_TARGETS = {
    bob = COURSE_BOB, ccm = COURSE_CCM, wf = COURSE_WF, jrb = COURSE_JRB,
    lll = COURSE_LLL, ssl = COURSE_SSL, wdw = COURSE_WDW,
    ttm = COURSE_TTM, ttc = COURSE_TTC, sl = COURSE_SL,
}

shuffle.ENV_TARGETS = {
    hmc = "inside_castle_seg7_texture_07016800",
    ddd = "inside_castle_seg7_texture_07017000",
}

shuffle.HIDDEN_FACES = { ssl = COURSE_SSL, sl = COURSE_SL }

function shuffle.hidden_faces_wanted()
    if not OF.util.asks(OF.rules, "value") then return false end
    return OF.rules.value("hiddenfaces") == 1
end

function shuffle.painting_swap_on()
    return OF.util.asks(OF.modifiers, "is_on")
        and OF.modifiers.is_on("paintswap") == true
end

function shuffle.own_faces()
    local own = {}
    local function home(key) own[key] = { key = key } end
    for key in pairs(shuffle.FACE_TARGETS) do home(key) end
    for key in pairs(shuffle.ENV_TARGETS) do home(key) end
    for _, key in pairs(shuffle.SPLIT_PAINTINGS) do home(key) end
    return own
end

function shuffle.faces()
    local out = {}

    shuffle.splitWanted = {}
    if shuffle.stands_down() then return out end
    local np = gNetworkPlayers[0]
    if np == nil or np.currLevelNum ~= LEVEL_CASTLE then return out end
    if OF.util == nil or type(OF.util.PAINTINGS) ~= "table" then return out end
    local byKey = nil
    local swap = shuffle.painting_swap_on()
    if shuffle.is_on() then
        local labels = shuffle.labels()
        if labels == "blind" then return out end
        byKey = shuffle.deal()
        if labels == "lies" then
            byKey = deal_for((shuffle.seed() % 9000) + 1001, shuffle.pool())
        end
        local faced = byKey
        if swap then

            faced = shuffle.own_faces()
            for key, to in pairs(byKey) do faced[key] = to end
        end
        shuffle.dealt_faces(faced, out, shuffle.splitWanted, swap)
    elseif swap then
        shuffle.dealt_faces(shuffle.own_faces(), out, shuffle.splitWanted, true)
    end

    if shuffle.hidden_faces_wanted() then
        for key, course in pairs(shuffle.HIDDEN_FACES) do
            local to = byKey ~= nil and byKey[key] or nil
            local halves = OF.util.PAINTINGS[course]
            local face = shuffle.FACES[key]
            if halves ~= nil and face ~= nil and out[halves.top] == nil
                and (to == nil or to.key == key) then
                out[halves.top] = face.top
                out[halves.bottom] = face.bottom
            end
        end
    end
    return out
end

function shuffle.dealt_faces(byKey, out, split, ownToo)
    for key, target in pairs(shuffle.ENV_TARGETS) do
        local to = byKey[key]
        local face = to ~= nil and shuffle.FACES[to.key] or nil
        if face ~= nil and (to.key ~= key or ownToo == true) then out[target] = face.env end
    end
    for key, course in pairs(shuffle.FACE_TARGETS) do
        local to = byKey[key]
        local halves = OF.util.PAINTINGS[course]
        if to ~= nil and halves ~= nil then
            local face = shuffle.FACES[to.key]
            if face ~= nil and (to.key ~= key or ownToo == true) then
                out[halves.top] = face.top
                out[halves.bottom] = face.bottom
            end
        end
    end

    if split ~= nil then
        for field, key in pairs(shuffle.SPLIT_PAINTINGS) do
            local to = byKey[key]
            if to ~= nil and shuffle.FACES[to.key] ~= nil then split[field] = to.key end
        end
    end
    return out
end

shuffle.SPLIT_PAINTINGS = { thi_huge_painting = "thi", thi_tiny_painting = "thitiny" }

local splitShown, splitOriginal = {}, {}

local function painting_textures(field)
    local values = gPaintingValues
    local painting = values ~= nil and values[field] or nil
    if painting == nil then return nil end
    local array = painting.textureArray
    if array == nil then return nil end
    return array
end

function shuffle.split_face(field, faceKey)
    local array = painting_textures(field)
    if array == nil then return false end
    if faceKey == nil then
        local kept = splitOriginal[field]
        if kept ~= nil then
            array[1], array[2] = kept[1], kept[2]
        end
        splitShown[field] = nil
        return true
    end
    local face = shuffle.FACES[faceKey]
    if face == nil then return false end
    local bottom = get_texture_info(face.bottom)
    local top = get_texture_info(face.top)
    if bottom == nil or top == nil or bottom.texture == nil or top.texture == nil then
        return false
    end
    if splitOriginal[field] == nil then
        splitOriginal[field] = { array[1], array[2] }
    end
    array[1], array[2] = bottom.texture, top.texture
    splitShown[field] = faceKey
    return true
end

function shuffle.split_faces_off()
    for field in pairs(splitShown) do shuffle.split_face(field, nil) end
    splitShown = {}
end

local facesShown = {}

function shuffle.show_faces(force)
    local wanted = shuffle.faces()
    local changed = 0
    for target, shown in pairs(facesShown) do
        if wanted[target] == nil then
            texture_override_reset(target)
            facesShown[target] = nil
            changed = changed + 1
        elseif wanted[target] ~= shown then
            facesShown[target] = nil
        end
    end
    for target, replacement in pairs(wanted) do
        if force == true or facesShown[target] ~= replacement then
            local info = get_texture_info(replacement)
            if info ~= nil then
                texture_override_set(target, info)
                facesShown[target] = replacement
                changed = changed + 1
            end
        end
    end

    local split = shuffle.splitWanted or {}
    for field in pairs(splitShown) do
        if split[field] == nil then
            shuffle.split_face(field, nil)
            changed = changed + 1
        end
    end
    for field, key in pairs(split) do
        if (force == true or splitShown[field] ~= key) and shuffle.split_face(field, key) then
            changed = changed + 1
        end
    end
    return changed
end

function shuffle.hide_faces()
    for target in pairs(facesShown) do texture_override_reset(target) end
    facesShown = {}
    shuffle.split_faces_off()
end

local faceTick = 0
local downSeen = nil
function shuffle.face_tick()

    local down = shuffle.stands_down()
    if down ~= downSeen then
        downSeen = down
        faceTick = 0
        return shuffle.show_faces(true)
    end
    faceTick = faceTick + 1
    if faceTick < 15 then return end
    faceTick = 0
    shuffle.show_faces()
end

hook_event(HOOK_ON_EXIT, function() shuffle.hide_faces() end)

function shuffle.faces_now()
    faceTick = 0
    return shuffle.show_faces(true)
end

hook_event(HOOK_ON_LEVEL_INIT, function() shuffle.faces_now() end)
hook_event(HOOK_ON_WARP, function() shuffle.faces_now() end)

local function clock_seed(avoid)
    local now = (OF.util.optional("get_time", 0) or 0)
        + math.floor(((OF.util.optional("get_global_timer", 0) or 0)) % 100000)
    local seed = (step_of(now) % 9000) + 1000
    if avoid ~= nil and seed == avoid then
        seed = (step_of(seed) % 9000) + 1000
    end
    return seed
end

local drifting = false

local seatsAt = {}

function shuffle.drifting() return drifting end

local function set_drift(on)
    drifting = on and true or false
    seatsAt = {}
    if drifting then shuffle.watch_seats() end
end

function shuffle.drift(on)
    if not OF.util.is_host() then return false, "Only the host." end

    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() then
        return false, "A round or a run has the castle out on loan."
    end
    set_drift(on)
    return true
end

local function seat_place(np)
    if np == nil or not np.connected then return nil end
    local level, area = np.currLevelNum, np.currAreaIndex
    if type(level) ~= "number" or type(area) ~= "number" then return nil end
    if level <= 0 then return nil end
    return tostring(level) .. ":" .. tostring(area)
end

function shuffle.watch_seats()
    local moved = false
    for index = 0, (MAX_PLAYERS or 16) - 1 do
        local np = gNetworkPlayers[index]
        local place = seat_place(np)
        if place == nil then
            seatsAt[index] = nil
        elseif seatsAt[index] == nil then
            seatsAt[index] = place
        elseif seatsAt[index] ~= place then
            seatsAt[index] = place
            if np.currLevelNum ~= LEVEL_CASTLE then moved = true end
        end
    end
    return moved
end

local function redraw()
    local seed = shuffle.seed()
    if seed <= 0 then return false end
    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() then return false end
    OF.util.publish(shuffle.SEED_KEY, clock_seed(seed))
    return true
end

function shuffle.drift_tick()
    if not drifting then return false end
    if not OF.util.is_host() then return false end
    if not shuffle.watch_seats() then return false end
    return redraw()
end

hook_event(HOOK_UPDATE, function()
    shuffle.drift_tick()
    shuffle.face_tick()
end)

function shuffle.roll(wanted)
    if not OF.util.is_host() then return false, "Only the host." end

    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() then
        return false, "A round or a run has the castle out on loan."
    end
    local seed = tonumber(wanted)
    if seed == nil then seed = clock_seed() end
    seed = math.floor(seed)
    if seed < 1 then return false, "A seed is a number above zero." end
    set_drift(false)
    OF.util.publish(shuffle.SEED_KEY, seed)
    return true
end

function shuffle.borrow_seed(seed)
    if not OF.util.is_host() then return false end
    seed = math.floor(tonumber(seed) or 0)
    if seed < 0 then return false end
    if shuffle.seed() == seed then return false end
    OF.util.publish(shuffle.SEED_KEY, seed)
    return true
end

function shuffle.capture()
    local shaped = gGlobalSyncTable[shuffle.SHAPE_KEY]
    return { seed = shuffle.seed(),
             shape = (type(shaped) == "number") and shaped or 0,
             drift = drifting == true }
end

function shuffle.put_back(snap)
    if not OF.util.is_host() then return false end
    if type(snap) ~= "table" then return false end
    set_drift(false)
    entered = nil
    local shaped = gGlobalSyncTable[shuffle.SHAPE_KEY]
    if (type(shaped) == "number" and shaped or 0) ~= (snap.shape or 0) then
        OF.util.publish(shuffle.SHAPE_KEY, snap.shape or 0)
    end
    if shuffle.seed() ~= (snap.seed or 0) then
        OF.util.publish(shuffle.SEED_KEY, snap.seed or 0)
    end
    if snap.drift then set_drift(true) end
    return true
end

function shuffle.off()
    if not OF.util.is_host() then return false, "Only the host." end

    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() then
        return false, "A round or a run has the castle out on loan."
    end
    set_drift(false)
    entered = nil
    OF.util.publish(shuffle.SEED_KEY, 0)

    local shaped = gGlobalSyncTable[shuffle.SHAPE_KEY]
    if type(shaped) == "number" and shaped ~= 0 then
        OF.util.publish(shuffle.SHAPE_KEY, 0)
    end
    return true
end

hook_event(HOOK_BEFORE_WARP, function(destLevel, destArea, destWarpNode, arg)

    local np = gNetworkPlayers[0]
    local here = nil
    if np ~= nil then here = np.currLevelNum end

    local out = shuffle.redirect(here, destLevel, destArea, destWarpNode)
    if out == nil then return nil end

    if OF.util.asks(OF.warp, "land_warp_seen") then
        OF.warp.land_warp_seen(out.destLevel, out.destWarpNode)
    end
    return out
end)
