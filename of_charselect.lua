OF = OF or {}
OF.charselect = OF.charselect or {}

local cs = OF.charselect

function cs.present()
    return _G.charSelectExists == true and type(_G.charSelect) == "table"
end

function cs.name_of(localIndex)
    if not cs.present() then return nil end

    local api = _G.charSelect
    if type(api.character_get_current_number) ~= "function" then return nil end
    if type(api.character_get_nickname) ~= "function" then return nil end

    local ok, number = pcall(api.character_get_current_number, localIndex)
    if not ok or type(number) ~= "number" then return nil end

    local named, nickname = pcall(api.character_get_nickname, number)
    if not named or type(nickname) ~= "string" or nickname == "" then return nil end

    return OF.util.plain(nickname)
end

function cs.suffix(localIndex)
    local name = cs.name_of(localIndex)
    if name == nil or name == "Mario" then return "" end
    return "  (" .. name .. ")"
end

local DRESS_CALLS = {
    "character_edit",
    "character_edit_costume",
    "character_get_current_number",
    "character_get_current_costume",
    "character_get_current_table",
}

function cs.can_dress()
    if not cs.present() then return false end
    local api = _G.charSelect
    for _, name in ipairs(DRESS_CALLS) do
        if type(api[name]) ~= "function" then return false end
    end
    return true
end

local heldRows = {}

local dressedAs = nil

local function row_key(number, alt)
    return tostring(number) .. ":" .. tostring(alt)
end

local function current_row()
    local api = _G.charSelect

    local ok, number = pcall(api.character_get_current_number, 0)
    if not ok or type(number) ~= "number" then return nil end

    local okAlt, alt = pcall(api.character_get_current_costume, 0)
    if not okAlt or type(alt) ~= "number" then return nil end

    local okRow, row = pcall(api.character_get_current_table, number, alt)
    if not okRow or type(row) ~= "table" then return nil end

    return number, alt, row
end

local function poke(modelId)
    local m = gMarioStates[0]
    if m == nil or m.marioObj == nil then return end
    OF.util.optional("obj_set_model_extended", nil, m.marioObj, modelId)
end

function cs.dress(modelId)
    if type(modelId) ~= "number" then return false end
    if not cs.can_dress() then return false end

    local number, alt, row = current_row()
    if number == nil then return false end

    local key = row_key(number, alt)
    if heldRows[key] == nil then

        heldRows[key] = { number = number, alt = alt,
            model = tonumber(row.model) or tonumber(row.ogModel) }
    end

    if tonumber(row.model) == modelId then
        dressedAs = modelId

        if OF.util.optional("obj_has_model_extended", 1,
                gMarioStates[0] and gMarioStates[0].marioObj, modelId) ~= 1 then
            poke(modelId)
        end
        return true, false
    end

    local api = _G.charSelect
    if not pcall(api.character_edit, number, nil, nil, nil, nil, modelId) then
        return false, false
    end
    dressedAs = modelId
    poke(modelId)
    return true, true
end

function cs.undress()
    if next(heldRows) == nil then
        dressedAs = nil
        return false
    end
    if not cs.can_dress() then

        heldRows = {}
        dressedAs = nil
        return false
    end

    local api = _G.charSelect
    for _, held in pairs(heldRows) do
        if held.model ~= nil then

            pcall(api.character_edit_costume, held.number, held.alt,
                nil, nil, nil, nil, held.model)
        end
    end
    heldRows = {}
    dressedAs = nil

    local _, _, row = current_row()
    if row ~= nil and tonumber(row.model) ~= nil then poke(tonumber(row.model)) end
    return true
end

function cs.dressed_as()
    return dressedAs
end

function cs.forget_dress()
    heldRows = {}
    dressedAs = nil
end

function cs.owns_player_list()
    return cs.present()
end

function cs.owns_nametag_health()
    return cs.present()
end

local function restrict(name, on)
    if not cs.present() then return false end
    local api = _G.charSelect
    if type(api[name]) ~= "function" then return false end
    return (pcall(api[name], on == true))
end

local function restricted(name)
    if not cs.present() then return nil end
    local api = _G.charSelect
    if type(api[name]) ~= "function" then return nil end
    local ok, answer = pcall(api[name])
    if not ok or type(answer) ~= "boolean" then return nil end
    return answer
end

function cs.restrict_palettes(on) return restrict("restrict_palettes", on) end
function cs.restrict_movesets(on) return restrict("restrict_movesets", on) end

function cs.palettes_restricted() return restricted("are_palettes_restricted") end
function cs.movesets_restricted() return restricted("are_movesets_restricted") end

local menuHooked = false

function cs.round_allows_menu()
    if not OF.util.asks(OF.gamemodes, "is_running") then return true end
    local ok, running = pcall(OF.gamemodes.is_running)
    if not ok then return true end
    return running ~= true
end

function cs.hook_their_menu()
    if menuHooked then return false end
    if not cs.present() then return false end
    local api = _G.charSelect
    if type(api.hook_allow_menu_open) ~= "function" then return false end
    if not pcall(api.hook_allow_menu_open, cs.round_allows_menu) then return false end
    menuHooked = true
    return true
end

hook_event(HOOK_ON_MODS_LOADED, function()
    cs.hook_their_menu()
end)

local function their_row(localIndex)
    if not cs.present() then return nil end
    if type(localIndex) ~= "number" then return nil end
    local np = gNetworkPlayers[localIndex]
    if np == nil or np.connected ~= true then return nil end

    local rows = _G.charSelect.gCSPlayers
    if type(rows) ~= "table" then return nil end
    local row = rows[localIndex]
    if type(row) ~= "table" then return nil end
    return row
end

function cs.in_menu(localIndex)
    local row = their_row(localIndex)
    return row ~= nil and row.inMenu == true
end

function cs.restore_palette(np)
    if np == nil then return false end
    OF.util.optional("network_player_reset_override_palette", nil, np)

    if not cs.present() then return false end
    local api = _G.charSelect
    if type(api.update_preset_palette) ~= "function" then return false end
    return (pcall(api.update_preset_palette, np))
end
