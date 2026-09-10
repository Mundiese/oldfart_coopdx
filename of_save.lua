OF = OF or {}
OF.save = OF.save or {}

local save = OF.save

save.PACKET = "save"
local function file_index()
    local num = get_current_save_file_num()
    if num == nil or num < 1 then return 0 end
    return num - 1
end

save.FLAGS = {
    { key = "wingcap",  name = "Wing Cap switch",    flag = SAVE_FLAG_HAVE_WING_CAP,
      blurb = "the red switch has been pressed, so wing cap boxes work" },
    { key = "metalcap", name = "Metal Cap switch",   flag = SAVE_FLAG_HAVE_METAL_CAP,
      blurb = "the green switch has been pressed, so metal cap boxes work" },
    { key = "vanishcap", name = "Vanish Cap switch", flag = SAVE_FLAG_HAVE_VANISH_CAP,
      blurb = "the blue switch has been pressed, so vanish cap boxes work" },
    { key = "key1",     name = "Basement key",       flag = SAVE_FLAG_HAVE_KEY_1,
      blurb = "the key Bowser drops in the Dark World" },
    { key = "key2",     name = "Upstairs key",       flag = SAVE_FLAG_HAVE_KEY_2,
      blurb = "the key Bowser drops in the Fire Sea" },
    { key = "basement", name = "Basement door",      flag = SAVE_FLAG_UNLOCKED_BASEMENT_DOOR,
      blurb = "the door down to the basement stands unlocked" },
    { key = "upstairs", name = "Upstairs door",      flag = SAVE_FLAG_UNLOCKED_UPSTAIRS_DOOR,
      blurb = "the door up to the second floor stands unlocked" },
    { key = "door50",   name = "50 star door",       flag = SAVE_FLAG_UNLOCKED_50_STAR_DOOR,
      blurb = "the door on the third floor stands unlocked" },
    { key = "pss",      name = "Secret Slide door",  flag = SAVE_FLAG_UNLOCKED_PSS_DOOR,
      blurb = "the way into Princess's Secret Slide stands open" },
    { key = "wf",       name = "Whomp's door",       flag = SAVE_FLAG_UNLOCKED_WF_DOOR,
      blurb = "the star door in front of Whomp's Fortress stands open" },
    { key = "ccm",      name = "Cool Cool door",     flag = SAVE_FLAG_UNLOCKED_CCM_DOOR,
      blurb = "the star door in front of Cool, Cool Mountain stands open" },
    { key = "jrb",      name = "Jolly Roger door",   flag = SAVE_FLAG_UNLOCKED_JRB_DOOR,
      blurb = "the star door in front of Jolly Roger Bay stands open" },
    { key = "bitdw",    name = "Dark World door",    flag = SAVE_FLAG_UNLOCKED_BITDW_DOOR,
      blurb = "the star door to Bowser in the Dark World stands open" },
    { key = "bitfs",    name = "Fire Sea door",      flag = SAVE_FLAG_UNLOCKED_BITFS_DOOR,
      blurb = "the star door to Bowser in the Fire Sea stands open" },
    { key = "moat",     name = "Moat drained",       flag = SAVE_FLAG_MOAT_DRAINED,
      blurb = "the water is out of the castle moat - reload the area to see it" },
    { key = "ddd",      name = "DDD moved back",     flag = SAVE_FLAG_DDD_MOVED_BACK,
      blurb = "the sub is gone from Dire, Dire Docks - reload the area to see it" },
}

save.CAP_FLAGS = { SAVE_FLAG_HAVE_WING_CAP, SAVE_FLAG_HAVE_METAL_CAP, SAVE_FLAG_HAVE_VANISH_CAP }

save.GEOMETRY_FLAGS = {
    SAVE_FLAG_MOAT_DRAINED, SAVE_FLAG_DDD_MOVED_BACK,
}

save.DOOR_FLAGS = {
    SAVE_FLAG_UNLOCKED_BASEMENT_DOOR, SAVE_FLAG_UNLOCKED_UPSTAIRS_DOOR,
    SAVE_FLAG_UNLOCKED_50_STAR_DOOR, SAVE_FLAG_UNLOCKED_PSS_DOOR,
    SAVE_FLAG_UNLOCKED_WF_DOOR, SAVE_FLAG_UNLOCKED_CCM_DOOR,
    SAVE_FLAG_UNLOCKED_JRB_DOOR, SAVE_FLAG_UNLOCKED_BITDW_DOOR,
    SAVE_FLAG_UNLOCKED_BITFS_DOOR,
}

function save.find_flag(key)
    for _, entry in ipairs(save.FLAGS) do
        if entry.key == key then return entry end
    end
    return nil
end

function save.has_flag(flag)
    return OF.util.has_flag(save_file_get_flags(), flag)
end

local writing = 0
local owed = false

