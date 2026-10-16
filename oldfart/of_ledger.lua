OF = OF or {}
OF.ledger = OF.ledger or {}

local ledger = OF.ledger

local CASTLE_COURSE = 0

local CASTLE_INDEX = -1
local CASTLE_STARS = 5

local COIN_STAR = 7

local MAIN_COURSE_STARS = 7

local CANNON_COURSES = {
    [COURSE_BOB] = true, [COURSE_WF] = true, [COURSE_JRB] = true,
    [COURSE_CCM] = true, [COURSE_SSL] = true, [COURSE_SL] = true,
    [COURSE_WDW] = true, [COURSE_TTM] = true, [COURSE_THI] = true,
    [COURSE_RR] = true, [COURSE_WMOTR] = true,
}

ledger.COURSES = {
    { num = COURSE_BOB,  stars = MAIN_COURSE_STARS },
    { num = COURSE_WF,   stars = MAIN_COURSE_STARS },
    { num = COURSE_JRB,  stars = MAIN_COURSE_STARS },
    { num = COURSE_CCM,  stars = MAIN_COURSE_STARS },
    { num = COURSE_BBH,  stars = MAIN_COURSE_STARS },
    { num = COURSE_HMC,  stars = MAIN_COURSE_STARS },
    { num = COURSE_LLL,  stars = MAIN_COURSE_STARS },
    { num = COURSE_SSL,  stars = MAIN_COURSE_STARS },
    { num = COURSE_DDD,  stars = MAIN_COURSE_STARS },
    { num = COURSE_SL,   stars = MAIN_COURSE_STARS },
    { num = COURSE_WDW,  stars = MAIN_COURSE_STARS },
    { num = COURSE_TTM,  stars = MAIN_COURSE_STARS },
    { num = COURSE_THI,  stars = MAIN_COURSE_STARS },
    { num = COURSE_TTC,  stars = MAIN_COURSE_STARS },
    { num = COURSE_RR,   stars = MAIN_COURSE_STARS },
    { num = COURSE_BITDW, stars = 1, name = "Bowser in the Dark World" },
    { num = COURSE_BITFS, stars = 1, name = "Bowser in the Fire Sea" },
    { num = COURSE_BITS,  stars = 1, name = "Bowser in the Sky" },
    { num = COURSE_PSS,   stars = 2, name = "The Princess's Secret Slide" },
    { num = COURSE_COTMC, stars = 1, name = "Cavern of the Metal Cap" },
    { num = COURSE_TOTWC, stars = 1, name = "Tower of the Wing Cap" },
    { num = COURSE_VCUTM, stars = 1, name = "Vanish Cap under the Moat" },
    { num = COURSE_WMOTR, stars = 1, name = "Wing Mario over the Rainbow" },
    { num = COURSE_SA,    stars = 1, name = "The Secret Aquarium" },
    { num = COURSE_CAKE_END, stars = 0, name = "The End" },
}

function ledger.file_index()
    local num = get_current_save_file_num()
    if num == nil or num < 1 then return 0 end
    return num - 1
end

function ledger.file_number()
    local num = get_current_save_file_num()
    if num == nil or num < 1 then return 1 end
    return num
end

local function has_star(flags, starNum)
    if starNum == nil or starNum < 1 then return false end
    return OF.util.has_flag(flags, 2 ^ (starNum - 1))
end

function ledger.star_name(courseNum, starNum)
    local name = nil

    if OF.util.asks(OF.roundbrief, "original_star") then
        name = OF.roundbrief.original_star(courseNum, starNum)
    end
    if name == nil and get_star_name ~= nil then
        local ok, value = pcall(get_star_name, courseNum, starNum)
        if ok and type(value) == "string" and value ~= "" then name = value end
    end
    if name == nil then name = OF.lang.fill("Star @", starNum) end
    return name
end

function ledger.course_name(entry)
    if entry.name ~= nil then return entry.name end
    return OF.util.course_name(entry.num)
end

function ledger.cannon(courseNum)
    if not CANNON_COURSES[courseNum] then return nil end
    if type(save_file_is_cannon_unlocked) ~= "function" then return nil end
    local ok, value = pcall(save_file_is_cannon_unlocked, ledger.file_index(), courseNum)
    if not ok or value == nil then return nil end
    return value ~= 0
end

