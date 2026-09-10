OF = OF or {}
OF.offlimits = OF.offlimits or {}

local offlimits = OF.offlimits

offlimits.KEY = "ofOffLimits"
local STORE_KEY = "offlimits"
offlimits.MAX = 60

offlimits.KINDS = offlimits.KINDS or {}
local BY_KIND = {}
local BY_ID = {}

function offlimits.register(def)
    if type(def) ~= "table" then return false end
    if type(def.kind) ~= "string" or def.kind == "" then return false end
    if type(def.id) ~= "string" or #def.id ~= 1 then return false end

    local sitting = BY_ID[def.id]
    if sitting ~= nil and sitting.kind ~= def.kind then return false end

    if BY_KIND[def.kind] ~= nil then
        for index, entry in ipairs(offlimits.KINDS) do
            if entry.kind == def.kind then offlimits.KINDS[index] = def end
        end
    else
        table.insert(offlimits.KINDS, def)
    end
    BY_KIND[def.kind] = def
    BY_ID[def.id] = def
    return true
end

function offlimits.kind(name)
    return BY_KIND[name]
end

function offlimits.covers()
    local said = {}
    for _, def in ipairs(offlimits.KINDS) do
        local name = OF.lang.t(def.name or def.kind)
        said[#said + 1] = string.lower(name)
    end
    if #said == 0 then return nil end
    if #said == 1 then return said[1] end
    local last = table.remove(said)
    return table.concat(said, ", ") .. " and " .. last
end

function offlimits.token(kind, id, level)
    local def = BY_KIND[kind]
    if def == nil or id == nil then return nil end
    local token = def.id .. tostring(id)
    if level ~= nil and level ~= "" then token = token .. "=" .. tostring(level) end
    return token
end

local cachedFrom = nil
local cachedSet = nil

local function current()
    local packed = gGlobalSyncTable[offlimits.KEY]
    if type(packed) ~= "string" or packed == "" then return nil end
    if packed ~= cachedFrom then
        local set = {}
        for token in string.gmatch(packed, "[^,]+") do set[token] = true end
        cachedFrom = packed
        cachedSet = set
    end
    return cachedSet
end

function offlimits.tokens()
    local list = {}
    local packed = gGlobalSyncTable[offlimits.KEY]
    if type(packed) ~= "string" or packed == "" then return list end
    for token in string.gmatch(packed, "[^,]+") do table.insert(list, token) end
    return list
end

function offlimits.count()
    return #offlimits.tokens()
end

function offlimits.has(token)
    local off = current()
    return off ~= nil and token ~= nil and off[token] == true
end

function offlimits.allows(kind, id, level)
    local off = current()
    if off == nil then return true end
    local def = BY_KIND[kind]
    if def == nil or id == nil then return true end

    local token = def.id .. tostring(id)
    if off[token] then return false end
    if level ~= nil and off[token .. "=" .. tostring(level)] then return false end
    return true
end

local function reader(what)
    if type(what) == "function" then return what end
    if type(what) == "string" then
        return function(entry) return entry ~= nil and entry[what] or nil end
    end
    return nil
end

function offlimits.keep(kind, list, idof, levelof)
    if type(list) ~= "table" then return list, 0 end
    if current() == nil then return list, 0 end
    if BY_KIND[kind] == nil then return list, 0 end

    local readId = reader(idof)
    local readLevel = reader(levelof)
    if readId == nil then return list, 0 end

    local kept = {}
    local dropped = 0
    for _, entry in ipairs(list) do
        local level = readLevel ~= nil and readLevel(entry) or nil
        if offlimits.allows(kind, readId(entry), level) then
            table.insert(kept, entry)
        else
            dropped = dropped + 1
        end
    end
    return kept, dropped
end

function offlimits.describe(token)
    if type(token) ~= "string" or token == "" then return "" end

    local def = BY_ID[string.sub(token, 1, 1)]
    if def == nil then return token end

    local rest = string.sub(token, 2)
    local id, level = string.match(rest, "^(.-)=(%d+)$")
    if id == nil then id = rest end

    local name, levelName = id, nil
    if type(def.items) == "function" then
        local ok, items = pcall(def.items)
        if ok and type(items) == "table" then
            for _, item in ipairs(items) do
                if tostring(item.id) == id then
                    name = tostring(item.name or id)
                    if level ~= nil and type(item.levels) == "table" then
                        levelName = item.levels[tonumber(level)]
                    end
                end
            end
        end
    end

    if level == nil then return name end
    if levelName ~= nil then
        return OF.lang.fill("@ - @", name, tostring(levelName))
    end
    return OF.lang.fill("@ - setting @", name, tostring(level))
end

local function may_write()
    if not OF.perms.can("settings") then
        return false, "Your rank cannot do that.", "settings"
    end
    if not OF.util.is_host() then
        return false, "Only the host can change what is off limits."
    end
    return true
end

local function publish(list)
    local packed = table.concat(list, ",")
    OF.util.publish(offlimits.KEY, packed)
    OF.util.store(STORE_KEY, packed)
end

function offlimits.add_token(token)
    local ok, why = may_write()
    if not ok then return false, why end
    if type(token) ~= "string" or token == "" then
        return false, "Say what should be off limits."
    end
    if BY_ID[string.sub(token, 1, 1)] == nil then
        return false, "Nothing in this lobby rolls that."
    end
    if offlimits.has(token) then return false, "That is already off limits." end

    local list = offlimits.tokens()
    if #list >= offlimits.MAX then
        return false, "The list is full."
    end

    table.insert(list, token)

    if #table.concat(list, ",") > OF.util.publish_limit() then
        return false, "The list is as long as it can be sent."
    end

    publish(list)
    return true
end

function offlimits.add(kind, id, level)
    local token = offlimits.token(kind, id, level)
    if token == nil then return false, "Nothing in this lobby rolls that." end
    return offlimits.add_token(token)
end

function offlimits.remove(token)
    local ok, why = may_write()
    if not ok then return false, why end

    local list = offlimits.tokens()
    for index, entry in ipairs(list) do
        if entry == token then
            table.remove(list, index)
            publish(list)
            return true
        end
    end
    return false, "That is not on the list."
end

function offlimits.clear()
    local ok, why = may_write()
    if not ok then return false, why end
    publish({})
    return true
end

local function match_in(def, word, level)
    if type(def.items) ~= "function" then

        local id = string.gsub(string.lower(word), "[^%w_]", "")
        if id == "" then return nil end
        return offlimits.token(def.kind, id, level)
    end

    local ok, items = pcall(def.items)
    if not ok or type(items) ~= "table" then return nil end

    local wanted = string.lower(word)
    for _, item in ipairs(items) do
        if string.lower(tostring(item.id)) == wanted
            or string.lower(tostring(item.name or "")) == wanted then
            return offlimits.token(def.kind, item.id, level)
        end
    end

    for _, item in ipairs(items) do
        local name = string.lower(tostring(item.name or ""))
        if name ~= "" and string.sub(name, 1, #wanted) == wanted then
            return offlimits.token(def.kind, item.id, level)
        end
    end
    return nil
end

function offlimits.resolve(text)
    local words = {}
    for word in string.gmatch(tostring(text or ""), "%S+") do
        table.insert(words, word)
    end
    if #words == 0 then return nil end

    local level = nil
    if #words > 1 and string.match(words[#words], "^%d+$") ~= nil then
        level = table.remove(words)
    end

    local whole = table.concat(words, " ")
    if #words == 1 and BY_ID[string.sub(whole, 1, 1)] ~= nil
        and offlimits.has(whole) then
        return whole
    end

    if #words > 1 and BY_KIND[string.lower(words[1])] ~= nil then
        local def = BY_KIND[string.lower(words[1])]
        return match_in(def, table.concat(words, " ", 2), level)
    end

    for _, def in ipairs(offlimits.KINDS) do
        local token = match_in(def, whole, level)

        if token ~= nil and type(def.items) == "function" then return token end
    end

    local first = offlimits.KINDS[1]
    if first ~= nil then return match_in(first, whole, level) end
    return nil
end

offlimits.register({
    kind = "mod", id = "m",
    name = "Modifiers", one = "modifier",
    items = function()
        local out = {}
        for _, entry in ipairs(OF.modifiers.LIST or {}) do
            if entry.id ~= nil then
                local levels = {}
                for _, step in ipairs(entry.levels or {}) do
                    table.insert(levels, step.name)
                end
                table.insert(out, { id = entry.id, name = entry.name,
                    levels = levels })
            end
        end
        return out
    end,
})

offlimits.register({
    kind = "level", id = "l",
    name = "Places", one = "place",
    items = function()
        local out = {}
        for _, course in ipairs(OF.COURSES or {}) do
            table.insert(out, { id = tostring(course.num), name = course.name })
        end
        return out
    end,
})

function offlimits.level_closed(levelNum)
    if type(levelNum) ~= "number" then return false end
    local num = OF.util.course_of_level(levelNum)
    if type(num) ~= "number" or num <= 0 then return false end
    return not offlimits.allows("level", tostring(num))
end

hook_event(HOOK_ON_MODS_LOADED, function()
    if not OF.util.is_host() then return end
    local stored = mod_storage_load(STORE_KEY, "")
    if stored ~= nil and stored ~= "" then
        OF.util.publish(offlimits.KEY, stored)
    end
end)
