OF = OF or {}
OF.rules = OF.rules or {}

local rules = OF.rules

rules.peaceful = rules.peaceful or false

rules.wantRedRadar = rules.wantRedRadar or false
rules.wantSecretRadar = rules.wantSecretRadar or false

rules.doorsOpen = rules.doorsOpen or false

rules.hiddenFaces = rules.hiddenFaces or false

rules.doorsMode = rules.doorsMode or 0

rules.cannonsOpen = rules.cannonsOpen or false

rules.cannonsRound = rules.cannonsRound or false

rules.cannonFires = rules.cannonFires or false

rules.healOnTouch = rules.healOnTouch or false

rules.waterMends = (rules.waterMends ~= false)

rules.exitBack = rules.exitBack or false

rules.movesGone = rules.movesGone or 0

rules.tagsWhen = rules.tagsWhen or 1

rules.hitWhere = rules.hitWhere or 0

rules.deathShake = rules.deathShake or 0

rules.throwWhere = rules.throwWhere or 0

local HURTS = {
    INTERACT_DAMAGE, INTERACT_SHOCK, INTERACT_FLAME, INTERACT_SNUFIT_BULLET,
    INTERACT_MR_BLIZZARD, INTERACT_CLAM_OR_BUBBA, INTERACT_WHIRLPOOL,
    INTERACT_STRONG_WIND, INTERACT_TORNADO,
}

local HURTS_UNLESS_ATTACKING = {
    [INTERACT_BOUNCE_TOP]     = "not_from_below",
    [INTERACT_BOUNCE_TOP2]    = "not_from_below",
    [INTERACT_KOOPA]          = "not_from_below",
    [INTERACT_BULLY]          = "not_from_below",
    [INTERACT_HIT_FROM_BELOW] = "any",
    [INTERACT_SPINY_WALKING]  = "punch",
}

local ATTACK_BITS = {
    not_from_below = {
        INT_GROUND_POUND, INT_TWIRL, INT_PUNCH, INT_KICK, INT_TRIP,
        INT_SLIDE_KICK, INT_FAST_ATTACK_OR_SHELL, INT_HIT_FROM_ABOVE,
    },
    any = {
        INT_GROUND_POUND, INT_TWIRL, INT_PUNCH, INT_KICK, INT_TRIP,
        INT_SLIDE_KICK, INT_FAST_ATTACK_OR_SHELL, INT_HIT_FROM_ABOVE,
        INT_HIT_FROM_BELOW,
    },
    punch = { INT_PUNCH },
}

local METAL_IS_AN_ATTACK = {
    [INTERACT_BOUNCE_TOP]     = true,
    [INTERACT_BOUNCE_TOP2]    = true,
    [INTERACT_KOOPA]          = true,
    [INTERACT_BULLY]          = true,
    [INTERACT_HIT_FROM_BELOW] = true,
}

local function would_attack(m, obj, interactType)
    local kind = HURTS_UNLESS_ATTACKING[interactType]
    if kind == nil then return false end
    if METAL_IS_AN_ATTACK[interactType]
        and OF.util.has_flag(m.flags, MARIO_METAL_CAP) then
        return true
    end
    if determine_interaction == nil or obj == nil then return false end
    local ok, interaction = pcall(determine_interaction, m, obj)
    if not ok or type(interaction) ~= "number" then return false end
    for _, bit in ipairs(ATTACK_BITS[kind]) do
        if OF.util.has_flag(interaction, bit) then return true end
    end
    return false
end

local CAP_WING   = 1800
local CAP_METAL  = 600
local CAP_VANISH = 600
local CAP_TOTWC  = 1200
local CAP_COTMC  = 600
local CAP_VCUTM  = 600

local function cap_scaled(base, percent)
    return math.floor(base * percent / 100)
end

local KOOPA_BOB   = 4.0
local KOOPA_THI   = 6.0
local KOOPA_CATCH = 8.0

local BALL_BOB     = 20.0
local BALL_BOB2    = 10.0
local BALL_TTM     = 20.0
local BALL_THI_BIG = 25.0
local BALL_THI_SML = 10.0

local WDW_SPEED = 10.0

local KING_FVEL = 3.0
local KING_YAW  = 0x100

local PENGUIN_RADIUS     = 200.0
local PENGUIN_BIG_RADIUS = 350.0

local function scaled(base, percent)
    return base * percent / 100
end

local function percent_of(now, base)
    if type(now) ~= "number" or now <= 0 or base <= 0 then return 100 end
    return math.floor(now * 100 / base + 0.5)
end

local CEILING_DEFAULT = 20000

local BULLY_DEATH_DEFAULT = 1030.0

local GATE_DEFAULTS = {
    CourtyardBoosRequirement = 12,
    GrateStarRequirement     = 120,
    MipsStar1Requirement     = 15,
    MipsStar2Requirement     = 50,
    ToadStar1Requirement     = 12,
    ToadStar2Requirement     = 25,
    ToadStar3Requirement     = 35,
}

function rules.scale_the_gates(percent)
    for name, base in pairs(GATE_DEFAULTS) do
        gBehaviorValues[name] = math.floor(base * percent / 100)
    end
end

local land = {

    ask = {},

    shadowsOff = false,

    fields = {
        floorLowerLimit = true,
        floorLowerLimitMisc = true,
        floorLowerLimitShadow = true,
        cellHeightLimit = true,
    },
}

local function ceiling_now()
    local asked = land.ask.cellHeightLimit
    if type(asked) == "number" then return asked end
    return CEILING_DEFAULT
end

function rules.set_land_limit(field, value)
    if gLevelValues == nil then return false end
    if land.fields[field] ~= true then return false end
    if type(value) ~= "number" then return false end
    land.ask[field] = value

    if field == "floorLowerLimitShadow" and land.shadowsOff then return false end
    gLevelValues[field] = value
    return true
end

function rules.land_limit_base(field)
    if field == "cellHeightLimit" then return CEILING_DEFAULT end
    if field == "floorLowerLimitShadow" then return land.shadowBase end
    return nil
end

function rules.reset_the_lid()
    gLevelValues.cellHeightLimit = ceiling_now()
end

function rules.set_star_home(field, x, y, z)
    if gLevelValues == nil then return false end
    if type(field) ~= "string" then return false end
    if type(x) ~= "number" or type(y) ~= "number"
        or type(z) ~= "number" then return false end
    local all = gLevelValues.starPositions
    if all == nil then return false end
    local spot = all[field]
    if spot == nil then return false end

    if type(spot.x) ~= "number" or type(spot.y) ~= "number"
        or type(spot.z) ~= "number" then return false end
    spot.x, spot.y, spot.z = x, y, z
    return true
end

function rules.set_bully_death(value)
    if gBehaviorValues == nil then return false end
    if type(value) ~= "number" then return false end

    if type(gBehaviorValues.ChillBullyDeathPosY) ~= "number" then return false end
    gBehaviorValues.ChillBullyDeathPosY = value
    return true
end

function rules.bully_death_base()
    return BULLY_DEATH_DEFAULT
end

do
    local lodsShipped = nil
    function rules.wear_lods(on)
        if gBehaviorValues == nil then return false end
        local now = gBehaviorValues.ProcessLODs
        if now == nil then return false end
        if on then
            if lodsShipped == nil then lodsShipped = now end
            gBehaviorValues.ProcessLODs = 1
            return true
        end
        if lodsShipped ~= nil then
            gBehaviorValues.ProcessLODs = lodsShipped
            lodsShipped = nil
        end
        return true
    end
end

local function hold_the_lid(m)
    if m == nil or m.playerIndex ~= 0 then return end

    local above = rules.step_setting("lid", "above", nil)
    if above == nil then return end

    local bottom = nil
    if gLevelValues ~= nil and type(gLevelValues.floorLowerLimit) == "number" then
        bottom = gLevelValues.floorLowerLimit
    end

    local floor = m.floorHeight
    if type(floor) ~= "number" then return rules.reset_the_lid() end

    if bottom ~= nil and floor <= bottom then return rules.reset_the_lid() end

    local lid = floor + above

    if lid >= ceiling_now() or lid > 32767 or lid < -32768 then
        return rules.reset_the_lid()
    end

    local y = m.pos ~= nil and m.pos.y or nil
    if type(y) ~= "number" or y >= lid then return rules.reset_the_lid() end

    gLevelValues.cellHeightLimit = lid
end

local SURFACE_FLOOR_MIN_Y = 0.01
local SURFACE_CEIL_LIMIT_Y = -0.01
local WALL_RADIUS_CLAMP = 200
local LIVES_CEILING = 100
local COINS_CEILING = 999
local KING_WHOMP_HEALTH = 3

local CAP_SEQUENCES = {
    { field = "wingCapSequence",   base = 14 },
    { field = "metalCapSequence",  base = 15 },
    { field = "vanishCapSequence", base = 14 },
    { field = "shellSequence",     base = 14 + 0x80 },
}

function rules.set_cap_music(seq)
    if gLevelValues == nil then return false end
    for _, row in ipairs(CAP_SEQUENCES) do
        gLevelValues[row.field] = seq or row.base
    end
    return true
end

local PAINTING_FIELDS = {
    "cotmc_painting", "bob_painting", "ccm_painting", "wf_painting",
    "jrb_painting", "lll_painting", "ssl_painting", "hmc_painting",
    "ddd_painting", "wdw_painting", "thi_tiny_painting", "ttm_painting",
    "ttc_painting", "sl_painting", "thi_huge_painting", "ttm_slide_painting",
}

local paintingWasAt = {}

function rules.fade_the_paintings(alpha)
    local values = gPaintingValues
    if values == nil then return 0 end
    local touched = 0
    for _, field in ipairs(PAINTING_FIELDS) do
        local painting = values[field]
        if painting ~= nil then
            if paintingWasAt[field] == nil then
                local was = painting.alpha
                paintingWasAt[field] = type(was) == "number" and was or 255
            end
            painting.alpha = alpha or paintingWasAt[field]
            touched = touched + 1
        end
    end
    return touched
end

local boxesWere = nil

local function box_defaults()
    if boxesWere == nil then
        local got = OF.util.optional("get_exclamation_box_contents", nil)
        if type(got) ~= "table" then return nil end
        local laid = {}
        for _, row in pairs(got) do
            if type(row) == "table" and type(row.id) == "number" then
                table.insert(laid, row)
            end
        end
        if #laid == 0 then return nil end
        table.sort(laid, function(a, c) return a.id < c.id end)
        boxesWere = laid
    end
    return boxesWere
end

rules.box_defaults = box_defaults

function rules.reflection_note()
    if rules.step("reflection") == 0 then
        return OF.lang.t("The castle's mirror room, and only that room.")
    end
    return OF.lang.t("Only the castle's mirror room has one to change.")
end

function rules.textbox_note()
    if rules.step("textbox") == 0 then
        return OF.lang.t("Signs, speeches and star messages all use it.")
    end
    return OF.lang.t("Every message box in the game, colours and width.")
end

function rules.tremor_note()
    local every = rules.step_setting("tremor", "every", nil)
    if every == nil then
        return OF.lang.t("The camera is shaken on a clock, wherever you are.")
    end
    return OF.lang.fill("A shake every @ second(s), everywhere.",
        string.format("%.1f", every / 30))
end

local function star_behavior()
    local rows = box_defaults()
    if rows == nil then return nil end
    for _, row in ipairs(rows) do
        if row.id == 8 then return row.behavior end
    end
    return nil
end

function rules.fill_the_boxes(pick)
    local rows = box_defaults()
    if rows == nil then return 0 end

    local wanted = nil
    if pick ~= nil then
        for _, row in ipairs(rows) do
            if row.id == pick then wanted = row end
        end
        if wanted == nil then return 0 end
    end

    local star = star_behavior()
    local built, changed = {}, 0
    for _, row in ipairs(rows) do
        local model, behavior = row.model, row.behavior
        if wanted ~= nil and (star == nil or row.behavior ~= star) then
            model, behavior = wanted.model, wanted.behavior
            changed = changed + 1
        end
        table.insert(built, {
            id = row.id, unused = row.unused or 0,
            firstByte = row.firstByte or 0,
            model = model, behavior = behavior,
        })
    end

    OF.util.optional("set_exclamation_box_contents", nil, built)
    return changed
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, hold_the_lid, OF.LOCAL_MARIO)

local function fold_s16(value)
    return ((value + 0x8000) % 0x10000) - 0x8000
end

function rules.dress_the_mirror(node, playerIndex)
    if node == nil then return false end

    if OF.util.asks(OF.roundscope, "hides_reflection")
        and OF.roundscope.hides_reflection(playerIndex) then
        local flags = node.node ~= nil and node.node.flags or nil
        if type(flags) == "number" and OF.util.has_flag(flags, GRAPH_RENDER_ACTIVE) then
            node.node.flags = flags - GRAPH_RENDER_ACTIVE
        end
        return true
    end
    local step = rules.step("reflection")
    if step == 0 then return false end

    if rules.step_setting("reflection", "hide", false) then

        local flags = node.node ~= nil and node.node.flags or nil
        if type(flags) == "number" and OF.util.has_flag(flags, GRAPH_RENDER_ACTIVE) then
            node.node.flags = flags - GRAPH_RENDER_ACTIVE
        end
        return true
    end

    local scale = rules.step_setting("reflection", "scale", nil)
    if scale ~= nil and node.scale ~= nil then
        node.scale.x = node.scale.x * scale
        node.scale.y = node.scale.y * scale
        node.scale.z = node.scale.z * scale
        return true
    end

    local roll = rules.step_setting("reflection", "roll", nil)
    if roll ~= nil and node.angle ~= nil then
        node.angle.z = fold_s16(node.angle.z + roll)
        return true
    end

    local spin = rules.step_setting("reflection", "spin", nil)
    if spin ~= nil and node.angle ~= nil then

        local timer = OF.util.optional("get_global_timer", 0) or 0
        node.angle.y = fold_s16(node.angle.y + spin * timer)
        return true
    end
    return false
end

hook_event(HOOK_MIRROR_MARIO_RENDER, rules.dress_the_mirror)

function rules.dress_the_text_box()
    local width = rules.step_setting("textbox", "width", nil)
    if width ~= nil then
        OF.util.optional("set_min_dialog_width", nil, width)
    end
    local bg = rules.step_setting("textbox", "bg", nil)
    local fg = rules.step_setting("textbox", "fg", nil)
    if type(bg) ~= "table" or type(fg) ~= "table" then return width ~= nil end
    OF.util.optional("set_dialog_override_color", nil,
        bg[1], bg[2], bg[3], bg[4], fg[1], fg[2], fg[3], fg[4])
    return true
end

function rules.plain_text_box()
    OF.util.optional("reset_dialog_override_color", nil)
    OF.util.optional("reset_dialog_override_pos", nil)
    OF.util.optional("set_min_dialog_width", nil, 0)
    return true
end

local tremorLeft = 0
local tremorWas = 0

function rules.shake_the_room(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    local step = rules.step("tremor")
    if step ~= tremorWas then
        tremorWas = step
        tremorLeft = 0
    end
    if step == 0 then return false end

    tremorLeft = tremorLeft - 1
    if tremorLeft > 0 then return false end
    tremorLeft = rules.step_setting("tremor", "every", 300)

    local preset = _G[rules.step_setting("tremor", "shake", "SHAKE_POS_SMALL")]
    if type(preset) ~= "number" then return false end
    if m.pos == nil then return false end

    OF.util.optional("set_camera_shake_from_point", nil, preset,
        m.pos.x, m.pos.y, m.pos.z)
    return true
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, rules.shake_the_room, OF.LOCAL_MARIO)

local DEATH_ACTIONS = {}
for _, action in ipairs({ ACT_BUBBLED, ACT_DROWNING, ACT_WATER_DEATH,
    ACT_STANDING_DEATH, ACT_QUICKSAND_DEATH, ACT_ELECTROCUTION,
    ACT_SUFFOCATION, ACT_DEATH_ON_STOMACH, ACT_DEATH_ON_BACK,
    ACT_EATEN_BY_BUBBA }) do
    if type(action) == "number" then DEATH_ACTIONS[action] = true end
end

local deathWas = {}

function rules.enrol_forgetting()
    if rules.forgettingDeaths then return true end
    if not OF.util.asks(OF.util, "on_forget_seat") then return false end
    rules.forgettingDeaths = OF.util.on_forget_seat("a death this lobby felt",
        function(localIndex)
            deathWas[localIndex] = nil
        end)
    return rules.forgettingDeaths == true
end

function rules.shake_where_they_died(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    rules.enrol_forgetting()

    local on = rules.step("deathshake") ~= 0
    local me = gNetworkPlayers[0]
    local shook = false

    for _, row in ipairs(OF.util.connected_players()) do
        local seat = row.localIndex

        local other = gMarioStates[seat]
        local action = nil
        if other ~= nil then action = other.action end
        local dying = type(action) == "number" and DEATH_ACTIONS[action] == true

        if dying and not deathWas[seat] and on and me ~= nil and other ~= nil
            and row.np ~= nil
            and OF.util.seen_here(seat)
            and other.pos ~= nil then

            local preset = _G["SHAKE_POS_MEDIUM"]
            if type(preset) == "number" then
                OF.util.optional("set_camera_shake_from_point", nil, preset,
                    other.pos.x, other.pos.y, other.pos.z)
                shook = true
            end
        end

        deathWas[seat] = dying
    end

    return shook
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, rules.shake_where_they_died, OF.LOCAL_MARIO)

function rules.rounds_keep_handouts()
    return false
end

