OF = OF or {}
OF.scoreboard = OF.scoreboard or {}

local scoreboard = OF.scoreboard

local SHOWING_KEY = "scoreboard_on"
local BOARD_X = 0.03
local BOARD_Y = 0.16

local MOST_SCALE = 0.85
local LEAST_SCALE = 0.55

local ROW_GAP = 4

local BOARD_TITLE = "This round"
scoreboard.on = mod_storage_load_bool(SHOWING_KEY, true)

function scoreboard.is_on()
    return scoreboard.on == true
end

function scoreboard.set_on(value)
    scoreboard.on = (value == true)
    OF.util.store_bool(SHOWING_KEY, scoreboard.on)
    return true
end

function scoreboard.key_held()
    return OF.util.optional("djui_attempting_to_open_playerlist", false) == true
end

local grumbledAbout = nil

function scoreboard.standings()
    if not OF.util.asks(OF.gamemodes, "finishing_order") then return nil end

    local ok, board, right = pcall(OF.gamemodes.finishing_order)
    if not ok then
        local key = gGlobalSyncTable.ofGmKey or ""
        if grumbledAbout ~= key then
            grumbledAbout = key
            OF.util.report(false, board)
        end
        return nil
    end
    grumbledAbout = nil

    if type(board) ~= "table" or #board == 0 then return nil end

    if type(right) ~= "function" then right = function() return "" end end
    return board, right
end

function scoreboard.showing()
    if not scoreboard.is_on() then return false end
    if not scoreboard.key_held() then return false end

    if OF.util.menu_has_screen() then return false end

    if not OF.util.asks(OF.gamemodes, "is_running") then return false end
    if not OF.gamemodes.is_running() then return false end

    if OF.util.asks(OF.gamemodes, "hears_round") and not OF.gamemodes.hears_round() then
        return false
    end

    if OF.util.flag(gServerSettings.enablePlayerList) == 0 then return false end

    if OF.util.asks(OF.charselect, "owns_player_list")
        and OF.charselect.owns_player_list() then
        return false
    end

    return true
end

local function fit(top, rows)
    local unit = OF.util.line_height(1.0)
    if unit <= 0 then return MOST_SCALE, rows end

    local bottom = djui_hud_get_screen_height() - OF.util.ROW_FIT_MARGIN
    local room = bottom - top

    local wanted = ((room / (rows + 2)) - ROW_GAP) / unit
    local scale = OF.util.clamp(wanted, LEAST_SCALE, MOST_SCALE)

    local pitch = OF.util.line_height(scale) + ROW_GAP
    return scale, OF.util.rows_that_fit(top + pitch, pitch)
end

local function render()
    if not scoreboard.showing() then return end

    local board, right = scoreboard.standings()
    if board == nil then return end

    local top = djui_hud_get_screen_height() * BOARD_Y
    local scale, fits = fit(top, #board)

    local rows = {}
    local shown = math.min(#board, fits)

    local named = shown
    if #board > shown and shown > 1 then named = shown - 1 end

    for place, entry in ipairs(board) do
        if place > named then break end

        local ok, text = pcall(right, entry)

        rows[#rows + 1] = {
            place = place,
            name = tostring(entry.name or ""),
            right = ok and tostring(text) or "",
        }
    end

    if named < shown then
        rows[#rows + 1] = {
            name = OF.lang.fill("@ more", tostring(#board - named)),
            right = "",
        }
    end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)
    OF.util.board(djui_hud_get_screen_width() * BOARD_X, top,
        OF.lang.t(BOARD_TITLE), rows,
        { scale = scale, max = #rows, width = 200, column = 140 })
end

hook_event(HOOK_ON_HUD_RENDER, render)

function scoreboard.ready()
    return true
end
