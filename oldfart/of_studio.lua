OF = OF or {}
OF.studio = OF.studio or {}

local studio = OF.studio

studio.PLACE = "the_studio"
studio.PRESETS = {
    { key = "green",   name = "Green screen",   rgb = { 0, 177, 64 } },
    { key = "blue",    name = "Blue screen",    rgb = { 0, 71, 187 } },
    { key = "magenta", name = "Magenta", rgb = { 255, 0, 255 } },
    { key = "white",   name = "White",   rgb = { 255, 255, 255 } },
    { key = "black",   name = "Black",   rgb = { 0, 0, 0 } },
}

studio.colour = studio.colour or { 0, 177, 64 }
if studio.shadowsOff == nil then studio.shadowsOff = true end
if studio.hudOff == nil then studio.hudOff = false end
if studio.flat == nil then studio.flat = false end

studio.worn = studio.worn or "off"
studio.VERTICES = {
    "the_studio_dl_Cube_001_mesh_layer_1_vtx_0",
    "the_studio_dl_Cube_002_mesh_layer_1_vtx_0",
}

studio.painted = studio.painted or nil

function studio.paint(rgb)
    local r, g, b = 255, 255, 255
    if type(rgb) == "table" then
        r = math.floor(OF.util.clamp(tonumber(rgb[1]) or 255, 0, 255))
        g = math.floor(OF.util.clamp(tonumber(rgb[2]) or 255, 0, 255))
        b = math.floor(OF.util.clamp(tonumber(rgb[3]) or 255, 0, 255))
    end
    local find = OF.util.binding("vtx_get_from_name")
    if find == nil then return 0 end
    local written = 0
    for _, name in ipairs(studio.VERTICES) do
        local ok, buffer, count = pcall(find, name)
        if ok and buffer ~= nil then
            count = tonumber(count) or 0
            for i = 0, count - 1 do
                local vert = OF.util.optional("vtx_get_vertex", nil, buffer, i)
                if vert == nil then break end
                vert.r, vert.g, vert.b = r, g, b
                written = written + 1
            end
        end
    end
    if rgb == nil then
        studio.painted = nil
    else
        studio.painted = r .. " " .. g .. " " .. b
    end
    return written
end

function studio.hex(rgb)
    rgb = rgb or studio.colour
    return string.format("#%02X%02X%02X",
        math.floor(rgb[1] or 0), math.floor(rgb[2] or 0), math.floor(rgb[3] or 0))
end

function studio.preset_now()
    for _, preset in ipairs(studio.PRESETS) do
        local rgb = preset.rgb
        if rgb[1] == studio.colour[1] and rgb[2] == studio.colour[2]
            and rgb[3] == studio.colour[3] then
            return preset.key
        end
    end
    return nil
end

function studio.set_colour(rgb)
    if type(rgb) ~= "table" then return false end
    local out = {}
    for i = 1, 3 do
        local value = tonumber(rgb[i])
        if value == nil then return false end
        out[i] = math.floor(OF.util.clamp(value, 0, 255))
    end
    studio.colour = out
    studio.settle()
    return true
end

function studio.set_preset(key)
    for _, preset in ipairs(studio.PRESETS) do
        if preset.key == key then return studio.set_colour(preset.rgb) end
    end
    return false
end

function studio.reset_screen()
    local green = studio.PRESETS[1].rgb
    local c = studio.colour or {}
    local moved = c[1] ~= green[1] or c[2] ~= green[2] or c[3] ~= green[3]
        or studio.shadowsOff ~= true or studio.hudOff ~= false or studio.flat ~= false
    if not moved then return false end
    studio.shadowsOff, studio.hudOff, studio.flat = true, false, false
    studio.set_colour(green)
    return true
end

function studio.level()
    if not OF.util.asks(OF.arena, "find") then return nil end
    local place = OF.arena.find(studio.PLACE)
    if place == nil then return nil end
    return place.level
end

function studio.here()
    local level = studio.level()
    if level == nil then return false end
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if np == nil then return false end
    return np.currLevelNum == level
end

function studio.stands_down()
    if OF.util.asks(OF.lockdown, "menu_stands_down") then
        return OF.lockdown.menu_stands_down(0) == true
    end
    return false
end

function studio.round_look()
    if not OF.util.asks(OF.gamemodes, "current") then return nil end
    if OF.gamemodes.state() == OF.gamemodes.OFF then return nil end
    local mode = OF.gamemodes.current()
    local look = mode ~= nil and mode.studio or nil
    if type(look) ~= "table" or type(look.tint) ~= "table" then return nil end
    return {
        tint = { look.tint[1] or 255, look.tint[2] or 255, look.tint[3] or 255 },
        shadows = false, hud = false, flat = false,
    }
end

function studio.wish()
    if not studio.here() then return nil end
    if studio.stands_down() then return studio.round_look() end
    return {
        tint = { studio.colour[1], studio.colour[2], studio.colour[3] },
        shadows = studio.shadowsOff == true,
        hud = studio.hudOff == true,
        flat = studio.flat == true,
    }
end

local function wish_key(wish)
    if wish == nil then return "off" end
    return table.concat({ wish.tint[1], wish.tint[2], wish.tint[3],
        tostring(wish.shadows), tostring(wish.hud), tostring(wish.flat) }, " ")
end

