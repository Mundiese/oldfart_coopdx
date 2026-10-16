OF = OF or {}
OF.split = OF.split or {}

local split = OF.split

split.KEY = "ofSplitGot"
local HUD_HOLD = "split"
local STAR_BITS = 7

local function file_index()
    local num = get_current_save_file_num()
    if num == nil or num < 1 then return 0 end
    return num - 1
end

local on = false

function split.on()
    return on == true
end

function split.got(localIndex)
    local row = gPlayerSyncTable[localIndex or 0]
    local value = row ~= nil and row[split.KEY] or nil
    if type(value) ~= "number" or value < 0 then return 0 end
    return math.floor(value)
end

function split.seed()
    return save_file_get_total_star_count(file_index(),
        COURSE_MIN - 1, COURSE_MAX - 1)
end

function split.mine(localIndex)
    return split.seed() + split.got(localIndex)
end

local counted = {}

function split.forget_counted()
    counted = {}
end

local function star_name_of(obj)

    if OF.util.optional("obj_has_behavior_id", 0, obj, id_bhvBowserKey) ~= 0 then
        return nil
    end
    local index = OF.util.star_act_index(obj)
    if index == nil then return nil end
    local here = gNetworkPlayers[0]
    local levelNum = here ~= nil and here.currLevelNum or 0
    return tostring(levelNum) .. ":" .. tostring(index)
end

local function took_a_star(m, obj)
    if not split.on() then return end
    if m == nil or m.playerIndex ~= 0 then return end
    split.count_star(star_name_of(obj))
end

function split.count_star(name)
    if not split.on() then return false end
    if name == nil then return false end
    if counted[name] then return false end
    counted[name] = true
    OF.util.publish_row(0, "ofSplitGot", split.got(0) + 1)

    if OF.util.asks(OF.rules, "aim_star_gates") then OF.rules.aim_star_gates() end
    return true
end

function split.bonus_got()
    local n = 0
    for name in pairs(counted) do
        if string.sub(name, 1, 6) == "bonus:" then n = n + 1 end
    end
    return n
end

hook_event(HOOK_ON_INTERACT, function(m, obj, interactType)
    if interactType ~= INTERACT_STAR_OR_KEY then return end
    took_a_star(m, obj)
end)

local frozen = nil

local function reading()
    local index = file_index()
    local shot = {
        file = index,
        castle = save_file_get_star_flags(index, -1),
        total = save_file_get_total_star_count(index,
            COURSE_MIN - 1, COURSE_MAX - 1),
        courses = {},
    }
    for courseNum = COURSE_MIN, COURSE_MAX do
        local courseIndex = courseNum - 1
        shot.courses[courseIndex] = save_file_get_star_flags(index, courseIndex)
    end
    return shot
end

local function gained_bits(now, was)
    local gained, mask = 0, 1
    for _ = 1, STAR_BITS do
        if now % (mask * 2) >= mask and was % (mask * 2) < mask then
            gained = gained + mask
        end
        mask = mask * 2
    end
    return gained
end

local function hold_the_file()
    if frozen == nil then return end
    local index = frozen.file

    if save_file_get_total_star_count(index, COURSE_MIN - 1, COURSE_MAX - 1)
        == frozen.total then
        return
    end

    local put = false
    for courseNum = COURSE_MIN, COURSE_MAX do
        local courseIndex = courseNum - 1
        local gained = gained_bits(save_file_get_star_flags(index, courseIndex),
            frozen.courses[courseIndex] or 0)
        if gained > 0 then
            save_file_remove_star_flags(index, courseIndex, gained)
            put = true
        end
    end

    local castle = gained_bits(save_file_get_star_flags(index, -1),
        frozen.castle or 0)
    if castle > 0 then
        save_file_remove_star_flags(index, -1, castle)
        put = true
    end

    if put then save_file_do_save(index, 1) end
end

hook_event(HOOK_UPDATE, function()
    if not OF.util.is_host() then return end
    hold_the_file()
end)

function split.set_on(wanted)
    wanted = wanted == true
    if wanted == on then return end
    on = wanted
    split.forget_counted()
    OF.util.publish_row(0, "ofSplitGot", 0)
    if on then
        frozen = OF.util.is_host() and reading() or nil
    else
        frozen = nil
    end

    if OF.util.asks(OF.rules, "aim_star_gates") then OF.rules.aim_star_gates() end
end

local TALLY_SCALE = 0.75

split.tallyWidth = 0

function split.tally_width()
    return split.tallyWidth or 0
end

local function race_has_the_corner()
    if not OF.util.asks(OF.speedrun, "tally_width") then return false end
    return OF.speedrun.tally_width() > 0
end

local function render()
    local want = split.on() and not race_has_the_corner()

    OF.util.hud_hide(HUD_DISPLAY_FLAG_STAR_COUNT, HUD_HOLD, want)
    if not want then
        split.tallyWidth = 0
        return
    end
    if OF.util.menu_has_screen() then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    local gold = OF.util.gold()

    local glyph = nil
    if OF.util.asks(OF.speedrun, "star_glyph") then
        glyph = OF.speedrun.star_glyph()
    end
    split.tallyWidth = OF.util.corner_counter(glyph,
        tostring(split.mine(0)), gold.r, gold.g, gold.b, 0, TALLY_SCALE)
end

hook_event(HOOK_ON_HUD_RENDER, render)