local function commit()
    if writing > 0 then
        owed = true
        return false
    end

    set_save_file_modified(true)
    save_file_do_save(file_index(), 1)
    return true
end

local function write_begin()
    writing = writing + 1
end

local function write_end()
    if writing > 0 then writing = writing - 1 end
    if writing > 0 then return false end
    if not owed then return false end
    owed = false
    return commit()
end

function save.write_depth()
    return writing
end

local cause = nil

local function file_change(what, was, now)
    if not OF.util.asks(OF.ledger, "record") then return false end
    OF.ledger.record(what, was, now, cause)
    return true
end

local function flag_name(flag)
    for _, entry in ipairs(save.FLAGS) do
        if entry.flag == flag then return entry.name end
    end
    return nil
end

local function count_on(list)
    local on = 0
    for _, flag in ipairs(list) do
        if save.has_flag(flag) then on = on + 1 end
    end
    return on
end

function save.reload_level()
    local np = gNetworkPlayers[0]
    if np == nil then return false end
    local area = np.currAreaIndex
    local fromTheStart = false
    if area ~= 1 and OF.util.asks(OF.net, "entrance_into_here")
        and not OF.net.entrance_into_here(np.currLevelNum, area) then
        area = 1
        fromTheStart = true
    end

    if not OF.net.warp_local(np.currLevelNum, area, np.currActNum, nil,
        "This map has no entrance, so it cannot be loaded again.") then
        return false
    end
    if fromTheStart and OF.util.asks(OF.notify, "show") then
        OF.notify.show("No entrance here, so the map reloads from its start.",
            "info", 6)
    end
    return true
end

function save.can_edit()
    if not OF.util.is_host() then
        return false, "The lobby plays on the host's save file - only the host can change it."
    end
    return true
end

save.before = nil

local sweeping = 0

function save.reading()
    local index = file_index()
    local shot = { file = index, stars = save.star_count(),
                   castle = save_file_get_star_flags(index, -1),
                   courses = {}, cannons = {}, flags = {} }

    for courseNum = COURSE_MIN, COURSE_MAX do
        local courseIndex = courseNum - 1
        shot.courses[courseIndex] = save_file_get_star_flags(index, courseIndex)

        shot.cannons[courseIndex] = OF.util.optional(
            "save_file_is_cannon_unlocked", 0, index, courseIndex) ~= 0
    end
    for _, entry in ipairs(save.FLAGS) do
        shot.flags[entry.key] = save.has_flag(entry.flag)
    end
    return shot
end

function save.snapshot()
    local shot = save.reading()
    save.before = shot
    return shot
end

local function sweep_begin()
    sweeping = sweeping + 1
    if sweeping == 1 then save.snapshot() end
end

local function sweep_end()
    if sweeping > 0 then sweeping = sweeping - 1 end
end

function save.undo_stars()
    if save.before == nil then return nil end
    return save.before.stars
end

function save.can_undo()
    if save.before == nil then
        return false, "There is nothing to put back."
    end
    local allowed, why = save.can_edit()
    if not allowed then return false, why end

    if save.before.file ~= file_index() then
        return false, "That was a different save file - this one never changed."
    end
    return true
end

function save.set_flag(flag, value)
    local allowed, why = save.can_edit()
    if not allowed then return false, why end
    if value then
        save_file_set_flags(flag)
    else
        save_file_clear_flags(flag)
    end
    commit()

    save.note_door_box(flag, value)

    local name = flag_name(flag)
    if name ~= nil then
        if value then
            file_change(OF.lang.fill("Set @ on", name),
                OF.lang.t("off"), OF.lang.t("on"))
        else
            file_change(OF.lang.fill("Set @ off", name),
                OF.lang.t("on"), OF.lang.t("off"))
        end
    end

    for _, geometry in ipairs(save.GEOMETRY_FLAGS) do
        if flag == geometry then
            OF.notify.show("Reload the area to see that change", "info", 5)
            return true
        end
    end
    return true
end

function save.toggle_flag(flag)
    return save.set_flag(flag, not save.has_flag(flag))
end

local function door_stars(o)
    if o == nil then return nil, nil end
    local params = tonumber(o.oBehParams)
    if params == nil then return nil, nil end
    if params < 0 then params = params + 0x100000000 end
    return math.floor(params / 0x1000000) % 0x100, params
end

local function door_flag(o, need)
    if need == 1 then
        if (tonumber(o.oPosY) or 0) > 500.0 then
            return SAVE_FLAG_UNLOCKED_PSS_DOOR
        end
        return SAVE_FLAG_UNLOCKED_WF_DOOR
    elseif need == 3 then
        if (tonumber(o.oPosX) or 0) < 0.0 then
            return SAVE_FLAG_UNLOCKED_CCM_DOOR
        end
        return SAVE_FLAG_UNLOCKED_JRB_DOOR
    elseif need == 8 then
        return SAVE_FLAG_UNLOCKED_BITDW_DOOR
    elseif need == 30 then
        return SAVE_FLAG_UNLOCKED_BITFS_DOOR
    elseif need == 50 then
        return SAVE_FLAG_UNLOCKED_50_STAR_DOOR
    end
    return nil