function studio.settle(force)
    if not OF.util.asks(OF.modifiers, "wear_studio") then return false end
    local wish = studio.wish()
    local key = wish_key(wish)
    if key == studio.worn and not force then return false end
    studio.worn = key

    studio.paint(wish ~= nil and wish.tint or nil)
    local rest = nil
    if wish ~= nil then
        rest = { tint = nil, shadows = wish.shadows, hud = wish.hud, flat = wish.flat }
    end
    OF.modifiers.wear_studio(rest)
    if wish ~= nil and not studio.wasHere then studio.hintLeft = studio.HINT_FRAMES end
    studio.wasHere = wish ~= nil
    return true
end

studio.HINT_FRAMES = 180
studio.hintLeft = studio.hintLeft or 0
studio.HINT = "Colours: Travel > Arenas > The Studio's walls and screen"
function studio.hint_line()
    if (studio.hintLeft or 0) <= 0 then return nil end
    if not studio.here() or studio.stands_down() then return nil end
    return OF.lang.t(studio.HINT)
end

hook_event(HOOK_ON_HUD_RENDER, function()
    local line = studio.hint_line()
    if line == nil then return end
    if OF.util.asks(OF.util, "menu_has_screen") and OF.util.menu_has_screen() then return end
    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)
    local scale = 0.8
    local width = OF.util.width(line, scale)
    local x = (djui_hud_get_screen_width() - width) * 0.5
    local y = djui_hud_get_screen_height() - 90
    OF.util.text(line, x, y, scale, 255, 255, 255, 255)
end)

hook_event(HOOK_UPDATE, function()
    studio.settle(false)
    if (studio.hintLeft or 0) > 0 then studio.hintLeft = studio.hintLeft - 1 end
end)

hook_event(HOOK_ON_LEVEL_INIT, function() studio.settle(studio.worn ~= "off") end)

function studio.build_page(panel)
    local rows = {}
    local here = studio.here()

    if here then
        table.insert(rows, panel.label_row(
            OF.lang.t("You are in the studio. Only your screen changes.")))
    else
        table.insert(rows, panel.label_row(
            OF.lang.t("Set up here; it is worn when you walk in.")))
    end

    table.insert(rows, panel.with_help(panel.header_row(OF.lang.t("The walls")),
        "the colour of the walls - you and everybody in it keep their own"))

    local now = studio.preset_now()
    for _, preset in ipairs(studio.PRESETS) do
        local key = preset.key
        table.insert(rows, panel.with_help(panel.row(
            panel.tick(now == key, OF.lang.t(preset.name)), 255, 255, 255,
            function() studio.set_preset(key) end),
            OF.lang.fill("paints the walls @", studio.hex(preset.rgb))))
    end

    local function channel_row(name, index)
        local built = panel.row("   " .. OF.lang.t(name), 255, 255, 255,
            function()
                local rgb = { studio.colour[1], studio.colour[2], studio.colour[3] }
                rgb[index] = rgb[index] + 16
                if rgb[index] > 255 then rgb[index] = 0 end
                studio.set_colour(rgb)
            end)
        built = panel.with_slider(built, studio.colour[index], 255,
            function(wanted)
                local rgb = { studio.colour[1], studio.colour[2], studio.colour[3] }
                rgb[index] = wanted
                studio.set_colour(rgb)
            end)
        return panel.picker_row(built,
            string.format("%02X", math.floor(studio.colour[index])), false)
    end
    table.insert(rows, panel.with_help(channel_row("Wall red", 1),
        "two hex digits of red - a press adds 16"))
    table.insert(rows, panel.with_help(channel_row("Wall green", 2),
        "two hex digits of green - a press adds 16"))
    table.insert(rows, panel.with_help(channel_row("Wall blue", 3),
        "two hex digits of blue - a press adds 16"))
    table.insert(rows, panel.label_row(
        OF.lang.fill("The walls now: @", studio.hex())))

    table.insert(rows, panel.with_help(panel.header_row(OF.lang.t("The picture")),
        "what else is on your screen while you are in the studio"))
    table.insert(rows, panel.with_help(panel.row(
        panel.tick(studio.shadowsOff, OF.lang.t("Shadows off")), 255, 255, 255,
        function()
            studio.shadowsOff = not studio.shadowsOff
            studio.settle()
        end), "nobody casts a shadow on the floor - back on at the door"))
    table.insert(rows, panel.with_help(panel.row(
        panel.tick(studio.hudOff, OF.lang.t("HUD off")), 255, 255, 255,
        function()
            studio.hudOff = not studio.hudOff
            studio.settle()
        end), "no lives, coins or stars on screen - back on at the door"))
    table.insert(rows, panel.with_help(panel.row(
        panel.tick(studio.flat, OF.lang.t("Flat light")), 255, 255, 255,
        function()
            studio.flat = not studio.flat
            studio.settle()
        end), "everybody in the studio lit evenly, no shading - off at the door"))

    table.insert(rows, panel.back_row())
    return rows
end

hook_event(HOOK_ON_MODS_LOADED, function()
    local panel = OF.panel
    if panel == nil or type(panel.PAGES) ~= "table" then return end
    if panel.PAGES.studio ~= nil then return end
    panel.PAGES.studio = {
        title = "The Studio", tab = "travel", up = "arena",
        build = function() return studio.build_page(panel) end,
    }
end)

function studio.ready()
    return studio.PRESETS ~= nil and #studio.PRESETS == 5
end