function ledger.coins(courseNum)
    if type(course_is_main_course) ~= "function" then return nil end
    local ok, main = pcall(course_is_main_course, courseNum)

    if not ok or OF.util.flag(main) == 0 then return nil end
    if type(save_file_get_course_coin_score) ~= "function" then return nil end
    local got, value = pcall(save_file_get_course_coin_score,
        ledger.file_index(), courseNum - 1)
    if not got or type(value) ~= "number" then return nil end
    return value
end

function ledger.coin_target()
    if gLevelValues == nil then return 100 end
    local need = gLevelValues.coinsRequiredForCoinStar
    if type(need) ~= "number" or need <= 0 then return 100 end
    return need
end

local function course_entry(courseNum)
    for _, candidate in ipairs(ledger.COURSES) do
        if candidate.num == courseNum then return candidate end
    end
    return nil
end

function ledger.course_progress(courseNum)
    local entry = course_entry(courseNum)
    if entry == nil then return nil end

    local flags = save_file_get_star_flags(ledger.file_index(), courseNum - 1)
    local got, missing, only = 0, 0, nil
    for starNum = 1, entry.stars do
        if has_star(flags, starNum) then
            got = got + 1
        else
            missing = missing + 1
            only = starNum
        end
    end

    return {
        num = courseNum,
        name = ledger.course_name(entry),
        total = entry.stars,
        got = got,
        cannon = ledger.cannon(courseNum),
        missingStar = (missing == 1) and only or nil,
    }
end

function ledger.course(courseNum)
    local entry = course_entry(courseNum)
    if entry == nil then return nil end

    local flags = save_file_get_star_flags(ledger.file_index(), courseNum - 1)

    local stars = {}
    local missing = {}
    local got = 0

    for starNum = 1, entry.stars do
        local have = has_star(flags, starNum)
        local name = ledger.star_name(courseNum, starNum)
        table.insert(stars, { num = starNum, name = name, have = have })
        if have then
            got = got + 1
        else
            table.insert(missing, name)
        end
    end

    return {
        num = courseNum,
        name = ledger.course_name(entry),
        total = entry.stars,
        got = got,
        stars = stars,
        missing = missing,
        cannon = ledger.cannon(courseNum),
        coins = ledger.coins(courseNum),
    }
end

function ledger.castle()
    local flags = save_file_get_star_flags(ledger.file_index(), CASTLE_INDEX)
    local needs = {}
    local values = gBehaviorValues
    if values ~= nil then
        needs[1] = values.ToadStar1Requirement
        needs[2] = values.ToadStar2Requirement
        needs[3] = values.ToadStar3Requirement
        needs[4] = values.MipsStar1Requirement
        needs[5] = values.MipsStar2Requirement
    end

    local total = ledger.star_count()

    local stars = {}
    local got = 0
    for starNum = 1, CASTLE_STARS do
        local have = has_star(flags, starNum)
        local need = needs[starNum]
        if type(need) ~= "number" then need = nil end
        table.insert(stars, {
            num = starNum,
            name = ledger.star_name(CASTLE_COURSE, starNum),
            have = have,
            needs = need,

            waiting = (not have) and need ~= nil and total >= need,
        })
        if have then got = got + 1 end
    end
    return { got = got, total = CASTLE_STARS, stars = stars }
end

function ledger.star_count()
    return save_file_get_total_star_count(ledger.file_index(),
        COURSE_MIN - 1, COURSE_MAX - 1)
end

function ledger.star_total()
    local total = CASTLE_STARS
    for _, entry in ipairs(ledger.COURSES) do total = total + entry.stars end
    return total
end

ledger.DOORS = {
    { flag = SAVE_FLAG_UNLOCKED_WF_DOOR,    needs = 1,  name = "Whomp's Fortress door" },
    { flag = SAVE_FLAG_UNLOCKED_PSS_DOOR,   needs = 1,  name = "Secret Slide door" },
    { flag = SAVE_FLAG_UNLOCKED_CCM_DOOR,   needs = 3,  name = "Cool, Cool Mountain door" },
    { flag = SAVE_FLAG_UNLOCKED_JRB_DOOR,   needs = 3,  name = "Jolly Roger Bay door" },
    { flag = SAVE_FLAG_UNLOCKED_BITDW_DOOR, needs = 8,  name = "Dark World door" },
    { flag = SAVE_FLAG_UNLOCKED_BITFS_DOOR, needs = 30, name = "Fire Sea door" },
    { flag = SAVE_FLAG_UNLOCKED_50_STAR_DOOR, needs = 50, name = "50 star door" },
}