end

local held = nil

local function hand_the_door_back()
    local one = held
    held = nil
    if one == nil or one.obj == nil then return false end
    if one.obj.oBehParams == nil then return false end
    one.obj.oBehParams = one.params
    return true
end

function save.door_flag_of(o)
    local need = door_stars(o)
    if need == nil or need <= 0 then return nil end
    return door_flag(o, need)
end

local ceremony_owed = {}

local STAR_DOOR_FLAGS = {}
do
    local list = {
        SAVE_FLAG_UNLOCKED_PSS_DOOR, SAVE_FLAG_UNLOCKED_WF_DOOR,
        SAVE_FLAG_UNLOCKED_CCM_DOOR, SAVE_FLAG_UNLOCKED_JRB_DOOR,
        SAVE_FLAG_UNLOCKED_BITDW_DOOR, SAVE_FLAG_UNLOCKED_BITFS_DOOR,
        SAVE_FLAG_UNLOCKED_50_STAR_DOOR,
    }
    for i = 1, 7 do
        if list[i] ~= nil then STAR_DOOR_FLAGS[list[i]] = true end
    end
end

local DOOR_ACTIONS = {}
do
    local list = { ACT_ENTERING_STAR_DOOR, ACT_PUSHING_DOOR, ACT_PULLING_DOOR }
    for i = 1, 3 do
        if list[i] ~= nil then DOOR_ACTIONS[list[i]] = true end
    end
end

function save.note_door_box(flag, value)
    if flag == nil or not STAR_DOOR_FLAGS[flag] then return false end

    if value then
        ceremony_owed[flag] = true
        return true
    end
    ceremony_owed[flag] = nil
    return false
end

function save.owes_ceremony(flag)
    if flag == nil then return false end
    return ceremony_owed[flag] == true
end

hook_event(HOOK_ALLOW_INTERACT, function(m, obj, interactType)

    hand_the_door_back()
    if interactType ~= INTERACT_DOOR then return end
    if m == nil or m.playerIndex ~= 0 then return end
    if obj == nil then return end
    local need, params = door_stars(obj)
    if need == nil or need <= 0 then return end
    local flag = door_flag(obj, need)
    if flag == nil or not save.has_flag(flag) then return end
    held = { obj = obj, params = params, flag = flag }
    obj.oBehParams = params - need * 0x1000000
end)

hook_event(HOOK_ON_INTERACT, function(m, obj, interactType, interacted)
    local one = held

    hand_the_door_back()
    if one == nil or one.flag == nil then return end
    if interacted ~= true then return end
    if m == nil or m.playerIndex ~= 0 then return end
    if ceremony_owed[one.flag] == nil then return end
    if not DOOR_ACTIONS[m.action] then return end
    ceremony_owed[one.flag] = nil
    set_mario_action(m, ACT_UNLOCKING_STAR_DOOR, m.actionArg or 0)
end)

function save.set_flags(list, value)
    local allowed, why = save.can_edit()
    if not allowed then return false, why end
    sweep_begin()
    write_begin()
    for _, flag in ipairs(list) do
        if value then save_file_set_flags(flag) else save_file_clear_flags(flag) end

        if not value then save.note_door_box(flag, false) end
    end
    commit()
    write_end()
    sweep_end()
    return true
end

local STAR_MASKS = {
    [COURSE_BITDW] = 0x01, [COURSE_BITFS] = 0x01, [COURSE_BITS] = 0x01,
    [COURSE_PSS]   = 0x03,
    [COURSE_COTMC] = 0x01, [COURSE_TOTWC] = 0x01, [COURSE_VCUTM] = 0x01,
    [COURSE_WMOTR] = 0x01, [COURSE_SA]    = 0x01,
    [COURSE_CAKE_END] = 0x00,
}

local CASTLE_SECRET_MASK = 0x1F
local FULL_COURSE_MASK = 0x7F

local function mask_for_course(courseNum)
    local mask = STAR_MASKS[courseNum]
    if mask ~= nil then return mask end
    return FULL_COURSE_MASK
end

function save.refresh_star_count()
    local total = save_file_get_total_star_count(file_index(), COURSE_MIN - 1, COURSE_MAX - 1)
    for i = 0, MAX_PLAYERS - 1 do
        if gMarioStates[i] ~= nil then gMarioStates[i].numStars = total end
    end
    if gHudDisplay ~= nil then gHudDisplay.stars = total end
    return total
end