rules.LIST = {
    {
        key = "interactions", id = "pi", name = "Players touching",
        blurb = "whether one player can stand on, push or hit another",
        section = "Between players",
        options = {
            { value = 0, name = "pass through each other" },
            { value = 1, name = "solid" },
            { value = 2, name = "fighting" },
            { value = 3, name = "solid, and touching heals" },
        },

        plain = 1,
        perMode = "In modes.ROUND_RULE_KEYS and unanimous there: fourteen modes"
            .. " write this themselves in setup, which runs after the lock and"
            .. " wins, and the fourteen that do not are the fourteen with no"
            .. " business inheriting a brawl.",

        note = function() return rules.interactions_note() end,
        get = function()
            if rules.healOnTouch
                and gServerSettings.playerInteractions == PLAYER_INTERACTIONS_SOLID then
                return 3
            end
            return gServerSettings.playerInteractions
        end,
        set = function(value)
            rules.healOnTouch = (value == 3)
            if value == 3 then
                gServerSettings.playerInteractions = PLAYER_INTERACTIONS_SOLID
            else
                gServerSettings.playerInteractions = value
            end
        end,
    },

    {
        key = "fighting", id = "pv", name = "Fighting style",
        blurb = "how a punch leads into the next one",
        section = "Between players",
        options = {
            { value = 0, name = "classic" },
            { value = 1, name = "combos" },
        },
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Fighting style\" at the game's own value, and a mode that"
            .. " wants its own answer can rules.lend(\"fighting\", ...) it from its own"
            .. " setup.",
        note = function() return rules.fighting_note() end,
        get = function() return gServerSettings.pvpType end,
        set = function(value) gServerSettings.pvpType = value end,
    },

    {
        key = "hitwhere", id = "hw", name = "Where a hit counts",
        blurb = "a punch only lands from the direction the lobby allows",
        section = "Between players",
        options = {
            { value = 0, name = "from anywhere" },
            { value = 1, name = "only from above" },
            { value = 2, name = "only from behind" },
            { value = 3, name = "only in mid-air" },
        },

        note = function() return rules.hitwhere_note() end,
        plain = 0,
        perMode = "No column. Where a punch may land is the shape of every"
            .. " fighting round in this mod, and a mode that wants a hit"
            .. " refused from the front can refuse it in its own"
            .. " `on_pvp_attack` - which runs after the lock and therefore"
            .. " wins - rather than inherit a session's house rule.",
        get = function() return rules.hitWhere or 0 end,
        set = function(value) rules.hitWhere = value end,
    },
    {
        key = "knockback", id = "kb", name = "Knockback",
        blurb = "how far a hit throws whoever takes it",
        section = "Between players",

        options = {
            { value = 0,   name = "none" },
            { value = 5,   name = "a tap" },
            { value = 10,  name = "light" },
            { value = 25,  name = "normal" },
            { value = 40,  name = "firm" },
            { value = 60,  name = "heavy" },
            { value = 100, name = "brutal" },
            { value = 160, name = "silly" },
            { value = 255, name = "off the map" },
        },

        plain = 25,
        perMode = "In modes.ROUND_RULE_KEYS and unanimous there: this plain"
            .. " exists because silly knockback is a different game from the"
            .. " one every fighting mode was balanced for, so handing it back"
            .. " to them undoes the decision rather than refining it.",
        get = function() return gServerSettings.playerKnockbackStrength end,
        set = function(value) gServerSettings.playerKnockbackStrength = value end,
    },

    {
        key = "throwdir", id = "td", name = "Which way a hit throws you",
        blurb = "a hit throws you in towards the middle of the level",
        section = "Between players",
        options = {
            { value = 0, name = "the way the punch was facing" },
            { value = 1, name = "in towards the level's centre" },
        },
        plain = 0,
        perMode = "No column, and for the row above's reason said of the"
            .. " direction rather than the distance: a lobby that aims every"
            .. " hit inwards has decided how Knock Out and Sumo are played without"
            .. " saying so, and a mode that wants a hit aimed somewhere can aim"
            .. " it itself rather than inherit a lobby's flavour.",
        note = function() return rules.throwdir_note() end,
        get = function() return rules.throwWhere or 0 end,
        set = function(value) rules.throwWhere = value end,
    },
    {
        key = "bubble", id = "bd", name = "Bubble on death",
        blurb = "dying puts you in a bubble instead of costing a life",
        section = "Between players",
        options = {
            { value = 0, name = "off" },
            { value = 1, name = "on" },
        },

        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and it should not be: a mode"
            .. " that wants a death to end in a bubble writes it in its own"
            .. " setup, which runs after the lock and therefore wins, exactly"
            .. " as the fourteen that want fighting do. A per-mode column would"
            .. " be twenty-eight decisions about a rule twenty-eight modes have"
            .. " no opinion on - and the two that would want it back are the"
            .. " two that can say so in one line.",
        get = function() return gServerSettings.bubbleDeath end,
        set = function(value) gServerSettings.bubbleDeath = value end,
    },
    {
        key = "bounce", id = "bl", name = "Bouncy level bounds",
        blurb = "the level's edges throw you back instead of falling off",
        section = "Getting around",
        options = {
            { value = 0, name = "off" },
            { value = 1, name = "on" },
            { value = 2, name = "on with a cap" },
        },

        plain = 0,
        perMode = "A column in modes.ROUND_RULE_KEYS that no round keeps any more."
            .. " Since R1 and R3 every round flattens it - Hide and Seek, Manhunt"
            .. " and Murder included, whose originals leave a fall to the game's"
            .. " own death planes - and the column stays as the machinery a mode"
            .. " would use if one ever earned the lobby's bounds back.",
        get = function() return gServerSettings.bouncyLevelBounds end,
        set = function(value) gServerSettings.bouncyLevelBounds = value end,
    },

    {
        key = "nametags", id = "nt", name = "Name tags",
        blurb = "a name floating over everybody's head",
        section = "Between players", look = true,
        plain = 1,
        perMode = "Not in modes.ROUND_RULE_KEYS, but three modes already lend it by"
            .. " hand: Last One Standing and Murder turn it on so a chase has a name"
            .. " to give chase to, and Zombies turns it off. Every mode with no"
            .. " opinion plays the game's own tags rather than whatever the lobby had"
            .. " chosen.",
        note = function() return rules.nametag_note() end,

        options = {
            { value = 0, name = "none" },
            { value = 1, name = "over every head" },
            { value = 2, name = "only while they stand still" },
            { value = 3, name = "only close by" },
            { value = 4, name = "what they are carrying" },
        },

        get = function() return rules.tag_shape() end,
        set = function(value)
            rules.tagsField = (value == 0) and 0 or 1

            gServerSettings.nametags = rules.engineTagsHeld and 0 or rules.tagsField
            rules.tagsWhen = value
        end,
    },

    {
        key = "ranktag", id = "rk", name = "Rank colour on name tags",
        blurb = "a name over a head is drawn in the colour of its rank",
        section = "Between players", look = true,
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Rank colour on name tags\" at the game's own value, and a"
            .. " mode that wants its own answer can rules.lend(\"ranktag\", ...) it"
            .. " from its own setup.",
    },

    {
        key = "health", id = "hp", name = "Health on name tags",
        blurb = "the name over a head carries their health with it",
        section = "Between players", look = true,
        options = {
            { value = 0, name = "off" },
            { value = 1, name = "on" },
        },

        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS. Last One Standing lends it on beside"
            .. " nametags, so a chase can see who is close to going out; every other"
            .. " mode plays the meter's own resting state, off, rather than a lobby's"
            .. " leftover choice.",
        get = function()
            if OF.util.asks(OF.charselect, "owns_nametag_health")
                and OF.charselect.owns_nametag_health() then
                return 0
            end
            return OF.util.flag(gNametagsSettings.showHealth)
        end,
        set = function(value) gNametagsSettings.showHealth = (value == 1) end,
        forced = function()
            if OF.util.asks(OF.charselect, "owns_nametag_health")
                and OF.charselect.owns_nametag_health() then
                return 0, "Character Select turns this off on every nametag."
            end
        end,
    },

    {
        key = "whereabouts", id = "wa", name = "Everybody's whereabouts",
        blurb = "where everybody in the castle is, on show to the lobby",
        section = "Between players",
        vanilla = 1,
        options = {
            { value = 0, name = "hidden" },
            { value = 1, name = "shown" },
        },

        plain = 1,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Everybody's whereabouts\" at the game's own value, and a mode"
            .. " that wants its own answer can rules.lend(\"whereabouts\", ...) it from"
            .. " its own setup.",
        get = function()
            if OF.util.asks(OF.charselect, "owns_player_list")
                and OF.charselect.owns_player_list() then
                return 1
            end
            return OF.util.flag(gServerSettings.enablePlayerList)
        end,
        set = function(value)
            gServerSettings.enablePlayerList = value
            gServerSettings.enablePlayersInLevelDisplay = value
        end,
        forced = function()
            if OF.util.asks(OF.charselect, "owns_player_list")
                and OF.charselect.owns_player_list() then
                return 1, "Character Select draws its own list, and it cannot be hidden."
            end
        end,
    },

    {
        key = "pause", id = "pa", name = "Pause anywhere",
        blurb = "the pause menu opens outside the castle too",
        section = "The lobby",
        options = {
            { value = 0, name = "off" },
            { value = 1, name = "on" },
        },
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Pause anywhere\" at the game's own value, and a mode that"
            .. " wants its own answer can rules.lend(\"pause\", ...) it from its own"
            .. " setup.",
        get = function() return gServerSettings.pauseAnywhere end,
        set = function(value) gServerSettings.pauseAnywhere = value end,
    },

    {
        key = "enemies", id = "en", name = "Enemies",
        blurb = "whether the level's creatures may land a hit at all",
        section = "The lobby",
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Enemies\" at the game's own value, and a mode that wants its"
            .. " own answer can rules.lend(\"enemies\", ...) it from its own setup.",
        note = function() return rules.enemies_note() end,
        options = {
            { value = 0, name = "can hurt you" },
            { value = 1, name = "cannot hurt you" },
        },
        get = function() return rules.peaceful and 1 or 0 end,
        set = function(value) rules.peaceful = (value == 1) end,
    },

    {
        key = "moveban", id = "mb", name = "Moves",
        blurb = "the move this lobby does without",
        section = "The lobby",
        note = function() return rules.moveban_note() end,

        options = {
            { value = 0, name = "all of them" },
            { value = 1, name = "no long jump" },
            { value = 2, name = "no ground pound" },
            { value = 3, name = "no dive" },
            { value = 4, name = "no long jump or dive" },
            { value = 5, name = "no backflip or side flip" },
            { value = 6, name = "no double or triple jump" },
            { value = 7, name = "no flips and no dive" },
            { value = 8, name = "no ground pound or dive" },
            { value = 9, name = "one jump and nothing else" },
            { value = 10, name = "no long jump or flips" },

            { value = 11, name = "a different one each level" },
        },
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS. A round now plays every move"
            .. " the game has; a mode that wants one gone - the way `Fancy"
            .. " moves` once let a lobby ask - takes it away in its own setup"
            .. " rather than inheriting whatever the lobby had banned for a"
            .. " different evening.",
        get = function() return rules.movesGone or 0 end,
        set = function(value) rules.movesGone = value end,
    },

    {
        key = "spawngrace", id = "sg", name = "Grace after landing",
        blurb = "how long you are safe from harm after you arrive",
        section = "Between players",
        vanilla = 2,
        options = {
            { value = 0, name = "no grace" },
            { value = 1, name = "one second" },
            { value = 2, name = "two seconds" },
            { value = 3, name = "three seconds" },
            { value = 5, name = "five seconds" },
        },
        plain = 2,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Grace after landing\" at the game's own value, and a mode"
            .. " that wants its own answer can rules.lend(\"spawngrace\", ...) it from"
            .. " its own setup.",
        get = function()
            local seconds = rules.graceSeconds
            if type(seconds) ~= "number" or seconds < 0 then return 0 end
            return seconds
        end,
        set = function(value) rules.graceSeconds = value end,
    },
    {
        key = "redradar", id = "rr", name = "Red coin radar",
        blurb = "the red coins in this area, and how many are taken",
        section = "Helpers",
        options = {
            { value = 0, name = "off" },
            { value = 1, name = "on" },
        },
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Red coin radar\" at the game's own value, and a mode that"
            .. " wants its own answer can rules.lend(\"redradar\", ...) it from its own"
            .. " setup.",
        get = function() return rules.wantRedRadar and 1 or 0 end,

        set = function(value) rules.wantRedRadar = (value == 1) end,
    },

    {
        key = "secretradar", id = "sr", name = "Secret radar",
        blurb = "the secrets in this area, and how many are found",
        section = "Helpers",
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Secret radar\" at the game's own value, and a mode that wants"
            .. " its own answer can rules.lend(\"secretradar\", ...) it from its own"
            .. " setup.",
        note = function() return rules.secrets_note() end,
        options = {
            { value = 0, name = "off" },
            { value = 1, name = "on" },
        },

        get = function() return rules.wantSecretRadar and 1 or 0 end,
        set = function(value) rules.wantSecretRadar = (value == 1) end,
    },
    {
        key = "showsecrets", id = "vs", name = "Secrets you can see",
        blurb = "secrets a course counts but hides, drawn in place",
        section = "Helpers",
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Secrets you can see\" at the game's own value, and a mode"
            .. " that wants its own answer can rules.lend(\"showsecrets\", ...) it from"
            .. " its own setup.",
        note = function() return rules.secrets_note() end,
        options = {
            { value = 0, name = "off" },
            { value = 1, name = "on" },
        },
        get = function() return OF.util.flag(gLevelValues.visibleSecrets) end,
        set = function(value) gLevelValues.visibleSecrets = (value == 1) end,
    },
    {
        key = "bluecoins", id = "bc", name = "Blue coins before the switch",
        blurb = "a blue coin is there before anybody presses its switch",
        section = "Coins",
        options = {
            { value = 0, name = "off" },
            { value = 1, name = "on" },
        },
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Blue coins before the switch\" at the game's own value, and a"
            .. " mode that wants its own answer can rules.lend(\"bluecoins\", ...) it"
            .. " from its own setup.",
        get = function() return OF.util.flag(gLevelValues.previewBlueCoins) end,
        set = function(value) gLevelValues.previewBlueCoins = (value == 1) end,
    },
    {
        key = "captimer", id = "ct", name = "Cap timer",
        blurb = "the clock on a cap, drawn while you are wearing one",
        section = "Helpers",
        options = {
            { value = 0, name = "off" },
            { value = 1, name = "on" },
        },
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Cap timer\" at the game's own value, and a mode that wants"
            .. " its own answer can rules.lend(\"captimer\", ...) it from its own"
            .. " setup.",
        get = function() return OF.util.flag(gLevelValues.hudCapTimer) end,
        set = function(value) gLevelValues.hudCapTimer = (value == 1) end,
    },

    {
        key = "allstars", id = "as", name = "Every act at once",
        blurb = "every act of a course is open without picking one first",
        section = "Stars",
        note = "Takes effect the next time a level loads.",
        options = {
            { value = 0, name = "off" },
            { value = 1, name = "on" },
        },
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS. Hide and Seek lends it on so a hider"
            .. " can duck into any act of the course; every other mode plays the"
            .. " course's own act picker rather than whatever the lobby had left"
            .. " open.",
        get = function() return OF.util.flag(gLevelValues.disableActs) end,
        set = function(value) gLevelValues.disableActs = (value == 1) end,
    },

    {
        key = "starnumbers", id = "sn", name = "Numbers over stars",
        blurb = "a star carries the number of the act it belongs to",
        section = "Stars",
        options = {
            { value = 0, name = "off" },
            { value = 1, name = "on" },
        },
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Numbers over stars\" at the game's own value, and a mode that"
            .. " wants its own answer can rules.lend(\"starnumbers\", ...) it from its"
            .. " own setup.",
        get = function() return OF.util.flag(gLevelValues.showStarNumber) end,
        set = function(value) gLevelValues.showStarNumber = (value == 1) end,
    },

    {
        key = "stardialog", id = "sx", name = "The star text box",
        blurb = "what the game says when a star is taken",
        section = "Stars",
        options = {
            { value = 0, name = "the game's own" },
            { value = 1, name = "no save prompt" },
            { value = 2, name = "nothing at all" },
        },

        plain = 2,
        perMode = "No column: this was asked for by name for every round, and"
            .. " re-opening a settled instruction twenty-eight times is twenty-"
            .. " eight chances to lose it.",
        get = function()
            local dialog = OF.util.flag(gBehaviorValues.ShowStarDialog)
            local milestones = OF.util.flag(gBehaviorValues.ShowStarMilestones)
            if dialog == 0 and milestones == 0 then return 2 end
            if dialog == 0 or milestones == 0 then return 1 end
            return 0
        end,
        set = function(value)
            gBehaviorValues.ShowStarDialog = (value == 0)
            gBehaviorValues.ShowStarMilestones = (value <= 1)
        end,
    },

    {
        key = "starheal", id = "sh", name = "A star heals you",
        blurb = "a star fills your health back up",
        section = "Stars",
        options = {
            { value = 0, name = "off" },
            { value = 1, name = "on" },
        },
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"A star heals you\" at the game's own value, and a mode that"
            .. " wants its own answer can rules.lend(\"starheal\", ...) it from its own"
            .. " setup.",
        get = function() return OF.util.flag(gLevelValues.starHeal) end,
        set = function(value) gLevelValues.starHeal = (value == 1) end,
    },
    {
        key = "mushroomheal", id = "mh", name = "A 1-Up heals you",
        blurb = "a 1-Up fills your health back up",
        section = "Stars",
        options = {
            { value = 0, name = "off" },
            { value = 1, name = "on" },
        },
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"A 1-Up heals you\" at the game's own value, and a mode that"
            .. " wants its own answer can rules.lend(\"mushroomheal\", ...) it from its"
            .. " own setup.",
        get = function() return OF.util.flag(gLevelValues.mushroom1UpHeal) end,
        set = function(value) gLevelValues.mushroom1UpHeal = (value == 1) end,
    },

    {
        key = "coinstar", id = "cs", name = "The coin star",
        blurb = "how many coins a course needs for its coin star",
        section = "Coins",
        vanilla = 100,

        options = {
            { value = 10,  name = "at 10 coins" },
            { value = 20,  name = "at 20 coins" },
            { value = 30,  name = "at 30 coins" },
            { value = 50,  name = "at 50 coins" },
            { value = 70,  name = "at 70 coins" },
            { value = 100, name = "at 100 coins" },
        },
        plain = 100,
        perMode = "Not in modes.ROUND_RULE_KEYS. Bank and Coin Rush both lend it to the"
            .. " wire's own ceiling so a coin total never fires the vanilla star"
            .. " mid-round; every other mode plays the game's own hundred coins.",
        get = function() return gLevelValues.coinsRequiredForCoinStar or 100 end,
        set = function(value) gLevelValues.coinsRequiredForCoinStar = value end,
    },

    {
        key = "stardoors", id = "sd", name = "Star doors",
        blurb = "whether a star door asks for its stars before it opens",
        section = "Stars",
        options = {
            { value = 0, name = "need their stars" },
            { value = 1, name = "always open" },
        },
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Star doors\" at the game's own value, and a mode that wants"
            .. " its own answer can rules.lend(\"stardoors\", ...) it from its own"
            .. " setup.",
        get = function() return rules.doorsOpen and 1 or 0 end,
        set = function(value) rules.doorsOpen = (value == 1) end,
    },

    {
        key = "splitstars", id = "pc", name = "Star count",
        blurb = "one shared star total, or everybody counts their own",
        section = "Stars",
        hostOnly = true,
        options = {
            { value = 0, name = "shared by the lobby" },
            { value = 1, name = "everybody counts their own" },
        },
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Star count\" at the game's own value, and a mode that wants"
            .. " its own answer can rules.lend(\"splitstars\", ...) it from its own"
            .. " setup.",
        note = function() return rules.split_note() end,

        get = function()
            if not OF.util.asks(OF.split, "on") then return 0 end
            return OF.split.on() and 1 or 0
        end,
        set = function(value)
            if not OF.util.asks(OF.split, "set_on") then return end
            OF.split.set_on(value == 1)
        end,
    },

    {
        key = "opendoors", id = "od", name = "Doors",
        blurb = "what the castle's ordinary doors do as you walk up",
        section = "The lobby",

        note = function()
            local mode = rules.value("opendoors") or 0
            if mode == 0 then return nil end

            if mode == 3 then
                return OF.lang.t("Every other door in the castle behaves as it always did.")
            end
            return OF.lang.t("Warp doors between levels always stay shut.")
        end,

        options = {
            { value = 0, name = "open normally" },
            { value = 1, name = "stand open" },
            { value = 2, name = "open as you approach" },
            { value = 3, name = "only the star doors stand open" },
        },

        plain = 2,
        perMode = "No column, and for the same reason as the star box: the host"
            .. " asked for open doors in every round by name. The stop it lands"
            .. " on was picked so a castle still sounds like a castle.",
        get = function() return rules.doorsMode or 0 end,
        set = function(value) rules.doorsMode = value end,
    },

    {
        key = "cannons", id = "cn", name = "Cannons",
        blurb = "every cannon in the level standing open",
        section = "The lobby",
        note = function()
            if (rules.value("cannons") or 0) == 0 then return nil end
            return OF.lang.t("A cannon opened this way is open until the level reloads.")
        end,

        options = {
            { value = 0, name = "as the save left them" },
            { value = 1, name = "all open" },
            { value = 2, name = "and they turn all the way round" },
        },

        plain = 1,
        perMode = "No column, and the other half of the doors sentence: a round"
            .. " is played on the level the level is, not on the subset of it"
            .. " somebody's save file has paid for.",

        get = function()
            if rules.cannonsRound then return 2 end
            return rules.cannonsOpen and 1 or 0
        end,
        set = function(value)
            rules.cannonsOpen = (value >= 1)
            rules.cannonsRound = (value == 2)
        end,
    },

    {
        key = "cannonfire", id = "cf", name = "Cannons fire by themselves",
        blurb = "an open cannon throws out whoever is sitting in it",
        section = "The lobby",
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Cannons fire by themselves\" at the game's own value, and a"
            .. " mode that wants its own answer can rules.lend(\"cannonfire\", ...) it"
            .. " from its own setup.",
        note = function()
            if (rules.value("cannonfire") or 0) == 0 then return nil end
            return OF.lang.t("Five seconds in the barrel, counted down on screen, and then it fires.")
        end,
        options = {
            { value = 0, name = "in rounds and runs" },
            { value = 1, name = "in the lobby too" },
        },
        get = function() return rules.cannonFires and 1 or 0 end,
        set = function(value) rules.cannonFires = (value == 1) end,
    },

    {

        key = "airstar", id = "ai", name = "A star caught in the air",
        blurb = "what Mario does when a star is caught in mid-air",
        section = "Stars",
        options = {
            { value = 0, name = "you fall, as the game does it" },
            { value = 1, name = "you dance where you are" },
        },
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"A star caught in the air\" at the game's own value, and a"
            .. " mode that wants its own answer can rules.lend(\"airstar\", ...) it"
            .. " from its own setup.",
        get = function() return OF.util.flag(gLevelValues.floatingStarDance) end,
        set = function(value) gLevelValues.floatingStarDance = (value == 1) end,
    },

    {
        key = "collision", id = "cb", name = "Collision",
        blurb = "which of the game's own wall and floor bugs are left in",
        section = "The lobby",
        options = {
            { value = 0, name = "the original bugs" },
            { value = 1, name = "fixed" },
            { value = 2, name = "fixed, and vanish grates give way" },
            { value = 3, name = "fixed, but walls pick themselves as they did" },
        },
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Collision\" at the game's own value, and a mode that wants"
            .. " its own answer can rules.lend(\"collision\", ...) it from its own"
            .. " setup.",
        note = function() return rules.collision_note() end,

        get = function()
            if OF.util.flag(gLevelValues.fixCollisionBugs) == 0 then return 0 end
            if OF.util.flag(gLevelValues.fixVanishFloors) == 1 then return 2 end
            if OF.util.flag(gLevelValues.fixCollisionBugsPickBestWall) == 0 then
                return 3
            end
            return 1
        end,
        set = function(value)
            gLevelValues.fixCollisionBugs = (value >= 1)

            gLevelValues.fixCollisionBugsRoundedCorners = (value >= 1)
            gLevelValues.fixCollisionBugsFalseLedgeGrab = (value >= 1)
            gLevelValues.fixCollisionBugsGroundPoundBonks = (value >= 1)
            gLevelValues.fixCollisionBugsPickBestWall = (value >= 1 and value ~= 3)
            gLevelValues.fixVanishFloors = (value == 2)
        end,
    },

    {
        key = "roomsize", id = "mp", name = "Lobby size",
        blurb = "how many players the lobby lets in",
        section = "The lobby",

        hostOnly = true,
        vanilla = 16,
        note = function() return rules.room_size_note() end,

        options = {
            { value = 1,  name = "just you" },
            { value = 2,  name = "two" },
            { value = 4,  name = "four" },
            { value = 6,  name = "six" },
            { value = 8,  name = "eight" },
            { value = 10, name = "ten" },
            { value = 12, name = "twelve" },

            { value = 16, name = "sixteen" },
        },
        get = function()
            local wanted = gServerSettings.maxPlayers
            if type(wanted) ~= "number" or wanted <= 0 then return 16 end
            return wanted
        end,
        set = function(value) gServerSettings.maxPlayers = value end,
    },

    {
        key = "stairs", id = "is", name = "Endless stairs",
        blurb = "what the endless staircase asks for before it lets you up",
        section = "Getting around",
        options = {
            { value = 70, name = "seventy stars, as the game wants" },
            { value = 0,  name = "open to everybody" },
            { value = 999, name = "never end" },
        },

        plain = 70,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Endless stairs\" at the game's own value, and a mode that"
            .. " wants its own answer can rules.lend(\"stairs\", ...) it from its own"
            .. " setup.",
        get = function()
            local wanted = rules.stairs_wish()
            if type(wanted) ~= "number" then return 70 end
            return wanted
        end,
        set = function(value) rules.set_stairs(value) end,

        note = function()
            if rules.step("climb") > 0 then
                return OF.lang.t("Every climb is that staircase is on, everywhere.")
            end
            return OF.lang.t("This staircase only - the other row does them all.")
        end,
    },
    {
        key = "star", id = "sa", name = "After a star",
        blurb = "what happens to whoever takes a star, on their machine",
        section = "Stars",
        options = {
            { value = 0, name = "leave the level" },
            { value = 1, name = "stay in it" },
            { value = 2, name = "never stop" },
        },
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"After a star\" at the game's own value, and a mode that wants"
            .. " its own answer can rules.lend(\"star\", ...) it from its own setup.",
        get = function() return gServerSettings.stayInLevelAfterStar end,
        set = function(value) gServerSettings.stayInLevelAfterStar = value end,
    },

    {
        key = "caplength", id = "cl", name = "Cap length",
        blurb = "how long a cap keeps working after you put it on",
        section = "Caps",
        vanilla = 100,
        plain = 100,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Cap length\" at the game's own value, and a mode that wants"
            .. " its own answer can rules.lend(\"caplength\", ...) it from its own"
            .. " setup.",
        note = function() return rules.cap_length_note() end,

        options = {
            { value = 25,  name = "a quarter as long" },
            { value = 50,  name = "half as long" },
            { value = 100, name = "as the game does it" },
            { value = 200, name = "twice as long" },
            { value = 400, name = "four times as long" },
            { value = 800, name = "eight times as long" },
        },

        get = function()
            local frames = gLevelValues.wingCapDuration
            if type(frames) ~= "number" or frames <= 0 then return 100 end
            return math.floor(frames * 100 / CAP_WING + 0.5)
        end,
        set = function(value)
            gLevelValues.wingCapDuration   = cap_scaled(CAP_WING, value)
            gLevelValues.metalCapDuration  = cap_scaled(CAP_METAL, value)
            gLevelValues.vanishCapDuration = cap_scaled(CAP_VANISH, value)
        end,
    },

    {
        key = "capstage", id = "cg", name = "A cap stage's own cap",
        blurb = "how long the cap a cap stage hands out keeps working",
        section = "Caps",
        vanilla = 100,
        plain = 100,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"A cap stage's own cap\" at the game's own value, and a mode"
            .. " that wants its own answer can rules.lend(\"capstage\", ...) it from"
            .. " its own setup.",
        note = function() return rules.cap_stage_note() end,

        options = {
            { value = 25,  name = "a quarter as long" },
            { value = 50,  name = "half as long" },
            { value = 100, name = "as the game does it" },
            { value = 200, name = "twice as long" },
            { value = 400, name = "four times as long" },
            { value = 800, name = "eight times as long" },
        },
        get = function()
            local frames = gLevelValues.wingCapDurationTotwc
            if type(frames) ~= "number" or frames <= 0 then return 100 end
            return math.floor(frames * 100 / CAP_TOTWC + 0.5)
        end,
        set = function(value)
            gLevelValues.wingCapDurationTotwc   = cap_scaled(CAP_TOTWC, value)
            gLevelValues.metalCapDurationCotmc  = cap_scaled(CAP_COTMC, value)
            gLevelValues.vanishCapDurationVcutm = cap_scaled(CAP_VCUTM, value)
        end,
    },

    {
        key = "cappits", id = "cp", name = "Cap stage pits",
        blurb = "what the drop out of a cap stage costs you",
        section = "Caps",
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Cap stage pits\" at the game's own value, and a mode that"
            .. " wants its own answer can rules.lend(\"cappits\", ...) it from its own"
            .. " setup.",
        note = function() return rules.cap_pits_note() end,
        options = {
            { value = 0, name = "kill you" },
            { value = 1, name = "bubble you" },
        },
        get = function()
            return OF.util.flag(gLevelValues.bubbleOnDeathBarrierInCapStages)
        end,
        set = function(value)
            gLevelValues.bubbleOnDeathBarrierInCapStages = (value == 1)
        end,
    },

    {
        key = "winglight", id = "wl", name = "Wing cap light",
        blurb = "when the tower's light over the wing cap starts shining",
        section = "Caps",
        vanilla = 10,
        plain = 10,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Wing cap light\" at the game's own value, and a mode that"
            .. " wants its own answer can rules.lend(\"winglight\", ...) it from its"
            .. " own setup.",
        note = function() return rules.wing_light_note() end,

        options = {
            { value = 0,   name = "from the start" },
            { value = 10,  name = "at ten stars, as the game" },
            { value = 30,  name = "at thirty stars" },
            { value = 50,  name = "at fifty stars" },
            { value = 70,  name = "at seventy stars" },
            { value = 121, name = "out of reach" },
        },
        get = function()
            local wanted = gLevelValues.wingCapLookUpReq
            if type(wanted) ~= "number" then return 10 end
            return wanted
        end,
        set = function(value) gLevelValues.wingCapLookUpReq = value end,
    },

    {
        key = "exitcourse", id = "xc", name = "Leaving a course",
        blurb = "when Exit Course may be used, and where it puts you",
        section = "The lobby",
        vanilla = 1,
        plain = 1,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Leaving a course\" at the game's own value, and a mode that"
            .. " wants its own answer can rules.lend(\"exitcourse\", ...) it from its"
            .. " own setup.",
        note = function() return rules.exit_course_note() end,
        options = {
            { value = 0, name = "only while standing still" },
            { value = 1, name = "from anywhere" },
            { value = 2, name = "from anywhere, and it puts you back" },
        },

        get = function()
            if rules.exitBack then return 2 end
            return OF.util.flag(gLevelValues.pauseExitAnywhere)
        end,
        set = function(value)
            gLevelValues.pauseExitAnywhere = (value >= 1)
            rules.exitBack = (value == 2)
            rules.point_the_exit()
        end,
    },

    {
        key = "switchback", id = "sw", name = "Blue coin switches",
        blurb = "whether a blue coin switch can be hit more than once",
        section = "Coins",
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Blue coin switches\" at the game's own value, and a mode that"
            .. " wants its own answer can rules.lend(\"switchback\", ...) it from its"
            .. " own setup.",
        note = function() return rules.blue_switch_note() end,
        options = {
            { value = 0, name = "one press each" },
            { value = 1, name = "come back" },
        },
        get = function()
            return OF.util.flag(gLevelValues.respawnBlueCoinsSwitch)
        end,
        set = function(value)
            gLevelValues.respawnBlueCoinsSwitch = (value == 1)
        end,
    },

    {

        key = "selftag", id = "st", name = "Show your own name tag",
        blurb = "your own name floating over your own head",
        section = "Between players", look = true,
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Show your own name tag\" at the game's own value, and a mode that"
            .. " wants its own answer can rules.lend(\"selftag\", ...) it from its own"
            .. " setup.",
        note = function() return rules.self_tag_note() end,
        options = {
            { value = 0, name = "off" },
            { value = 1, name = "on" },
        },
        get = function() return OF.util.flag(gNametagsSettings.showSelfTag) end,
        set = function(value) gNametagsSettings.showSelfTag = (value == 1) end,
    },

    {
        key = "capagain", id = "mc", name = "A cap you already wear",
        blurb = "a cap you are already wearing can be taken again",
        section = "Caps",
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"A cap you already wear\" at the game's own value, and a mode"
            .. " that wants its own answer can rules.lend(\"capagain\", ...) it from"
            .. " its own setup.",
        note = function() return rules.cap_again_note() end,
        options = {
            { value = 0, name = "cannot be picked up again" },
            { value = 1, name = "can be picked up again" },
        },
        get = function()
            return OF.util.flag(gBehaviorValues.MultipleCapCollection)
        end,
        set = function(value)
            gBehaviorValues.MultipleCapCollection = (value == 1)
        end,
    },

    {
        key = "coinlife", id = "cv", name = "A 1-Up out of coins",
        blurb = "how often collecting coins hands out a spare life",
        section = "Coins",
        vanilla = 50,
        plain = 50,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"A 1-Up out of coins\" at the game's own value, and a mode"
            .. " that wants its own answer can rules.lend(\"coinlife\", ...) it from"
            .. " its own setup.",
        note = function() return rules.coin_life_note() end,
        options = {
            { value = 0,   name = "never" },
            { value = 10,  name = "every 10 coins" },
            { value = 25,  name = "every 25 coins" },
            { value = 50,  name = "at 50, 100 and 150, as the game" },
            { value = 75,  name = "every 75 coins" },
            { value = 100, name = "every 100 coins" },
        },
        get = function()
            local wanted = gLevelValues.numCoinsToLife
            if type(wanted) ~= "number" then return 50 end
            return wanted
        end,
        set = function(value) gLevelValues.numCoinsToLife = value end,
    },

    {
        key = "slidestar", id = "ts", name = "The slide's time star",
        blurb = "how fast the slide has to be run for its time star",
        section = "Out in the courses",
        vanilla = 630,
        plain = 630,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"The slide's time star\" at the game's own value, and a mode"
            .. " that wants its own answer can rules.lend(\"slidestar\", ...) it from"
            .. " its own setup.",
        note = function() return rules.slide_star_note() end,

        options = {
            { value = 300,  name = "10 seconds" },
            { value = 450,  name = "15 seconds" },
            { value = 630,  name = "21 seconds, as the game" },
            { value = 900,  name = "30 seconds" },
            { value = 1200, name = "40 seconds" },
        },
        get = function()
            local wanted = gLevelValues.pssSlideStarTime
            if type(wanted) ~= "number" or wanted <= 0 then return 630 end
            return wanted
        end,
        set = function(value) gLevelValues.pssSlideStarTime = value end,
    },

    {
        key = "water", id = "ww", name = "Wet-Dry World's water",
        blurb = "how quickly Wet-Dry World's water finds its new level",
        section = "Out in the courses",
        vanilla = 100,
        plain = 100,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Wet-Dry World's water\" at the game's own value, and a mode"
            .. " that wants its own answer can rules.lend(\"water\", ...) it from its"
            .. " own setup.",
        note = function() return rules.water_note() end,
        options = {
            { value = 25,  name = "a crawl" },
            { value = 50,  name = "slowly" },
            { value = 100, name = "as the game does it" },
            { value = 200, name = "briskly" },
            { value = 300, name = "quickly" },
            { value = 900, name = "almost at once" },
        },
        get = function()
            return percent_of(gLevelValues.wdwWaterLevelSpeed, WDW_SPEED)
        end,
        set = function(value)
            gLevelValues.wdwWaterLevelSpeed = scaled(WDW_SPEED, value)
        end,
    },

    {
        key = "waterheal", id = "wh", name = "The water mends you",
        blurb = "floating at the surface fills your health back up",
        section = "Out in the courses",
        options = {
            { value = 0, name = "as the game does it" },
            { value = 1, name = "not at all" },
        },
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"The water mends you\" at the game's own value, and a mode"
            .. " that wants its own answer can rules.lend(\"waterheal\", ...) it from"
            .. " its own setup.",
        get = function() return rules.waterMends and 0 or 1 end,
        set = function(value) rules.waterMends = (value ~= 1) end,
    },

    {
        key = "koopa", id = "kq", name = "Koopa the Quick",
        blurb = "how fast Koopa the Quick runs his races",
        section = "Races and bosses",
        vanilla = 100,
        plain = 100,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Koopa the Quick\" at the game's own value, and a mode that"
            .. " wants its own answer can rules.lend(\"koopa\", ...) it from its own"
            .. " setup.",
        note = function() return rules.koopa_note() end,
        options = {
            { value = 25,  name = "a stroll" },
            { value = 50,  name = "half as fast" },
            { value = 100, name = "as the game does it" },
            { value = 150, name = "a real race" },
            { value = 250, name = "no chance" },
            { value = 400, name = "gone before you look up" },
        },
        get = function()
            return percent_of(gBehaviorValues.KoopaBobAgility, KOOPA_BOB)
        end,
        set = function(value)
            gBehaviorValues.KoopaBobAgility   = scaled(KOOPA_BOB, value)
            gBehaviorValues.KoopaThiAgility   = scaled(KOOPA_THI, value)
            gBehaviorValues.KoopaCatchupAgility = scaled(KOOPA_CATCH, value)
        end,
    },

    {
        key = "bowling", id = "bo", name = "Bowling balls",
        blurb = "how fast the rolling balls come down at you",
        section = "Out in the courses",
        vanilla = 100,
        plain = 100,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Bowling balls\" at the game's own value, and a mode that"
            .. " wants its own answer can rules.lend(\"bowling\", ...) it from its own"
            .. " setup.",
        note = function() return rules.bowling_note() end,
        options = {
            { value = 25,  name = "barely rolling" },
            { value = 50,  name = "half as fast" },
            { value = 100, name = "as the game does it" },
            { value = 200, name = "twice as fast" },
            { value = 400, name = "four times as fast" },
            { value = 800, name = "cannonballs" },
        },
        get = function()
            return percent_of(gBehaviorValues.BowlingBallBobSpeed, BALL_BOB)
        end,
        set = function(value)
            gBehaviorValues.BowlingBallBobSpeed      = scaled(BALL_BOB, value)
            gBehaviorValues.BowlingBallBob2Speed     = scaled(BALL_BOB2, value)
            gBehaviorValues.BowlingBallTtmSpeed      = scaled(BALL_TTM, value)
            gBehaviorValues.BowlingBallThiLargeSpeed = scaled(BALL_THI_BIG, value)
            gBehaviorValues.BowlingBallThiSmallSpeed = scaled(BALL_THI_SML, value)
        end,
    },

    {
        key = "kingbob", id = "bb", name = "King Bob-omb",
        blurb = "how fast King Bob-omb moves in his fight",
        section = "Races and bosses",
        vanilla = 100,
        plain = 100,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"King Bob-omb\" at the game's own value, and a mode that wants"
            .. " its own answer can rules.lend(\"kingbob\", ...) it from its own setup.",
        note = function() return rules.king_note() end,
        options = {
            { value = 25,  name = "he ambles" },
            { value = 50,  name = "half as fast" },
            { value = 100, name = "as the game does it" },
            { value = 200, name = "twice as fast" },
            { value = 400, name = "he is on you" },
        },
        get = function()
            return percent_of(gBehaviorValues.KingBobombFVel, KING_FVEL)
        end,
        set = function(value)
            gBehaviorValues.KingBobombFVel = scaled(KING_FVEL, value)

            gBehaviorValues.KingBobombYawVel =
                math.floor(scaled(KING_YAW, value))
        end,
    },

    {
        key = "penguin", id = "rp", name = "The racing penguin",
        blurb = "how much of the slope the racing penguin takes up",
        section = "Races and bosses",
        vanilla = 100,
        plain = 100,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"The racing penguin\" at the game's own value, and a mode that"
            .. " wants its own answer can rules.lend(\"penguin\", ...) it from its own"
            .. " setup.",
        note = function() return rules.penguin_note() end,
        options = {
            { value = 0,   name = "you run through him" },
            { value = 50,  name = "half as wide" },
            { value = 100, name = "as the game does it" },
            { value = 200, name = "twice as wide" },
            { value = 400, name = "he has the whole slope" },
        },

        get = function()
            local now = gBehaviorValues.RacingPenguinRadius
            if type(now) ~= "number" or now < 0 then return 100 end
            if now == 0 then return 0 end
            return math.floor(now * 100 / PENGUIN_RADIUS + 0.5)
        end,
        set = function(value)
            gBehaviorValues.RacingPenguinRadius = scaled(PENGUIN_RADIUS, value)
            gBehaviorValues.RacingPenguinBigRadius =
                scaled(PENGUIN_BIG_RADIUS, value)
        end,
    },

    {
        key = "shellbox", id = "xb", name = "Shell boxes",
        blurb = "whether a shell box refills after its shell is taken",
        section = "Out in the courses",
        vanilla = 1,
        plain = 1,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Shell boxes\" at the game's own value, and a mode that wants"
            .. " its own answer can rules.lend(\"shellbox\", ...) it from its own"
            .. " setup.",
        note = function() return rules.shell_box_note() end,
        options = {
            { value = 0, name = "one shell each" },
            { value = 1, name = "come back" },
        },
        get = function()
            return OF.util.flag(gBehaviorValues.RespawnShellBoxes)
        end,
        set = function(value)
            gBehaviorValues.RespawnShellBoxes = (value == 1)
        end,
    },

    {
        key = "shellride", id = "rs", name = "Riding a shell",
        blurb = "what happens to your ride when the shell under it goes",
        section = "The lobby",
        vanilla = 1,
        plain = 1,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Riding a shell\" at the game's own value, and a mode that"
            .. " wants its own answer can rules.lend(\"shellride\", ...) it from its"
            .. " own setup.",
        note = function() return rules.shell_ride_note() end,
        options = {
            { value = 0, name = "carries on without it" },
            { value = 1, name = "stops when the shell goes" },
        },
        get = function()
            return OF.util.flag(gLevelValues.fixInvalidShellRides)
        end,
        set = function(value)
            gLevelValues.fixInvalidShellRides = (value == 1)
        end,
    },

    {
        key = "lid", id = "ld", name = "The lid",
        section = "What the course does to you",
        zero = "no ceiling",
        plain = 0,
        perMode = "No column. An invisible ceiling is the arena's business and"
            .. " every mode that wants one builds its own; a leftover lobby lid"
            .. " over a round is a roof nobody in that round agreed to.",
        blurb = "an invisible ceiling, this far above the ground",
        levels = {

            { name = "high", above = 4000 },
            { name = "low", above = 2000 },
            { name = "no flying at all", above = 900 },

            { name = "very high", above = 8000 },
            { name = "you can feel it", above = 400 },
        },
        restore = function() rules.reset_the_lid() end,
    },

    {
        key = "climb", id = "cm", name = "Every climb is that staircase",
        section = "What the course does to you",
        zero = "never",
        plain = 0,
        perMode = "No column. A staircase that never ends is a joke for one session"
            .. " and a wall in a round, and no mode is measured on a climb it"
            .. " cannot finish.",
        blurb = "climb enough on foot and you're back where you started",
        levels = {

            { name = "long climbs only", climb = 600 },

            { name = "any climb at all", climb = 200 },

            { name = "only a whole mountain", climb = 2400 },
            { name = "a single jump is too far", climb = 90 },
        },
        note = function() return OF.util.asks(OF.modifiers, "climb_note")
            and OF.modifiers.climb_note() or nil end,
        restore = function() OF.modifiers.forget_climb() end,
    },

    {
        key = "mercy", id = "hz", name = "The level's hazards",
        section = "What the course does to you",
        zero = "as the game has them",
        plain = 0,
        perMode = "No column. What a course may do to you is what every round is"
            .. " balanced against, and a mode that wants the hazards off turns"
            .. " them off in its own setup.",
        blurb = "what the course is allowed to do to you",
        levels = {
            { name = "the lava does not burn", lava = true },
            { name = "the quicksand lets go", sand = true },
            { name = "neither lava nor quicksand", lava = true, sand = true },
        },
        note = function() return OF.util.asks(OF.modifiers, "mercy_note")
            and OF.modifiers.mercy_note() or nil end,
    },
    {
        key = "sting", id = "hi", name = "What a hit takes off",
        section = "What the course does to you",
        zero = "as the game has it",
        plain = 0,
        perMode = "No column. How much a hit takes off is the number every"
            .. " elimination round counts lives in, so a leftover lobby scale"
            .. " would be deciding how long the round lasts.",
        blurb = "every knock from the level's cast; worth more or less",
        levels = {
            { name = "double", factor = 2 },
            { name = "triple", factor = 3 },

            { name = "half", factor = 0.5 },
            { name = "a quarter", factor = 0.25 },

            { name = "one wedge, whatever it was", wedges = 1 },
            { name = "every hit is a killing blow", wedges = 8 },

            { name = "a lottery, one wedge to all eight", lottery = true },
        },
        world = function() end,
        restore = function() OF.modifiers.forget_stings() end,
    },
    {
        key = "gas", id = "ga", name = "The air down there",
        section = "What the course does to you",
        zero = "clean",
        plain = 0,
        perMode = "No column. A round that wants the air down there to be poison"
            .. " says so itself; one that does not would inherit a slow death"
            .. " nobody in it chose.",
        blurb = "poison gas fills the level from the bottom - climb out of it",
        levels = {

            { name = "the pits", share = 0.12 },
            { name = "the lower third", share = 0.33 },
            { name = "most of it", share = 0.70 },
            { name = "all but the rooftops", share = 0.92 },

            { name = "nowhere is safe", everywhere = true },
        },
        note = function() return OF.util.asks(OF.modifiers, "gas_note")
            and OF.modifiers.gas_note() or nil end,
        world = function() end,
        restore = function() OF.modifiers.clear_gas() end,
    },

    {
        key = "starclock", id = "sc", name = "A star against the clock",
        section = "What the course does to you",
        zero = "no clock",
        plain = 0,
        perMode = "No column. A round keeps its own clock and a run its own"
            .. " timer; a countdown that took lives on top of either would be"
            .. " a second referee.",
        blurb = "in a course: a star in time, or you lose a life",
        levels = {
            { name = "five minutes", seconds = 300 },
            { name = "three minutes", seconds = 180 },
            { name = "ninety seconds", seconds = 90 },
        },
        world = function() end,
        restore = function() rules.stop_star_clock() end,
    },
    {
        key = "fightback", id = "fb", name = "The level fights back",
        section = "What the course does to you",
        zero = "no harder than it did",
        plain = 0,
        perMode = "No column. A level that fights back is spice for one session"
            .. " and a second opponent in a round, and no mode was balanced"
            .. " against one.",
        blurb = "the course's own crushers and turntables, turned up",

        levels = {
            { name = "meaner" },
            { name = "nasty" },
            { name = "unfair" },
            { name = "brutal" },
            { name = "the course wants you gone" },
        },
        note = function() return OF.util.asks(OF.modifiers, "fight_note")
            and OF.modifiers.fight_note() or nil end,
    },
    {
        key = "clock", id = "ck", name = "Clockwork",
        section = "What the course does to you",
        zero = "at the game's own pace",
        plain = 0,
        perMode = "No column. Tick Tock Clock at six times speed is a different"
            .. " course, and a round played on a different course from the one"
            .. " it was measured on is not that round.",
        blurb = "how fast the clock parts run; and whether they run at all",
        levels = {
            { name = "slow", speed = TTC_SPEED_SLOW },
            { name = "fast", speed = TTC_SPEED_FAST },
            { name = "unpredictable", speed = TTC_SPEED_RANDOM },
            { name = "stopped", speed = TTC_SPEED_STOPPED },

            { name = "double time", speed = TTC_SPEED_FAST, overdrive = 2 },

            { name = "the clock comes off its spring", speed = TTC_SPEED_FAST,
              overdrive = 6 },
        },
        note = function() return OF.util.asks(OF.modifiers, "clock_note")
            and OF.modifiers.clock_note() or nil end,
        world = function()
            OF.util.optional("set_ttc_speed_setting", nil,
                rules.step_setting("clock", "speed", TTC_SPEED_SLOW))
        end,

        restore = function()
            OF.util.optional("set_ttc_speed_setting", nil, TTC_SPEED_SLOW)
        end,
    },
    {
        key = "conveyor", id = "mf", name = "The floor moves",
        section = "What the course does to you",
        zero = "not at all",
        plain = 0,
        perMode = "No column. A floor that pushes is the one thing no round"
            .. " scored on standing somewhere can survive, and the rounds that"
            .. " are not scored that way gain nothing from it.",
        blurb = "the ground pushes - standing still is not an option",
        levels = {
            { name = "outward", which = 1 },
            { name = "inward", which = 2 },
            { name = "round and round", which = 3 },
        },
        note = function() return rules.conveyor_note() end,
        world = function()
            if OF.util.asks(OF.ground, "blow") then
                OF.ground.blow(rules.step_setting("conveyor", "which", 1))
            end
        end,
        restore = function()
            if OF.util.asks(OF.ground, "restore") then OF.ground.restore() end
        end,
    },

    {
        key = "oneway", id = "ow", name = "A floor that only works one way",
        section = "What the course does to you",
        zero = "there is no line",
        plain = 0,
        perMode = "No column. A height that swallows whoever falls past it is"
            .. " the round's own business, and a lobby line left standing over"
            .. " a round would be deciding who is still in it.",
        blurb = "a height, not a wall of blocks: falling through it costs you",
        levels = {

            { name = "the low ground is not there", kind = 2, share = 0.25 },

            { name = "the low ground is lava", kind = 3, share = 0.25 },

            { name = "the low ground kills", kind = 1, share = 0.25 },

            { name = "nothing below halfway holds you", kind = 2, share = 0.50 },
            { name = "only the rooftops hold you", kind = 2, share = 0.85 },
        },
        note = function() return rules.oneway_note() end,

    },

    {
        key = "crowd", id = "cw", name = "A door needs everybody at it",
        section = "What the course does to you",
        zero = "one player opens it",
        plain = 0,
        perMode = "No column. A door that refuses a lone player is the arena"
            .. " deciding who may be where, which is the round's own business"
            .. " and never a leftover from the lobby's page.",
        blurb = "a door opens only with enough players standing at it",
        levels = {
            { name = "everybody connected", share = 100 },
            { name = "two", count = 2 },
            { name = "three", count = 3 },
            { name = "four", count = 4 },

            { name = "half the lobby", share = 50 },
        },
        note = function() return rules.crowd_note() end,
    },

    {
        key = "gates", id = "gt", name = "The castle's star gates",
        section = "Stars",
        zero = "as the game asks",
        blurb = "how many stars the castle asks for",
        levels = {
            { name = "nothing is locked", percent = 0 },
            { name = "half", percent = 50 },
            { name = "double", percent = 200 },

            { name = "a quarter", percent = 25 },
            { name = "a third", percent = 33 },
            { name = "four times", percent = 400 },
        },

        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS. Hide and Seek lends it open so nobody"
            .. " is locked out of a hiding spot by the castle's own star count; every"
            .. " other mode plays the castle exactly as the lobby found it.",
        note = function() return OF.util.asks(OF.modifiers, "gates_note")
            and OF.modifiers.gates_note() or nil end,
        world = function() rules.scale_the_gates(
            rules.step_setting("gates", "percent", 100)) end,
        restore = function() rules.scale_the_gates(100) end,
    },

    {
        key = "doorprice", id = "dp", name = "Star door prices",
        section = "Stars",
        zero = "as the game priced them",
        blurb = "the castle's four star prices, re-written door by door",
        levels = {

            { name = "three free, the last one everything",
              price = { [8] = 0, [30] = 0, [50] = 0, [70] = 120 } },

            { name = "the castle backwards",
              price = { [8] = 70, [30] = 50, [50] = 30, [70] = 8 } },

            { name = "one star more for each door",
              price = { [8] = 1, [30] = 2, [50] = 3, [70] = 4 } },

            { name = "every door asks for eight",
              price = { [8] = 8, [30] = 8, [50] = 8, [70] = 8 } },

        },
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Star door prices\" at the game's own value, and a mode that"
            .. " wants its own answer can rules.lend(\"doorprice\", ...) it from its"
            .. " own setup.",
        note = function() return rules.door_price_note() end,

        world = function() rules.aim_star_gates() end,
        restore = function() rules.aim_star_gates() end,
    },

    {
        key = "hud", id = "hu", name = "Hide the HUD",
        section = "Helpers",
        plain = 0,
        perMode = "No column. Every mode draws its own bar and its own numbers"
            .. " over the top, and a round that also took the coins and the"
            .. " health away would be hiding what it is asking players to do.",
        blurb = "Takes the game's HUD off your screen",
        world = function() OF.modifiers.wear_hud(true) end,
        restore = function() OF.modifiers.wear_hud(false) end,
    },

    {
        key = "steep", id = "sy", name = "How steep the ground can be",
        section = "Getting around",
        plain = 0,
        perMode = "No column. Which slopes are walkable is the shape of the"
            .. " ground a round is walked on, and every mode's arena was"
            .. " measured with the course's own angles under it.",
        zero = "as the course was built",
        blurb = "past this angle a slope is a wall, and you have to jump it",
        levels = {
            { name = "nothing past sixty degrees", minY = 0.5 },
            { name = "nothing past forty-five", minY = 0.71 },
            { name = "nothing past thirty", minY = 0.87 },
            { name = "only flat ground is ground", minY = 0.95 },
        },
        note = function() return rules.surface_note("steep") end,
        world = function()
            if gLevelValues == nil then return end
            gLevelValues.floorNormalMinY =
                rules.step_setting("steep", "minY", SURFACE_FLOOR_MIN_Y)
        end,
        restore = function()
            if gLevelValues == nil then return end
            gLevelValues.floorNormalMinY = SURFACE_FLOOR_MIN_Y
        end,
    },

    {
        key = "overhang", id = "oh", name = "What counts as a ceiling",
        section = "Getting around",
        plain = 0,
        perMode = "No column, for the same reason as steep: a round is measured"
            .. " on the course as it was built, and a ceiling turned into a"
            .. " wall is a different set of ledges.",
        zero = "as the course was built",
        blurb = "a ceiling overhang becomes a wall you can kick off",
        levels = {
            { name = "a leaning overhang is a wall", maxY = -0.3 },
            { name = "and so is anything past sixty degrees", maxY = -0.5 },
            { name = "and past forty-five", maxY = -0.71 },
            { name = "only a flat ceiling is a ceiling", maxY = -0.95 },
        },
        note = function() return rules.surface_note("overhang") end,
        world = function()
            if gLevelValues == nil then return end
            gLevelValues.ceilNormalMaxY =
                rules.step_setting("overhang", "maxY", SURFACE_CEIL_LIMIT_Y)
        end,
        restore = function()
            if gLevelValues == nil then return end
            gLevelValues.ceilNormalMaxY = SURFACE_CEIL_LIMIT_Y
        end,
    },

    {
        key = "shoulders", id = "sq", name = "How wide you stand",
        section = "Getting around",
        plain = 0,
        perMode = "No column. How close a wall gets before it pushes back is a"
            .. " movement setting, and any round measured on ground covered or"
            .. " a point held is measured against the game's own width.",
        zero = "as wide as the game says",
        blurb = "how close to a wall you get before it pushes back",
        levels = {
            { name = "your shoulders stop catching", radius = 24 },
            { name = "you can thread a doorway", radius = 12 },
            { name = "walls barely reach you", radius = 6 },
        },
        world = function()
            if gLevelValues == nil then return end
            gLevelValues.wallMaxRadius =
                rules.step_setting("shoulders", "radius", WALL_RADIUS_CLAMP)
        end,
        restore = function()
            if gLevelValues == nil then return end
            gLevelValues.wallMaxRadius = WALL_RADIUS_CLAMP
        end,
    },

    {
        key = "coursecam", id = "xm", name = "The camera a course takes",
        section = "Getting around",
        plain = 0,
        perMode = "No column. A mode that wants a particular camera sets it in"
            .. " setup, which runs after the lock and wins; a leftover refusal"
            .. " would be the lobby quietly overruling the round.",
        zero = "the course decides",
        blurb = "which courses can change your camera; which cannot",
        levels = {
            { name = "the water leaves your camera alone" },
            { name = "and so do rails and fixed corners" },
            { name = "and the slides and the cannons" },
        },
    },

    {
        key = "angles", id = "an", name = "Swapping to Mario cam",
        section = "Getting around",
        blurb = "everybody sees the level the same way round",
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Swapping to Mario cam\" at the game's own value, and a mode"
            .. " that wants its own answer can rules.lend(\"angles\", ...) it from its"
            .. " own setup.",
        note = function() return rules.mario_cam_note() end,
    },

    {
        key = "wipes", id = "wp", name = "The screen wipe",
        section = "Sound and screen",
        zero = "every one the game plays",
        blurb = "the star, the circle and the fade between two levels",
        levels = {
            { name = "only the ones that fade back in" },
            { name = "none at all" },
        },
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"The screen wipe\" at the game's own value, and a mode that"
            .. " wants its own answer can rules.lend(\"wipes\", ...) it from its own"
            .. " setup.",
    },

    {
        key = "mapweather", id = "mw", name = "A map's own weather",
        section = "Sound and screen",
        zero = "each map brings its own",
        blurb = "the rain, fog and colours a map was made with",
        levels = {
            { name = "the lobby's look everywhere" },
        },
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS: a round that holds the visuals"
            .. " already wears its own dress and nothing of a map's, so this row"
            .. " has nothing left to say during one.",
    },

    {
        key = "stopwatch", id = "tw", name = "The course clock",
        section = "Helpers",
        plain = 0,
        perMode = "Every mode draws a clock of its own, so no round has a "
            .. "reason to keep the lobby's - two clocks on one screen is one "
            .. "too many. Flattened for all of them rather than columned.",
        blurb = "the game's own course clock, running in every course",
        world = function()
            rules.course_clock(true)
        end,
        restore = function()
            rules.course_clock(false)
        end,
    },

    {
        key = "poles", id = "pl", name = "Poles and trees",
        section = "Getting around",
        plain = 0,
        perMode = "No column. Taking every climb away changes which routes a"
            .. " course has, and a round measured on reaching somewhere is"
            .. " measured on the routes the course was built with.",
        blurb = "nobody climbs - every way up is a jump",
    },

    {
        key = "lives", id = "nl", name = "Lives",
        section = "The lobby",
        plain = 0,
        perMode = "No column. Last One Standing and Zombies count lives"
            .. " themselves, and a leftover cap under a mode that hands out"
            .. " three is two rules arguing about one number.",
        zero = "as many as anybody can carry",
        blurb = "the most lives anybody in this lobby may hold",
        levels = {
            { name = "ten", cap = 10 },
            { name = "five", cap = 5 },
            { name = "three", cap = 3 },
        },
        world = function()
            if gLevelValues == nil then return end
            gLevelValues.maxLives = rules.step_setting("lives", "cap", LIVES_CEILING)
        end,
        restore = function()
            if gLevelValues == nil then return end
            gLevelValues.maxLives = LIVES_CEILING
        end,
    },

    {
        key = "signs", id = "sb", name = "Signs and message blocks",
        section = "Sound and screen",
        blurb = "signs, Bowser and doors stop telling you anything",
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Signs and message blocks\" at the game's own value, and a"
            .. " mode that wants its own answer can rules.lend(\"signs\", ...) it from"
            .. " its own setup.",
    },

    {
        key = "textvoice", id = "tv", name = "The text box voice",
        section = "Sound and screen",
        zero = "whoever is speaking",
        blurb = "the voice every text box in the game answers in",
        levels = {
            { name = "Bowser, music and all", speaker = 2 },
            { name = "a Boo", speaker = 5 },
            { name = "a Koopa", speaker = 3 },
            { name = "Yoshi", speaker = 10 },
            { name = "nothing at all", speaker = 0xff },
        },
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"The text box voice\" at the game's own value, and a mode that"
            .. " wants its own answer can rules.lend(\"textvoice\", ...) it from its"
            .. " own setup.",
    },

    {
        key = "capmusic", id = "cq", name = "Cap music",
        section = "Sound and screen",
        zero = "the game's own",
        blurb = "the tune a wing, metal or vanish cap plays when taken",
        levels = {
            { name = "the metal cap's, for all of them", seq = 15 },
            { name = "a boss fight", seq = 22 },
            { name = "a race starting", seq = 20 },
            { name = "the merry-go-round", seq = 19 },
            { name = "the high score jingle", seq = 18 },
        },
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Cap music\" at the game's own value, and a mode that wants"
            .. " its own answer can rules.lend(\"capmusic\", ...) it from its own"
            .. " setup.",
        world = function() rules.set_cap_music(
            rules.step_setting("capmusic", "seq", nil)) end,
        restore = function() rules.set_cap_music(nil) end,
    },

    {
        key = "pausecam", id = "pz", name = "The pause camera",

        vanilla = 1,
        section = "Sound and screen",
        blurb = "pausing pulls the camera back over the whole level",
        plain = 1,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"The pause camera\" at the game's own value, and a mode that"
            .. " wants its own answer can rules.lend(\"pausecam\", ...) it from its own"
            .. " setup.",
        note = function() return rules.pause_cam_note() end,
        options = {
            { value = 0, name = "off" },
            { value = 1, name = "on" },
        },
        get = function() return OF.util.flag(gLevelValues.zoomOutCameraOnPause) end,
        set = function(value) gLevelValues.zoomOutCameraOnPause = (value == 1) end,
    },

    {
        key = "paintings", id = "pn", name = "The paintings",
        section = "Sound and screen",
        zero = "hanging as they are",
        blurb = "paintings fade; the entrances stay where they were",
        levels = {
            { name = "faded", alpha = 150 },
            { name = "ghosts", alpha = 60 },
            { name = "gone, and the doors still work", alpha = 0 },
        },
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"The paintings\" at the game's own value, and a mode that"
            .. " wants its own answer can rules.lend(\"paintings\", ...) it from its"
            .. " own setup.",
        world = function() rules.fade_the_paintings(
            rules.step_setting("paintings", "alpha", nil)) end,
        restore = function() rules.fade_the_paintings(nil) end,
    },

    {
        key = "hiddenfaces", id = "hf", name = "Hidden entrance paintings",
        section = "Sound and screen",
        blurb = "the two hidden entrances show their level's picture",
        options = {
            { value = 0, name = "off" },
            { value = 1, name = "on" },
        },
        vanilla = 0,
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Hidden entrance paintings\" at the game's own walls, and a"
            .. " mode that wants its own answer can rules.lend(\"hiddenfaces\", ...)"
            .. " it from its own setup.",
        get = function() return rules.hiddenFaces == true and 1 or 0 end,
        set = function(value) rules.hiddenFaces = (value == 1) end,
    },

    {
        key = "boxes", id = "xk", name = "What the boxes hold",
        section = "Out in the courses",
        zero = "whatever the course put in them",
        blurb = "every exclamation box in the game, holding one thing",
        levels = {
            { name = "a wing cap", pick = 0 },
            { name = "a metal cap", pick = 1 },
            { name = "a vanish cap", pick = 2 },
            { name = "a koopa shell", pick = 3 },
            { name = "ten coins", pick = 6 },
            { name = "a green mushroom", pick = 7 },
        },
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"What the boxes hold\" at the game's own value, and a mode"
            .. " that wants its own answer can rules.lend(\"boxes\", ...) it from its"
            .. " own setup.",
        note = function() return rules.boxes_note() end,
        world = function() rules.fill_the_boxes(
            rules.step_setting("boxes", "pick", nil)) end,
        restore = function() rules.fill_the_boxes(nil) end,
    },

    {
        key = "whomp", id = "kw", name = "King Whomp",
        section = "Races and bosses",
        zero = "three pounds, as the game has it",
        blurb = "how many ground pounds the King of the fortress takes",
        levels = {
            { name = "one", health = 1 },
            { name = "five", health = 5 },
            { name = "eight", health = 8 },
            { name = "fifteen", health = 15 },
        },
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"King Whomp\" at the game's own value, and a mode that wants"
            .. " its own answer can rules.lend(\"whomp\", ...) it from its own setup.",
        note = function() return rules.whomp_note() end,
        world = function()
            if gBehaviorValues == nil then return end
            gBehaviorValues.KingWhompHealth =
                rules.step_setting("whomp", "health", KING_WHOMP_HEALTH)
        end,
        restore = function()
            if gBehaviorValues == nil then return end
            gBehaviorValues.KingWhompHealth = KING_WHOMP_HEALTH
        end,
    },

    {
        key = "jrbsky", id = "jb", name = "Jolly Roger Bay's dark sky",

        vanilla = 1,
        section = "Out in the courses",
        blurb = "the bay's sky stays grim until its first star is out",
        options = {
            { value = 0, name = "off" },
            { value = 1, name = "on" },
        },
        plain = 1,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"Jolly Roger Bay's dark sky\" at the game's own value, and a"
            .. " mode that wants its own answer can rules.lend(\"jrbsky\", ...) it from"
            .. " its own setup.",
        get = function() return OF.util.flag(gLevelValues.jrbDarkenSkybox) end,
        set = function(value) gLevelValues.jrbDarkenSkybox = (value == 1) end,
    },

    {
        key = "skipintro", id = "si", name = "The opening cutscene",

        vanilla = 1,
        section = "The lobby",
        blurb = "a first-time player watches Bowser's intro, or skips it",
        plain = 1,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"The opening cutscene\" at the game's own value, and a mode"
            .. " that wants its own answer can rules.lend(\"skipintro\", ...) it from"
            .. " its own setup.",
        note = function() return rules.intro_note() end,
        options = {
            { value = 0, name = "off" },
            { value = 1, name = "on" },
        },

        get = function()
            return OF.util.flag(gServerSettings.skipIntro) == 1 and 0 or 1
        end,
        set = function(value) gServerSettings.skipIntro = (value == 0) end,
    },

    {
        key = "hoot", id = "ho", name = "Hoot the owl",
        section = "Out in the courses",
        plain = 0,
        perMode = "No column, and the same argument as the poles: the owl is a "
            .. "route up one course, and a round measured on reaching "
            .. "somewhere is measured on the routes that course was built "
            .. "with.",
        blurb = "the owl still flies - he just will not carry anybody",
        note = function() return rules.hoot_note() end,
    },

    {
        key = "coincap", id = "cx", name = "The coins you can carry",
        section = "Coins",
        zero = "as many as the game allows",
        blurb = "the coin counter stops here; so does anything counting it",
        levels = {
            { name = "three hundred", cap = 300 },
            { name = "one hundred", cap = 100 },
            { name = "fifty", cap = 50 },
            { name = "twenty", cap = 20 },
        },
        perMode = "No column. Half the modes in this mod count coins and every "
            .. "one of them counts the engine's own, so a leftover ceiling "
            .. "would be the lobby quietly deciding what a round is scored out "
            .. "of.",
        plain = 0,
        note = function() return rules.coin_cap_note() end,
        world = function()
            if gLevelValues == nil then return end
            gLevelValues.maxCoins = rules.step_setting("coincap", "cap", COINS_CEILING)
        end,
        restore = function()
            if gLevelValues == nil then return end
            gLevelValues.maxCoins = COINS_CEILING
        end,
    },

    {
        key = "reflection", id = "rf", name = "The castle's mirror",

        section = "Out in the courses",
        zero = "shows what it always showed",
        blurb = "what looks back at you in the castle's mirror room",
        levels = {
            { name = "nobody at all", hide = true },
            { name = "twice the size", scale = 2.0 },
            { name = "half the size", scale = 0.5 },

            { name = "upside down", roll = 0x8000 },

            { name = "spinning", spin = 0x0300 },
        },
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"The castle's mirror\" at the game's own value, and a mode"
            .. " that wants its own answer can rules.lend(\"reflection\", ...) it from"
            .. " its own setup.",
        note = function() return rules.reflection_note() end,
    },

    {
        key = "textbox", id = "tb", name = "The text box",
        section = "Sound and screen",
        zero = "as the game draws it",
        blurb = "the colours and the width of every message box",
        levels = {

            { name = "wide", width = 260 },
            { name = "black on white", bg = { 255, 255, 255, 255 },
              fg = { 0, 0, 0, 255 } },
            { name = "a green screen", bg = { 0, 0, 0, 255 },
              fg = { 90, 255, 120, 255 } },

            { name = "barely there", bg = { 0, 0, 0, 70 },
              fg = { 255, 255, 255, 255 } },
        },
        plain = 0,
        perMode = "Not in modes.ROUND_RULE_KEYS, and nothing lends it today: a round"
            .. " leaves \"The text box\" at the game's own value, and a mode that wants"
            .. " its own answer can rules.lend(\"textbox\", ...) it from its own setup.",
        note = function() return rules.textbox_note() end,
        world = function() rules.dress_the_text_box() end,
        restore = function() rules.plain_text_box() end,
    },

    {
        key = "tremor", id = "tr", name = "The ground shakes",

        section = "Sound and screen",
        zero = "steady",
        plain = 0,
        perMode = "No column. A screen that will not hold still changes every"
            .. " round in this mod by the same amount and none of them for the"
            .. " better, so a mode that wants the screen shaken can shake it"
            .. " itself rather than inherit a session's decoration.",
        blurb = "every screen shakes on a timer, wherever you stand",
        levels = {

            { name = "a tremor now and then", every = 300,
              shake = "SHAKE_POS_SMALL" },
            { name = "every five seconds", every = 150,
              shake = "SHAKE_POS_MEDIUM" },
            { name = "hardly a moment's peace", every = 45,
              shake = "SHAKE_POS_MEDIUM" },
            { name = "the screen will not stand still", every = 20,
              shake = "SHAKE_POS_LARGE" },
        },
        note = function() return rules.tremor_note() end,
    },

    {
        key = "deathshake", id = "dq", name = "A death shakes the ground",
        section = "Sound and screen",
        blurb = "a nearby death shakes every screen where they fell",
        options = {
            { value = 0, name = "off" },
            { value = 1, name = "on" },
        },
        plain = 0,
        perMode = "No column, and for the row above's reason said of the round"
            .. " that would inherit it: a screen shaken every time anybody dies"
            .. " is a different Last One Standing and a different Zombies, and"
            .. " a mode that wants a death felt can shake the screen itself"
            .. " rather than take a session's decoration into its scoring.",
        note = function() return rules.deathshake_note() end,
        get = function() return rules.deathShake or 0 end,
        set = function(value) rules.deathShake = value end,
    },

    {
        key = "doorbust", id = "db", name = "Kicked doors fly off",

        section = "What the course does to you",
        zero = "a kick bounces off",
        blurb = "a slide kick or a jump kick knocks a door off its hinges",
        levels = {
            { name = "and it misses everybody", hurt = 0 },
            { name = "and it knocks over who it hits", hurt = 1 },
            { name = "and it hits hard", hurt = 3 },
        },
        plain = 0,
        perMode = "No column. A doorway a player can open with their feet is"
            .. " the arena changing shape under the round, and a door in the"
            .. " air is a hit nobody in the round dealt.",
        note = function() return rules.doorbust_note() end,
    },
}