ledger.STAIRS_STARS = 70

ledger.KEYS = {
    { key = SAVE_FLAG_HAVE_KEY_1, door = SAVE_FLAG_UNLOCKED_BASEMENT_DOOR,
      name = "Basement key", doorName = "basement door" },
    { key = SAVE_FLAG_HAVE_KEY_2, door = SAVE_FLAG_UNLOCKED_UPSTAIRS_DOOR,
      name = "Upstairs key", doorName = "upstairs door" },
}

ledger.CAPS = {
    { flag = SAVE_FLAG_HAVE_WING_CAP,   name = "Wing Cap",
      where = "Tower of the Wing Cap" },
    { flag = SAVE_FLAG_HAVE_METAL_CAP,  name = "Metal Cap",
      where = "Cavern of the Metal Cap" },
    { flag = SAVE_FLAG_HAVE_VANISH_CAP, name = "Vanish Cap",
      where = "Vanish Cap under the Moat" },
}

local function flags_now()
    return save_file_get_flags()
end

function ledger.has_flag(flag)
    return OF.util.has_flag(flags_now(), flag)
end

local function cap_holders()
    return {
        { flag = SAVE_FLAG_CAP_ON_GROUND,
          where = "lying on the ground where it fell" },
        { flag = SAVE_FLAG_CAP_ON_KLEPTO,
          where = "Klepto has it, in Shifting Sand Land" },
        { flag = SAVE_FLAG_CAP_ON_UKIKI,
          where = "Ukiki has it, in Tall, Tall Mountain" },
        { flag = SAVE_FLAG_CAP_ON_MR_BLIZZARD,
          where = "Mr. Blizzard has it, in Snowman's Land" },
    }
end

function ledger.cap_holder()
    local flags = flags_now()
    for _, entry in ipairs(cap_holders()) do
        if entry.flag ~= nil and OF.util.has_flag(flags, entry.flag) then
            return entry.where
        end
    end
    return nil
end

function ledger.world()
    return {
        { name = "The moat is drained", on = ledger.has_flag(SAVE_FLAG_MOAT_DRAINED),
          note = "Both pillars in the basement's flooded room have been pounded." },
        { name = "The Dire, Dire Docks painting has slid back",
          on = ledger.has_flag(SAVE_FLAG_DDD_MOVED_BACK),
          note = "Slides once Board Bowser's Sub is taken, and stays back." },
    }
end

function ledger.nearly()
    local out = {}
    local total = ledger.star_count()

    for _, entry in ipairs(ledger.KEYS) do
        if ledger.has_flag(entry.key) and not ledger.has_flag(entry.door) then
            table.insert(out, OF.lang.fill(
                "The @ is in hand and its door has never been opened.",
                entry.name))
        end
    end

    for _, entry in ipairs(ledger.COURSES) do
        if entry.stars > 1 then
            local course = ledger.course_progress(entry.num)
            if course ~= nil and course.missingStar ~= nil then
                table.insert(out, OF.lang.fill("@ is one short: @",
                    course.name, ledger.star_name(entry.num, course.missingStar)))
            end
        end
    end

    local target = ledger.coin_target()
    for _, entry in ipairs(ledger.COURSES) do
        if entry.stars == MAIN_COURSE_STARS then
            local flags = save_file_get_star_flags(ledger.file_index(), entry.num - 1)
            local coins = ledger.coins(entry.num)
            if coins ~= nil and coins >= target and not has_star(flags, COIN_STAR) then
                table.insert(out, OF.lang.fill(
                    "@ has had @ coins in one go and never taken the coin star.",
                    ledger.course_name(entry), coins))
            end
        end
    end

    for _, entry in ipairs(ledger.DOORS) do
        if total >= entry.needs and not ledger.has_flag(entry.flag) then
            table.insert(out, OF.lang.fill(
                "The @ takes @ and has never been opened.", entry.name, entry.needs))
        end
    end

    local castle = ledger.castle()
    for _, star in ipairs(castle.stars) do
        if star.waiting then
            table.insert(out, OF.lang.fill("@ is waiting - it wanted @ stars.",
                star.name, star.needs))
        end
    end

    if total < ledger.STAIRS_STARS then
        local short = ledger.STAIRS_STARS - total
        if short <= 10 then
            table.insert(out, OF.lang.fill(
                "The endless stairs want @ stars - @ to go.",
                ledger.STAIRS_STARS, short))
        end
    end

    return out
end