function save.set_all_stars(value)
    local allowed, why = save.can_edit()
    if not allowed then return false, why end

    sweep_begin()

    write_begin()
    local index = file_index()

    local had = save.star_count()

    for courseNum = COURSE_MIN, COURSE_MAX do
        local courseIndex = courseNum - 1
        if value then
            local mask = mask_for_course(courseNum)
            if mask > 0 then save_file_set_star_flags(index, courseIndex, mask) end
        else
            save_file_remove_star_flags(index, courseIndex, FULL_COURSE_MASK)
        end
    end

    if value then
        save_file_set_star_flags(index, -1, CASTLE_SECRET_MASK)
    else
        save_file_remove_star_flags(index, -1, FULL_COURSE_MASK)
    end

    if not value then

        save.set_flags(save.DOOR_FLAGS, false)
        save.set_flags(save.CAP_FLAGS, false)
        save_file_clear_flags(SAVE_FLAG_HAVE_KEY_1)
        save_file_clear_flags(SAVE_FLAG_HAVE_KEY_2)
    else
        save.set_flags(save.DOOR_FLAGS, true)
        save.set_flags(save.CAP_FLAGS, true)
        save_file_set_flags(SAVE_FLAG_HAVE_KEY_1)
        save_file_set_flags(SAVE_FLAG_HAVE_KEY_2)
    end

    commit()
    save.refresh_star_count()
    write_end()
    sweep_end()

    if value then
        file_change(OF.lang.t("Gave every star, both keys, all caps and every door"),
            OF.lang.fill("@ stars", had), OF.lang.fill("@ stars", save.star_count()))
    else
        file_change(OF.lang.t("Wiped the save - stars, keys, caps and doors"),
            OF.lang.fill("@ stars", had), OF.lang.fill("@ stars", save.star_count()))
    end
    return true
end

function save.star_bit(courseNum, starIndex)
    if type(starIndex) ~= "number" or starIndex < 0 or starIndex > 6 then
        return nil
    end
    local bit = 2 ^ starIndex
    local mask = courseNum == -1 and CASTLE_SECRET_MASK or mask_for_course(courseNum)
    if not OF.util.has_flag(mask, bit) then return nil end
    return bit
end

function save.star_on(courseNum, starIndex)
    local bit = save.star_bit(courseNum, starIndex)
    if bit == nil then return false end
    local courseIndex = courseNum == -1 and -1 or (courseNum - 1)
    local flags = save_file_get_star_flags(file_index(), courseIndex) or 0
    return OF.util.has_flag(flags, bit)
end

function save.set_star(courseNum, starIndex, value)
    local allowed, why = save.can_edit()
    if not allowed then return false, why end

    local bit = save.star_bit(courseNum, starIndex)
    if bit == nil then
        return false, OF.lang.t("That course has no such star.")
    end

    local courseIndex = courseNum == -1 and -1 or (courseNum - 1)
    local had = save.star_count()

    write_begin()
    if value then
        save_file_set_star_flags(file_index(), courseIndex, bit)
    else
        save_file_remove_star_flags(file_index(), courseIndex, bit)
    end
    commit()
    save.refresh_star_count()
    write_end()

    local where = courseNum == -1 and OF.lang.t("the castle")
        or OF.util.course_name(courseNum)
    file_change(OF.lang.fill(value and "Gave star @ of @" or "Took back star @ of @",
        starIndex + 1, where),
        OF.lang.fill("@ stars", had), OF.lang.fill("@ stars", save.star_count()))
    return true
end

function save.toggle_star(courseNum, starIndex)
    return save.set_star(courseNum, starIndex, not save.star_on(courseNum, starIndex))
end

function save.course_stars(courseNum, total)
    local on = 0
    for i = 0, 6 do
        if save.star_bit(courseNum, i) ~= nil and save.star_on(courseNum, i) then
            on = on + 1
        end
    end
    return on, total
end

function save.star_count()
    return save_file_get_total_star_count(file_index(), COURSE_MIN - 1, COURSE_MAX - 1)
end

local CANNON_BIT = 0x80

save.MIRROR = "savedown"
local mirroring = nil

local function mirror_begin()
    mirroring = {}
end

local function clear_flag(flag)
    save_file_clear_flags(flag)
    if mirroring ~= nil then mirroring[flag] = true end
end

local function mirror_end()
    local set = mirroring
    mirroring = nil
    if set == nil then return false end
    local word = 0
    for flag in pairs(set) do word = word + flag end
    if word == 0 then return false end

    if not OF.util.is_host() then return false end
    return OF.util.tell_all({ ofp = save.MIRROR, off = word })
end

