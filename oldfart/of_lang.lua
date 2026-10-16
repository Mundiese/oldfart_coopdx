OF = OF or {}
OF.lang = OF.lang or {}

local lang = OF.lang

function lang.game_language()
    if smlua_text_utils_get_language == nil then return "English" end
    local ok, name = pcall(smlua_text_utils_get_language)
    if not ok or type(name) ~= "string" or name == "" then return "English" end
    return name
end

lang.MENU_LANGUAGE = "English"
function lang.current()
    return lang.MENU_LANGUAGE
end

lang.STRINGS = {}

function lang.get(english)
    if type(english) ~= "string" then return english end
    local table_ = lang.STRINGS[lang.current()]
    if table_ == nil then return english end
    local translated = table_[english]
    if type(translated) ~= "string" or translated == "" then return english end
    return translated
end

function lang.t(english)
    return lang.get(english)
end

local function safe(value)
    if type(value) == "number" and value == math.floor(value) then
        return string.format("%.0f", value)
    end
    return tostring(value)
end

local WHITE = "\\#FFFFFF\\"
local ANY_ESCAPE = "\\" .. "#%x*" .. "\\"
local function closed(value)
    local last, at = nil, 1
    while true do
        local from, to = string.find(value, ANY_ESCAPE, at)
        if from == nil then break end
        last = string.sub(value, from, to)
        at = to + 1
    end
    if last == nil or string.upper(last) == WHITE then return value end
    return value .. WHITE
end

function lang.fill(english, first, second)
    local text = lang.get(english)

    local values = {}
    if first ~= nil then values[#values + 1] = first end
    if second ~= nil then values[#values + 1] = second end
    if #values == 0 then return text end

    local at = 0
    local filled = string.gsub(text, "@", function()
        at = at + 1
        if at > #values then return "@" end
        return closed(safe(lang.get(values[at])))
    end, #values)
    return filled
end

function lang.holes(english)
    if type(english) ~= "string" then return 0 end
    local n = 0
    for _ in string.gmatch(english, "@") do n = n + 1 end
    return n
end

function lang.count(name)
    local table_ = lang.STRINGS[name or "German"]
    if table_ == nil then return 0 end
    local n = 0
    for _ in pairs(table_) do n = n + 1 end
    return n
end

function lang.plural(n, one, many)
    local value = tonumber(n) or 0
    local english = (value == 1 or many == nil) and one or many
    if type(english) ~= "string" then return "" end
    return lang.fill(english, tostring(n))
end