function ledger.mips()
    local castle = ledger.castle()
    local total = ledger.star_count()
    local taken = 0
    local soonest = nil
    for _, star in ipairs(castle.stars) do
        if star.num == 4 or star.num == 5 then
            if star.have then
                taken = taken + 1
            elseif star.needs ~= nil then
                if total >= star.needs then return star.name end
                if soonest == nil or star.needs < soonest then soonest = star.needs end
            end
        end
    end
    if soonest ~= nil then
        return nil, OF.lang.fill("MIPS turns up in the basement at @ stars.", soonest)
    end
    if taken > 0 then
        return nil, OF.lang.t("MIPS is not down there - both his stars are taken.")
    end
    return nil, OF.lang.t("MIPS is not down there.")
end

local MOST = 20

ledger.entries = ledger.entries or {}

function ledger.count()
    return #ledger.entries
end

function ledger.latest()
    return ledger.entries[1]
end

function ledger.forget()
    ledger.entries = {}
    return true
end

function ledger.clock_text()
    local now = OF.util.optional("get_date_and_time", nil)
    if now == nil then return nil end
    local hour, minute = now.hour, now.minute
    if type(hour) ~= "number" or type(minute) ~= "number" then return nil end
    return string.format("%02.0f:%02.0f", math.floor(hour), math.floor(minute))
end