local function on_mirror(data)
    if data == nil then return end
    if data.ofp ~= save.MIRROR then return end
    if not OF.util.from_host(data) then return end
    local word = tonumber(data.off)
    if word == nil or word <= 0 then return end
    for _, entry in ipairs(save.FLAGS) do
        if OF.util.has_flag(word, entry.flag) then
            save_file_clear_flags(entry.flag)
        end
    end
end

hook_event(HOOK_ON_PACKET_RECEIVE, on_mirror)

local function put_back(shot)
    local index = shot.file

    for courseNum = COURSE_MIN, COURSE_MAX do
        local courseIndex = courseNum - 1
        local mask = shot.courses[courseIndex] or 0
        save_file_remove_star_flags(index, courseIndex, FULL_COURSE_MASK)
        if mask > 0 then save_file_set_star_flags(index, courseIndex, mask) end

        if shot.cannons ~= nil then
            save_file_remove_star_flags(index, courseIndex, CANNON_BIT)
            if shot.cannons[courseIndex] then
                save_file_set_star_flags(index, courseIndex, CANNON_BIT)
            end
        end
    end
    save_file_remove_star_flags(index, -1, FULL_COURSE_MASK)
    if shot.castle > 0 then save_file_set_star_flags(index, -1, shot.castle) end

    for _, entry in ipairs(save.FLAGS) do
        if shot.flags[entry.key] then
            save_file_set_flags(entry.flag)
        else
            clear_flag(entry.flag)
        end
    end
end

function save.undo()
    local ok, why = save.can_undo()
    if not ok then return false, why end

    local shot = save.before

    local had = save.star_count()

    put_back(shot)

    save.before = nil
    commit()
    save.refresh_star_count()

    file_change(OF.lang.t("Put the save back to how it was"),
        OF.lang.fill("@ stars", had), OF.lang.fill("@ stars", save.star_count()))
    return true
end

local function fresh_reading(index)
    local shot = { file = index, stars = 0, castle = 0,
                   courses = {}, cannons = {}, flags = {} }
    for courseNum = COURSE_MIN, COURSE_MAX do
        shot.courses[courseNum - 1] = 0
        shot.cannons[courseNum - 1] = false
    end
    for _, entry in ipairs(save.FLAGS) do
        shot.flags[entry.key] = false
    end
    return shot
end

local function without_spending_the_undo(run)
    local wasUndo = save.before
    mirror_begin()
    run()
    mirror_end()
    commit()
    save.refresh_star_count()
    save.before = wasUndo
end

function save.world_take()
    local allowed, why = save.can_edit()
    if not allowed then return nil, why end

    local shot = save.reading()

    shot.borrow = "fresh"
    local had = shot.stars

    write_begin()
    without_spending_the_undo(function()
        put_back(fresh_reading(shot.file))
    end)
    write_end()

    local wasCause = cause
    cause = OF.lang.t("a star-count run starting the castle fresh")
    file_change(OF.lang.t("Locked the castle for a run"),
        OF.lang.fill("@ stars", had), OF.lang.fill("@ stars", save.star_count()))
    cause = wasCause
    return shot
end

local COURSE_BITS = { 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40 }

local function bits_added(was, mask)
    local out = math.floor(tonumber(was) or 0)
    for _, bit in ipairs(COURSE_BITS) do
        if OF.util.has_flag(mask, bit) and not OF.util.has_flag(out, bit) then
            out = out + bit
        end
    end
    return out
end

local OPEN_LEAVES_ALONE = { moat = true }

local function open_reading(shot)
    local open = { file = shot.file, stars = shot.stars,
                   castle = bits_added(shot.castle, CASTLE_SECRET_MASK),
                   courses = {}, cannons = {}, flags = {} }
    for courseNum = COURSE_MIN, COURSE_MAX do
        local courseIndex = courseNum - 1

        open.courses[courseIndex] =
            bits_added(shot.courses[courseIndex], mask_for_course(courseNum))
        open.cannons[courseIndex] = true
    end
    for _, entry in ipairs(save.FLAGS) do
        if OPEN_LEAVES_ALONE[entry.key] then
            open.flags[entry.key] = shot.flags[entry.key] == true
        else
            open.flags[entry.key] = true
        end
    end
    return open
end

function save.world_open()
    local allowed, why = save.can_edit()
    if not allowed then return nil, why end

    local shot = save.reading()
    shot.borrow = "open"
    local had = shot.stars

    write_begin()
    without_spending_the_undo(function()
        put_back(open_reading(shot))
    end)
    write_end()

    return shot
end

