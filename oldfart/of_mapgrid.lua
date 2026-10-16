OF = OF or {}
OF.mapgrid = OF.mapgrid or {}

local mg = OF.mapgrid

mg.MIN = 3

mg.S = nil

local function now()
    if get_global_timer == nil then return 0 end
    return get_global_timer() or 0
end

local function cue(word)
    if OF.hud ~= nil and type(OF.hud.sound) == "function" then OF.hud.sound(word) end
end

function mg.cards_of(rows)
    local keys, cards, mine = {}, {}, nil
    for _, r in ipairs(rows or {}) do
        local card = r.mapCard
        if type(card) == "table" and r.key ~= nil then
            keys[#keys + 1] = r.key
            cards[#cards + 1] = { name = card.name, level = card.level, area = card.area,
                tags = card.tags, tone = card.tone }
            if card.on then mine = #cards end
        end
    end
    return keys, cards, mine
end

mg.COPIES = { quick = true, find = true, search = true, active = true }

function mg.offer(panel, rows)
    if type(rows) ~= "table" or mg.COPIES[panel.page] then return false end
    local keys = mg.cards_of(rows)
    if #keys < mg.MIN then return false end
    for i, r in ipairs(rows) do
        if type(r.mapCard) == "table" then
            local door = panel.with_key(panel.with_help(
                panel.row(OF.lang.t("See every map as a grid..."), 255, 255, 255,
                    function() mg.open(panel) end),
                OF.lang.t("every map this mode can use, with its picture")), "mapgrid:door")

            door.notAShortcut = true
            table.insert(rows, i, door)
            return true
        end
    end
    return false
end

function mg.open(panel)
    panel = panel or OF.panel
    local _, cards, mine = mg.cards_of(panel.rows)
    if #cards == 0 then return false end
    mg.S = { page = panel.page, selected = mine or 1, first = 0, at = now() }
    cue("open")
    return true
end

function mg.close(quiet)
    if mg.S == nil then return false end
    mg.S = nil
    if not quiet then cue("back") end
    return true
end

function mg.is_open()
    local panel = OF.panel
    if mg.S == nil or panel == nil or not panel.open then return false end
    if mg.S.page ~= panel.page then mg.S = nil return false end
    return true
end

function mg.pick(i)
    local panel = OF.panel
    local keys = mg.cards_of(panel.rows)
    local key = keys[i]
    if key == nil then return false end
    for index, r in ipairs(panel.rows or {}) do
        if r.key == key then
            mg.S = nil
            if r.action == nil then cue("denied") return false end
            panel.cursor = index
            cue("choose")
            if OF.util.asks(OF.shortcuts, "used") then OF.shortcuts.used(panel.page, r) end
            panel.run(r.action)
            return true
        end
    end
    return false
end

local function columns(count)
    local H = OF.hud
    if H == nil or type(H.map_grid_layout) ~= "function" then return 1 end
    return H.map_grid_layout(count).cols or 1
end

local function move(step, count)
    local S = mg.S
    local to = math.max(1, math.min(count, S.selected + step))
    if to ~= S.selected then
        S.selected = to
        cue("move")
    end
end

function mg.input(m, input, pressed, repeated)
    if not mg.is_open() then return false end
    local panel = OF.panel
    local _, cards = mg.cards_of(panel.rows)
    local n = #cards
    if n == 0 then mg.close(true) return false end
    local cols = columns(n)
    if repeated(R_JPAD) then move(1, n)
    elseif repeated(L_JPAD) then move(-1, n)
    elseif repeated(D_JPAD) then move(cols, n)
    elseif repeated(U_JPAD) then move(-cols, n) end
    local vertical = input.stick_step(m)
    if vertical ~= 0 then move(vertical * cols, n) end
    if type(panel.stick_slide) == "function" then
        local side = panel.stick_slide(m)
        if side ~= nil and side ~= 0 then move(side, n) end
    end
    if pressed(A_BUTTON) then mg.pick(mg.S.selected)
    elseif pressed(B_BUTTON) then mg.close()
    elseif pressed(START_BUTTON) then mg.close(true) panel.close() end
    return true
end

local function inside(r, x, y)
    return r ~= nil and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function mg.render(mouseX, mouseY, clicked, rightClicked, moved)
    if not mg.is_open() then return false end
    local H = OF.hud
    if H == nil or type(H.menu_map_grid) ~= "function" then return false end
    local panel = OF.panel
    local _, cards, mine = mg.cards_of(panel.rows)
    local S = mg.S
    local def = panel.PAGES ~= nil and panel.PAGES[panel.page] or nil
    local title = def ~= nil and OF.lang.t(panel.page_title(def)) or ""
    local rects, first = H.menu_map_grid(cards, { selected = S.selected, mine = mine, first = S.first,
        title = string.upper(title), sub = OF.lang.t("A picks - B goes back") }, now() - S.at)
    S.first = first or S.first
    for i, r in pairs(rects or {}) do
        if inside(r, mouseX, mouseY) then
            if moved and S.selected ~= i then S.selected = i cue("move") end
            if clicked then mg.pick(i) return true end
        end
    end
    if rightClicked then mg.close() end
    return true
end
