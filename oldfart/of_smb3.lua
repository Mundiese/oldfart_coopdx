OF = OF or {}
OF.cards = OF.cards or {}

local cards = OF.cards

cards.FACES = {
    { key = "oneup", name = "1-Up", r = 110, g = 230, b = 110 },
    { key = "flower", name = "Flower", r = 255, g = 140, b = 70 },
    { key = "star", name = "Star", r = 255, g = 225, b = 70 },
}

cards.PAYS = { oneup = 2, flower = 3, star = 5 }
cards.MIXED = 1
cards.HAND = 3

cards.TURN = 6

cards.LONGEST = 90

cards.MOST_LIVES = 99

local hand = {}
local turning = nil
local frame = 0

local DANCES = nil
local function dancing(m)
    if DANCES == nil then
        DANCES = {}
        for _, a in ipairs({ ACT_STAR_DANCE_EXIT, ACT_STAR_DANCE_NO_EXIT,
                             ACT_STAR_DANCE_WATER, ACT_FALL_AFTER_STAR_GRAB }) do
            if a ~= nil then DANCES[a] = true end
        end
    end
    return m ~= nil and DANCES[m.action] == true
end

local function on()
    return OF.util.asks(OF.modifiers, "is_on") and OF.modifiers.is_on("cards") == true
end

function cards.face_at(first, frames)
    local count = #cards.FACES
    return ((first - 1) + math.floor(math.max(frames or 0, 0) / cards.TURN)) % count + 1
end

function cards.pay_of(three)
    if three == nil or #three < cards.HAND then return 0, false end
    local key = three[1]
    for k = 2, #three do
        if three[k] ~= key then return cards.MIXED, false end
    end
    return cards.PAYS[key] or cards.MIXED, true
end

function cards.deal(first)
    if not on() then return false end
    if turning ~= nil then return false end
    turning = { start = frame, first = first or math.random(#cards.FACES), danced = false }
    return true
end

function cards.keep()
    if turning == nil then return nil, 0 end
    local face = cards.face_at(turning.first, frame - turning.start)
    turning = nil
    local key = cards.FACES[face].key
    hand[#hand + 1] = key
    if #hand < cards.HAND then
        OF.notify.show(OF.lang.fill("A card: @", OF.lang.t(cards.FACES[face].name)), "info", 3)
        return key, 0
    end
    local lives, set = cards.pay_of(hand)
    local m = gMarioStates[0]
    if m ~= nil then
        m.numLives = math.min((tonumber(m.numLives) or 0) + lives, cards.MOST_LIVES)
    end
    if set then
        OF.notify.show(OF.lang.fill("Three of a kind - @ lives!", tostring(lives)), "good", 4)
    else
        OF.notify.show(OF.lang.t("A mixed hand - one life"), "good", 4)
    end
    if OF.util.asks(OF.sounds, "play") and SOUND_GENERAL_COLLECT_1UP ~= nil then
        OF.sounds.play(SOUND_GENERAL_COLLECT_1UP)
    end
    hand = {}
    return key, lives
end

function cards.hand()
    return hand
end

function cards.turning()
    return turning
end

function cards.forget()
    hand, turning = {}, nil
end

function cards.update()
    frame = frame + 1
    if turning == nil then return end
    local m = gMarioStates[0]
    if dancing(m) then
        turning.danced = true
    elseif turning.danced or frame - turning.start >= cards.LONGEST then
        cards.keep()
    end
end

hook_event(HOOK_UPDATE, function()
    cards.update()
end)

hook_event(HOOK_ON_INTERACT, function(m, o, interactType)
    if m == nil or m.playerIndex ~= 0 then return end
    if interactType ~= INTERACT_STAR_OR_KEY then return end
    cards.deal()
end)

local function card(x, y, w, h, face, alpha)
    local f = cards.FACES[face]
    if f == nil then return end
    djui_hud_set_color(20, 20, 30, math.floor(200 * alpha / 255))
    djui_hud_render_rect(x, y, w, h)
    djui_hud_set_color(f.r, f.g, f.b, alpha)
    djui_hud_render_rect(x + 3, y + 3, w - 6, 4)
    local text = OF.lang.t(f.name)
    local scale = h / 64
    local tw = djui_hud_measure_text(text) * scale
    djui_hud_print_text(text, x + (w - tw) / 2, y + h * 0.35, scale)
end

function cards.render()
    if not on() then return 0 end
    if OF.util.menu_has_screen ~= nil and OF.util.menu_has_screen() then return 0 end
    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)
    local drawn = 0
    local sw = djui_hud_get_screen_width()
    local sh = djui_hud_get_screen_height()
    local now = cards.turning()
    if now ~= nil then
        local face = cards.face_at(now.first, frame - now.start)
        card(sw / 2 - 60, sh * 0.12, 120, 150, face, 255)
        drawn = drawn + 1
    end
    for k, key in ipairs(cards.hand()) do
        for index, f in ipairs(cards.FACES) do
            if f.key == key then
                card(sw * 0.02 + (k - 1) * 58, sh * 0.80, 52, 66, index, 230)
                drawn = drawn + 1
            end
        end
    end
    return drawn
end

hook_event(HOOK_ON_HUD_RENDER, function()
    cards.render()
end)

hook_event(HOOK_ON_LEVEL_INIT, function()

    if turning ~= nil then cards.keep() end
end)

OF.frog = OF.frog or {}
local frog = OF.frog

frog.CRUISE = 42
frog.BURST = 64
frog.BURST_FRAMES = 12

local burstLeft = 0

local function frog_on()
    if not OF.util.asks(OF.cheats, "is_on") then return false end
    return OF.cheats.is_on("frog") == true and OF.cheats.is_on("fins") ~= true
end

function frog.swim(m)
    if m == nil or m.playerIndex ~= 0 or m.vel == nil then return nil end
    if not OF.util.has_flag(m.action or 0, ACT_FLAG_SWIMMING or 0x2000) then return nil end
    if not frog_on() then return nil end
    local c = m.controller
    if c ~= nil and OF.util.has_flag(c.buttonPressed or 0, A_BUTTON or 0x8000) then
        burstLeft = frog.BURST_FRAMES
    end
    local held = c ~= nil and (tonumber(c.stickMag) or 0) > 12
    local speed = nil
    if burstLeft > 0 then
        burstLeft = burstLeft - 1
        speed = frog.BURST
    elseif held then
        speed = frog.CRUISE
    end
    if speed == nil then return nil end
    local pitch = (m.faceAngle.x or 0) * math.pi / 0x8000
    local yaw = (m.faceAngle.y or 0) * math.pi / 0x8000
    local stroke = (m.forwardVel or 0) * math.sin(pitch)
    local buoyancy = (m.vel.y or 0) - stroke
    m.forwardVel = speed
    m.vel.x = speed * math.cos(pitch) * math.sin(yaw)
    m.vel.y = speed * math.sin(pitch) + buoyancy
    m.vel.z = speed * math.cos(pitch) * math.cos(yaw)
    return speed
end

function frog.forget()
    burstLeft = 0
end

hook_event(HOOK_BEFORE_PHYS_STEP, function(m, stepType)
    if stepType ~= STEP_TYPE_WATER then return end
    frog.swim(m)
end)

hook_event(HOOK_ON_LEVEL_INIT, function()
    frog.forget()
end)

OF.smb3 = OF.smb3 or {}
function OF.smb3.ready()
    return true
end