function save.world_give_back(shot)
    if type(shot) ~= "table" or shot.courses == nil or shot.flags == nil then
        return false, "There is nothing to put back."
    end
    local allowed, why = save.can_edit()
    if not allowed then return false, why end
    if shot.file ~= file_index() then
        return false, "That was a different save file - this one never changed."
    end

    local had = save.star_count()
    write_begin()
    without_spending_the_undo(function() put_back(shot) end)
    write_end()

    local wasCause = cause
    if shot.borrow == "stranded" then
        cause = OF.lang.t("a round that never finished")
        file_change(OF.lang.t("Put the castle back after a round that did not end"),
            OF.lang.fill("@ stars", had),
            OF.lang.fill("@ stars", save.star_count()))
    elseif shot.borrow ~= "open" then
        cause = OF.lang.t("a star-count run ending")
        file_change(OF.lang.t("Gave the castle back after a run"),
            OF.lang.fill("@ stars", had),
            OF.lang.fill("@ stars", save.star_count()))
    end
    cause = wasCause
    return true
end

local HEX = "0123456789abcdef"
local function hex_digits(value, digits)
    local n = math.floor(tonumber(value) or 0)
    if n < 0 then n = 0 end
    local out = ""
    for _ = 1, digits do
        local digit = n % 16
        out = string.sub(HEX, digit + 1, digit + 1) .. out
        n = math.floor(n / 16)
    end
    return out
end

function save.world_pack(shot)
    if type(shot) ~= "table" or shot.courses == nil or shot.flags == nil then
        return nil
    end
    local word = 0
    for _, entry in ipairs(save.FLAGS) do
        if shot.flags[entry.key] then word = word + entry.flag end
    end
    local bytes = {}
    for courseNum = COURSE_MIN, COURSE_MAX do
        local courseIndex = courseNum - 1
        local byte = (math.floor(tonumber(shot.courses[courseIndex]) or 0)) % 0x80
        if shot.cannons ~= nil and shot.cannons[courseIndex] then
            byte = byte + CANNON_BIT
        end
        table.insert(bytes, hex_digits(byte, 2))
    end
    return "1:" .. tostring(math.floor(tonumber(shot.file) or 0))
        .. ":" .. hex_digits(word, 8)
        .. ":" .. hex_digits((math.floor(tonumber(shot.castle) or 0)) % 0x80, 2)
        .. ":" .. table.concat(bytes)
end

function save.world_unpack(text)
    if type(text) ~= "string" then return nil end
    local version, index, word, castle, bytes =
        string.match(text, "^(%d+):(%d+):(%x+):(%x+):(%x+)$")
    if version ~= "1" then return nil end
    local courses = COURSE_MAX - COURSE_MIN + 1
    if #bytes ~= courses * 2 then return nil end

    local shot = { file = tonumber(index), stars = 0,
                   castle = tonumber(castle, 16),
                   courses = {}, cannons = {}, flags = {} }
    word = tonumber(word, 16)
    for courseNum = COURSE_MIN, COURSE_MAX do
        local at = (courseNum - COURSE_MIN) * 2 + 1
        local byte = tonumber(string.sub(bytes, at, at + 1), 16)
        shot.courses[courseNum - 1] = byte % 0x80
        shot.cannons[courseNum - 1] = byte >= CANNON_BIT
    end
    for _, entry in ipairs(save.FLAGS) do
        shot.flags[entry.key] = OF.util.has_flag(word, entry.flag)
    end

    for courseNum = COURSE_MIN, COURSE_MAX do
        for bit = 0, 6 do
            if OF.util.has_flag(shot.courses[courseNum - 1], 2 ^ bit) then
                shot.stars = shot.stars + 1
            end
        end
    end
    for bit = 0, 6 do
        if OF.util.has_flag(shot.castle, 2 ^ bit) then
            shot.stars = shot.stars + 1
        end
    end
    return shot
end

function save.apply(action, value)
    local allowed, why = save.can_edit()
    if not allowed then return false, why end
    if action == "flag" then
        local entry = save.find_flag(value)

        if entry == nil then return false end
        return save.toggle_flag(entry.flag)
    elseif action == "allstars" then
        save.set_all_stars(true)
    elseif action == "nostars" then
        save.set_all_stars(false)
    elseif action == "allcaps" then
        local had = count_on(save.CAP_FLAGS)
        save.set_flags(save.CAP_FLAGS, true)
        file_change(OF.lang.t("Gave all three caps"),
            OF.lang.fill("@ of 3 caps", had),
            OF.lang.fill("@ of 3 caps", count_on(save.CAP_FLAGS)))
    elseif action == "nocaps" then
        local had = count_on(save.CAP_FLAGS)
        save.set_flags(save.CAP_FLAGS, false)
        file_change(OF.lang.t("Took all three caps"),
            OF.lang.fill("@ of 3 caps", had),
            OF.lang.fill("@ of 3 caps", count_on(save.CAP_FLAGS)))

    elseif action == "alldoors" then
        local had = count_on(save.DOOR_FLAGS)
        write_begin()
        save.set_flags(save.DOOR_FLAGS, true)
        save_file_set_flags(SAVE_FLAG_HAVE_KEY_1)
        save_file_set_flags(SAVE_FLAG_HAVE_KEY_2)
        commit()
        write_end()
        file_change(OF.lang.t("Unlocked every door and gave both keys"),
            OF.lang.fill("@ of 9 doors", had),
            OF.lang.fill("@ of 9 doors", count_on(save.DOOR_FLAGS)))
    elseif action == "nodoors" then
        local had = count_on(save.DOOR_FLAGS)
        write_begin()
        save.set_flags(save.DOOR_FLAGS, false)
        save_file_clear_flags(SAVE_FLAG_HAVE_KEY_1)
        save_file_clear_flags(SAVE_FLAG_HAVE_KEY_2)
        commit()
        write_end()
        file_change(OF.lang.t("Locked every door and took both keys"),
            OF.lang.fill("@ of 9 doors", had),
            OF.lang.fill("@ of 9 doors", count_on(save.DOOR_FLAGS)))
    else
        return false
    end
    return true