function rules.find(key)
    local index = rules.BY_KEY
    if index ~= nil then return index[key] end
    for _, entry in ipairs(rules.LIST) do
        if entry.key == key then return entry end
    end
    return nil
end

local function ladder_options(levels, zero)
    local built = { { value = 0, name = zero or "off" } }
    if levels == nil or #levels == 0 then
        table.insert(built, { value = 1, name = "on" })
        return built
    end
    for index, step in ipairs(levels) do
        table.insert(built, { value = index, name = step.name })
    end
    return built
end

local ladder = {}

for _, entry in ipairs(rules.LIST) do
    if entry.options == nil then
        entry.options = ladder_options(entry.levels, entry.zero)

        local key = entry.key

        local made = entry.get == nil and entry.set == nil
        entry.get = entry.get or function() return ladder[key] or 0 end
        entry.set = entry.set or function(value) ladder[key] = value end
        entry.ladderOnly = made
    end
end

function rules.step(key)
    local value = rules.value(key)
    return type(value) == "number" and value or 0
end

function rules.step_setting(key, field, fallback)
    local entry = rules.find(key)
    if entry == nil or entry.levels == nil then return fallback end
    local step = entry.levels[rules.step(key)]
    if step == nil or step[field] == nil then return fallback end
    return step[field]