function ledger.record(what, was, now, cause)
    if type(what) ~= "string" or what == "" then return nil end
    local entry = {
        what = what,
        was = was,
        now = now,
        cause = cause,
        at = ledger.clock_text(),
    }
    table.insert(ledger.entries, 1, entry)

    while #ledger.entries > MOST do
        table.remove(ledger.entries, #ledger.entries)
    end
    return entry
end

ledger.view = nil
ledger.courseNum = nil

local function land_on(view)
    ledger.view = view

    if OF.panel ~= nil then
        OF.panel.scroll = 0
        OF.panel.cursor = 1
    end
end

function ledger.open()
    land_on("main")
    return true
end

function ledger.close()
    ledger.view = nil
    ledger.courseNum = nil
    if OF.panel ~= nil then
        OF.panel.scroll = 0
        OF.panel.cursor = 1
    end
    return true
end

function ledger.page_title()
    if ledger.view == nil then return nil end
    if ledger.view == "course" then return "Save file: a course" end
    if ledger.view == "locks" then return "Save file: doors and keys" end
    if ledger.view == "record" then return "Save file: what was changed" end
    return "Save file: what it has done"
end

function ledger.open_course(courseNum)
    ledger.courseNum = courseNum
    land_on("course")
    return true
end

local function star_row(panel, star)
    local r, g, b = 200, 200, 200
    if star.have then r, g, b = 255, 255, 255 end
    return panel.label_row(panel.tick(star.have, star.name), r, g, b)
end

local function build_main(panel)
    local rows = {}
    local total = ledger.star_count()
    local whole = ledger.star_total()

    table.insert(rows, panel.label_row(OF.lang.fill(
        "Save file @ - @ stars.", ledger.file_number(),
        total .. " of " .. whole)))
    table.insert(rows, panel.label_row(OF.lang.t(
        "Reading only. Nothing on these pages changes the file.")))

    local nearly = ledger.nearly()
    if #nearly > 0 then
        table.insert(rows, panel.header_row(OF.lang.t("One press away")))
        for _, line in ipairs(nearly) do
            table.insert(rows, panel.label_row(line, 255, 215, 0))
        end
    end

    table.insert(rows, panel.header_row(OF.lang.t("The fifteen courses")))
    for _, entry in ipairs(ledger.COURSES) do
        if entry.stars == MAIN_COURSE_STARS then
            local course = ledger.course_progress(entry.num)
            local r, g, b = 255, 255, 255
            if course.got == 0 then r, g, b = 160, 160, 160 end
            if course.got == course.total then r, g, b = 160, 255, 160 end
            local mark = ""
            if course.cannon == false then mark = "  " .. OF.lang.t("(cannon shut)") end
            local num = entry.num
            table.insert(rows, panel.with_help(panel.with_right(
                panel.row(course.name .. mark, r, g, b, function()
                    ledger.open_course(num)
                end),
                course.got .. "/" .. course.total),
                OF.lang.t("opens this course and names every star in it")))
        end
    end

    table.insert(rows, panel.header_row(OF.lang.t("The other places")))
    for _, entry in ipairs(ledger.COURSES) do
        if entry.stars > 0 and entry.stars ~= MAIN_COURSE_STARS then
            local course = ledger.course_progress(entry.num)
            local r, g, b = 200, 200, 200
            if course.got == course.total then r, g, b = 160, 255, 160 end
            if course.total == 1 then

                table.insert(rows, panel.label_row(
                    panel.tick(course.got == 1, course.name), r, g, b))
            else
                local num = entry.num
                table.insert(rows, panel.with_help(panel.with_right(
                    panel.row(course.name, r, g, b, function()
                        ledger.open_course(num)
                    end),
                    course.got .. "/" .. course.total),
                    OF.lang.t("opens this place and names every star in it")))
            end
        end
    end

    table.insert(rows, panel.header_row(OF.lang.t("The castle's own five")))
    local castle = ledger.castle()
    for _, star in ipairs(castle.stars) do
        local text = panel.tick(star.have, star.name)
        local right = nil
        if star.needs ~= nil then
            right = OF.lang.fill("@ stars", star.needs)
        end
        local r, g, b = 200, 200, 200
        if star.have then r, g, b = 255, 255, 255 end
        if star.waiting then r, g, b = 255, 215, 0 end
        table.insert(rows, panel.with_right(panel.label_row(text, r, g, b), right))
    end
    local mips, why = ledger.mips()
    if mips ~= nil then
        table.insert(rows, panel.label_row(OF.lang.fill(
            "MIPS is loose in the basement, carrying @.", mips), 255, 215, 0))
    else
        table.insert(rows, panel.label_row(why))
    end

    table.insert(rows, panel.with_help(
        panel.row(OF.lang.t("Keys, caps and doors..."),
            255, 255, 255, function() land_on("locks") end),
        OF.lang.t("what the file has unlocked, and what is still shut")))

    local changes = ledger.count()
    local right = nil
    if changes > 0 then right = OF.lang.fill("@ so far", changes) end
    table.insert(rows, panel.with_help(panel.with_right(
        panel.row(OF.lang.t("What has been changed, and what it was..."),
            255, 255, 255, function() land_on("record") end),
        right),
        "every edit this session, newest first, with what the file held before it"))

    table.insert(rows, panel.row(OF.lang.t("< Back to the save editor"),
        180, 180, 180, function() ledger.close() end))
    table.insert(rows, panel.back_row("fun"))
    return rows
end

local function build_course(panel)
    local rows = {}
    local course = ledger.course(ledger.courseNum)
    if course == nil then
        table.insert(rows, panel.label_row(OF.lang.t("That course is not in this file.")))
        table.insert(rows, panel.row(OF.lang.t("< Back"), 180, 180, 180,
            function() land_on("main") end))
        return rows
    end

    table.insert(rows, panel.label_row(OF.lang.fill("@ - @ stars.",
        course.name, course.got .. " of " .. course.total)))

    for _, star in ipairs(course.stars) do
        table.insert(rows, star_row(panel, star))
    end

    if course.cannon ~= nil then
        table.insert(rows, panel.with_help(panel.label_row(
            panel.tick(course.cannon, OF.lang.t("Cannon open")),
            course.cannon and 255 or 200, course.cannon and 255 or 200,
            course.cannon and 255 or 200),
            "a Bob-omb Buddy opens it, and the file remembers it for ever"))
    end

    if course.coins ~= nil then
        local target = ledger.coin_target()
        table.insert(rows, panel.with_right(panel.label_row(
            OF.lang.t("Best coins in one visit")),
            course.coins .. "/" .. target))
    end

    if #course.missing > 0 then
        table.insert(rows, panel.header_row(OF.lang.t("Still out there")))
        for _, name in ipairs(course.missing) do
            table.insert(rows, panel.label_row(name, 255, 215, 0))
        end
    end

    table.insert(rows, panel.row(OF.lang.t("< Every course"), 180, 180, 180,
        function() land_on("main") end))
    table.insert(rows, panel.back_row("fun"))
    return rows
end

local function build_locks(panel)
    local rows = {}
    local total = ledger.star_count()

    table.insert(rows, panel.header_row(OF.lang.t("The two keys")))
    for _, entry in ipairs(ledger.KEYS) do

        local through = ledger.has_flag(entry.door)
        local held = ledger.has_flag(entry.key)

        local level, r, g, b = nil, 200, 200, 200
        if through then
            level = OF.lang.fill("spent, @ open", entry.doorName)
            r, g, b = 160, 255, 160
        elseif held then
            level = OF.lang.t("in hand")
            r, g, b = 255, 215, 0
        end
        table.insert(rows, panel.with_help(
            panel.level_right(
                panel.label_row(panel.tick(through or held, entry.name),
                    r, g, b),
                through or held, level),
            "one of the two keys the castle locks a floor behind"))
    end

    table.insert(rows, panel.header_row(OF.lang.t("The star doors")))
    for _, entry in ipairs(ledger.DOORS) do
        local open = ledger.has_flag(entry.flag)
        local r, g, b = 200, 200, 200
        if open then r, g, b = 255, 255, 255 end
        if not open and total >= entry.needs then r, g, b = 255, 215, 0 end
        table.insert(rows, panel.with_right(
            panel.label_row(panel.tick(open, entry.name), r, g, b),
            OF.lang.fill("@ stars", entry.needs)))
    end
    table.insert(rows, panel.with_help(panel.with_right(panel.label_row(
        OF.lang.t("The endless stairs"),
        total >= ledger.STAIRS_STARS and 255 or 200,
        total >= ledger.STAIRS_STARS and 255 or 200,
        total >= ledger.STAIRS_STARS and 255 or 200),
        OF.lang.fill("@ stars", ledger.STAIRS_STARS)),
        "no tick box: the stairs keep no flag, so the count is asked every time"))

    table.insert(rows, panel.header_row(OF.lang.t("The three caps")))
    for _, entry in ipairs(ledger.CAPS) do
        local on = ledger.has_flag(entry.flag)
        table.insert(rows, panel.with_right(
            panel.label_row(panel.tick(on, entry.name),
                on and 255 or 200, on and 255 or 200, on and 255 or 200),
            entry.where))
    end
    local holder = ledger.cap_holder()
    if holder ~= nil then
        table.insert(rows, panel.with_help(panel.label_row(
            OF.lang.fill("The cap is off: @", holder), 255, 215, 0),
            "the game keeps this one to itself - the editor cannot write it"))
    end

    table.insert(rows, panel.header_row(OF.lang.t("The castle itself")))
    for _, entry in ipairs(ledger.world()) do
        table.insert(rows, panel.with_help(panel.label_row(
            panel.tick(entry.on, entry.name),
            entry.on and 255 or 200, entry.on and 255 or 200, entry.on and 255 or 200),
            entry.note))
    end

    table.insert(rows, panel.row(OF.lang.t("< Everything this file has done"),
        180, 180, 180, function() land_on("main") end))
    table.insert(rows, panel.back_row("fun"))
    return rows
end

local function build_record(panel)
    local rows = {}

    table.insert(rows, panel.label_row(OF.lang.t(
        "What has been done to this file since the lobby started.")))
    table.insert(rows, panel.label_row(OF.lang.t(
        "Kept in memory, so it goes when the lobby does. The file's own history is not written down anywhere.")))

    if #ledger.entries == 0 then
        table.insert(rows, panel.label_row(OF.lang.t(
            "Nothing has changed it this session."), 160, 255, 160))
    end

    for _, entry in ipairs(ledger.entries) do
        local text = entry.what
        if entry.cause ~= nil then
            text = OF.lang.fill("@ - @", text, entry.cause)
        end
        local help = nil
        if entry.was ~= nil and entry.now ~= nil then
            help = OF.lang.fill("@ before this, @ after", entry.was, entry.now)
        elseif entry.was ~= nil then
            help = OF.lang.fill("it was @ before this", entry.was)
        end
        table.insert(rows, panel.with_help(panel.with_right(
            panel.label_row(text, 255, 255, 255), entry.at), help))
    end

    table.insert(rows, panel.row(OF.lang.t("< Everything this file has done"),
        180, 180, 180, function() land_on("main") end))
    table.insert(rows, panel.back_row("fun"))
    return rows
end

function ledger.build_rows(panel)
    if ledger.view == nil then return nil end
    if panel == nil then return nil end
    if ledger.view == "course" then return build_course(panel) end
    if ledger.view == "locks" then return build_locks(panel) end
    if ledger.view == "record" then return build_record(panel) end
    return build_main(panel)
end

function ledger.build_entry_row(panel)
    return panel.with_help(panel.row(
        OF.lang.t("Read the save - every star by name, and what changed..."),
        255, 255, 255, function() ledger.open() end),
        "reads the file and writes nothing - everything else on this page writes")
end