end

function save.broadcast(action, value)
    if not OF.perms.can("save_edit") then
        return false, "Your rank cannot do that.", "save_edit"
    end

    if not OF.util.is_host() then
        return false, "Only the host can edit save files."
    end

    local had = save.star_count()

    cause = OF.lang.t("a race starting the lobby from scratch")
    local ok, why = save.apply(action, value)
    cause = nil
    if ok and action == "nostars" and had > 0 then

        OF.notify.show(
            "The save is at zero - Fun, Save file editor puts @ stars back.",
            "warn", 8, had)
    end
    return ok, why
end

function save.send_to(globalIndex, action, value)
    if not OF.perms.can("save_edit") then
        return false, "Your rank cannot do that.", "save_edit"
    end
    if globalIndex == network_global_index_from_local(0) then
        return save.apply(action, value)
    end
    if not OF.util.is_host() then
        return false, "Only the host can edit somebody else's save file."
    end
    if OF.util.local_from_global(globalIndex) == nil then
        return false, "That player has left."
    end
    return false, "There is one save file in a lobby and it is the host's - editing it changes it for everybody."
end

local function on_packet_receive(data)
    if data == nil then return end
    if data.ofp ~= save.PACKET then return end
    if not OF.util.from_host(data) then return end
    if not OF.settings.allowSaveEdits then return end
    if not save.can_edit() then return end

    save.apply(data.act, data.val)
    OF.notify.show("The host changed your save file", "warn", 5)
end

hook_event(HOOK_ON_PACKET_RECEIVE, on_packet_receive)