end

local applied = {}

local function sync_world()
    for _, entry in ipairs(rules.LIST) do
        if entry.levels ~= nil or entry.world ~= nil then
            local wanted = rules.step(entry.key)
            local have = applied[entry.key] or 0

            if have ~= 0 and have ~= wanted then
                if entry.restore ~= nil then entry.restore() end
                applied[entry.key] = nil
                have = 0
            end
            if wanted ~= 0 and have == 0 then
                if entry.world ~= nil then entry.world(wanted) end
                applied[entry.key] = wanted
            end
        end
    end
end

rules.sync_world = sync_world

hook_event(HOOK_ON_LEVEL_INIT, function()
    for key in pairs(applied) do applied[key] = nil end
    sync_world()
end)

rules.SECTIONS = { "Between players", "The lobby", "Getting around",
                   "What the course does to you", "Out in the courses",
                   "Races and bosses", "Coins", "Stars", "Caps",
                   "Sound and screen", "Helpers" }

rules.SECTION_HELP = {

    ["Between players"] =
        "what happens when two players meet - whether they are solid, whether "
        .. "they can fight, and how hard a hit throws somebody",
    ["The lobby"] =
        "settings for the lobby as a whole: who may pause, how many may join, "
        .. "and what the level lets anybody do",
    ["Getting around"] =
        "how the ground, the walls and the camera behave while somebody is "
        .. "moving through a course",
    ["What the course does to you"] =
        "the damage the level itself deals - its hazards, its air, its ceiling "
        .. "and the floor underfoot",
    ["Out in the courses"] =
        "settings that belong to one named course each, rather than to every "
        .. "level",
    ["Sound and screen"] =
        "what the game plays and shows between one thing and the next",
    ["Helpers"] =
        "read-outs the game does not normally give you - radars, timers and the "
        .. "course clock",
}

