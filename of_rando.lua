OF = OF or {}
OF.rando = OF.rando or {}
local rando = OF.rando

local STORE = "ofRando"
local runSeed = nil

local drawSeed = nil

local function step_of(state)
    return (1103515245 * state + 12345) % 2147483648
end

local function stream_for(key)
    local mixed = 0
    for index = 1, #key do
        mixed = (mixed * 131 + string.byte(key, index)) % 2147483648
    end
    local state = (rando.draw_seed() * 1103515 + mixed) % 2147483648

    state = step_of(state)
    return function(bound)
        if bound == nil or bound < 1 then return 1 end
        state = step_of(state)
        return (state % bound) + 1
    end
end

local function deal_order(list, draw)
    for index = #list, 2, -1 do
        local pick = draw(index)
        list[index], list[pick] = list[pick], list[index]
    end
    return list
end

local function room_stream_for(key)
    local seed = rando.draw_seed()
    if type(seed) ~= "number" or seed <= 0 then return nil end

    local mixed = 0
    for index = 1, #key do
        mixed = (mixed * 131 + string.byte(key, index)) % 2147483648
    end

    local state = (seed * 1103515 + mixed) % 2147483648
    state = step_of(state)
    return function(bound)
        if bound == nil or bound < 1 then return 1 end
        state = step_of(state)
        return (state % bound) + 1
    end
end

local function here()
    local np = gNetworkPlayers and gNetworkPlayers[0]
    if np == nil then return nil, nil end
    return np.currLevelNum, np.currAreaIndex
end

local POOL_BEHAVIOURS = {
    "id_bhvRedCoin", "id_bhvYellowCoin", "id_bhvOneCoin",
    "id_bhvHiddenBlueCoin", "id_bhv1Up",
}

local PROBE_UP = 300

local MAX_DROP = 1200

local STAR_LIFT = 60

local SCATTER_REACH = 350
rando.SCATTER_REACH = SCATTER_REACH

local SCATTER_TRIES = 4

