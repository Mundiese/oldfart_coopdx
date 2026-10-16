OF = OF or {}
OF.roundbrief = OF.roundbrief or {}

local brief = OF.roundbrief

brief.EVERY = 15

brief.MOST = 30

local MAIN_COURSES = 15

local held = nil
local written = nil
local frames = 0

local function own_index()
    local mod = OF.own_mod ~= nil and OF.own_mod() or nil
    if mod == nil then return nil end
    return mod.index
end

local function clip(text)
    if #text <= brief.MOST then return text end
    return string.sub(text, 1, brief.MOST - 3) .. "..."
end

local function clock(seconds)
    seconds = math.max(0, math.floor(seconds))
    local minutes = math.floor(seconds / 60)
    local rest = seconds - minutes * 60
    return string.format("%.0f:%s%.0f", minutes, rest < 10 and "0" or "", rest)
end

function brief.act_line()
    local modes = OF.gamemodes
    if modes == nil then return "" end
    if modes.state ~= nil and modes.COUNTDOWN ~= nil
        and modes.state() == modes.COUNTDOWN then
        return "about to start"
    end
    local parts = {}
    local role = modes.my_role ~= nil and modes.my_role() or ""
    if role ~= "" and role ~= modes.WAITING then table.insert(parts, role) end
    local left = modes.time_left ~= nil and modes.time_left() or nil
    if left ~= nil then table.insert(parts, clock(left) .. " left") end
    if #parts == 0 then return "the round is on" end
    return clip(table.concat(parts, " - "))
end

local function current_course()
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    local course = np ~= nil and np.currCourseNum or nil
    if type(course) ~= "number" then return nil end
    if course < 1 or course > (COURSE_MAX or 25) then return nil end
    return course
end

function brief.wanted()
    local modes = OF.gamemodes
    if modes == nil or modes.is_running == nil or not modes.is_running() then
        return nil
    end
    if not (OF.util.asks(OF.roundscope, "inside") and OF.roundscope.inside(0)) then
        return nil
    end
    local mode = modes.current ~= nil and modes.current() or nil
    if mode == nil or type(mode.name) ~= "string" then return nil end
    local course = current_course()
    if course == nil then return nil end
    return course, clip(mode.name), brief.act_line()
end

local function keep(course)
    local optional = OF.util.optional
    held = {
        course = course,
        name = optional("smlua_text_utils_course_name_get", nil, course),
        owner = optional("smlua_text_utils_course_name_mod_index", -1, course),
        acts = {},
        withActs = course <= MAIN_COURSES,
    }
    if not held.withActs then return end
    for act = 1, 6 do
        held.acts[act] = {
            name = optional("smlua_text_utils_act_name_get", nil, course, act),
            owner = optional("smlua_text_utils_act_name_mod_index", -1, course, act),
        }
    end
end

local function put_back(owner, name, write, reset, ...)
    local ours = own_index()
    if type(owner) == "number" and owner >= 0 and owner ~= ours
        and type(name) == "string" then
        local args = { ... }
        table.insert(args, name)
        OF.util.optional(write, nil, table.unpack(args))
    else
        OF.util.optional(reset, nil, ...)
    end
end

function brief.hand_back()
    if held == nil then return false end
    local course = held.course
    put_back(held.owner, held.name, "smlua_text_utils_course_name_replace",
        "smlua_text_utils_course_name_reset", course)
    for act = 1, held.withActs and 6 or 0 do
        local kept = held.acts[act]
        put_back(kept.owner, kept.name, "smlua_text_utils_act_name_replace",
            "smlua_text_utils_act_name_reset", course, act)
    end
    held, written = nil, nil
    return true
end

local function write(course, name, act)
    if held == nil then keep(course) end
    if written == nil or written.name ~= name then
        OF.util.optional("smlua_text_utils_course_name_replace", nil, course, name)
    end
    if held.withActs and (written == nil or written.act ~= act) then
        for n = 1, 6 do
            OF.util.optional("smlua_text_utils_act_name_replace", nil, course, n, act)
        end
    end
    written = { course = course, name = name, act = act }
end

function brief.update()
    local course, name, act = brief.wanted()
    if course == nil then
        brief.hand_back()
        return
    end
    if held ~= nil and held.course ~= course then brief.hand_back() end
    write(course, name, act)
end

function brief.watch()
    frames = frames + 1
    if frames < brief.EVERY then return end
    frames = 0
    brief.update()
end

function brief.original_star(course, star)
    if held == nil or held.course ~= course or not held.withActs then return nil end
    local kept = held.acts[star]
    if kept == nil or type(kept.name) ~= "string" or kept.name == "" then return nil end
    return kept.name
end

hook_event(HOOK_UPDATE, function() brief.watch() end)