function rules.in_section_order(which)
    local out, taken = {}, {}

    local function wanted(entry)
        if which == "look" then return entry.look == true end
        if which == "readouts" then return entry.section == "Helpers" end
        if which == "page" then
            return entry.look ~= true and entry.section ~= "Helpers"
        end
        return true
    end
    for _, section in ipairs(rules.SECTIONS) do
        local first = true
        for _, entry in ipairs(rules.LIST) do
            if entry.section == section then
                taken[entry.key] = true
                if wanted(entry) then
                    table.insert(out,
                        { entry = entry, header = first and section or nil })
                    first = false
                end
            end
        end
    end
    for _, entry in ipairs(rules.LIST) do
        if not taken[entry.key] and wanted(entry) then
            table.insert(out, { entry = entry })
        end
    end
    return out
end

function rules.room_size_note()
    local limit = rules.value("roomsize")
    if type(limit) ~= "number" then return nil end
    local here = #OF.util.connected_players()
    if here <= limit then return nil end
    return OF.lang.fill("@ are here already - this only refuses new arrivals.", here)
end

local SECRET_LEVELS = "Bob-omb Battlefield, Wet-Dry World, Shifting Sand Land and Tiny-Huge Island"
function rules.interactions_note()
    if (rules.value("interactions") or 0) ~= 3 then return nil end
    return OF.lang.t("Touching somebody mends you both, at the water's own pace.")
end

function rules.fighting_note()

    if (rules.value("interactions") or 0) ~= 2 then
        return OF.lang.t("Nothing until Players touching is fighting.")
    end
    if (rules.value("fighting") or 0) == 1 then
        return OF.lang.t("A punch lands on somebody already down. Juggling.")
    end
    return OF.lang.t("Somebody already down cannot be punched again.")
end

function rules.moveban_note()
    local step = rules.value("moveban") or 0
    if step == 0 then return nil end
    if step == rules.ROLLED_MOVE_STEP then
        local name = rules.option_name(rules.find("moveban"), rules.rolled_ban())
        if type(name) == "string" then
            return OF.lang.fill("In this level: @.", name)
        end
    end
    return OF.lang.t("A move you do not have still does something, so nothing is closed off.")
end

function rules.deathshake_note()
    if rules.step("deathshake") == 0 then return nil end
    return OF.lang.t("Only a death close enough to feel, in the level you are in.")
end

function rules.hitwhere_note()
    local step = rules.value("hitwhere") or 0
    if step == 0 then return nil end

    if (rules.value("interactions") or 0) ~= 2 then
        return OF.lang.t("Nothing until Players touching is fighting.")
    end
    if step == 1 then
        return OF.lang.t("A swing only counts while you are over their head.")
    end
    if step == 2 then
        return OF.lang.t("A swing only counts against somebody's back.")
    end
    return OF.lang.t("A swing only counts while you are both off the ground.")
end

function rules.throwdir_note()
    if (rules.value("throwdir") or 0) == 0 then return nil end
    return OF.lang.t("The centre is the point the level's camera turns around.")
end

rules.engineTagsHeld = rules.engineTagsHeld or false
function rules.hold_engine_tags(on)
    on = on == true
    if on == rules.engineTagsHeld then
        if on and gServerSettings.nametags ~= 0 then gServerSettings.nametags = 0 end
        return false
    end
    if on and rules.tagsField == nil then
        rules.tagsField = OF.util.flag(gServerSettings.nametags) == 0 and 0 or 1
    end
    rules.engineTagsHeld = on
    if on then
        gServerSettings.nametags = 0
    else
        gServerSettings.nametags = rules.tagsField or 1
    end
    return true
end

function rules.tag_shape()
    local field = gServerSettings.nametags
    if rules.engineTagsHeld then field = rules.tagsField or 1 end
    if OF.util.flag(field) == 0 then return 0 end
    local when = rules.tagsWhen
    if type(when) ~= "number" or when < 2 or when > 4 then return 1 end
    return when
end

function rules.nametag_note()
    local shape = rules.value("nametags") or 0
    if shape < 2 then return nil end
    if OF.util.asks(OF.gamemodes, "is_running") and OF.gamemodes.is_running() then
        return OF.lang.t("A round draws every name tag, as it always did.")
    end
    if (rules.value("health") or 0) == 1 then
        return OF.lang.t("A hidden name still carries its health meter.")
    end
    return nil
end

function rules.collision_note()
    local value = rules.value("collision") or 0
    if value == 0 then return nil end
    if value == 2 then
        return OF.lang.t("A grate you could stand on now drops you while the cap is on.")
    end

    if value == 3 then
        return OF.lang.t("Invisible walls gone, and the old wall picking kept.")
    end
    return OF.lang.t("Invisible walls are exposed ceilings. This removes them.")
end

function rules.secrets_note()
    local m = gMarioStates[0]
    local area = m ~= nil and m.area or nil
    local placed = area ~= nil and area.numSecrets or nil

    if placed == nil or placed <= 0 then
        return OF.lang.fill("No secrets in this level - they are in @", SECRET_LEVELS)
    end

    local left = placed
    if count_objects_with_behavior ~= nil and get_behavior_from_id ~= nil then
        local ok, found = pcall(count_objects_with_behavior,
            get_behavior_from_id(id_bhvHiddenStarTrigger))
        if ok and type(found) == "number" then left = found end
    end

    if left <= 0 then
        return OF.lang.t("Every secret in this level has been found.")
    end
    return OF.lang.fill("@ still hidden in this level.", left)
end

local function cap_seconds(base, percent)
    return tostring(math.floor(base * percent / 100 / 30)) .. "s"
end

function rules.cap_length_note()
    local percent = rules.value("caplength")
    if type(percent) ~= "number" then return nil end
    return OF.lang.fill("@ of wing cap, @ of metal and vanish.",
        cap_seconds(CAP_WING, percent), cap_seconds(CAP_METAL, percent))
end

function rules.cap_stage_note()
    local percent = rules.value("capstage")
    if type(percent) ~= "number" then return nil end
    return OF.lang.fill("On entering: @ in the Tower, @ in the Cavern and the Moat.",
        cap_seconds(CAP_TOTWC, percent), cap_seconds(CAP_COTMC, percent))
end

function rules.cap_pits_note()
    if (rules.value("cappits") or 0) == 0 then return nil end
    if (rules.value("bubble") or 0) == 0 then
        return OF.lang.t("Nothing while Bubble on death is off.")
    end
    if #OF.util.connected_players() <= 1 then
        return OF.lang.t("Nobody bubbles while they are the only one here.")
    end
    return OF.lang.t("The Tower, the Cavern, the Moat and Winged Mario over the Rainbow.")
end

function rules.wing_light_note()
    local need = rules.value("winglight")
    if type(need) ~= "number" then return nil end

    if OF.util.asks(OF.save, "has_flag") and SAVE_FLAG_HAVE_WING_CAP ~= nil
        and OF.save.has_flag(SAVE_FLAG_HAVE_WING_CAP) then
        return OF.lang.t("The wing cap switch is pressed - there is no beam left.")
    end

    if not OF.util.asks(OF.save, "star_count") then return nil end
    local have = OF.save.star_count()
    if type(have) ~= "number" then return nil end

    if have >= need then
        return OF.lang.t("The beam is in the castle - stand under it and look up.")
    end
    return OF.lang.fill("@ more stars before the beam appears.", need - have)
end

function rules.point_the_exit(level, area)
    if not rules.exitBack then
        gLevelValues.exitCastleLevel = LEVEL_CASTLE
        gLevelValues.exitCastleArea = 1
        gLevelValues.exitCastleWarpNode = 0x1F
        return
    end
    if level == nil then
        local np = gNetworkPlayers[0]
        if np == nil then return end

        level, area = np.currLevelNum, np.currAreaIndex
    end
    if type(level) ~= "number" or type(area) ~= "number" then return end
    if level == LEVEL_NONE then return end
    gLevelValues.exitCastleLevel = level
    gLevelValues.exitCastleArea = area
    gLevelValues.exitCastleWarpNode = 0x1F
end

function rules.exit_course_note()
    local value = rules.value("exitcourse") or 0
    if value == 2 then
        return OF.lang.t("Exit Course drops you back in at this level's start.")
    end
    if value == 1 then return nil end
    return OF.lang.t("No way out of the pause menu until you are standing still.")
end

function rules.self_tag_note()
    if (rules.value("nametags") or 0) == 0 then
        return OF.lang.t("Nothing while Name tags is off.")
    end
    if (rules.value("selftag") or 0) == 0
        and #OF.util.connected_players() <= 1 then
        return OF.lang.t("Alone in the lobby, no tags are drawn until this is on.")
    end
    return nil
end

function rules.enemies_note()
    if (rules.value("enemies") or 0) == 0 then return nil end
    return OF.lang.t("Lava, pits and long falls are the level rather than an enemy.")
end

function rules.cap_again_note()
    if (rules.value("capagain") or 0) == 0 then return nil end
    return OF.lang.t("Somebody else's cap on the floor is yours to pick up.")
end

function rules.split_note()

    if not OF.util.asks(OF.split, "on") or not OF.split.on() then return nil end
    if not OF.util.asks(OF.split, "seed") then
        return OF.lang.t("Nothing is written to the save file while this is on.")
    end
    return OF.lang.fill("Everybody started from the lobby's @. Nothing is "
        .. "written to the save file while this is on.",
        tostring(OF.split.seed()))
end

function rules.coin_life_note()
    if (rules.value("star") or 0) == 0 then
        return OF.lang.t("Nothing while After a star is leave the level.")
    end
    local every = rules.value("coinlife") or 50
    if every == 0 then return nil end
    if every == 50 then
        return OF.lang.t("The game's own three: fifty, a hundred, a hundred and fifty.")
    end
    return OF.lang.fill("A 1-Up every @ coins, as often as it comes round.",
        tostring(every))
end

function rules.slide_star_note()
    local frames = rules.value("slidestar")
    if type(frames) ~= "number" then return nil end
    return OF.lang.fill(
        "@ seconds down Princess's Secret Slide, and the star is there.",
        tostring(math.floor(frames / 30)))
end

function rules.water_note()
    local percent = rules.value("water")
    if type(percent) ~= "number" then return nil end
    if percent == 100 then
        return OF.lang.t("The game's own speed, and only Wet-Dry World has diamonds.")
    end
    return OF.lang.fill("@% of the game's speed, and only Wet-Dry World has diamonds.",
        tostring(math.floor(percent + 0.5)))
end

function rules.koopa_note()
    if (rules.value("koopa") or 100) == 100 then return nil end
    return OF.lang.t("Bob-omb Battlefield and Tiny-Huge Island.")
end

function rules.bowling_note()
    if (rules.value("bowling") or 100) == 100 then return nil end
    return OF.lang.t("Bob-omb Battlefield, Tall Tall Mountain, Tiny-Huge Island.")
end

function rules.king_note()
    if (rules.value("kingbob") or 100) == 100 then return nil end
    return OF.lang.t("Bob-omb Battlefield, and this is his pace rather than his health.")
end

function rules.penguin_note()
    local width = rules.value("penguin")
    if type(width) ~= "number" or width == 100 then return nil end
    if width == 0 then
        return OF.lang.t("Cool, Cool Mountain - he still races, he just cannot block you.")
    end
    return OF.lang.t("Cool, Cool Mountain, both races down the slope.")
end

function rules.shell_box_note()
    if (rules.value("shellbox") or 1) == 1 then
        return OF.lang.t("Ten seconds, then the box is back. The cap boxes always are.")
    end
    return OF.lang.t("The cap boxes still come back - this is the shell one.")
end

function rules.shell_ride_note()
    if (rules.value("shellride") or 1) == 1 then return nil end
    return OF.lang.t("The shell can vanish under you and you slide on.")
end

function rules.blue_switch_note()
    if (rules.value("switchback") or 0) == 0 then return nil end
    if count_objects_with_behavior == nil or get_behavior_from_id == nil then
        return nil
    end
    local ok, here = pcall(count_objects_with_behavior,
        get_behavior_from_id(id_bhvBlueCoinSwitch))
    if not ok or type(here) ~= "number" then return nil end
    if here <= 0 then
        return OF.lang.t("No blue coin switch in this level.")
    end
    return OF.lang.t("It comes back until its last coin is collected.")
end

function rules.forced_of(entry)
    if entry == nil or type(entry.forced) ~= "function" then return nil end
    local ok, value, reason = pcall(entry.forced)
    if not ok or value == nil then return nil end
    return value, (type(reason) == "string" and reason ~= "") and reason or nil
end

function rules.hosts_own(entry)
    return entry ~= nil and entry.hostOnly == true
end

function rules.shown_value(key)
    local entry = rules.find(key)
    if entry == nil then return nil end
    local forced = rules.forced_of(entry)
    if forced ~= nil then return forced end
    return rules.lobby_value(key)
end

function rules.note_of(entry)
    if entry == nil then return nil end

    local _, reason = rules.forced_of(entry)
    if reason ~= nil then return OF.lang.t(reason) end

    local note = entry.note
    if type(note) ~= "function" then
        return note ~= nil and OF.lang.t(note) or nil
    end
    local ok, text = pcall(note)
    if not ok or type(text) ~= "string" or text == "" then return nil end
    return text
end

function rules.is_switch(entry)
    local options = entry ~= nil and entry.options or nil
    if options == nil or #options ~= 2 then return false end
    return options[1].name == "off" and options[2].name == "on"
end

function rules.baseline(entry)
    if entry == nil then return nil end
    if entry.vanilla ~= nil then return entry.vanilla end
    local first = (entry.options or {})[1]
    return first ~= nil and first.value or nil
end

function rules.option_name(entry, value)
    for _, option in ipairs(entry.options or {}) do
        if option.value == value then return option.name end
    end
    return tostring(value)
end

function rules.next_value(entry, value)
    local options = entry.options or {}
    for index, option in ipairs(options) do
        if option.value == value then
            local nextOption = options[index + 1] or options[1]
            return nextOption.value
        end
    end
    return (options[1] or { value = value }).value
end

function rules.step_of(entry, value)
    local options = entry.options or {}
    local best, bestGap = 1, nil
    for index, option in ipairs(options) do
        if option.value == value then return index end
        local gap = math.abs((tonumber(option.value) or 0) - (tonumber(value) or 0))
        if bestGap == nil or gap < bestGap then
            best, bestGap = index, gap
        end
    end
    return best
end

function rules.step_count(entry)
    return #(entry.options or {})
end