function save.build_page(panel)

    if OF.util.asks(OF.ledger, "build_rows") then
        local reading = OF.ledger.build_rows(panel)
        if reading ~= nil then return reading end
    end

    local rows = {}

    table.insert(rows, panel.label_row(
        OF.lang.fill("This lobby's save: @ of 120 stars.", save.star_count())))
    table.insert(rows, panel.label_row(
        OF.lang.t("One file, the host's, shared by the lobby. The game keeps no backup.")))

    if OF.util.asks(OF.ledger, "build_entry_row") then
        table.insert(rows, OF.ledger.build_entry_row(panel))
    end

    local back = save.undo_stars()
    if back ~= nil then
        table.insert(rows, panel.with_help(panel.gated_row("save_edit",
            OF.lang.fill("Put the save back to @ stars, as it was", back),
            160, 255, 160, function()
                if OF.util.report(save.undo()) then
                    OF.notify.show("The save is back to how it was", "good")
                end
            end),
            "One step, and only until the lobby restarts."))
    end

    table.insert(rows, panel.with_help(panel.row(
        OF.lang.t("Reload this area to show door and water changes"),
        255, 255, 255, function()
            save.reload_level()
            panel.close()
        end),
        OF.lang.t("a drained moat and an unlocked door are built into the area")))

    table.insert(rows, panel.with_help(
        panel.header_row(OF.lang.t("Everything at once")),
        "one press writes the whole castle: every door, every cap switch, or "
        .. "every star there is"))

    table.insert(rows, panel.with_help(panel.gated_row("save_edit",
        OF.lang.t("Unlock every door and give both keys"),
        255, 255, 255, function()
        if OF.util.report(save.apply("alldoors")) then
            OF.notify.show("Doors unlocked", "good")
        end
    end),
        OF.lang.t("nine doors and both of Bowser's keys, in one press")))
    table.insert(rows, panel.with_help(panel.gated_confirm_row("save_edit", "nodoors",
        OF.lang.t("Lock every door and take both keys"),
        255, 200, 120, function()
        if OF.util.report(save.apply("nodoors")) then
            OF.notify.show("Doors locked", "warn")
        end
    end),
        OF.lang.t("puts the castle back behind its locks - stars are untouched")))
    table.insert(rows, panel.with_help(panel.gated_row("save_edit",
        OF.lang.t("Unlock all caps"), 255, 255, 255, function()
        OF.util.report(save.apply("allcaps"))
    end),
        OF.lang.t("all three switches count as pressed, so every cap box works")))
    table.insert(rows, panel.with_help(panel.gated_confirm_row("save_edit", "nocaps",
        OF.lang.t("Take all caps"), 255, 200, 120, function()
        OF.util.report(save.apply("nocaps"))
    end),
        OF.lang.t("the three switches count as unpressed, so no cap box works")))
    table.insert(rows, panel.with_help(panel.gated_confirm_row("save_edit", "allstars",
        OF.lang.fill("Give every star: @ now, 120 after, keys, caps and doors too",
            save.star_count()),
        255, 215, 0, function()
            if OF.util.report(save.set_all_stars(true)) then
                OF.notify.show("All 120 stars", "good")
            end
        end),
        "writes over the host's own progress - only this mod's own way back undoes it"))
    table.insert(rows, panel.with_help(panel.gated_confirm_row("save_edit", "nostars",
        OF.lang.fill("Wipe the save: @ stars, both keys, every cap and door go",
            save.star_count()),
        255, 140, 90, function()
            if OF.util.report(save.set_all_stars(false)) then
                OF.notify.show("Save wiped to zero", "warn")
            end
        end),
        "the host's real file, on the host's disk - the game keeps no backup"))

    table.insert(rows, panel.with_help(
        panel.header_row(
            OF.lang.fill("Stars, one at a time (@ of 120)", save.star_count())),
        "one course to a row, opened to reach the stars inside it"))
    local courses = OF.util.asks(OF.ledger, "COURSES") and OF.ledger.COURSES or nil
    for _, entry in ipairs(courses or {}) do

        if (entry.stars or 0) > 0 then
            local on = save.course_stars(entry.num, entry.stars)
            local name = entry.name or OF.util.course_name(entry.num)
            local num = entry.num

            table.insert(rows, panel.with_help(
                panel.with_right(panel.row(OF.lang.fill("@ stars...", name),
                    255, 255, 255, function()
                        save.pick_star_course(num)
                        panel.go("savestar")
                    end), on .. "/" .. entry.stars),
                OF.lang.t("opens this course's stars in the host's save file, "
                    .. "one box each")))
        end
    end

    table.insert(rows, panel.with_help(
        panel.with_right(panel.row(OF.lang.t("The castle itself..."),
            255, 255, 255, function()
                save.pick_star_course(-1)
                panel.go("savestar")
            end), save.course_stars(-1, 5) .. "/5"),
        OF.lang.t("the three Toads and the two stars MIPS gives up")))

    table.insert(rows, panel.with_help(
        panel.header_row(OF.lang.t("One at a time")),
        "the doors, the keys and the cap switches, each ticked on its own"))

    table.insert(rows, panel.label_row(OF.lang.t(
        "A door you tick opens at any star count, and unlocks in front of you "
        .. "the first time you reach it.")))
    for _, entry in ipairs(save.FLAGS) do
        local on = save.has_flag(entry.flag)
        local r, g, b = 200, 200, 200
        if on then r, g, b = 255, 255, 255 end

        table.insert(rows, panel.with_help(
            panel.gated_row("save_edit", panel.tick(on, OF.lang.t(entry.name)),
                r, g, b, function()
                    OF.util.report(save.toggle_flag(entry.flag))
                end),
            OF.lang.t(entry.blurb)))
    end

    table.insert(rows, panel.back_row())
    return rows
end

local starCourse = nil

function save.star_course()
    return starCourse
end

function save.pick_star_course(num)
    starCourse = num
    return true
end

function save.build_star_page(panel)
    local rows = {}
    local num = starCourse

    if num == nil then
        rows[#rows + 1] = panel.label_row(OF.lang.t("Pick a course first."))
        rows[#rows + 1] = panel.back_row("save")
        return rows
    end

    local name = num == -1 and OF.lang.t("The castle itself")
        or OF.util.course_name(num)
    rows[#rows + 1] = panel.label_row(name)

    local allowed, why = save.can_edit()
    if not allowed and why ~= nil then
        rows[#rows + 1] = panel.label_row(why)
    end

    for i = 0, 6 do
        if save.star_bit(num, i) ~= nil then
            local lit = save.star_on(num, i)
            local r, g, b = 200, 200, 200
            if lit then r, g, b = 255, 255, 255 end
            local at = i
            rows[#rows + 1] = panel.with_help(panel.gated_row("save_edit",
                panel.tick(lit, OF.lang.fill("Star @", i + 1)), r, g, b,
                function() OF.util.report(save.toggle_star(num, at)) end),
                OF.lang.t("writes this one star into the host's file"))
        end
    end

    rows[#rows + 1] = panel.back_row("save")
    return rows
end