local function gather_pool()
    local pool = {}
    if OF.util.binding("obj_get_first_with_behavior_id") == nil then return pool end
    if OF.util.binding("obj_get_next_with_same_behavior_id") == nil then return pool end

    for _, name in ipairs(POOL_BEHAVIOURS) do

        local id = _G[name]
        if type(id) == "number" then
            local object = obj_get_first_with_behavior_id(id)
            local seen = 0

            while object ~= nil and seen < 10000 do
                seen = seen + 1
                local x, y, z = object.oPosX, object.oPosY, object.oPosZ
                if type(x) == "number" and type(y) == "number"
                    and type(z) == "number" then
                    pool[#pool + 1] = { x = x, y = y, z = z }
                end
                object = obj_get_next_with_same_behavior_id(object)
            end
        end
    end
    return pool
end

local function standable(point)
    local floor = OF.util.optional("find_floor_height", nil,
        point.x, point.y + PROBE_UP, point.z)
    if type(floor) ~= "number" then return nil end

    if point.y - floor > MAX_DROP then return nil end
    if floor > point.y + PROBE_UP then return nil end
    return floor
end

local function vetted_pool()
    local out = {}
    for _, point in ipairs(gather_pool()) do
        local floor = standable(point)
        if floor ~= nil then
            out[#out + 1] = { x = point.x, y = math.max(point.y, floor + STAR_LIFT),
                              z = point.z }
        end
    end
    return out
end

local function scatter_from(point, draw)
    local landed = nil
    for _ = 1, SCATTER_TRIES do
        local dx = draw(SCATTER_REACH * 2 + 1) - SCATTER_REACH - 1
        local dz = draw(SCATTER_REACH * 2 + 1) - SCATTER_REACH - 1

        if landed == nil then
            local try = { x = point.x + dx, y = point.y, z = point.z + dz }
            local floor = standable(try)
            if floor ~= nil then
                landed = { x = try.x, y = floor + STAR_LIFT, z = try.z }
            end
        end
    end
    return landed or point
end

local placedAt = nil

function rando.place_here(wantStars, wantCoins)
    local level, area = here()
    if level == nil then return 0 end
    if not wantStars and not wantCoins then return 0 end

    local pool = vetted_pool()
    if #pool == 0 then return 0 end

    local moved = 0

    local tag = tostring(level) .. ":" .. tostring(area)

    if wantStars and type(id_bhvStar) == "number"
        and OF.util.binding("obj_get_first_with_behavior_id") ~= nil then
        local draw = room_stream_for("star:" .. tag)
        if draw ~= nil then
            local star = obj_get_first_with_behavior_id(id_bhvStar)
            local seen = 0
            while star ~= nil and seen < 10000 do
                seen = seen + 1
                local point = pool[draw(#pool)]
                star.oPosX, star.oPosY, star.oPosZ = point.x, point.y, point.z

                star.oHomeX, star.oHomeY, star.oHomeZ = point.x, point.y, point.z
                moved = moved + 1
                star = obj_get_next_with_same_behavior_id(star)
            end
        end
    end

    if wantCoins then
        local draw = room_stream_for("coin:" .. tag)
        if draw ~= nil then
            local places = {}
            for index, point in ipairs(pool) do places[index] = point end
            deal_order(places, draw)

            local at = 0
            for _, name in ipairs(POOL_BEHAVIOURS) do
                local id = _G[name]
                if type(id) == "number" then
                    local object = obj_get_first_with_behavior_id(id)
                    local seen = 0
                    while object ~= nil and seen < 10000 do
                        seen = seen + 1
                        at = at + 1
                        local point = scatter_from(
                            places[((at - 1) % #places) + 1], draw)
                        object.oPosX, object.oPosY, object.oPosZ =
                            point.x, point.y, point.z
                        object.oHomeX, object.oHomeY, object.oHomeZ =
                            point.x, point.y, point.z
                        moved = moved + 1
                        object = obj_get_next_with_same_behavior_id(object)
                    end
                end
            end
        end
    end

    placedAt = tag
    return moved
end

local doorsAt = nil

function rando.shuffle_doors_here()
    local level, area = here()
    if level == nil then return 0 end

    local id = _G["id_bhvDoorWarp"]
    if type(id) ~= "number" then return 0 end
    if OF.util.binding("obj_get_first_with_behavior_id") == nil then return 0 end
    if OF.util.binding("obj_get_next_with_same_behavior_id") == nil then return 0 end

    if OF.util.asks(OF.offlimits, "level_closed")
        and OF.offlimits.level_closed(level) then
        return 0
    end

    local doors, nodes = {}, {}
    local door = obj_get_first_with_behavior_id(id)
    local seen = 0

    while door ~= nil and seen < 10000 do
        seen = seen + 1
        local params = door.oBehParams
        if type(params) == "number" then
            doors[#doors + 1] = door

            nodes[#nodes + 1] = math.floor(params / 65536) % 256
        end
        door = obj_get_next_with_same_behavior_id(door)
    end

    if #doors < 2 then return 0 end

    local draw = room_stream_for("door:" .. tostring(level) .. ":" .. tostring(area))
    if draw == nil then return 0 end
    deal_order(nodes, draw)

    for index, one in ipairs(doors) do
        local params = one.oBehParams
        local was = math.floor(params / 65536) % 256
        one.oBehParams = params - was * 65536 + nodes[index] * 65536

        one.oBehParams2ndByte = nodes[index]
    end

    doorsAt = tostring(level) .. ":" .. tostring(area)
    return #doors
end

local function draw_hand(count)
    if not OF.util.asks(OF.modifiers, "set_text") then return false end
    if not OF.util.asks(OF.modifiers, "pack") then return false end

    local pool = {}
    for _, entry in ipairs(OF.modifiers.LIST or {}) do
        for level = 1, OF.modifiers.step_count(entry) do
            table.insert(pool, { key = entry.key, id = entry.id, level = level })
        end
    end
    if OF.util.asks(OF.offlimits, "keep") then
        pool = OF.offlimits.keep("mod", pool, "id", "level")
    end

    local draw = stream_for("hand")
    local set = {}
    local anomalies = 0
    local cap = OF.util.asks(OF.chaos, "anomaly_cap") and OF.chaos.anomaly_cap() or 1
    local taken = 0

    local attempts = math.min(#pool, count * 4)
    for _ = 1, attempts do
        if taken >= count or #pool == 0 then break end
        local at = draw(#pool)
        local pick = pool[at]
        table.remove(pool, at)

        local anomaly = OF.util.asks(OF.chaos, "is_anomaly")
            and OF.chaos.is_anomaly(pick.key)
        if (not anomaly or anomalies < cap) and set[pick.key] == nil then
            if anomaly then anomalies = anomalies + 1 end
            set[pick.key] = pick.level
            taken = taken + 1
            local entry = OF.modifiers.BY_KEY[pick.key]
            for _, other in ipairs(entry ~= nil and entry.excludes or {}) do
                set[other] = nil
            end
        end
    end

    if taken == 0 then return false end
    return OF.modifiers.set_text(OF.modifiers.pack(set))
end

local function deal_queue(how)
    if not OF.util.asks(OF.rounds, "clear") then return false end
    if how == "order" and OF.util.asks(OF.rounds, "fill_with_everything") then
        return OF.rounds.fill_with_everything(nil, "")
    end

    local playable = {}
    for _, mode in ipairs(OF.gamemodes.LIST or {}) do

        if OF.gamemodes.can_start_here(mode) then
            table.insert(playable, mode.key)
        end
    end
    if #playable == 0 then return false end

    deal_order(playable, stream_for("queue"))
    if how == "six" then
        while #playable > 6 do table.remove(playable) end
    end

    if not OF.rounds.clear() then return false end
    local added = 0
    for _, key in ipairs(playable) do
        if OF.rounds.add(key, nil, "") then added = added + 1 end
    end
    return added > 0
end

function rando.handout_pool()
    local pool = {}
    for _, row in ipairs(OF.powerups.LIST or {}) do
        if row.kind == "good" and row.group ~= "Wild" then
            pool[#pool + 1] = row.key
        end
    end
    return pool
end

rando.SECTIONS = {

    { name = "The way in",    keys = { "entrances", "doorways" },
      help = "where the castle's paintings and its doors come out" },
    { name = "The world",     keys = { "world", "enemies", "sky" },
      help = "the level once you are inside it - what stands in it, what lives "
          .. "there and what is overhead" },
    { name = "The save file", keys = { "stars", "doors", "caps" },
      help = "what the host's own file says has been done already, and it is "
          .. "written for real" },

    { name = "The wardrobe", keys = { "outfit", "hats" },
      help = "what every player is dressed as, drawn from the run's own seed" },

    { name = "The soundtrack", keys = { "music" },
      help = "the track the lobby plays under, drawn from the run's own seed" },

    { name = "What the lobby wears", keys = { "hand" },
      help = "the settings and the modifiers the run opens under - not "
          .. "clothes" },

    { name = "Everybody in it", keys = { "handout" },
      help = "what each player starts holding, and how fast they move" },
    { name = "The session",   keys = { "queue" },
      help = "the order the rounds are lined up in for the session" },
}

rando.KNOBS = {
    {
        key = "stars",
        name = "Stars to begin with",
        blurb = "the host's real save file - there is no backup",
        choices = {
            { value = "keep", name = "Leave the file alone" },
            { value = "none", name = "Wipe to zero" },
            { value = "all",  name = "Every one" },
        },
        apply = function(value)
            if value == "keep" then return true end
            if not OF.util.asks(OF.save, "set_all_stars") then return false end
            return OF.save.set_all_stars(value == "all")
        end,
    },
    {
        key = "doors",
        name = "Castle doors",
        blurb = "applied after the stars, which write these themselves",
        choices = {
            { value = "keep", name = "As the file has them" },
            { value = "open", name = "All unlocked" },
            { value = "shut", name = "All locked" },
        },
        apply = function(value)
            if value == "keep" then return true end
            if not OF.util.asks(OF.save, "set_flags") then return false end
            return OF.save.set_flags(OF.save.DOOR_FLAGS, value == "open")
        end,
    },
    {
        key = "caps",
        name = "Cap switches",
        blurb = "the three coloured switches, on or off together",
        choices = {
            { value = "keep", name = "As the file has them" },
            { value = "on",   name = "All pressed" },
            { value = "off",  name = "All unpressed" },
        },
        apply = function(value)
            if value == "keep" then return true end
            if not OF.util.asks(OF.save, "set_flags") then return false end
            return OF.save.set_flags(OF.save.CAP_FLAGS, value == "on")
        end,
    },

    {
        key = "world",
        name = "Where the stars and coins stand",
        blurb = "stars take another place the level authored; coins scatter"
            .. " around one, on ground they can be picked up from",
        choices = {
            { value = "keep",  name = "As the game placed them" },
            { value = "stars", name = "Stars move",           stars = true },
            { value = "coins", name = "Stars and coins move", stars = true, coins = true },
        },

        apply = function(value, choice)
            if value == "keep" then return true end
            rando.place_here(choice.stars, choice.coins)
            return true
        end,
    },

    {
        key = "entrances",
        name = "Where the entrances lead",
        blurb = "draws the castle's number, so every painting and door moves",
        choices = {
            { value = "keep",  name = "As the castle has them" },
            { value = "drawn", name = "A drawn castle" },

            { value = "off",   name = "Put the castle back" },

            { value = "never", name = "A castle that never settles" },
        },
        apply = function(value)
            if value == "keep" then return true end

            if value == "off" then
                if not OF.util.asks(OF.shuffle, "off") then return false end
                return OF.shuffle.off()
            end
            if not OF.util.asks(OF.shuffle, "roll") then return false end

            local open = 0
            for _, course in ipairs(OF.COURSES or {}) do
                if not OF.util.asks(OF.offlimits, "allows")
                    or OF.offlimits.allows("level", tostring(course.num)) then
                    open = open + 1
                end
            end
            if open < 2 then return false end

            local draw = stream_for("entrances")
            local ok, why = OF.shuffle.roll(draw(9000) + 999)
            if not ok then return ok, why end
            if value ~= "never" then return true end

            if not OF.util.asks(OF.shuffle, "drift") then return false end
            return OF.shuffle.drift(true)
        end,
    },

    {
        key = "doorways",
        name = "Where the castle's doors lead",
        blurb = "the castle's warp doors - no other level in the game has one",
        choices = {
            { value = "keep",  name = "As the castle has them" },
            { value = "drawn", name = "Drawn, door by door" },
        },
        apply = function(value)
            if value == "keep" then return true end

            rando.shuffle_doors_here()
            return true
        end,
    },

    {
        key = "sky",
        name = "The sky over the whole run",
        blurb = "one of the engine's ten, drawn - through the modifier that owns it",
        choices = {
            { value = "keep",  name = "Each level's own" },
            { value = "drawn", name = "A drawn sky" },
        },
        apply = function(value)
            if value == "keep" then return true end
            if not OF.util.asks(OF.modifiers, "set_level") then return false end
            if not OF.util.asks(OF.modifiers, "step_count") then return false end

            local entry = nil
            for _, mod in ipairs(OF.modifiers.LIST or {}) do
                if mod.key == "night" then entry = mod end
            end
            if entry == nil then return false end

            local steps = OF.modifiers.step_count(entry)
            if steps == nil or steps < 1 then return false end
            local draw = stream_for("sky")
            return OF.modifiers.set_level("night", draw(steps))
        end,
    },

    {
        key = "outfit",
        name = "What everybody wears",
        blurb = "drawn from the run's seed, so a shared code dresses the lobby twice",
        choices = {
            { value = "keep", name = "Everybody's own choice" },
            { value = "same", name = "One drawn face, all of us" },
            { value = "each", name = "A drawn face each" },
        },
        apply = function(value)
            if value == "keep" then return true end
            if not OF.util.asks(OF.costumes, "set") then return false end
            local list = OF.costumes.LIST or {}
            if #list == 0 then return false end

            local draw = stream_for("outfit")
            local one = list[draw(#list)]
            local any = false
            for index = 0, MAX_PLAYERS - 1 do
                local np = gNetworkPlayers and gNetworkPlayers[index]
                if np ~= nil and np.connected then
                    local pick = (value == "same") and one or list[draw(#list)]
                    if pick ~= nil and OF.costumes.set(index, pick.key) then
                        any = true
                    end
                end
            end
            return any
        end,
    },

    {
        key = "hats",
        name = "What everybody has on their head",
        blurb = "drawn from the run's seed, the same way the faces are",
        choices = {
            { value = "keep", name = "Everybody's own choice" },
            { value = "same", name = "One drawn hat, all of us" },
            { value = "each", name = "A drawn hat each" },
        },
        apply = function(value)
            if value == "keep" then return true end
            if not OF.util.asks(OF.hats, "set") then return false end
            local list = OF.hats.LIST or {}
            if #list == 0 then return false end

            local draw = stream_for("hats")
            local one = list[draw(#list)]
            local any = false
            for index = 0, MAX_PLAYERS - 1 do
                local np = gNetworkPlayers and gNetworkPlayers[index]
                if np ~= nil and np.connected then
                    local pick = (value == "same") and one or list[draw(#list)]
                    if pick ~= nil and OF.hats.set(index, pick.key) then
                        any = true
                    end
                end
            end
            return any
        end,
    },

    {
        key = "music",
        name = "What the lobby hears",
        blurb = "one track, drawn - the lobby's own row still sets a chosen one",
        choices = {
            { value = "keep",    name = "As the lobby has it" },
            { value = "courses", name = "A drawn course track", group = "COURSES" },
            { value = "any",     name = "A drawn track, any of them" },
        },
        apply = function(value, choice)
            if value == "keep" then return true end
            if not OF.util.asks(OF.music, "set_lobby") then return false end
            local want = choice.group ~= nil and OF.music[choice.group] or nil

            local pool = {}
            for _, track in ipairs(OF.music.TRACKS or {}) do
                if want == nil or track.group == want then
                    pool[#pool + 1] = track
                end
            end
            if #pool == 0 then return false end

            local draw = stream_for("music")
            return OF.music.set_lobby(pool[draw(#pool)].seq)
        end,
    },

    {
        key = "hand",
        name = "Modifiers to open with",
        blurb = "drawn from the run's own seed, so a shared code deals it twice",
        choices = {
            { value = "none",  name = "None" },
            { value = "two",   name = "Two, drawn",  count = 2 },
            { value = "four",  name = "Four, drawn", count = 4 },
            { value = "six",   name = "Six, drawn",  count = 6 },
        },
        apply = function(value, choice)
            return draw_hand(choice.count or 0)
        end,
    },

    {
        key = "handout",
        name = "What everybody starts with",
        blurb = "one handout apiece, drawn from the run's own seed",
        choices = {
            { value = "none", name = "Nothing" },
            { value = "same", name = "One drawn handout, all of us" },
            { value = "each", name = "A drawn handout each" },
        },
        apply = function(value)
            if value == "none" then return true end
            if not OF.util.asks(OF.powerups, "give") then return false end

            local pool = rando.handout_pool()
            if #pool == 0 then return false end

            local draw = stream_for("handout")
            local one = pool[draw(#pool)]
            local any = false
            for index = 0, MAX_PLAYERS - 1 do
                local np = gNetworkPlayers and gNetworkPlayers[index]
                if np ~= nil and np.connected then
                    local pick = (value == "same") and one or pool[draw(#pool)]
                    if OF.powerups.give(np.globalIndex, pick) then any = true end
                end
            end
            return any
        end,
    },

    {
        key = "queue",
        name = "The session's plan",
        blurb = "lines the round queue up, in an order the seed decides",
        choices = {
            { value = "keep",  name = "Leave the queue alone" },
            { value = "order", name = "Every mode, menu order" },
            { value = "all",   name = "Every mode, drawn order" },
            { value = "six",   name = "Six modes, drawn" },
        },
        apply = function(value)
            return deal_queue(value)
        end,
    },

    {
        key = "enemies",
        name = "What the level's enemies are",
        blurb = "a drawn creature for the whole run - a dress, so every course"
            .. " is still finishable",
        choices = {
            { value = "keep",   name = "The course's own" },
            { value = "dress",  name = "One drawn creature, everywhere" },
            { value = "temper", name = "A drawn creature, in a drawn temper",
              temper = true },
        },
        apply = function(value, choice)
            if value == "keep" then return true end
            if not OF.util.asks(OF.enemies, "set_step") then return false end
            local rows = OF.enemies.BY_KEY or {}

            local dress = rows.dress
            local steps = dress ~= nil and dress.steps or nil
            if steps == nil or #steps < 2 then return false end

            local draw = stream_for("enemies")

            if not OF.enemies.set_step("dress", draw(#steps - 1) + 1, true) then
                return false
            end
            if not choice.temper then return true end

            local temper = rows.temper
            local moods = temper ~= nil and temper.steps or nil
            if moods == nil or #moods < 2 then return true end

            OF.enemies.set_step("temper", draw(#moods), true)
            return true
        end,
    },
}

function rando.knob(key)
    for _, entry in ipairs(rando.KNOBS) do
        if entry.key == key then return entry end
    end
    return nil
end

function rando.default(key)
    local knob = rando.knob(key)
    if knob == nil then return nil end
    return knob.choices[1].value
end

function rando.choice(key)
    local knob = rando.knob(key)
    if knob == nil then return nil end

    local stored = OF.util.optional("mod_storage_load", "",
        STORE .. "." .. key, "")
    for _, choice in ipairs(knob.choices) do
        if choice.value == stored then return stored end
    end
    return knob.choices[1].value
end

function rando.choice_row(key)
    local knob = rando.knob(key)
    if knob == nil then return nil end
    local want = rando.choice(key)
    for _, choice in ipairs(knob.choices) do
        if choice.value == want then return choice end
    end
    return knob.choices[1]
end

function rando.set(key, value)
    local knob = rando.knob(key)
    if knob == nil then return false, "No such setting." end
    for _, choice in ipairs(knob.choices) do
        if choice.value == value then
            return OF.util.store(STORE .. "." .. key, value)
        end
    end
    return false, "No such setting."
end

function rando.cycle(key)
    local knob = rando.knob(key)
    if knob == nil then return false, "No such setting." end
    local want = rando.choice(key)
    for index, choice in ipairs(knob.choices) do
        if choice.value == want then
            local nextOne = knob.choices[index + 1] or knob.choices[1]
            return rando.set(key, nextOne.value)
        end
    end
    return rando.set(key, knob.choices[1].value)
end

function rando.reset()
    local any = false
    for _, knob in ipairs(rando.KNOBS) do
        if rando.set(knob.key, knob.choices[1].value) then any = true end
    end
    runSeed = nil
    drawSeed = nil

    OF.util.store(STORE .. ".draw", "")

    OF.util.store(STORE .. ".room", "")
    return any
end

rando.PAGE_KEEPS = {
    stars = true, doors = true, caps = true,
}

function rando.draw_the_page()

    drawSeed = nil
    OF.util.store(STORE .. ".draw", "")
    rando.draw_seed()

    local draw = stream_for("thepage")
    local moved, first = 0, nil
    for _, knob in ipairs(rando.KNOBS) do
        if not rando.PAGE_KEEPS[knob.key] and #knob.choices > 1 then
            if first == nil then first = knob end
            local pick = knob.choices[draw(#knob.choices)]
            if pick ~= nil then
                rando.set(knob.key, pick.value)
                if pick.value ~= knob.choices[1].value then moved = moved + 1 end
            end
        end
    end

    if moved == 0 and first ~= nil then
        local pick = first.choices[draw(#first.choices - 1) + 1]
        if pick ~= nil then
            rando.set(first.key, pick.value)
            moved = 1
        end
    end
    if moved == 0 then return false, "Nothing on this page can be drawn." end
    return true
end

function rando.summary()
    local lines = {}
    for _, knob in ipairs(rando.KNOBS) do
        local choice = rando.choice_row(knob.key)
        if choice ~= nil and choice.value ~= knob.choices[1].value then
            lines[#lines + 1] = knob.name .. ": " .. choice.name
        end
    end
    return lines
end

local APPLY_ORDER = {
    "stars", "doors", "caps",
    "hand",
    "outfit", "hats", "music",
    "entrances", "doorways", "world", "enemies", "sky",
    "handout",
    "queue",
}

function rando.roll()
    if not OF.util.is_host() then
        return false, OF.lang.t("The host sets up the run.")
    end

    if not OF.perms.can("save_edit") then
        return false, OF.lang.t("That is above your rank.")
    end

    local done, refused = 0, {}
    for _, key in ipairs(APPLY_ORDER) do
        local knob = rando.knob(key)
        if knob ~= nil then
            local choice = rando.choice_row(key)

            if choice ~= nil and choice.value ~= knob.choices[1].value then
                local ok = knob.apply(choice.value, choice)
                if ok then
                    done = done + 1
                else
                    refused[#refused + 1] = knob.name
                end
            end
        end
    end

    if done == 0 and #refused == 0 then
        return false, OF.lang.t("Nothing is set to change.")
    end
    if #refused > 0 then
        return false, OF.lang.fill("@ of the run could not be set up",
            table.concat(refused, ", "))
    end

    OF.actionlog.by_hand(OF.util.presser(0),
        OF.lang.fill("set up a seeded run: castle @, draw @",
            tostring(rando.seed()), tostring(rando.draw_seed())))
    return true
end

rando.CODE_PREFIX = "OFR"
rando.CODE_MARK = "5"
function rando.seed()
    if runSeed ~= nil and runSeed > 0 then return runSeed end
    if OF.util.asks(OF.shuffle, "seed") then return OF.shuffle.seed() end
    return 0
end

function rando.draw_seed()
    if drawSeed == nil then
        local kept = tonumber(OF.util.optional("mod_storage_load", "",
            STORE .. ".draw", ""))
        if type(kept) == "number" and kept > 0 then drawSeed = math.floor(kept) end
    end
    if drawSeed ~= nil and drawSeed > 0 then return drawSeed end
    local now = (OF.util.optional("get_time", 0) or 0)
        + math.floor(((OF.util.optional("get_global_timer", 0) or 0)) % 100000)
    drawSeed = (step_of(now) % 9000) + 1000
    OF.util.store(STORE .. ".draw", tostring(drawSeed))
    return drawSeed
end

local function checksum(body)
    local total = 0
    for index = 1, #body do
        total = total + string.byte(body, index) * index
    end
    return OF.rules.to36(total % 36, 1)
end

function rando.code()
    local body = rando.CODE_MARK
    for _, knob in ipairs(rando.KNOBS) do
        local want = rando.choice(knob.key)
        local at = 1
        for index, choice in ipairs(knob.choices) do
            if choice.value == want then at = index end
        end
        body = body .. OF.rules.to36(at, 1)
    end

    body = body .. "-" .. OF.rules.to36(rando.seed(), 3)
        .. "-" .. OF.rules.to36(rando.draw_seed(), 3)

    return string.lower(rando.CODE_PREFIX .. "-" .. body .. "-" .. checksum(body))
end

function rando.read_code(code)
    if type(code) ~= "string" then return nil, "That is not a run code." end
    code = string.lower(string.gsub(code, "%s", ""))
    if code == "" then return nil, "Say a code after it." end

    local body, given = string.match(code,
        "^" .. string.lower(rando.CODE_PREFIX) .. "%-(.-)%-(%w)$")
    if body == nil then return nil, "That is not a run code." end
    if checksum(body) ~= given then return nil, "That code has a typo in it." end

    local parts = {}
    for piece in string.gmatch(body .. "-", "(.-)%-") do
        parts[#parts + 1] = piece
    end
    if #parts < 3 then return nil, "That code is the wrong shape." end

    local digits, seedText, drawText = parts[1], parts[2], parts[3]

    if #digits ~= #rando.KNOBS + 1
        or string.sub(digits, 1, 1) ~= string.lower(rando.CODE_MARK) then
        return nil, "That code is from an earlier build."
    end

    local picked = {}
    for index, knob in ipairs(rando.KNOBS) do
        local at = OF.rules.from36(string.sub(digits, index + 1, index + 1))
        local choice = knob.choices[at]

        if choice == nil then
            return nil, "That code is from a different build."
        end
        picked[knob.key] = choice.value
    end
    return picked, OF.rules.from36(seedText), OF.rules.from36(drawText)
end

function rando.use_code(code)
    local picked, seedOrWhy, drawn = rando.read_code(code)
    if picked == nil then return false, seedOrWhy end
    for key, value in pairs(picked) do rando.set(key, value) end
    runSeed = (type(seedOrWhy) == "number" and seedOrWhy > 0) and seedOrWhy or nil

    drawSeed = (type(drawn) == "number" and drawn > 0) and drawn or nil

    OF.util.store(STORE .. ".draw", drawSeed ~= nil and tostring(drawSeed) or "")
    return true
end

function rando.build_page(panel)
    local rows = {}

    rows[#rows + 1] = panel.label_row(OF.lang.t(
        "Everything here is drawn by the run. Chosen settings live on their own pages."))

    local function knob_rows(knob)
        local choice = rando.choice_row(knob.key)
        local key = knob.key
        local drawn = choice ~= nil and choice ~= knob.choices[1]
        local built = panel.gated_row("save_edit",
            panel.tick(drawn, OF.lang.t(knob.name)),
            255, 255, 255, function()
                OF.util.report(rando.cycle(key))
            end)

        built = panel.level_right(built, drawn,
            choice ~= nil and OF.lang.t(choice.name) or nil)
        if knob.blurb ~= nil then
            built = panel.with_help(built, OF.lang.t(knob.blurb))
        end
        rows[#rows + 1] = built
    end

    local placed = {}
    for _, section in ipairs(rando.SECTIONS) do
        local mine = {}
        for _, key in ipairs(section.keys) do
            local knob = rando.knob(key)
            if knob ~= nil then table.insert(mine, knob) end
        end
        if #mine > 0 then

            rows[#rows + 1] = panel.with_help(
                panel.header_row(OF.lang.t(section.name)), section.help)
            for _, knob in ipairs(mine) do
                placed[knob.key] = true
                knob_rows(knob)
            end
        end
    end

    local rest = {}
    for _, knob in ipairs(rando.KNOBS) do
        if not placed[knob.key] then table.insert(rest, knob) end
    end
    if #rest > 0 then
        rows[#rows + 1] = panel.header_row(OF.lang.t("Everything else"))
        for _, knob in ipairs(rest) do knob_rows(knob) end
    end

    if rando.choice("world") ~= "keep" or rando.choice("doorways") ~= "keep" then
        rows[#rows + 1] = panel.label_row(OF.lang.t(
            "Everybody must type the run code below, or only you see it."))
    end

    rows[#rows + 1] = panel.header_row(OF.lang.t("Draw the page itself"))

    rows[#rows + 1] = panel.with_help(panel.gated_row("save_edit",
        OF.lang.t("Draw every setting on this page"),
        180, 220, 255, function()
            OF.util.report(rando.draw_the_page())
        end),
        OF.lang.t("a new draw number fills every row above in - nothing is"
            .. " written to the save file or the lobby yet"))

    rows[#rows + 1] = panel.header_row(OF.lang.t("Start it"))

    local lines = rando.summary()
    if #lines == 0 then
        rows[#rows + 1] = panel.label_row(OF.lang.t(
            "Everything is on its default, so this would change nothing."))
    else
        for _, line in ipairs(lines) do
            rows[#rows + 1] = panel.label_row(line)
        end
    end

    rows[#rows + 1] = panel.with_help(panel.gated_row("save_edit",
        OF.lang.t("Set the run up now"),
        255, 220, 120, function()
            local ok, why = rando.roll()
            OF.util.report(ok, why)
            if ok and OF.util.asks(OF.notify, "show") then
                OF.notify.show("The run is set up.", "info", 4)
            end
        end),
        OF.lang.t("applies every ticked row above - the save file is written"))
    rows[#rows + 1] = panel.with_help(panel.gated_row("save_edit",
        OF.lang.t("Put every setting back"),
        200, 200, 200, function() OF.util.report(rando.reset()) end),
        OF.lang.t("unticks every row here - what a run already did stays done"))

    rows[#rows + 1] = panel.header_row(OF.lang.t("Hand this run on"))

    local code = panel.label_row(rando.code())
    code.walk = true
    rows[#rows + 1] = panel.with_help(code,
        OF.lang.t("type /rando use and that code to play the same run"))

    local plain = panel.label_row(OF.lang.fill("Castle @, draw @",
        tostring(rando.seed()), tostring(rando.draw_seed())))
    plain.walk = true
    rows[#rows + 1] = panel.with_help(plain,
        OF.lang.t("the code above in plain numbers, for reading out loud"))

    rows[#rows + 1] = panel.back_row("fun")
    return rows
end

function rando.chat(msg)
        local text = string.lower(tostring(msg or ""))

        if text == "" or text == "code" then
            OF.util.chat(OF.util.accent() .. rando.code())
            OF.util.chat(OF.lang.t("Hand that to somebody and you play the same run."))
            return true
        end

        local given = string.match(text, "^use%s+(.+)$")
        if given ~= nil then

            local ok, why = rando.use_code(given)
            if not ok then return true, why end
            OF.util.chat(OF.lang.t("Run loaded. Open Fun to see it, or set it up now."))
            return true
        end

        if text == "draw" or text == "surprise" then
            if OF.util.report(rando.draw_the_page()) then
                OF.util.chat(OF.lang.fill("Page drawn. Draw @ - open Fun to read it.",
                    tostring(rando.draw_seed())))
            end
            return true
        end

        if text == "start" or text == "go" or text == "roll" then
            if OF.util.report(rando.roll()) then
                OF.util.chat(OF.lang.fill("The run is set up. Castle @, draw @.",
                    tostring(rando.seed()), tostring(rando.draw_seed())))
            end
            return true
        end

        return true, OF.lang.t("Say 'draw', 'start', 'code', or 'use' and a code.")
end

hook_chat_command("rando",
    "- draw a whole run with 'draw', start it with 'start', hand it on with 'code', play one with 'use <code>'",
    function(msg) return rando.chat(msg) end)
hook_chat_command("randomize",
    "- draw a whole run with 'draw', start it with 'start', hand it on with 'code', play one with 'use <code>'",
    function(msg) return rando.chat(msg) end)
hook_chat_command("randomizer",
    "- draw a whole run with 'draw', start it with 'start', hand it on with 'code', play one with 'use <code>'",
    function(msg) return rando.chat(msg) end)

local settle = 0
local SETTLE_FRAMES = 20

hook_event(HOOK_ON_LEVEL_INIT, function()
    settle = SETTLE_FRAMES
    placedAt = nil
    doorsAt = nil
end)

hook_event(HOOK_UPDATE, function()
    if settle <= 0 then return end
    settle = settle - 1
    if settle > 0 then return end

    local level, area = here()
    if level == nil then return end
    local tag = tostring(level) .. ":" .. tostring(area)

    local choice = rando.choice_row("world")
    if choice ~= nil and choice.value ~= "keep" and placedAt ~= tag then
        rando.place_here(choice.stars, choice.coins)
    end

    if rando.choice("doorways") ~= "keep" and doorsAt ~= tag then
        rando.shuffle_doors_here()
    end
end)