function rules.value_at(entry, step)
    local options = entry.options or {}
    local option = options[OF.util.clamp(math.floor(step or 1), 1, #options)]
    if option == nil then return nil end
    return option.value
end

local WIRE_CHUNK = 160

local WIRE_KEYS = { "ofRules", "ofRules2", "ofRules3", "ofRules4" }

rules.WIRE_CHUNK = WIRE_CHUNK
rules.WIRE_KEYS = WIRE_KEYS

local BY_ID = {}
rules.BY_KEY = {}
for _, entry in ipairs(rules.LIST) do
    if entry.id ~= nil then BY_ID[entry.id] = entry end
    rules.BY_KEY[entry.key] = entry
end

local function entry_for(token)
    return BY_ID[token] or rules.find(token)
end

rules.DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"
local WIRE_WIDTH = 2
local WIRE_MAX = 36 * 36 - 1

rules.WIRE_WIDTH = WIRE_WIDTH
rules.WIRE_MAX = WIRE_MAX

function rules.to36(value, width)
    value = math.floor(tonumber(value) or 0)
    local digits = ""
    while value > 0 do
        local digit = value % 36
        digits = string.sub(rules.DIGITS, digit + 1, digit + 1) .. digits
        value = math.floor(value / 36)
    end
    while #digits < (width or 1) do digits = "0" .. digits end
    return digits
end

function rules.from36(text)
    if type(text) ~= "string" or text == "" then return nil end
    local value = 0
    for index = 1, #text do
        local at = string.find(rules.DIGITS, string.sub(text, index, index), 1, true)
        if at == nil then return nil end
        value = value * 36 + (at - 1)
    end
    return value
end

local function wire_value(entry, value)
    value = math.floor(tonumber(value) or 0)
    if value >= 0 and value <= WIRE_MAX then return value end
    return rules.value_at(entry, rules.step_of(entry, value)) or 0
end

function rules.pack_one(entry, value)
    if entry == nil or entry.id == nil then return "" end
    return entry.id .. rules.to36(wire_value(entry, value), WIRE_WIDTH)
end

function rules.pairs_of(text)
    local found = {}
    if type(text) ~= "string" or text == "" then return found end

    if string.find(text, "=", 1, true) ~= nil then
        for piece in string.gmatch(text, "[^,]+") do
            local token, value = string.match(piece, "^([^=]+)=(-?%d+)$")
            local entry = token ~= nil and entry_for(token) or nil
            if entry ~= nil then
                table.insert(found, { id = entry.id, entry = entry,
                                      value = tonumber(value) })
            end
        end
        return found
    end

    for id, digits in string.gmatch(text, "(%a%a)(%w%w)") do
        local entry = BY_ID[id]
        local value = rules.from36(digits)
        if entry ~= nil and value ~= nil then
            table.insert(found, { id = id, entry = entry, value = value })
        end
    end
    return found
end

function rules.parse_text(packed)
    local set = {}
    for _, pair in ipairs(rules.pairs_of(packed)) do
        set[pair.entry.key] = pair.value
    end
    return set
end

function rules.wire_text(swap, to)
    return OF.util.joined(WIRE_KEYS, swap, to)
end

local wireStamp, setAt, setNow = 0, nil, nil

local function parse()
    if setNow == nil or setAt ~= wireStamp then
        setAt = wireStamp
        setNow = rules.parse_text(rules.wire_text())
    end
    return setNow
end

rules.published = parse

local SHADOW_FLOOR = -10000
local SHADOW_NONE = 30000

land.shadowBase = SHADOW_FLOOR

function rules.set_shadows(on)
    if gLevelValues == nil then return false end
    land.shadowsOff = not on
    if not on then
        gLevelValues.floorLowerLimitShadow = SHADOW_NONE
        return true
    end
    local asked = land.ask.floorLowerLimitShadow
    if type(asked) ~= "number" then asked = SHADOW_FLOOR end
    gLevelValues.floorLowerLimitShadow = asked
    return true
end

function rules.lobby_value(key)
    local entry = rules.find(key)
    if entry == nil then return nil end
    local published = parse()[key]
    if published ~= nil then return published end
    return entry.get()
end

rules.ROUND_KEY = "ofRoundRules"
do

    local roundAt, roundSet = nil, nil

    function rules.round_dress()
        local text = gGlobalSyncTable[rules.ROUND_KEY]
        if type(text) ~= "string" then return "" end
        return text
    end

    function rules.round_set()
        local text = rules.round_dress()
        if roundSet == nil or roundAt ~= text then
            roundAt = text
            roundSet = rules.parse_text(text)
        end
        return roundSet
    end
end

function rules.round_value(key)
    return rules.round_set()[key]
end

function rules.round_holds()
    if not OF.util.asks(OF.lockdown, "menu_stands_down") then return false end
    return OF.lockdown.menu_stands_down() == true
end

function rules.in_force(key)
    local entry = rules.find(key)
    if entry == nil then return nil end

    if key == "whereabouts" and OF.roundscope ~= nil
        and OF.roundscope.keeps_whereabouts ~= nil and OF.roundscope.keeps_whereabouts() then
        return 0
    end

    if entry.plain == nil and rules.round_set()[key] == nil then
        return rules.lobby_value(key)
    end

    if rules.round_holds() then
        local named = rules.round_set()[key]
        if named ~= nil then return named end

        if entry.plain ~= nil then return entry.plain end
    end

    return rules.lobby_value(key)
end

function rules.value(key)
    return rules.in_force(key)
end

function rules.suspended(key)
    if not rules.round_holds() then return false end

    if rules.forced_of(rules.find(key)) ~= nil then return false end
    return rules.in_force(key) ~= rules.lobby_value(key)
end

function rules.apply()
    for _, entry in ipairs(rules.LIST) do

        local value
        if entry.ladderOnly then
            value = rules.lobby_value(entry.key)
        else
            value = rules.in_force(entry.key)
        end
        if value ~= nil and entry.get() ~= value then entry.set(value) end
    end

    gLevelValues.hudRedCoinsRadar = false

    gLevelValues.hudSecretsRadar = false

    rules.point_the_exit()

    if rules.apply_star_doors ~= nil then rules.apply_star_doors() end

    sync_world()
end

local applyHold = { depth = 0 }

function rules.defer_apply()
    return applyHold.depth > 0
end

local function publish_parts(parts)
    local chunks = OF.util.chunk_parts(parts, WIRE_CHUNK)
    if chunks == nil or #chunks > #WIRE_KEYS then

        local perKey = math.floor(WIRE_CHUNK / (2 + WIRE_WIDTH))
        OF.util.chat("Too many lobby rules to send ("
            .. tostring(#parts) .. " of them, "
            .. tostring(#WIRE_KEYS * perKey) .. " is the limit).", "warn")
        return false
    end

    local ok = true
    applyHold.depth = applyHold.depth + 1
    for index, wireKey in ipairs(WIRE_KEYS) do
        if not OF.util.publish(wireKey, chunks[index] or "") then ok = false end
    end
    applyHold.depth = applyHold.depth - 1

    if applyHold.depth <= 0 then rules.apply() end
    return ok
end

local function publish(set)
    local parts = {}
    for _, entry in ipairs(rules.LIST) do
        local value = set[entry.key]
        if value ~= nil then
            table.insert(parts, rules.pack_one(entry, value))
        end
    end
    return publish_parts(parts)
end

function rules.publish_text(text)
    if not OF.util.is_host() then return false end
    local parts = {}
    for _, pair in ipairs(rules.pairs_of(text)) do
        table.insert(parts, rules.pack_one(pair.entry, pair.value))
    end
    return publish_parts(parts)
end

function rules.publish_round(text)
    if not OF.util.is_host() then return false end
    local parts = {}
    for _, pair in ipairs(rules.pairs_of(text or "")) do
        table.insert(parts, rules.pack_one(pair.entry, pair.value))
    end
    local packed = table.concat(parts, "")
    if #packed > WIRE_CHUNK then
        OF.util.chat("The round's rule set is too long to send.", "warn")
        return false
    end

    return OF.util.publish(rules.ROUND_KEY, packed)
end

function rules.set_round(key, value)
    if not OF.util.is_host() then return false end
    local entry = rules.find(key)
    if entry == nil then return false end
    local set = rules.parse_text(rules.round_dress())
    set[key] = value
    local parts = {}
    for _, other in ipairs(rules.LIST) do
        if set[other.key] ~= nil then
            table.insert(parts, rules.pack_one(other, set[other.key]))
        end
    end
    return rules.publish_round(table.concat(parts, ""))
end

function rules.round_text()
    local wanted = {}
    for _, entry in ipairs(rules.LIST) do
        if entry.plain ~= nil then wanted[entry.id] = entry.plain end
    end

    local parts, seen = {}, {}
    for _, pair in ipairs(rules.pairs_of(rules.wire_text())) do
        seen[pair.id] = true
        local value = wanted[pair.id]
        if value == nil then value = pair.value end
        table.insert(parts, rules.pack_one(pair.entry, value))
    end

    for _, entry in ipairs(rules.LIST) do
        if entry.plain ~= nil and not seen[entry.id]
            and entry.get() ~= entry.plain then
            table.insert(parts, rules.pack_one(entry, entry.plain))
        end
    end
    return table.concat(parts, "")
end

function rules.snapshot()
    local values = {}
    for _, entry in ipairs(rules.LIST) do
        values[entry.id] = rules.value(entry.key)
    end
    return { text = rules.wire_text(), values = values }
end

function rules.restore_text(snap)
    if type(snap) ~= "table" then return nil end

    local held, parts = {}, {}
    for _, pair in ipairs(rules.pairs_of(snap.text or "")) do
        held[pair.id] = true
        table.insert(parts, rules.pack_one(pair.entry, pair.value))
    end

    for _, pair in ipairs(rules.pairs_of(rules.wire_text())) do
        local was = (snap.values or {})[pair.id]
        if not held[pair.id] and was ~= nil then
            table.insert(parts, rules.pack_one(pair.entry, was))
        end
    end
    return table.concat(parts, "")
end

function rules.would_change_for_round()
    local set = parse()
    for _, entry in ipairs(rules.LIST) do
        if entry.plain ~= nil and set[entry.key] ~= nil
            and set[entry.key] ~= entry.plain then
            return true
        end
    end
    return false
end

function rules.changed_line(before, after)
    local was, now = rules.parse_text(before), rules.parse_text(after)
    local moved, only = 0, nil
    for _, entry in ipairs(rules.LIST) do
        if was[entry.key] ~= now[entry.key] then
            moved = moved + 1
            only = entry
        end
    end
    if moved == 0 then return nil end
    if moved == 1 then
        return OF.lang.fill("@ - @", only.name,
            rules.option_name(only, now[only.key]))
    end
    return OF.lang.fill("@ rules changed", tostring(moved))
end

local function announce_set(entry, value, askerLocal)

    local signed = OF.util.asks(OF.notify, "credit")
        and OF.notify.credit(askerLocal, OF.lang.fill("@ - @", entry.name,
            rules.option_name(entry, value)))
    if not signed then
        OF.notify.send_all("@ - @", "info", 4,
            entry.name, rules.option_name(entry, value))
    end

    local note = rules.note_of(entry)
    if note ~= nil and askerLocal ~= nil
        and OF.util.asks(OF.notify, "send_to") then
        OF.notify.send_to(network_global_index_from_local(askerLocal),
            "@", "quiet", 4, note)
    end
end

function rules.set_many(wanted, quiet, askerLocal)
    if not OF.util.is_host() then return false, "Only the host sets the rules." end
    if type(wanted) ~= "table" then return false, "No such rule." end

    local chosen = {}
    for _, want in ipairs(wanted) do
        local entry = rules.find(want.key)
        if entry == nil then return false, "No such rule." end
        table.insert(chosen, { entry = entry, value = want.value })
    end

    if #chosen == 0 then return true end

    local set = rules.parse_text(rules.wire_text())

    for _, other in ipairs(rules.LIST) do
        if set[other.key] == nil then set[other.key] = other.get() end
    end
    for _, pick in ipairs(chosen) do set[pick.entry.key] = pick.value end

    if not publish(set) then
        return false, "That is too much to send to the lobby at once."
    end

    if not quiet then
        for _, pick in ipairs(chosen) do
            announce_set(pick.entry, pick.value, askerLocal)
        end
    end
    return true
end

function rules.set(key, value, quiet, askerLocal)
    return rules.set_many({ { key = key, value = value } }, quiet, askerLocal)
end

function rules.pin_the_room()
    if not OF.util.is_host() then return false end

    local set = rules.parse_text(rules.wire_text())
    local missing = {}
    for _, entry in ipairs(rules.LIST) do
        if set[entry.key] == nil then
            table.insert(missing, { key = entry.key, value = entry.get() })
        end
    end

    if #missing == 0 then return true end

    return rules.set_many(missing, true)
end

local lentRules = {}

local function room_in_round()
    if rules.round_holds() then return true end
    local lock = OF.lockdown
    if OF.util.asks(lock, "round_or_run") and lock.round_or_run() == true then
        return true
    end
    if OF.util.asks(lock, "held_by_round") and lock.held_by_round() == true then
        return true
    end
    return OF.util.asks(lock, "held_by_race") and lock.held_by_race() == true
end

local function lend_slot(key)
    local slot = lentRules[key]
    if slot == nil then
        slot = { round = room_in_round(), holders = {}, count = 0,
            wants = {}, order = {} }

        if not slot.round then slot.was = rules.lobby_value(key) end
        lentRules[key] = slot
    end
    return slot
end

local function lend_hand(slot, holder, value)
    if not slot.holders[holder] then
        slot.holders[holder] = true
        slot.count = slot.count + 1
        table.insert(slot.order, holder)
    end

    slot.wants[holder] = value
end

function rules.lend(key, holder, value)
    if not OF.util.is_host() then return false end
    if holder == nil or value == nil then return false end
    if rules.find(key) == nil then return false end

    local slot = lend_slot(key)
    lend_hand(slot, holder, value)

    if slot.round then
        if rules.round_value(key) ~= value then
            return rules.set_round(key, value)
        end
        return true
    end
    if rules.lobby_value(key) ~= value then
        return rules.set(key, value, true)
    end
    return true
end

function rules.lend_many(wanted, holder)
    if not OF.util.is_host() then return false end
    if type(wanted) ~= "table" or holder == nil then return false end

    local changing, dress = {}, nil
    for _, want in ipairs(wanted) do
        if want.value ~= nil and rules.find(want.key) ~= nil then
            local slot = lend_slot(want.key)
            lend_hand(slot, holder, want.value)
            if slot.round then
                if rules.round_value(want.key) ~= want.value then
                    if dress == nil then
                        dress = rules.parse_text(rules.round_dress())
                    end
                    dress[want.key] = want.value
                end
            elseif rules.lobby_value(want.key) ~= want.value then
                table.insert(changing, { key = want.key, value = want.value })
            end
        end
    end

    local ok = true
    if dress ~= nil then
        local parts = {}
        for _, entry in ipairs(rules.LIST) do
            if dress[entry.key] ~= nil then
                table.insert(parts, rules.pack_one(entry, dress[entry.key]))
            end
        end
        ok = rules.publish_round(table.concat(parts, ""))
    end

    if #changing == 0 then return ok end

    local sent, why = rules.set_many(changing, true)
    if not sent then return false, why end
    return ok
end

function rules.give_back(key, holder)
    if not OF.util.is_host() then return false end
    local slot = lentRules[key]
    if slot == nil or holder == nil then return false end
    if not slot.holders[holder] then return false end

    slot.holders[holder] = nil
    slot.count = slot.count - 1
    slot.wants[holder] = nil
    for at = #slot.order, 1, -1 do
        if slot.order[at] == holder then table.remove(slot.order, at) end
    end

    local last = slot.count <= 0

    local wanted = slot.was
    if not last then
        wanted = slot.wants[slot.order[#slot.order]]
    else

        lentRules[key] = nil
    end
    if slot.round then
        if rules.round_value(key) ~= wanted then
            return rules.set_round(key, wanted)
        end
        return true
    end
    if wanted ~= nil and rules.lobby_value(key) ~= wanted then
        return rules.set(key, wanted, true)
    end
    return true
end

function rules.round_release()
    if not OF.util.is_host() then return false end
    for key, slot in pairs(lentRules) do
        if slot.round then lentRules[key] = nil end
    end
    return rules.publish_round("")
end

function rules.ask_set(key, step)
    if not OF.perms.can("rules") then return false, "Your rank cannot do that." end
    local entry = rules.find(key)
    if entry == nil then return false, "No such rule." end

    if rules.hosts_own(entry) and not OF.util.is_host() then
        return false, "Only the host changes that one."
    end
    local value = rules.value_at(entry, step)
    if value == nil then return false, "No such setting for that rule." end

    if OF.util.is_host() then return rules.set(key, value, false, 0) end
    if entry.id == nil then return false, "That rule cannot travel." end
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does("rule", entry.id, step)
    end
    return false, "No host to ask yet - try again in a second."
end

function rules.set_here(asker, id, step)
    if not OF.util.is_host() then return false, "Only the host sets the rules." end
    if asker == nil then return false, "Who asked?" end
    if OF.perms.tier(asker) < OF.perms.required("rules", asker) then
        return false, "Your rank cannot do that."
    end
    local entry = entry_for(tostring(id))
    if entry == nil then return false, "No such rule." end

    if rules.hosts_own(entry) and not OF.util.is_host_player(asker) then
        return false, "Only the host changes that one."
    end
    local value = rules.value_at(entry, math.floor(tonumber(step) or 0))
    if value == nil then return false, "No such setting for that rule." end

    return rules.set(entry.key, value, false, asker)
end

function rules.set_from_panel(key)
    local entry = rules.find(key)
    if entry == nil then return false, "No such rule." end

    local wanted = rules.step_of(entry,
        rules.next_value(entry, rules.lobby_value(key)))
    return rules.ask_set(key, wanted)
end

function rules.set_step(key, step)
    return rules.ask_set(key, step)
end

local function each_door(fn)
    for _, behaviourId in ipairs({ id_bhvStarDoor, id_bhvDoor }) do
        if behaviourId ~= nil then
            local object = obj_get_first_with_behavior_id(behaviourId)
            while object ~= nil do
                fn(object)
                object = obj_get_next_with_same_behavior_id(object)
            end
        end
    end
end

local doorWas = {}

local function door_key(object)
    return tostring(math.floor(object.oPosX or 0)) .. ":"
        .. tostring(math.floor(object.oPosY or 0)) .. ":"
        .. tostring(math.floor(object.oPosZ or 0))
end

local function split_got()
    if not OF.util.asks(OF.split, "on") then return nil end
    if not OF.split.on() then return nil end
    return OF.split.got(0)
end

local stairsHeld = false
local stairsWas = nil

function rules.stairs_wish()
    if stairsHeld then return stairsWas end
    return gLevelValues.infiniteStairsRequirement
end

function rules.set_stairs(value)
    if not stairsHeld then
        gLevelValues.infiniteStairsRequirement = value
        return
    end
    stairsWas = value
    local wants = value - (split_got() or 0)
    if wants < 0 then wants = 0 end
    gLevelValues.infiniteStairsRequirement = wants
end

local CASTLE_DOORS = { 8, 30, 50, 70 }

local DOOR_PRICE_CEILING = 255

local function door_price(map, was)
    if map == nil or was == 0 then return was end
    local now = map[was]
    if type(now) ~= "number" then return was end
    if now < 0 then return 0 end
    if now > DOOR_PRICE_CEILING then return DOOR_PRICE_CEILING end
    return now
end

local function door_price_map()
    return rules.step_setting("doorprice", "price", nil)
end

function rules.door_price_note()
    local map = door_price_map()
    if map == nil then return nil end

    local was, now = "", ""
    for index, price in ipairs(CASTLE_DOORS) do
        local gap = index > 1 and ", " or ""
        was = was .. gap .. tostring(price)
        now = now .. gap .. tostring(door_price(map, price))
    end
    return was .. " stars become " .. now
end

local function aim_star_gates()
    local got = split_got()
    local map = door_price_map()

    if rules.doorsOpen then
        each_door(function(object)

            object.oBehParams = object.oBehParams % 16777216
        end)

        doorWas = {}
    elseif got ~= nil or map ~= nil then
        each_door(function(object)
            local key = door_key(object)
            local rest = object.oBehParams % 16777216
            local was = doorWas[key]
            if was == nil then

                was = math.floor(object.oBehParams / 16777216)
                doorWas[key] = was
            end

            local wants = door_price(map, was) - (got or 0)
            if wants < 0 then wants = 0 end
            if wants > DOOR_PRICE_CEILING then wants = DOOR_PRICE_CEILING end
            object.oBehParams = rest + wants * 16777216
        end)
    elseif next(doorWas) ~= nil then
        each_door(function(object)
            local key = door_key(object)
            local was = doorWas[key]
            if was == nil then return end
            object.oBehParams = object.oBehParams % 16777216 + was * 16777216
        end)
        doorWas = {}
    end

    if got ~= nil then
        if not stairsHeld then
            local wanted = gLevelValues.infiniteStairsRequirement
            if type(wanted) ~= "number" then wanted = 70 end
            stairsWas = wanted
            stairsHeld = true
        end
        local wants = stairsWas - got
        if wants < 0 then wants = 0 end
        gLevelValues.infiniteStairsRequirement = wants
    elseif stairsHeld then
        gLevelValues.infiniteStairsRequirement = stairsWas
        stairsHeld = false
        stairsWas = nil
    end
end

rules.aim_star_gates = aim_star_gates

rules.apply_star_doors = aim_star_gates

hook_event(HOOK_ON_LEVEL_INIT, function()

    doorWas = {}
    aim_star_gates()
end)

local CROWD_REACH = 300
local CROWD_RISE = 200

local CROWD_FULL = 180
local CROWD_FILLS = 2
local CROWD_DRAINS = 1

local crowdAt = {}

local function crowd_wanted()
    local entry = rules.find("crowd")
    if entry == nil or entry.levels == nil then return nil end
    local step = rules.step("crowd")
    if step == 0 then return nil end
    local level = entry.levels[step]
    if level == nil then return nil end

    local here = #OF.util.connected_players()
    if here < 1 then here = 1 end

    local want
    if level.share ~= nil then
        want = math.ceil(here * level.share / 100)
    else
        want = level.count
    end
    if type(want) ~= "number" then return nil end
    if want > here then want = here end
    if want < 1 then want = 1 end
    return want
end

rules.crowd_wanted = crowd_wanted

local function crowd_at(object)
    if object == nil then return 0 end
    local x, y, z = object.oPosX, object.oPosY, object.oPosZ
    if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
        return 0
    end

    local me = gNetworkPlayers[0]
    if me == nil then return 0 end

    local here = 0
    for _, row in ipairs(OF.util.connected_players()) do
        local other = gMarioStates[row.localIndex]
        local np = row.np

        if other ~= nil and other.pos ~= nil and np ~= nil
            and OF.util.seen_here(row.localIndex) then
            local rise = other.pos.y - y
            if rise < 0 then rise = -rise end
            if rise <= CROWD_RISE then
                local dx = other.pos.x - x
                local dz = other.pos.z - z
                if dx * dx + dz * dz <= CROWD_REACH * CROWD_REACH then
                    here = here + 1
                end
            end
        end
    end
    return here
end

local function wind_the_crowd()
    local want = crowd_wanted()
    if want == nil then

        if next(crowdAt) ~= nil then crowdAt = {} end
        return
    end

    local seen = {}
    each_door(function(object)
        local key = door_key(object)
        seen[key] = true
        local at = crowdAt[key] or 0
        if crowd_at(object) >= want then
            at = at + CROWD_FILLS
            if at > CROWD_FULL then at = CROWD_FULL end
        else
            at = at - CROWD_DRAINS
            if at < 0 then at = 0 end
        end
        crowdAt[key] = at
    end)

    for key in pairs(crowdAt) do
        if seen[key] == nil then crowdAt[key] = nil end
    end
end

rules.wind_the_crowd = wind_the_crowd

function rules.door_crowd_bar(object)
    if object == nil or crowd_wanted() == nil then return nil end
    return (crowdAt[door_key(object)] or 0) / CROWD_FULL
end

local function crowd_refuses(object, interactType)
    if interactType ~= INTERACT_DOOR
        and interactType ~= INTERACT_WARP_DOOR then
        return false
    end
    if object == nil then return false end
    if crowd_wanted() == nil then return false end
    return (crowdAt[door_key(object)] or 0) < CROWD_FULL
end

rules.crowd_refuses = crowd_refuses

function rules.crowd_note()
    local want = crowd_wanted()
    if want == nil then return nil end
    local here = #OF.util.connected_players()
    return tostring(here) .. " connected, so a door wants " .. tostring(want)
end

hook_event(HOOK_UPDATE, wind_the_crowd)

hook_event(HOOK_ON_LEVEL_INIT, function()

    crowdAt = {}
end)

hook_event(HOOK_ON_LEVEL_INIT, function(_, levelNum, areaIdx)
    rules.point_the_exit(levelNum, areaIdx)
end)

local DOOR_OPEN_ACTION = 1

local function open_frame(max)
    return math.floor(max * 9 / 16)
end

local DOOR_NEAR = 350
local DOOR_NEAR_SQ = DOOR_NEAR * DOOR_NEAR

local function somebody_at(object)
    local me = gNetworkPlayers[0]
    if me == nil then return false end
    for _, entry in ipairs(OF.util.connected_players()) do
        local np = entry.np
        local m = gMarioStates[entry.localIndex]
        if np ~= nil and m ~= nil and m.pos ~= nil
            and OF.util.seen_here(entry.localIndex) then
            local dx = m.pos.x - object.oPosX
            local dy = m.pos.y - object.oPosY
            local dz = m.pos.z - object.oPosZ
            if dx * dx + dy * dy + dz * dz < DOOR_NEAR_SQ then return true end
        end
    end
    return false
end

local function run_locked(object)
    if not (OF.util.asks(OF.roundact, "holder") and OF.roundact.holder() == "run"
        and OF.util.asks(OF.roundact, "plays") and OF.roundact.plays(0)) then
        return false
    end
    local need = math.floor((object.oBehParams or 0) / 0x1000000) % 0x100
    if need <= 0 then return false end
    local m = gMarioStates[0]
    return m == nil or (m.numStars or 0) < need
end

local function hold_doors_open()
    local mode = rules.doorsMode or 0

    if mode == 0 or mode == 3 then return end
    if obj_get_first_with_behavior_id == nil or id_bhvDoor == nil then return end

    local object = obj_get_first_with_behavior_id(id_bhvDoor)
    while object ~= nil do

        if not OF.util.has_flag(object.oInteractType, INTERACT_WARP_DOOR)
            and not run_locked(object)
            and (mode == 1 or somebody_at(object)) then
            local gfx = object.header ~= nil and object.header.gfx or nil
            local info = gfx ~= nil and gfx.animInfo or nil
            local anim = info ~= nil and info.curAnim or nil
            if anim ~= nil and (anim.loopEnd or 0) > 2 then
                object.oAction = DOOR_OPEN_ACTION
                info.animFrame = open_frame(anim.loopEnd - 2)
            end
        end
        object = obj_get_next_with_same_behavior_id(object)
    end
end

local STAR_DOOR_OPENING = 1
local STAR_DOOR_HOLDING = 2

local function nearest_other(doors, index)
    local leaf, best, bestDist = doors[index], nil, nil
    for other = 1, #doors do
        if other ~= index then
            local dx = doors[other].oPosX - leaf.oPosX
            local dy = doors[other].oPosY - leaf.oPosY
            local dz = doors[other].oPosZ - leaf.oPosZ
            local dist = dx * dx + dy * dy + dz * dz
            if bestDist == nil or dist < bestDist then
                best, bestDist = other, dist
            end
        end
    end
    return best
end

local function hold_star_doors_open()
    local mode = rules.doorsMode or 0
    if mode == 0 then return end
    if obj_get_first_with_behavior_id == nil or id_bhvStarDoor == nil then return end

    local always = (mode ~= 2)

    local doors, held = {}, {}
    local object = obj_get_first_with_behavior_id(id_bhvStarDoor)
    while object ~= nil do
        doors[#doors + 1] = object
        held[#doors] = not run_locked(object) and (always or somebody_at(object))
        object = obj_get_next_with_same_behavior_id(object)
    end

    if not always then
        local partner = {}
        for index = 1, #doors do partner[index] = nearest_other(doors, index) end
        for _ = 1, #doors do
            local spread = false
            for index = 1, #doors do
                local other = partner[index]
                if not held[index] and other ~= nil and held[other] then
                    held[index] = true
                    spread = true
                end
            end
            if not spread then break end
        end
    end

    for index = 1, #doors do
        if held[index] then
            local door = doors[index]
            local action = door.oAction or 0
            if action == 0 then
                door.oAction = STAR_DOOR_OPENING
            elseif action == STAR_DOOR_HOLDING then
                door.oTimer = 0
            end
        end
    end
end

rules.hold_star_doors_open = hold_star_doors_open

rules.hold_doors_open = hold_doors_open

local clockOn = false
local clockFrom = nil

local CLOCK_CEILING = 17999

local function clock_flags()
    return OF.util.optional("hud_get_value", nil, HUD_DISPLAY_FLAGS)
end

local function clock_flag(on)
    local flags = clock_flags()
    if type(flags) ~= "number" then return end
    local shown = OF.util.has_flag(flags, HUD_DISPLAY_FLAG_TIMER)
    if on and not shown then
        OF.util.optional("hud_set_value", nil, HUD_DISPLAY_FLAGS,
            flags + HUD_DISPLAY_FLAG_TIMER)
    elseif not on and shown then
        OF.util.optional("hud_set_value", nil, HUD_DISPLAY_FLAGS,
            flags - HUD_DISPLAY_FLAG_TIMER)
    end
end

function rules.course_clock(on)
    clockOn = on and true or false
    if clockOn then
        clockFrom = OF.util.optional("get_network_area_timer", nil)
        clock_flag(true)
        OF.util.optional("hud_set_value", nil, HUD_DISPLAY_TIMER, 0)
        return
    end
    clockFrom = nil
    clock_flag(false)
    OF.util.optional("hud_set_value", nil, HUD_DISPLAY_TIMER, 0)
end

function rules.course_clock_on()
    return clockOn
end

local function wind_course_clock()
    if not clockOn then return end
    if OF.util.optional("level_control_timer_running", 0) ~= 0 then return end

    local now = OF.util.optional("get_network_area_timer", nil)
    if type(now) ~= "number" then return end

    if type(clockFrom) ~= "number" or now < clockFrom then clockFrom = now end

    clock_flag(true)
    local elapsed = now - clockFrom
    if elapsed > CLOCK_CEILING then elapsed = CLOCK_CEILING end
    OF.util.optional("hud_set_value", nil, HUD_DISPLAY_TIMER, elapsed)
end

rules.wind_course_clock = wind_course_clock

local starClock = { from = nil, level = nil }

function rules.stop_star_clock()
    if starClock.from ~= nil and not clockOn then
        clock_flag(false)
        OF.util.optional("hud_set_value", nil, HUD_DISPLAY_TIMER, 0)
    end
    starClock.from, starClock.level = nil, nil
end

function rules.run_star_clock()
    local limit = rules.step_setting("starclock", "seconds", nil)
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    if limit == nil or np == nil or m == nil or (np.currCourseNum or 0) == 0 then
        rules.stop_star_clock()
        return false
    end
    if OF.util.optional("level_control_timer_running", 0) ~= 0 then return false end
    local now = OF.util.optional("get_network_area_timer", nil)
    if type(now) ~= "number" then return false end
    if starClock.from == nil or starClock.level ~= np.currLevelNum
        or now < starClock.from then
        starClock.from, starClock.level = now, np.currLevelNum
    end
    local left = limit * 30 - (now - starClock.from)
    clock_flag(true)
    OF.util.optional("hud_set_value", nil, HUD_DISPLAY_TIMER, math.max(0, left))
    if left > 0 then return false end

    if (m.hurtCounter or 0) < 40 then m.hurtCounter = 40 end
    starClock.from = now
    return true
end

hook_event(HOOK_UPDATE, function()
    wind_course_clock()
    rules.run_star_clock()
end)

hook_event(HOOK_UPDATE, hold_doors_open)

hook_event(HOOK_UPDATE, hold_star_doors_open)

local LID_OPEN = CANNON_TRAP_DOOR_ACT_OPEN or 3

local function open_cannons()
    if not rules.cannonsOpen then return end
    if obj_get_first_with_behavior_id == nil or id_bhvCannonClosed == nil then return end
    if OF.util.asks(OF.levelfix, "cannons_sealed")
        and OF.levelfix.cannons_sealed() then
        return
    end

    local object = obj_get_first_with_behavior_id(id_bhvCannonClosed)
    while object ~= nil do

        local nextObject = obj_get_next_with_same_behavior_id(object)
        if object.activeFlags ~= ACTIVE_FLAG_DEACTIVATED then

            object.oAction = LID_OPEN
            object.activeFlags = ACTIVE_FLAG_DEACTIVATED
        end
        object = nextObject
    end
end

rules.open_cannons = open_cannons

hook_event(HOOK_UPDATE, open_cannons)

local WATER_MEND = 0x1A

local healthWas = nil

local function refuse_the_water(m)

    if m == nil or m.playerIndex ~= 0 then return false end

    local health = tonumber(m.health)
    if health == nil then
        healthWas = nil
        return false
    end

    local before = healthWas

    healthWas = health

    if rules.waterMends then return false end
    if before == nil then return false end
    if health - before ~= WATER_MEND then return false end

    if not OF.util.has_flag(m.action, ACT_FLAG_SWIMMING) then return false end
    if OF.util.has_flag(m.action, ACT_FLAG_INTANGIBLE) then return false end

    m.health = before
    healthWas = before
    return true
end

rules.refuse_the_water = refuse_the_water

hook_event(HOOK_MARIO_UPDATE, refuse_the_water, OF.LOCAL_MARIO)

do

    local HEAL_ON_TOUCH = WATER_MEND
    local HEAL_FULL = 0x880

    local function marios_touching(a, b)
        if a == nil or b == nil then return false end
        local aObj, bObj = a.marioObj, b.marioObj
        if aObj == nil or bObj == nil then return false end
        if aObj.oIntangibleTimer ~= 0 or bObj.oIntangibleTimer ~= 0 then
            return false
        end
        local aBody, bBody = a.marioBodyState, b.marioBodyState
        if aBody == nil or bBody == nil then return false end
        if aBody.mirrorMario or bBody.mirrorMario then return false end

        local aTorso, bTorso = aBody.torsoPos, bBody.torsoPos
        if aTorso == nil or bTorso == nil then return false end

        local aBottom = aTorso.y - aObj.hitboxDownOffset
        local bBottom = bTorso.y - bObj.hitboxDownOffset
        local dx = aTorso.x - bTorso.x
        local dz = aTorso.z - bTorso.z
        local radius = (aObj.hitboxRadius + bObj.hitboxRadius) * 1.75
        if radius * radius <= (dx * dx + dz * dz) then return false end

        local aTop = aObj.hitboxHeight + aBottom
        local bTop = bObj.hitboxHeight + bBottom
        if aBottom > bTop or aTop < bBottom then return false end
        return true
    end

    function rules.heal_on_touch(m)
        if m == nil or m.playerIndex ~= 0 then return false end
        if rules.step("interactions") ~= 3 then return false end

        local health = tonumber(m.health)
        if health == nil or health >= HEAL_FULL then return false end

        local me = gNetworkPlayers[0]
        if me == nil then return false end

        local touching = false
        for _, row in ipairs(OF.util.connected_players()) do
            local seat = row.localIndex
            if seat ~= 0 and row.np ~= nil
                and OF.util.seen_here(seat)
                and marios_touching(m, gMarioStates[seat]) then
                touching = true
                break
            end
        end
        if not touching then return false end

        m.health = math.min(health + HEAL_ON_TOUCH, HEAL_FULL)
        return true
    end
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, rules.heal_on_touch, OF.LOCAL_MARIO)

local BUST_FRAMES = 10 * 30
local FLY_FRAMES = 4 * 30

local BUST_SPEED = 20

local BUST_MATCH = 60

local BUST_KICKS = {}
for _, name in ipairs({ "ACT_SLIDE_KICK", "ACT_SLIDE_KICK_SLIDE", "ACT_JUMP_KICK" }) do
    local id = _G[name]
    if type(id) == "number" then BUST_KICKS[id] = true end
end

local BUST_PACKET = "doorbust"
rules.BUST_PACKET = BUST_PACKET

local busted = {}
rules.bustedDoors = busted

local bustHitBy = {}

local BUST_INVISIBLE = GRAPH_RENDER_INVISIBLE or 16

function rules.doorbust_note()
    if rules.step("doorbust") == 0 then return nil end
    return OF.lang.t("Warp doors and doors that still want stars stay on their hinges.")
end

function rules.bust_wanted(m, obj, interactType)
    if m == nil or obj == nil or m.playerIndex ~= 0 then return false end
    if interactType ~= INTERACT_DOOR then return false end
    if rules.step("doorbust") == 0 then return false end
    if not BUST_KICKS[m.action or 0] then return false end
    if math.abs(m.forwardVel or 0) < BUST_SPEED then return false end

    if id_bhvDoor == nil
        or OF.util.optional("obj_has_behavior_id", 0, obj, id_bhvDoor) == 0 then
        return false
    end

    if math.floor((obj.oBehParams or 0) / 0x1000000) % 0x100 ~= 0 then return false end
    if (obj.oAction or 0) ~= 0 then return false end
    return busted[door_key(obj)] == nil
end

local function flier_init(o)
    o.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE or 0
    o.oGravity = 4
end

local function flier_loop(o)
    o.oTimer = o.oTimer or 0
    local airborne = (o.oForwardVel or 0) > 0
    if airborne then
        o.oPosX = o.oPosX + sins(o.oMoveAngleYaw) * o.oForwardVel
        o.oPosZ = o.oPosZ + coss(o.oMoveAngleYaw) * o.oForwardVel
        o.oVelY = (o.oVelY or 0) - (o.oGravity or 4)
        o.oPosY = o.oPosY + o.oVelY

        o.oFaceAnglePitch = (o.oFaceAnglePitch or 0) + 0x0C00
        local floorY = find_floor_height(o.oPosX, o.oPosY + 100, o.oPosZ)
        if floorY ~= nil and floorY > -10000 and o.oPosY <= floorY then
            o.oPosY = floorY
            o.oForwardVel = 0
            o.oVelY = 0
            o.oFaceAnglePitch = -0x4000
        end
    end
    if o.oTimer >= FLY_FRAMES then obj_mark_for_deletion(o) end
end

if type(hook_behavior) == "function" then
    rules.BUST_FLIER = hook_behavior(nil, OBJ_LIST_UNIMPORTANT or 9, false,
        flier_init, flier_loop, "of busted door")
end

function rules.bust_door(door, yaw, kicker)
    if door == nil then return false end
    local key = door_key(door)
    if busted[key] ~= nil then return false end

    local flier = nil
    if rules.BUST_FLIER ~= nil and spawn_non_sync_object ~= nil then
        local model = OF.util.optional("obj_get_model_id_extended", nil, door)
        if model ~= nil then
            flier = OF.slots.spawn_non_sync(rules.BUST_FLIER, model,
                door.oPosX, door.oHomeY or door.oPosY, door.oPosZ, function(o)
                    o.oMoveAngleYaw = yaw or 0
                    o.oFaceAngleYaw = door.oFaceAngleYaw or 0
                    o.oForwardVel = 70
                    o.oVelY = 36
                    o.oTimer = 0
                    o.globalPlayerIndex = kicker or 0
                end)
        end
    end

    busted[key] = { door = door, left = BUST_FRAMES, flier = flier,
                    fly = FLY_FRAMES - 2, kicker = kicker, key = key }

    local sound = _G["SOUND_GENERAL_BREAK_BOX"]
    if type(sound) == "number" and door.header ~= nil then
        OF.util.optional("play_sound", nil, sound, door.header.gfx.cameraToObject)
    end
    OF.util.optional("spawn_triangle_break_particles", nil, 20, 138, 1, 4)
    return true
end

local function mend(entry)
    local door = entry.door
    if door ~= nil and door.header ~= nil and door.header.gfx ~= nil then
        local node = door.header.gfx.node
        if node ~= nil and OF.util.has_flag(node.flags or 0, BUST_INVISIBLE) then
            node.flags = node.flags - BUST_INVISIBLE
        end
    end
end

function rules.mend_all_doors()
    for key, entry in pairs(busted) do
        mend(entry)
        busted[key] = nil
    end
    bustHitBy = {}
end

local function bust_hits_me(entry)
    local stop = rules.step_setting("doorbust", "hurt", 0)
    if stop <= 0 then return false end
    if (entry.fly or 0) <= 0 then return false end
    local o = entry.flier
    local m = gMarioStates[0]
    if o == nil or m == nil or m.pos == nil then return false end
    if (o.oForwardVel or 0) <= 0 then return false end
    if bustHitBy[entry.key] then return false end
    local me = network_global_index_from_local(0)
    if entry.kicker ~= nil and entry.kicker == me then return false end
    local dx, dz = m.pos.x - o.oPosX, m.pos.z - o.oPosZ
    local dy = m.pos.y - o.oPosY
    if dx * dx + dz * dz > 150 * 150 or dy < -200 or dy > 200 then return false end
    if (m.invincTimer or 0) > 0 then return false end

    bustHitBy[entry.key] = true
    m.hurtCounter = math.min(255, (m.hurtCounter or 0) + stop * 4)
    m.faceAngle.y = (o.oMoveAngleYaw or 0) + 0x8000

    set_mario_action(m, ACT_HARD_BACKWARD_AIR_KB, 0)
    return true
end
rules.bust_hits_me = bust_hits_me

function rules.bust_tick()
    if next(busted) == nil then return end

    if rules.step("doorbust") == 0 then
        rules.mend_all_doors()
        return
    end
    for key, entry in pairs(busted) do
        entry.left = entry.left - 1
        entry.fly = (entry.fly or 0) - 1
        local door = entry.door
        if entry.left <= 0 or door == nil or door.activeFlags == 0 then
            mend(entry)
            busted[key] = nil
            bustHitBy[key] = nil
        else
            local gfx = door.header ~= nil and door.header.gfx or nil
            if gfx ~= nil and gfx.node ~= nil then
                gfx.node.flags = OF.util.add_flag(gfx.node.flags or 0, BUST_INVISIBLE)
            end
            local info = gfx ~= nil and gfx.animInfo or nil
            local anim = info ~= nil and info.curAnim or nil
            if anim ~= nil and (anim.loopEnd or 0) > 2 then
                door.oAction = DOOR_OPEN_ACTION
                info.animFrame = open_frame(anim.loopEnd - 2)
            end
            bust_hits_me(entry)
        end
    end
end

hook_event(HOOK_UPDATE, rules.bust_tick)
hook_event(HOOK_ON_LEVEL_INIT, function()
    busted = {}
    rules.bustedDoors = busted
    bustHitBy = {}
end)

local function door_at(x, y, z)
    if obj_get_first_with_behavior_id == nil or id_bhvDoor == nil then return nil end
    local best, bestD = nil, BUST_MATCH * BUST_MATCH
    local door = obj_get_first_with_behavior_id(id_bhvDoor)
    while door ~= nil do
        local dx, dy, dz = door.oPosX - x, door.oPosY - y, door.oPosZ - z
        local d = dx * dx + dy * dy + dz * dz
        if d <= bestD then best, bestD = door, d end
        door = obj_get_next_with_same_behavior_id(door)
    end
    return best
end
rules.door_at = door_at

function rules.kick_door(m, door)
    local np = gNetworkPlayers[0]
    if np == nil or door == nil then return false end
    local me = network_global_index_from_local(0)
    local yaw = m ~= nil and m.faceAngle ~= nil and m.faceAngle.y or 0
    if not rules.bust_door(door, yaw, me) then return false end
    local wire = { ofp = BUST_PACKET, gi = me, l = np.currLevelNum,
        a = np.currAreaIndex, c = np.currActNum,
        x = door.oPosX, y = door.oPosY, z = door.oPosZ, w = yaw }
    if OF.util.is_host() then
        OF.util.tell_all(wire)
    else
        OF.util.send_to_host(wire)
    end
    return true
end

local function land_a_bust(data)
    if rules.step("doorbust") == 0 then return false end
    local np = gNetworkPlayers[0]
    if np == nil then return false end
    if data.gi == network_global_index_from_local(0) then return false end
    if data.l ~= np.currLevelNum or data.a ~= np.currAreaIndex
        or data.c ~= np.currActNum then
        return false
    end
    if type(data.x) ~= "number" or type(data.y) ~= "number"
        or type(data.z) ~= "number" then
        return false
    end
    local door = door_at(data.x, data.y, data.z)
    if door == nil then return false end
    return rules.bust_door(door, tonumber(data.w) or 0, data.gi)
end
rules.land_a_bust = land_a_bust

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil or data.ofp ~= BUST_PACKET then return end
    if OF.util.is_host() then
        if not OF.util.asks(OF.pass, "owner") then return end
        local globalIndex = OF.pass.owner(data.pk)
        if globalIndex == nil then return end
        data.gi = globalIndex
        land_a_bust(data)
        OF.util.tell_all({ ofp = BUST_PACKET, gi = globalIndex, l = data.l,
            a = data.a, c = data.c, x = data.x, y = data.y, z = data.z,
            w = data.w })
        return
    end
    if not OF.util.from_host_effect(data) then return end
    land_a_bust(data)
end)

hook_event(HOOK_ALLOW_INTERACT, function(m, obj, interactType)
    if m == nil or m.playerIndex ~= 0 then return end

    if crowd_refuses(obj, interactType) then return false end

    if rules.bust_wanted(m, obj, interactType) then
        rules.kick_door(m, obj)
        return false
    end

    if not rules.peaceful then return end
    for _, kind in ipairs(HURTS) do
        if interactType == kind then return false end
    end

    if HURTS_UNLESS_ATTACKING[interactType] ~= nil
        and not would_attack(m, obj, interactType) then
        return false
    end
end)

local GRACE_FPS = 30

rules.graceSeconds = 2

function rules.in_spawn_grace()
    local frames = rules.spawn_grace_frames()
    if frames <= 0 then return false end
    local since = OF.util.optional("get_network_area_timer", nil)
    if type(since) ~= "number" then return false end
    return since < frames
end

function rules.spawn_grace_frames()
    local seconds = rules.graceSeconds
    if type(seconds) ~= "number" or seconds <= 0 then return 0 end
    return math.floor(seconds * GRACE_FPS)
end

local HIT_ABOVE_BY = 50

local HIT_BEHIND_BY = 0x4000

local function hit_signed(angle)
    return ((math.floor(angle) + 0x8000) % 0x10000) - 0x8000
end

local function hit_airborne(m)
    if m == nil or type(m.action) ~= "number" then return false end
    return (m.action & ACT_FLAG_AIR) ~= 0
end

function rules.hit_counts(attacker, victim)
    local step = rules.value("hitwhere") or 0
    if step == 0 then return true end
    if attacker == nil or victim == nil then return true end
    if attacker.pos == nil or victim.pos == nil then return true end

    if step == 1 then
        return (attacker.pos.y - victim.pos.y) >= HIT_ABOVE_BY
    end

    if step == 2 then
        if victim.faceAngle == nil then return true end

        local toward = OF.util.optional("atan2s", nil,
            attacker.pos.z - victim.pos.z, attacker.pos.x - victim.pos.x)
        if type(toward) ~= "number" then return true end
        local off = hit_signed(toward - (victim.faceAngle.y or 0))
        return off < -HIT_BEHIND_BY or off > HIT_BEHIND_BY
    end

    if step == 3 then
        return hit_airborne(attacker) and hit_airborne(victim)
    end

    return true
end

function rules.may_attack(attacker, victim)
    if attacker == nil or victim == nil then return true end

    if OF.util.asks(OF.gamemodes, "state")
        and OF.gamemodes.state() == OF.gamemodes.COUNTDOWN then
        return false
    end

    if rules.in_spawn_grace() then return false end

    if OF.util.asks(OF.jail, "is_jailed") then
        if OF.jail.is_jailed(victim.playerIndex) then return false end
        if OF.jail.is_jailed(attacker.playerIndex) then return false end
    end

    if not rules.hit_counts(attacker, victim) then return false end

    if OF.util.asks(OF.gamemodes, "may_attack")
        and OF.gamemodes.may_attack(attacker, victim) == false then
        return false
    end

    return true
end

hook_event(HOOK_ALLOW_PVP_ATTACK, function(attacker, victim, interaction)

    if rules.may_attack(attacker, victim) then return end
    return false
end)

local THROW_CENTRE_DEADZONE = 10.0

function rules.throw_yaw(victim)

    if (rules.value("throwdir") or 0) ~= 1 then return nil end
    if victim == nil or victim.pos == nil then return nil end
    if victim.area == nil or victim.area.camera == nil then return nil end

    local centreX = victim.area.camera.areaCenX
    local centreZ = victim.area.camera.areaCenZ
    if type(centreX) ~= "number" or type(centreZ) ~= "number" then return nil end

    local dx = centreX - victim.pos.x
    local dz = centreZ - victim.pos.z
    if (dx * dx + dz * dz) < (THROW_CENTRE_DEADZONE * THROW_CENTRE_DEADZONE) then
        return nil
    end

    local yaw = OF.util.optional("atan2s", nil, dz, dx)
    if type(yaw) ~= "number" then return nil end
    return hit_signed(yaw)
end

function rules.turn_knockback(victim)
    local yaw = rules.throw_yaw(victim)
    if yaw == nil then return false end
    if victim.vel == nil or victim.faceAngle == nil then return false end

    local vx, vz = victim.vel.x, victim.vel.z
    if type(vx) ~= "number" or type(vz) ~= "number" then return false end

    local speed = math.sqrt(vx * vx + vz * vz)
    if speed <= 0 then return false end

    local was = OF.util.optional("atan2s", nil, vz, vx)
    local sinYaw = OF.util.optional("sins", nil, yaw)
    local cosYaw = OF.util.optional("coss", nil, yaw)
    if type(was) ~= "number" or type(sinYaw) ~= "number"
        or type(cosYaw) ~= "number" then
        return false
    end

    victim.vel.x = speed * sinYaw
    victim.vel.z = speed * cosYaw
    victim.slideVelX = victim.vel.x
    victim.slideVelZ = victim.vel.z
    victim.faceAngle.y = hit_signed(victim.faceAngle.y + hit_signed(yaw - was))
    return true
end

hook_event(HOOK_ON_PVP_ATTACK, function(attacker, victim, interaction)
    rules.turn_knockback(victim)
end)

local CONTINUE = -1

local MOVE_BANS = {
    [1] = { [ACT_LONG_JUMP] = ACT_JUMP },
    [2] = { [ACT_GROUND_POUND] = ACT_FREEFALL },
    [3] = { [ACT_DIVE] = ACT_JUMP },
    [4] = { [ACT_LONG_JUMP] = ACT_JUMP, [ACT_DIVE] = ACT_JUMP },
    [5] = { [ACT_BACKFLIP] = ACT_JUMP, [ACT_SIDE_FLIP] = ACT_JUMP },
    [6] = { [ACT_DOUBLE_JUMP] = ACT_JUMP, [ACT_TRIPLE_JUMP] = ACT_JUMP },
    [7] = { [ACT_BACKFLIP] = ACT_JUMP, [ACT_SIDE_FLIP] = ACT_JUMP,
            [ACT_DIVE] = ACT_JUMP },
    [8] = { [ACT_GROUND_POUND] = ACT_FREEFALL, [ACT_DIVE] = ACT_JUMP },

    [9] = { [ACT_LONG_JUMP] = ACT_JUMP, [ACT_BACKFLIP] = ACT_JUMP,
            [ACT_SIDE_FLIP] = ACT_JUMP, [ACT_DOUBLE_JUMP] = ACT_JUMP,
            [ACT_TRIPLE_JUMP] = ACT_JUMP, [ACT_DIVE] = ACT_JUMP,
            [ACT_GROUND_POUND] = ACT_FREEFALL },

    [10] = { [ACT_LONG_JUMP] = ACT_JUMP, [ACT_BACKFLIP] = ACT_JUMP,
             [ACT_SIDE_FLIP] = ACT_JUMP },
}

local ROLLED_BANS = { 1, 2, 3 }

rules.ROLLED_MOVE_STEP = 11

function rules.rolled_ban()
    local np = gNetworkPlayers[0]
    if np == nil then return ROLLED_BANS[1] end

    local level = np.currLevelNum
    if type(level) ~= "number" then return ROLLED_BANS[1] end
    return ROLLED_BANS[(level % #ROLLED_BANS) + 1]
end

function rules.moves_ban_step()
    local step = rules.movesGone or 0
    if step == rules.ROLLED_MOVE_STEP then return rules.rolled_ban() end
    return step
end

function rules.forbidden_move(m, action)
    if m == nil or m.playerIndex ~= 0 then return nil end
    local taken = MOVE_BANS[rules.moves_ban_step()]
    if taken == nil then return nil end
    return taken[action]
end

function rules.denied_move(m, action)
    local becomes = rules.forbidden_move(m, action)
    if becomes ~= nil then return becomes end
    if OF.util.asks(OF.modifiers, "substitute_move") then
        return OF.modifiers.substitute_move(m, action)
    end
    return nil
end

hook_event(HOOK_BEFORE_SET_MARIO_ACTION, function(m, action)
    return rules.forbidden_move(m, action)
end)

local function hold_the_ban(m)
    if m == nil or m.playerIndex ~= 0 then return CONTINUE end
    local becomes = rules.denied_move(m, m.action)
    if becomes == nil then return CONTINUE end
    set_mario_action(m, becomes, 0)
    return 1
end

local HELD_MOVES = {
    ACT_LONG_JUMP, ACT_BACKFLIP, ACT_SIDE_FLIP,
    ACT_DOUBLE_JUMP, ACT_TRIPLE_JUMP, ACT_DIVE, ACT_GROUND_POUND,
}

for _, action in ipairs(HELD_MOVES) do
    hook_mario_action(action, { every_frame = hold_the_ban })
end

function rules.held_moves()
    local list = {}
    for index, action in ipairs(HELD_MOVES) do list[index] = action end
    return list
end

for _, wireKey in ipairs(WIRE_KEYS) do
    hook_on_sync_table_change(gGlobalSyncTable, wireKey, wireKey, function(tag, prevValue)

        wireStamp = wireStamp + 1

        if OF.util.asks(OF.guard, "repair") and OF.guard.repair(wireKey) then
            return
        end

        if not rules.defer_apply() then rules.apply() end

        local credited = OF.util.asks(OF.notify, "credits_on")
            and OF.notify.credits_on()
        local putBack = OF.util.asks(OF.guard, "putting_back")
            and OF.guard.putting_back()
        if OF.util.asks(OF.notify, "show") and not credited and not putBack then
            local line = rules.changed_line(rules.wire_text(wireKey, prevValue),
                rules.wire_text())
            if line ~= nil then OF.notify.show("@", "quiet", 3, line) end
        end
    end)
end

hook_on_sync_table_change(gGlobalSyncTable, rules.ROUND_KEY, rules.ROUND_KEY,
    function()
        if OF.util.asks(OF.guard, "repair")
            and OF.guard.repair(rules.ROUND_KEY) then
            return
        end
        rules.apply()
    end)

rules.roundWas = nil

function rules.watch_the_round()
    local now = rules.round_holds() == true
    if now == rules.roundWas then return false end
    rules.roundWas = now
    rules.apply()
    return true
end

hook_event(HOOK_UPDATE, function() rules.watch_the_round() end)

hook_event(HOOK_ON_SYNC_VALID, function()
    rules.apply()
end)

hook_event(HOOK_ON_MODS_LOADED, function()
    if not OF.util.is_host() then return end
    if rules.wire_text() ~= "" then return end
    local set = {}
    for _, entry in ipairs(rules.LIST) do set[entry.key] = entry.get() end
    publish(set)
end)

hook_event(HOOK_ALLOW_INTERACT, function(m, _, interactType)
    if rules.step("hoot") <= 0 then return end
    if m == nil or m.playerIndex ~= 0 then return end
    if interactType == INTERACT_HOOT then return false end
end)

function rules.hoot_note()
    if rules.step("hoot") <= 0 then return nil end
    return OF.lang.t("Whomp's Fortress only, and the tower is still a climb.")
end

function rules.intro_note()
    if OF.util.flag(gServerSettings.skipIntro) == 1 then return nil end
    return OF.lang.t("Only somebody on a brand new save file ever sees it.")
end

function rules.coin_cap_note()
    local cap = rules.value("coincap")
    if type(cap) ~= "number" or cap == 0 then return nil end
    local held = rules.step_setting("coincap", "cap", COINS_CEILING)
    local needed = rules.value("coinstar")
    if type(needed) ~= "number" or needed <= 0 or held >= needed then return nil end
    return OF.lang.fill("The coin star wants @ and nobody can hold that many.",
        tostring(needed))
end

local COURSE_CAMERAS = {
    { CAMERA_MODE_BEHIND_MARIO, CAMERA_MODE_WATER_SURFACE },
    { CAMERA_MODE_PARALLEL_TRACKING, CAMERA_MODE_FIXED,
      CAMERA_MODE_SPIRAL_STAIRS, CAMERA_MODE_8_DIRECTIONS },
    { CAMERA_MODE_SLIDE_HOOT, CAMERA_MODE_BOSS_FIGHT, CAMERA_MODE_CLOSE },
}

function rules.refuses_camera(mode)
    local step = rules.step("coursecam")
    if step <= 0 or mode == nil then return false end
    for rung = 1, math.min(step, #COURSE_CAMERAS) do
        for _, taken in ipairs(COURSE_CAMERAS[rung]) do
            if taken ~= nil and mode == taken then return true end
        end
    end
    return false
end

hook_event(HOOK_ON_SET_CAMERA_MODE, function(_, mode)
    if rules.refuses_camera(mode) then return false end
end)

hook_event(HOOK_ON_CHANGE_CAMERA_ANGLE, function()
    if rules.step("angles") > 0 then return false end
end)

function rules.mario_cam_note()
    if rules.step("angles") <= 0 then return nil end
    return OF.lang.t("Anybody on the free camera has no Mario cam to be held off.")
end

function rules.refuses_wipe(kind)
    local step = rules.step("wipes")
    if step <= 0 or type(kind) ~= "number" then return false end
    if step >= 2 then return true end
    return kind % 2 == 1
end

hook_event(HOOK_ON_SCREEN_TRANSITION, function(kind)
    if rules.refuses_wipe(kind) then return false end
end)

local function is_a_star_box(dialogId)
    local values = gBehaviorValues
    local list = values ~= nil and values.dialogs or nil
    if list == nil then return false end
    return dialogId == list.CollectedStarDialog
        or dialogId == list.HundredCoinsDialog
end

local function knows_the_star_box()
    local values = gBehaviorValues
    local list = values ~= nil and values.dialogs or nil
    return list ~= nil and list.CollectedStarDialog ~= nil
end

function rules.refuses_sign(dialogId)
    if rules.step("signs") <= 0 then return false end
    if not knows_the_star_box() then return false end
    return not is_a_star_box(dialogId)
end

hook_event(HOOK_ON_DIALOG, function(dialogId)
    if rules.refuses_sign(dialogId) then return false end
end)

function rules.dialog_speaker()
    if rules.step("textvoice") <= 0 then return nil end
    return rules.step_setting("textvoice", "speaker", nil)
end

hook_event(HOOK_DIALOG_SOUND, function()
    return rules.dialog_speaker()
end)

hook_event(HOOK_ALLOW_INTERACT, function(m, _, interactType)
    if rules.step("poles") <= 0 then return end
    if m == nil or m.playerIndex ~= 0 then return end
    if interactType == INTERACT_POLE then return false end
end)

function rules.surface_note(key)
    if (rules.value(key) or 0) == 0 then return nil end
    return OF.lang.t("Moving platforms change now; the ground itself changes "
        .. "when the next course loads.")
end

function rules.conveyor_note()
    if (rules.value("conveyor") or 0) == 0 then return nil end
    if not OF.util.asks(OF.ground, "blow_spared") then return nil end
    local spared = OF.ground.blow_spared()
    if type(spared) ~= "number" or spared <= 0 then return nil end
    return OF.lang.t(
        "The lava, the pits and the warps keep their own job and do not push.")
end

do

local function line_height(share)
    if type(share) ~= "number" then return nil end
    if not (OF.util.asks(OF.ground, "lowest")
        and OF.util.asks(OF.ground, "highest")) then return nil end
    local low, high = OF.ground.lowest(), OF.ground.highest()
    if type(low) ~= "number" or type(high) ~= "number" then return nil end
    if high <= low then return nil end
    return low + (high - low) * share
end

local armedKind, armedHeight = nil, nil

local function let_go()
    if armedKind == nil then return end
    armedKind, armedHeight = nil, nil
    if OF.util.asks(OF.ground, "clear_line") then OF.ground.clear_line() end
end

local function hold_the_line()

    local step = rules.step("oneway")
    if step <= 0 then return let_go() end

    local kind = rules.step_setting("oneway", "kind", nil)
    local height = line_height(rules.step_setting("oneway", "share", nil))
    if type(kind) ~= "number" or height == nil then return let_go() end

    if OF.util.asks(OF.ground, "line_kind_count") then
        local kinds = OF.ground.line_kind_count()
        if type(kinds) ~= "number" or kind < 1 or kind > kinds then
            return let_go()
        end
    end

    if kind == armedKind and height == armedHeight then return end
    if not OF.util.asks(OF.ground, "set_line") then return end
    armedKind, armedHeight = kind, height
    OF.ground.set_line(kind, height)
end

hook_event(HOOK_UPDATE, hold_the_line)

end

function rules.oneway_note()
    if rules.step("oneway") <= 0 then return nil end
    if not OF.util.asks(OF.ground, "line") then return nil end

    local kind = OF.ground.line()
    if type(kind) ~= "number" then return nil end

    if (OF.ground.line_spared() or 0) > 0 then
        return OF.lang.t(
            "The course's own lava and pits keep the job the course gave them.")
    end

    local words = OF.ground.line_kind_name(kind)
    if type(words) ~= "string" then return nil end
    if OF.ground.line_holding() == nil and (OF.ground.line_took() or 0) <= 0 then
        return OF.lang.fill("Nobody has come down onto it yet; under it: @.",
            words)
    end
    return OF.lang.fill("Coming down onto the line, the ground is @.", words)
end

function rules.pause_cam_note()
    if OF.util.flag(gLevelValues.zoomOutCameraOnPause) == 0 then return nil end
    local here = #OF.util.connected_players()
    if here <= 1 then return nil end
    return OF.lang.fill("@ of you are here, and this one only applies alone.", here)
end

function rules.boxes_note()
    if rules.step("boxes") <= 0 then return nil end
    return OF.lang.t("A box a course put a star in still holds the star.")
end

function rules.whomp_note()
    if rules.step("whomp") <= 0 then return nil end
    return OF.lang.t("Lands the next time the fortress is entered.")
end

function rules.rows_for(panel, which, bare)
    local rows = {}

    for _, placed in ipairs(rules.in_section_order(which)) do
        local entry = placed.entry
        local key = entry.key
        local steps = rules.step_count(entry)

        local step = rules.step_of(entry, rules.lobby_value(key))

        if placed.header ~= nil and not bare then

            table.insert(rows, panel.with_help(
                panel.header_row(OF.lang.t(placed.header)),
                rules.SECTION_HELP[placed.header]))
        end

        local shownName = rules.option_name(entry, rules.shown_value(key))
        local text, ticked, level, picked
        if rules.is_switch(entry) then

            ticked = (shownName == "on")
            text = panel.tick(ticked, entry.name)
        elseif steps == 2 then

            picked = (rules.shown_value(key) ~= rules.baseline(entry))
            text = entry.name
            level = shownName
        else

            text = entry.name .. ": " .. shownName
        end

        local draw = rules.hosts_own(entry) and panel.host_row
            or panel.gated_row
        local built = draw("rules", text,
            255, 255, 255, function() OF.util.report(rules.set_from_panel(key)) end)

        if level ~= nil and steps <= 2 then
            built = panel.picker_row(built, OF.lang.t(level), picked)
        end

        if steps > 2 then

            built = panel.with_slider(built, step - 1, steps - 1, function(wanted)
                OF.util.report(rules.set_step(key, wanted + 1))
            end)
        end

        if rules.suspended(key) then
            built = panel.with_help(built,
                OF.lang.t(
                    "put away until the round ends - your setting is kept"))
        elseif entry.blurb ~= nil then
            built = panel.with_help(built, OF.lang.t(entry.blurb))
        end
        table.insert(rows, built)

        local note = rules.note_of(entry)
        if note ~= nil then
            table.insert(rows, panel.label_row("   " .. note))
        end
    end

    return rows
end

function rules.look_rows(panel)
    return rules.rows_for(panel, "look", true)
end

function rules.build_page(panel)
    local rows = {}

    table.insert(rows, panel.label_row("These reach everybody at once."))

    for _, built in ipairs(rules.rows_for(panel, "page")) do
        table.insert(rows, built)
    end

    for _, r in ipairs(OF.util.asks(OF.modifiers, "build_rows")
            and OF.modifiers.build_rows(panel, "rules") or {}) do
        table.insert(rows, r)
    end

    table.insert(rows, panel.back_row("control"))
    return rows
end
