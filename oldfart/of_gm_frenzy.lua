OF = OF or {}
OF.PARTY_ARENAS = OF.PARTY_ARENAS or {
    "bowser1", "bowser2", "bowser3", "the_plate",
}

local ROLE_IN = "in"
local ROLE_OUT = "out"
local STEP_KEY = "ofFzStep"
local AT_KEY = "ofFzAt"
local JUDGE_KEY = "ofFzJudge"
local OFF_KEY = "ofFzOff"
local ROW_KEY = "ofFzRow"
local FPS = 30

local UNDECIDED, WON, LOST = 0, 1, 2

local PACE = { 1.00, 1.15, 1.30, 1.50, 1.70, 1.90, 2.14 }
local PACE_CAP = #PACE

local function pace_of(step)
    step = math.floor(tonumber(step) or 1)
    if step < 1 then step = 1 end
    if step > PACE_CAP then step = PACE_CAP end
    return PACE[step]
end

local CARD_SECONDS = 1.0
local WORD_SECONDS, WORD_FLOOR = 1.5, 0.8
local SHORT_SECONDS, LONG_SECONDS = 5.0, 8.0
local SETTLE_SECONDS = 1.5
local RESULT_SECONDS, RESULT_FLOOR = 1.0, 0.6

local BOSS_SECONDS = 20

local ROOM_WAIT_SECONDS = 0.7

local CARD_NONE, CARD_SPEED, CARD_BOSS, CARD_LEVEL = 0, 1, 2, 3
local CARD_WORDS = {
    [CARD_SPEED] = "SPEED UP!",
    [CARD_BOSS] = "BOSS!",
    [CARD_LEVEL] = "LEVEL UP!",
}

local GAMES_TO_BOSS = 14

local NO_LIFE_FROM_LEVEL = 3

local TOP_LEVEL = 3

local SLOT_RADIUS = 750

local RESET_SLACK = 80

local FELL_DROP = 450

local SCORING_SURVIVAL, SCORING_POINTS, SCORING_BOTH = "survival", "points", "both"
local LIVES_STOPS = { four = 4, three = 3, two = 2, one = 1 }
local START_STOPS = { normal = 1, quick = 3, frantic = 5 }
local EVERY_STOPS = { five = 5, three = 3, eight = 8 }
local LENGTH_STOPS = { thirty = 30, twenty = 20, fifty = 50 }

local function opt(key, default)
    local said = OF.gamemodes.option_now(key)
    if said == nil then return default end
    return said
end

local function scoring() return opt("score", SCORING_SURVIVAL) end
local function has_lives() return scoring() ~= SCORING_POINTS end
local function lives_start() return LIVES_STOPS[opt("lives", "four")] or 4 end
local function start_step() return START_STOPS[opt("start", "normal")] or 1 end
local function speed_every() return EVERY_STOPS[opt("every", "five")] or 5 end
local function run_length() return LENGTH_STOPS[opt("length", "thirty")] or 30 end
local function bosses_on() return opt("boss", "on") ~= "off" end
local function ghost_play() return opt("ghost", "on") ~= "off" end

local function sound(id, obj)
    if id == nil then return nil end
    if obj ~= nil then return OF.gamemodes.round_sound_from(obj, id) end
    return OF.gamemodes.round_sound(id)
end

local HASH_P = 2147483647.0
local function hash01(a, b, salt)
    local n = (math.floor(a or 0) * 7919.0 + math.floor(b or 0) * 104729.0
        + math.floor(salt or 0) * 1299709.0 + 12345.0) % HASH_P
    n = (n * 48271.0) % HASH_P
    n = (n * 48271.0 + 7.0) % HASH_P
    return n / HASH_P
end

local function yaw_to(fromX, fromZ, toX, toZ)
    local dx, dz = toX - fromX, toZ - fromZ
    if dx == 0 and dz == 0 then return 0 end
    return math.floor(math.atan(dx, dz) * 32768 / math.pi) % 65536
end

local function flat_distance(ax, az, bx, bz)
    local dx, dz = ax - bx, az - bz
    return math.sqrt(dx * dx + dz * dz)
end

local function is_air(m)
    return m ~= nil and m.action ~= nil and OF.util.has_flag(m.action, ACT_FLAG_AIR)
end

local function contenders()
    local list = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_IN)) do
        if OF.util.can_play(entry.localIndex) then table.insert(list, entry) end
    end
    return list
end

local function floor_under(x, z, near)
    local y = OF.util.optional("find_floor_height", nil, x, near + 400, z)
    if type(y) ~= "number" or y < near - 600 then return near end
    return y
end

local stepRaw, stepParsed = nil, nil

local function step_now()
    local text = gGlobalSyncTable[STEP_KEY]
    if type(text) ~= "string" or text == "" then return nil end
    if text == stepRaw then return stepParsed end
    local serial, game, level, pace, card, seed =
        text:match("^(%d+) (%d+) (%d+) (%d+) (%d+) (%d+)$")
    stepRaw = text
    if serial == nil then
        stepParsed = nil
        return nil
    end
    stepParsed = {
        serial = tonumber(serial), game = tonumber(game),
        level = tonumber(level), paceStep = tonumber(pace),
        card = tonumber(card), seed = tonumber(seed), text = text,
    }
    return stepParsed
end

local atRaw, atParsed = nil, nil

local function arena_at()
    local text = gGlobalSyncTable[AT_KEY]
    if type(text) ~= "string" or text == "" then return nil end
    if text ~= atRaw then
        atRaw = text
        local level, area, x, y, z = text:match(
            "^(%-?%d+) (%-?%d+) (%-?[%d%.]+) (%-?[%d%.]+) (%-?[%d%.]+)$")
        if level == nil then
            atParsed = nil
        else
            atParsed = { level = tonumber(level), area = tonumber(area),
                x = tonumber(x), y = tonumber(y), z = tonumber(z) }
        end
    end
    return atParsed
end

local function row_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    local text = row ~= nil and row[ROW_KEY] or nil
    if type(text) ~= "string" or text == "" then return nil end
    local serial, verdict, lives, wins, points =
        text:match("^(%d+) (%d+) (%d+) (%d+) (%d+)$")
    if serial == nil then return nil end
    return { serial = tonumber(serial), verdict = tonumber(verdict),
        lives = tonumber(lives), wins = tonumber(wins),
        points = tonumber(points) }
end

local function judged_set(serial)
    local text = gGlobalSyncTable[JUDGE_KEY]
    if type(text) ~= "string" then return nil end
    local s, mask = text:match("^(%d+) (%x+)$")
    if s == nil or tonumber(s) ~= serial then return nil end
    local bits = tonumber(mask, 16) or 0
    local set = {}
    for g = 0, MAX_PLAYERS - 1 do
        if math.floor(bits / (2 ^ g)) % 2 == 1 then set[g] = true end
    end
    return set
end

local GAMES = {}
local BY_KEY = {}

local function add_game(game)
    table.insert(GAMES, game)
    BY_KEY[game.key] = #GAMES
end

local on_won = nil

local function decide(ctx, verdict)
    if ctx == nil or ctx.verdict ~= UNDECIDED then return false end
    ctx.verdict = verdict
    if verdict == WON then
        OF.gamemodes.cue("good", nil, "fzwon")
        if on_won ~= nil then on_won(ctx) end
    else
        OF.gamemodes.cue("bad", nil, "fzlost")
    end
    return true
end

local function default_for(game)
    if game.shape == "survive" or game.survives then return WON end
    return LOST
end

local BREAK_ME = 9

local POOF_ME = 8

local GO_ME = 7

local function at_load(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if not ok then return nil end
    return result
end

local function prop_frame(o)
    o.oFlags = OF.util.add_flag(o.oFlags or 0, OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE or 1)
    if o.oAction == GO_ME then
        OF.util.optional("obj_mark_for_deletion", nil, o)
        return
    end
    if o.oAction == BREAK_ME or o.oAction == POOF_ME then
        OF.util.optional("spawn_mist_particles", nil)
        if o.oAction == BREAK_ME then
            OF.util.optional("spawn_triangle_break_particles", nil, 20, 138, 1.5, 3)
        end
        OF.util.optional("obj_mark_for_deletion", nil, o)
        return
    end
    if o.collisionData ~= nil then
        OF.util.optional("load_object_collision_model", nil)
    end
end

bhvOfFrenzyProp = at_load("hook_behavior", nil, OBJ_LIST_SURFACE, false,
    prop_frame, prop_frame, "bhvOfFrenzyProp")

local TOKEN_LOW, TOKEN_HIGH = 0x10000000, 0x10400000
local function gone(o)
    if o == nil or o.activeFlags == 0 then return true end
    local tag = o.oBehParams or 0
    return tag < TOKEN_LOW or tag > TOKEN_HIGH
end

local propToken = 0

local function prop(ctx, model, x, y, z, yaw, collision)
    local bhv = bhvOfFrenzyProp or id_bhvStaticObject
    if bhv == nil then return nil end
    propToken = propToken % 0x3FFFFF + 1
    local token = TOKEN_LOW + propToken

    local spawn = OF.util.asks(OF.slots, "spawn_non_sync") and OF.slots.spawn_non_sync
        or function(...) return OF.util.optional("spawn_non_sync_object", nil, ...) end
    local o = spawn(bhv, model, x, y, z,
        function(obj)
            obj.oFlags = OF.util.add_flag(obj.oFlags or 0,
                OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE or 1)
            obj.oFaceAngleYaw = yaw or 0
            obj.oMoveAngleYaw = yaw or 0
            obj.oOpacity = 255

            obj.oInteractType = 0
            obj.oIntangibleTimer = -1
            obj.oBehParams = token
            if collision ~= nil then
                obj.collisionData = collision
                obj.oCollisionDistance = 1000
            end
        end)
    if o == nil then return nil end
    table.insert(ctx.props, { o = o, token = token })
    return o
end

local function still_mine(entry)
    return entry ~= nil and not gone(entry.o) and entry.o.oBehParams == entry.token
end

local function dress(o, animsName, index, rate)
    if o == nil then return false end
    local anims = gObjectAnimations ~= nil and gObjectAnimations[animsName] or nil
    if anims == nil then return false end
    o.oAnimations = anims
    OF.util.optional("obj_init_animation_with_accel_and_sound", nil, o,
        index or 0, rate or 1.0)
    return true
end

local function drop(o)
    if not gone(o) then OF.util.optional("obj_mark_for_deletion", nil, o) end
end

local function drop_all(ctx)
    if ctx == nil then return end
    for _, entry in ipairs(ctx.props) do
        if still_mine(entry) then drop(entry.o) end
    end
    ctx.props = {}
    ctx.fx = nil
end

local function retire(ctx, o, how)
    for at, entry in ipairs(ctx.props) do
        if entry.o == o then
            if still_mine(entry) then o.oAction = how end
            table.remove(ctx.props, at)
            return true
        end
    end
    return false
end

local function place(o, x, y, z)
    if gone(o) then return end
    o.oPosX, o.oPosY, o.oPosZ = x, y, z
end

local fx_frame
do
local BURST_COUNT, BURST_LIFE = 8, 16

local SPARKLE_FRAMES = 12

local function burst(ctx)
    local m = gMarioStates[0]
    if m == nil or ctx.props == nil then return end
    ctx.fx = ctx.fx or {}
    for i = 1, BURST_COUNT do
        local a = (i - 1) / BURST_COUNT * 2 * math.pi
        local o = prop(ctx, E_MODEL_SPARKLES, m.pos.x, m.pos.y + 110, m.pos.z, 0)
        if o ~= nil then
            OF.util.optional("obj_set_billboard", nil, o)
            OF.util.optional("obj_scale", nil, o, 1.4)
            table.insert(ctx.fx, { o = o, vx = math.sin(a) * 11, vy = 9,
                vz = math.cos(a) * 11, life = BURST_LIFE })
        end
    end
    sound(SOUND_MENU_STAR_SOUND or SOUND_GENERAL_COIN, nil)
end
on_won = burst

fx_frame = function(ctx)
    local list = ctx.fx
    if list == nil then return end
    for i = #list, 1, -1 do
        local f = list[i]
        f.life = f.life - 1
        if f.life <= 0 or gone(f.o) then
            retire(ctx, f.o, GO_ME)
            table.remove(list, i)
        else
            f.vy = f.vy - 0.9
            place(f.o, f.o.oPosX + f.vx, f.o.oPosY + f.vy, f.o.oPosZ + f.vz)
            f.o.oAnimState = (f.o.oAnimState + 1) % SPARKLE_FRAMES
        end
    end
end
end

local function from_slot(ctx, ahead, side)
    local s = ctx.slot
    local fx, fz = math.sin(s.yawRad), math.cos(s.yawRad)
    local x = s.x + fx * ahead + fz * side
    local z = s.z + fz * ahead - fx * side
    return x, floor_under(x, z, s.y), z
end

local function body_top(m)
    if OF.util.has_flag(m.action or 0, ACT_FLAG_SHORT_HITBOX or 0) then
        return m.pos.y + 100
    end
    return m.pos.y + 160
end

local PRESS_BUTTONS = {
    { flag = A_BUTTON, name = "A" },
    { flag = B_BUTTON, name = "B" },
    { flag = Z_TRIG, name = "Z" },
    { flag = L_TRIG, name = "L" },
    { flag = R_TRIG, name = "R" },
    { flag = U_CBUTTONS, name = "C-UP" },
    { flag = D_CBUTTONS, name = "C-DOWN" },
    { flag = L_CBUTTONS, name = "C-LEFT" },
    { flag = R_CBUTTONS, name = "C-RIGHT" },
}

local function presses(ctx, m)
    local c = m.controller
    if c == nil then return {} end
    local down = c.buttonDown or 0
    local pressed = c.buttonPressed or 0
    local was = ctx.data.down or down
    local rose = {}
    for _, one in ipairs(PRESS_BUTTONS) do
        if one.flag ~= nil and (OF.util.has_flag(pressed, one.flag)
            or (OF.util.has_flag(down, one.flag)
                and not OF.util.has_flag(was, one.flag))) then
            rose[one.flag] = true
        end
    end
    ctx.data.down = down

    ctx.data.readsC = true
    return rose
end

local labelWorld = { x = 0, y = 0, z = 0 }
local labelScreen = { x = 0, y = 0, z = 0 }

local function label_at(x, y, z, text, r, g, b)
    labelWorld.x, labelWorld.y, labelWorld.z = x, y, z
    if not OF.util.world_screen(labelWorld, labelScreen) then return false end
    return OF.util.world_label(labelScreen.x, labelScreen.y, OF.lang.t(text), 0.9,
        r or 255, g or 255, b or 255, 255)
end

local function nearest_other(m)
    local best = nil
    for _, entry in ipairs(contenders()) do
        if entry.localIndex ~= 0 and OF.gamemodes.distance(0, entry.localIndex) ~= nil then
            local o = gMarioStates[entry.localIndex]
            if o ~= nil then
                local d = flat_distance(o.pos.x, o.pos.z, m.pos.x, m.pos.z)
                if best == nil or d < best then best = d end
            end
        end
    end
    return best
end

local X = {}

function X.hold_lock(m, k)
    if k == nil or m == nil or m.pos == nil then return false end
    local moved = OF.util.wall_in(m, k.x, k.z, k.r)
    if k.inner ~= nil and k.inner > 0 then
        local dx, dz = m.pos.x - k.x, m.pos.z - k.z
        local d = math.sqrt(dx * dx + dz * dz)
        if d < k.inner then
            if d < 1 then dx, dz, d = 1, 0, 1 end
            local nx, nz = dx / d, dz / d
            m.pos.x, m.pos.z = k.x + nx * k.inner, k.z + nz * k.inner
            if m.vel ~= nil then
                local inward = -((m.vel.x or 0) * nx + (m.vel.z or 0) * nz)
                if inward > 0 then
                    m.vel.x, m.vel.z = (m.vel.x or 0) + inward * nx, (m.vel.z or 0) + inward * nz
                end
            end
            moved = true
        end
    end
    return moved
end

function X.draw_lock(k)
    if k == nil then return end
    local y = (k.y or 0) + 4
    OF.util.zone_ring({ x = k.x, y = y, z = k.z }, k.r, 48, 3, 150, 205, 255, 190)
    if k.inner ~= nil and k.inner > 0 then
        OF.util.zone_ring({ x = k.x, y = y, z = k.z }, k.inner, 32, 3, 150, 205, 255, 190)
    end
end

local CUE = {}
do

local KEY = { 255, 205, 60 }
local KEY_HOT = { 255, 255, 170 }
local KEY_DONE = { 140, 255, 150 }
local WORDS = { 235, 235, 235 }
local GHOST = { 170, 170, 170 }

local function pulse(t)
    return 0.5 + 0.5 * math.sin((t or 0) * 0.42)
end

local function seg(list, text, colour, mix, toward)
    if text == nil or text == "" then return end
    local r, g, b = colour[1], colour[2], colour[3]
    if mix ~= nil and toward ~= nil then
        r = math.floor(r + (toward[1] - r) * mix)
        g = math.floor(g + (toward[2] - g) * mix)
        b = math.floor(b + (toward[3] - b) * mix)
    end
    table.insert(list, { text = text, r = r, g = g, b = b })
end

function CUE.segments(text, hot, done, t, ghost)
    local list, keys = {}, {}
    if type(text) ~= "string" then return list, keys end
    local at = 1
    while at <= #text do
        local a, b, name = text:find("{([^}]+)}", at)
        if a == nil then
            seg(list, text:sub(at), ghost and GHOST or WORDS)
            break
        end
        seg(list, text:sub(at, a - 1), ghost and GHOST or WORDS)
        table.insert(keys, name)
        if ghost then
            seg(list, name, GHOST)
        elseif done ~= nil and done[name] then
            seg(list, name, KEY_DONE)
        elseif hot ~= nil and hot[name] then
            seg(list, name, KEY, pulse(t), KEY_HOT)
        else
            seg(list, name, KEY)
        end
        at = b + 1
    end
    return list, keys
end

local STRIP_OVER = 14
function CUE.draw(c, spec, t, ghost)
    if spec == nil or type(spec.text) ~= "string" or spec.text == "" then return nil end
    local runs = CUE.segments(OF.lang.t(spec.text), spec.hot, spec.done, t, ghost)
    if #runs == 0 then return nil end
    local opts = { segments = runs }
    if type(spec.under) == "string" and spec.under ~= "" then
        opts.under = OF.util.round_under(OF.lang.t(spec.under), "under",
            ghost and "dim" or (spec.underTone or "info"))
    end
    local top, x, w = OF.util.round_line_low(OF.util.segments_text(runs),
        spec.size or "line", "text", opts)
    if top == nil then return nil end
    if type(spec.share) == "number" then
        OF.util.banner_meter(top, x, w, spec.share,
            { r = KEY[1], g = KEY[2], b = KEY[3] }, { r = 70, g = 70, b = 80 })
    elseif type(spec.pips) == "table" then
        OF.util.banner_checks(top, x, spec.pips[1], spec.pips[2])
    end

    return top - STRIP_OVER
end

function CUE.of(c)
    if c == nil or c.game == nil or c.game.cue == nil then return nil end
    local ok, spec = pcall(c.game.cue, c)
    if not ok then return nil end
    return spec
end

end
X.cue_segments = CUE.segments

local FLAME_SCALE = 7.0

local function flame_prop(ctx, x, y, z, scale)
    local o = prop(ctx, E_MODEL_RED_FLAME, x, y, z, 0)
    if o ~= nil then
        OF.util.optional("obj_set_billboard", nil, o)
        OF.util.optional("obj_scale", nil, o, FLAME_SCALE * (scale or 1))
    end
    return o
end

local function flames_turn(list, t)
    local state = math.floor(t / 2) % 8
    for _, f in ipairs(list) do
        if not gone(f.o) then f.o.oAnimState = state end
    end
end

local MARIO_RADIUS = 37

local function attacking_towards(m, x, z)
    if not OF.util.has_flag(m.action or 0, ACT_FLAG_ATTACKING or 0) then return false end
    local want = yaw_to(m.pos.x, m.pos.z, x, z)
    local off = math.abs((want - m.faceAngle.y + 32768) % 65536 - 32768)
    return off < 0x3000
end

local COIN_REACH = 100

local COIN_ROW = { 180, 330, 480 }
local COIN_LIFT = 180

local function coin_prop(ctx, model, x, y, z)
    local o = prop(ctx, model, x, y, z, 0)
    if o ~= nil then OF.util.optional("obj_set_billboard", nil, o) end
    return o
end

local function coin_touched(m, x, y, z)
    if flat_distance(m.pos.x, m.pos.z, x, z) > COIN_REACH then return false end
    return y >= m.pos.y - 50 and y <= body_top(m) + 40
end

local function coins_frame(ctx, m, coins, soundId)
    local left = 0
    for _, coin in ipairs(coins) do
        if not coin.got then
            if not gone(coin.o) then coin.o.oAnimState = (coin.o.oAnimState + 1) % 8 end
            if coin_touched(m, coin.x, coin.y, coin.z) then
                coin.got = true
                retire(ctx, coin.o, POOF_ME)
                sound(soundId, nil)
            else
                left = left + 1
            end
        end
    end
    return left
end

do

local function asleep(m)
    return m.action == ACT_START_SLEEPING or m.action == ACT_SLEEPING
end

add_game({
    key = "sleep", shape = "survive", floor = 0,
    hint = "Mario lies down - touch nothing until the time is up",
    word = function() return "STAY ASLEEP!" end,
    cue = function(ctx)
        return { text = "LET GO OF EVERYTHING - NOT A TOUCH" }
    end,
    start = function(ctx, m)
        ctx.data.put = false
    end,
    frame = function(ctx, m)

        if not ctx.data.put then
            if is_air(m) then return end
            set_mario_action(m, ACT_START_SLEEPING, 0)
            ctx.data.put = true
            return
        end

        if not asleep(m) then decide(ctx, LOST) end
    end,
    status = function(ctx)
        if ctx.verdict == LOST then return "You woke up", "bad" end
        return "Hands off the controller", "cold"
    end,
})
end

do

local function press_button(ctx)
    local pick = math.floor(hash01(ctx.seed, ctx.me, 2) * #PRESS_BUTTONS) + 1
    return PRESS_BUTTONS[pick]
end
X.press_button = press_button

local function press_sequence(ctx)
    local list, used = { press_button(ctx) }, {}
    used[list[1].flag] = true
    for i = 2, math.min(ctx.level, 3) do
        local pick = math.floor(hash01(ctx.seed, ctx.me, 2 + i * 13) * #PRESS_BUTTONS) + 1
        while used[PRESS_BUTTONS[pick].flag] do pick = pick % #PRESS_BUTTONS + 1 end
        used[PRESS_BUTTONS[pick].flag] = true
        list[i] = PRESS_BUTTONS[pick]
    end
    return list
end
X.press_sequence = press_sequence

add_game({
    key = "press", shape = "judge", floor = 2.0, holds = true, deckName = "PRESS IT!",
    hint = "buttons are shown - press them in order, and only them",
    word = function(ctx)
        if ctx.level < 2 then return "PRESS " .. press_button(ctx).name .. "!" end
        return "IN ORDER!"
    end,
    cue = function(ctx)
        local list = press_sequence(ctx)
        local at = ctx.data.at or 1
        local pieces, done, hot = {}, {}, {}
        for i, b in ipairs(list) do
            table.insert(pieces, "{" .. b.name .. "}")
            if i < at then done[b.name] = true elseif i == at then hot[b.name] = true end
        end
        local text = table.concat(pieces, " ")
        if #list == 1 then text = "PRESS " .. text .. " - ONLY THAT ONE" end
        return { text = text, hot = hot, done = done, size = #list > 1 and "headline" or nil }
    end,
    start = function(ctx, m) ctx.data.down = nil ctx.data.at = 1 end,
    frame = function(ctx, m)
        local list = press_sequence(ctx)
        local rose = presses(ctx, m)
        if next(rose) == nil then return end
        local want = list[ctx.data.at or 1]
        if want == nil or not rose[want.flag] then decide(ctx, LOST) return end
        ctx.data.at = (ctx.data.at or 1) + 1
        if ctx.data.at > #list then
            decide(ctx, WON)
        else
            sound(SOUND_MENU_CHANGE_SELECT or SOUND_GENERAL_COIN, nil)
        end
    end,
    status = function(ctx)
        if ctx.verdict == WON then return "Got it", "good" end
        if ctx.verdict == LOST then return "Wrong button", "bad" end
        if ctx.level >= 2 then return "Left to right - a wrong one loses", "warn" end
        return "The first press counts", "warn"
    end,
})
end

do

local SPIN_TURNS = { 2, 3, 2 }

local function spin_turns(ctx)
    return SPIN_TURNS[math.min(ctx.level, #SPIN_TURNS)] or 3
end
X.spin_turns = spin_turns

local function spin_way(ctx)
    if ctx.level < 3 then return nil end
    return hash01(ctx.seed, 0, 9) < 0.5 and 1 or -1
end
X.spin_way = spin_way

local function spin_done(ctx)
    local way = spin_way(ctx)
    local turned = ctx.data.turned or 0
    if way == nil then return math.floor(math.abs(turned) / 65536) end
    return math.max(0, math.floor(turned * way / 65536))
end

add_game({
    key = "spin", shape = "do", floor = 3.0,
    hint = "run round in circles - at the top level, the way called",
    word = function(ctx)
        local way = spin_way(ctx)
        if way == 1 then return "SPIN LEFT!" elseif way == -1 then return "SPIN RIGHT!" end
        return "SPIN!"
    end,
    deckName = "SPIN!",
    cue = function(ctx)
        local way = spin_way(ctx)
        local text = "RUN IN CIRCLES - STICK ROUND AND ROUND"
        if way == 1 then text = "RUN IN CIRCLES - STICK ROUND TO THE LEFT" end
        if way == -1 then text = "RUN IN CIRCLES - STICK ROUND TO THE RIGHT" end
        return { text = text, pips = { spin_done(ctx), spin_turns(ctx) } }
    end,
    start = function(ctx, m)
        ctx.data.turned = 0
        ctx.data.last = m.faceAngle.y
    end,
    frame = function(ctx, m)
        local now = m.faceAngle.y
        local delta = (now - (ctx.data.last or now) + 32768) % 65536 - 32768
        ctx.data.last = now

        if math.abs(m.forwardVel or 0) >= 4 or is_air(m) then
            local before = spin_done(ctx)
            ctx.data.turned = ctx.data.turned + delta
            if spin_done(ctx) > before and spin_done(ctx) < spin_turns(ctx) then
                sound(SOUND_MENU_CHANGE_SELECT or SOUND_GENERAL_COIN, nil)
            end
        end
        if spin_done(ctx) >= spin_turns(ctx) then
            decide(ctx, WON)
        end
    end,
    status = function(ctx)
        local done = spin_done(ctx)
        if ctx.verdict == WON then return "Dizzy - done", "good" end
        return OF.lang.fill("@ of @ turns", tostring(done),
            tostring(spin_turns(ctx))), "warn"
    end,
})
end

do

local PUMP_RATE = { 2.6, 2.8, 3.0 }
local PUMP_MOST_RATE = 5.0

local PUMP_LEAK = 14

local PUMP_SMALL, PUMP_FULL, PUMP_KICK = 0.5, 2.0, 0.35

local function pump_target(ctx)
    local rate = PUMP_RATE[math.min(ctx.level, #PUMP_RATE)] or 3.2
    rate = math.min(rate, PUMP_MOST_RATE)
    return math.max(4, math.floor(rate * ctx.playF / FPS))
end
X.pump_target = pump_target

local function pump_next(ctx)
    if ctx.level < 2 then return PRESS_BUTTONS[1] end
    return (ctx.data.count or 0) % 2 == 0 and PRESS_BUTTONS[1] or PRESS_BUTTONS[2]
end
X.pump_next = pump_next

add_game({
    key = "pump", shape = "do", floor = 3.0, holds = true,
    hint = "mash the button shown - the 1-UP grows with every press",
    word = function() return "PUMP!" end,
    cue = function(ctx)
        local want = pump_next(ctx).name
        local share = math.min(1, (ctx.data.count or 0) / pump_target(ctx))
        if ctx.verdict == WON then
            return { text = "FULL!", share = 1 }
        end
        if ctx.level < 2 then
            return { text = "MASH {A}", hot = { A = true }, share = share }
        end
        local hot = { [want] = true }
        return { text = "{A} {B} {A} {B} - IN TURN", hot = hot, share = share,
            under = ctx.level >= 3 and "it leaks - do not stop" or nil,
            underTone = "warn" }
    end,
    start = function(ctx, m)
        ctx.data.count = 0
        ctx.data.down = nil
        ctx.data.kick = 0
        ctx.data.since = 0
        ctx.data.shroom = prop(ctx, E_MODEL_1UP, m.pos.x, m.pos.y + 220, m.pos.z, 0)
    end,
    frame = function(ctx, m)
        local d = ctx.data
        local rose = presses(ctx, m)
        if ctx.verdict == UNDECIDED then
            local want = pump_next(ctx)
            if rose[want.flag] then
                d.count = d.count + 1
                d.kick = PUMP_KICK
                d.since = 0
                sound(SOUND_GENERAL_BOING1, nil)
            elseif next(rose) ~= nil and ctx.level >= 2 then

                sound(SOUND_MENU_CAMERA_BUZZ or SOUND_GENERAL_BOING1, nil)
            else
                d.since = d.since + 1
                if ctx.level >= 3 and d.count > 0 and d.since >= PUMP_LEAK * 2
                    and d.since % PUMP_LEAK == 0 then

                    d.count = math.max(d.count % 2, d.count - 2)
                    sound(SOUND_GENERAL_FLAME_OUT or SOUND_GENERAL_BOING1, nil)
                end
            end
        end
        local share = math.min(1, d.count / pump_target(ctx))
        d.kick = math.max(0, (d.kick or 0) - 0.06)
        local o = d.shroom
        if not gone(o) then
            local won = ctx.verdict == WON
            local lift = won and math.min(240, (ctx.t - (d.wonAt or ctx.t)) * 14) or 0
            place(o, m.pos.x, m.pos.y + 200 + share * 60 + lift, m.pos.z)
            OF.util.optional("obj_scale", nil, o,
                PUMP_SMALL + share * (PUMP_FULL - PUMP_SMALL) + d.kick)
            if won then o.oFaceAngleYaw = (o.oFaceAngleYaw + 0x1400) % 65536 end
        end
        if d.count >= pump_target(ctx) and decide(ctx, WON) then
            d.wonAt = ctx.t
            sound(SOUND_GENERAL_COLLECT_1UP, nil)
        end
    end,
    draw = function(ctx)

        local m = gMarioStates[0]
        if m == nil or ctx.verdict ~= UNDECIDED then return end
        local share = math.min(1, (ctx.data.count or 0) / pump_target(ctx))
        local glow = 0.5 + 0.5 * math.sin(ctx.t * 0.42)
        label_at(m.pos.x, m.pos.y + 330 + share * 90, m.pos.z, pump_next(ctx).name,
            255, math.floor(205 + 50 * glow), math.floor(60 + 110 * glow))
    end,
    keepsRunning = true,
    status = function(ctx)
        if ctx.verdict == WON then return "Full size", "good" end
        return OF.lang.fill("@ of @ presses", tostring(ctx.data.count or 0),
            tostring(pump_target(ctx))), "warn"
    end,
})
end

do

local SHOOT_EARLIEST, SHOOT_LATEST = 0.3, 0.65

local SHOOT_SLOW, SHOOT_FAST = 0.6, 0.35

local SHOOT_TELL = 18
X.SHOOT_TELL = SHOOT_TELL

local function shoot_at(ctx)
    local share = SHOOT_EARLIEST + hash01(ctx.seed, 0, 5) * (SHOOT_LATEST - SHOOT_EARLIEST)
    return math.floor(share * ctx.playF)
end
X.shoot_at = shoot_at

local function shoot_allow(ctx)
    local t = (ctx.paceStep - 1) / (PACE_CAP - 1)
    return math.floor((SHOOT_SLOW + (SHOOT_FAST - SHOOT_SLOW) * t) * FPS)
end
X.shoot_allow = shoot_allow

local FEINT_FRAMES = 10
local function shoot_feint(ctx)
    if ctx.level < 2 then return nil end
    local at = math.floor((0.08 + hash01(ctx.seed, 0, 6) * 0.08) * ctx.playF)
    if shoot_at(ctx) - at < FEINT_FRAMES + 4 then return nil end
    return at
end
X.shoot_feint = shoot_feint

add_game({
    key = "shoot", shape = "judge", floor = 2.0, holds = true,
    hint = "wait for NOW, then B - early is out, slow is out, NO! is a trick",
    word = function() return "SHOOT!" end,
    cue = function(ctx)
        if ctx.data.flagged and ctx.verdict == UNDECIDED then
            return { text = "{B} NOW!", hot = { B = true }, size = "headline" }
        end
        local feint = shoot_feint(ctx)
        if feint ~= nil and ctx.started and ctx.t >= feint and ctx.t < feint + FEINT_FRAMES then
            return { text = "NO!", size = "headline" }
        end
        if ctx.started and ctx.t >= shoot_at(ctx) - SHOOT_TELL and ctx.verdict == UNDECIDED then
            return { text = "READY...", size = "headline" }
        end
        return { text = "WAIT FOR NOW... THEN {B}",
            under = ctx.level >= 2 and "not on NO!" or nil, underTone = "warn" }
    end,
    start = function(ctx, m) ctx.data.down = nil ctx.data.flagged = false end,
    frame = function(ctx, m)
        local now = ctx.t >= shoot_at(ctx)
        if not ctx.data.told and ctx.t >= shoot_at(ctx) - SHOOT_TELL then
            ctx.data.told = true
            sound(SOUND_GENERAL2_SWITCH_TICK_FAST or SOUND_GENERAL_BOING1, nil)
        end
        if now and not ctx.data.flagged then
            ctx.data.flagged = true
            OF.gamemodes.cue("hazard", nil, "fzdraw")
            sound(SOUND_GENERAL_RACE_GUN_SHOT, nil)
        end
        local feint = shoot_feint(ctx)
        if feint ~= nil and ctx.t == feint then
            ctx.data.feinted = true
            sound(SOUND_OBJ_BOO_LAUGH_SHORT or SOUND_GENERAL_BOING1, nil)
        end
        local rose = presses(ctx, m)
        if ctx.verdict ~= UNDECIDED then return end
        if now and ctx.t - shoot_at(ctx) > shoot_allow(ctx) then
            decide(ctx, LOST)
            return
        end
        if next(rose) == nil then return end
        if not now or not rose[B_BUTTON] then decide(ctx, LOST) return end
        decide(ctx, WON)
    end,
    status = function(ctx)
        if ctx.verdict == WON then return "Bang - first", "good" end
        if ctx.verdict == LOST then
            if not ctx.data.flagged and ctx.data.feinted then return "Fooled - that was NO!", "bad" end
            if not ctx.data.flagged then return "Too early", "bad" end
            return "Too slow", "bad"
        end
        if ctx.data.flagged then return "NOW - B!", "good" end
        return "Wait for it...", "warn"
    end,
})
end

do

local MOVES = {
    { word = "TRIPLE JUMP!", act = ACT_TRIPLE_JUMP, how = "RUN, THEN {A} {A} {A} AS YOU LAND" },
    { word = "BACKFLIP!", act = ACT_BACKFLIP, how = "STAND, HOLD {Z}, THEN {A}" },
    { word = "SIDE FLIP!", act = ACT_SIDE_FLIP, how = "RUN, PULL THE STICK BACK, {A}" },
    { word = "DIVE!", act = ACT_DIVE, how = "RUN, THEN {B}" },
    { word = "SLIDE KICK!", act = ACT_SLIDE_KICK, how = "RUN, HOLD {Z}, THEN {B}" },
    { word = "JUMP KICK!", act = ACT_JUMP_KICK, how = "{A}, THEN {B} IN THE AIR" },
    { word = "GROUND POUND!", act = ACT_GROUND_POUND, how = "{A}, THEN {Z} IN THE AIR" },
    { word = "DOUBLE JUMP!", act = ACT_DOUBLE_JUMP, how = "{A}, AND {A} AGAIN AS YOU LAND" },
}
X.MOVES = MOVES

local function move_of(ctx)
    local pick = math.floor(hash01(ctx.seed, 0, 7) * #MOVES) + 1
    return MOVES[pick]
end
X.move_of = move_of

local function moves_of(ctx)
    local list = { move_of(ctx) }
    if ctx.level >= 3 then
        local pick = math.floor(hash01(ctx.seed, 0, 8) * #MOVES) + 1
        if MOVES[pick] == list[1] then pick = pick % #MOVES + 1 end
        list[2] = MOVES[pick]
    end
    return list
end
X.moves_of = moves_of

local function bare(word) return (word:gsub("!$", "")) end

add_game({
    key = "move", shape = "do", floor = 2.5, deckName = "THE MOVE CALLS",
    hint = "a move is called - do it (triple jump, backflip, dive ...); two at the top level",
    word = function(ctx)
        local list = moves_of(ctx)
        if #list == 1 then return list[1].word end
        return bare(list[1].word) .. " + " .. list[2].word
    end,
    cue = function(ctx)
        local list = moves_of(ctx)
        local at = math.min(ctx.data.at or 1, #list)
        local spec = { text = list[at].how }
        if #list > 1 then
            spec.pips = { (ctx.data.at or 1) - 1, #list }
            spec.under = at == 1 and OF.lang.fill("then @", bare(list[2].word))
                or "now the second"
        end
        return spec
    end,
    start = function(ctx, m) ctx.data.at = 1 end,
    frame = function(ctx, m)
        local list = moves_of(ctx)
        local want = list[ctx.data.at or 1]
        if want == nil or want.act == nil or m.action ~= want.act then return end
        ctx.data.at = (ctx.data.at or 1) + 1
        if ctx.data.at > #list then
            decide(ctx, WON)
        else
            sound(SOUND_MENU_CHANGE_SELECT or SOUND_GENERAL_COIN, nil)
        end
    end,
    status = function(ctx)
        if ctx.verdict == WON then return "Nailed it", "good" end
        if #moves_of(ctx) > 1 then
            return OF.lang.fill("Move @ of 2", tostring(math.min(ctx.data.at or 1, 2))), "warn"
        end
        return "Do the move", "warn"
    end,
})
end

do

local GOOMBA_SCALE = 1.5
local GOOMBA_RADIUS = 72 * GOOMBA_SCALE
local GOOMBA_TALL = 50 * GOOMBA_SCALE
X.GOOMBA_TALL = GOOMBA_TALL

local GOOMBA_SPEED = 6

local GOOMBA_AHEAD = 560

local GOOMBA_KNOCK = 260
local GOOMBA_DAZE = 15
local GOOMBA_ANIMS = "goomba_seg8_anims_0801DA4C"
local function spawn_goomba_at(ctx, x, y, z, scale)
    scale = scale or GOOMBA_SCALE
    local o = prop(ctx, E_MODEL_GOOMBA, x, y, z, (ctx.slot.yaw + 32768) % 65536)
    if o == nil then return nil end
    OF.util.optional("obj_scale", nil, o, scale)
    dress(o, GOOMBA_ANIMS, 0, 1.0)
    return { o = o, x = x, y = y, z = z, squished = nil, dazed = 0, hop = 0,
        scale = scale }
end

local function spawn_goomba(ctx, side)
    local x, y, z = from_slot(ctx, GOOMBA_AHEAD, side)
    return spawn_goomba_at(ctx, x, y, z)
end

local function goomba_count(ctx)
    return ctx.level >= 3 and 2 or 1
end

local SPINY_ANIMS = "spiny_seg5_anims_05016EAC"
local SPINY_SIZE, SPINY_PACE = 0.75, 0.55

local function spawn_spiny(ctx, ahead, side)
    local x, y, z = from_slot(ctx, ahead, side)
    local o = prop(ctx, E_MODEL_SPINY, x, y, z, (ctx.slot.yaw + 32768) % 65536)
    if o == nil then return nil end
    dress(o, SPINY_ANIMS, 0, 1.0)
    return { o = o, x = x, y = y, z = z, squished = nil, dazed = 0, hop = 0,
        scale = 1.0, size = SPINY_SIZE, spiny = true }
end
X.spawn_spiny = spawn_spiny

local function goomba_touch(g, m)
    local size = g.size or ((g.scale or GOOMBA_SCALE) / GOOMBA_SCALE)
    local radius, tall = GOOMBA_RADIUS * size, GOOMBA_TALL * size
    local d = flat_distance(m.pos.x, m.pos.z, g.x, g.z)
    local top = g.y + tall
    if is_air(m) and (m.vel.y <= 0 or m.action == ACT_GROUND_POUND)
        and d < radius + MARIO_RADIUS * 0.5
        and m.pos.y >= g.y + tall * 0.4 and m.pos.y <= top + 60 then
        return "stomped"
    end
    if d < radius * 0.6 + MARIO_RADIUS and m.pos.y < top
        and body_top(m) > g.y then
        if attacking_towards(m, g.x, g.z) then return "punched" end
        return "hit"
    end
    return nil
end

local KING_DAZE, KING_BOUNCE, KING_SHRINK = 28, 58, 0.82

local function goombas_frame(ctx, m, walkers, hops, wave)
    local left = 0
    local speed = GOOMBA_SPEED * ctx.pace
    for _, g in ipairs(walkers) do
        if g.squished ~= nil then
            g.squished = g.squished + 1
            if g.squished == 20 then retire(ctx, g.o, POOF_ME) end
        else
            if not g.spiny then left = left + 1 end
            if g.dazed > 0 then
                g.dazed = g.dazed - 1
                if g.dazed == 0 and g.hp ~= nil and not gone(g.o) then

                    OF.util.optional("obj_scale", nil, g.o, g.scale)
                    sound(SOUND_OBJ_GOOMBA_ALERT, g.o)
                end
            else

                local yaw = yaw_to(g.x, g.z, m.pos.x, m.pos.z)
                local rad = yaw * math.pi / 32768
                local pace = g.spiny and speed * SPINY_PACE or speed
                g.x = g.x + math.sin(rad) * pace
                g.z = g.z + math.cos(rad) * pace
                if not gone(g.o) then g.o.oFaceAngleYaw = yaw end
            end

            local lift = 0
            if (hops or g.hops) and not g.spiny then
                g.hop = (g.hop + 1) % 30
                lift = math.sin(g.hop / 30 * math.pi) * 90
            end
            g.y = floor_under(g.x, g.z, ctx.slot.y) + lift
            place(g.o, g.x, g.y, g.z)
            local touch = goomba_touch(g, m)
            if g.spiny and touch ~= nil then

                sound(SOUND_OBJ_SPINY_UNK59 or SOUND_ACTION_HIT, g.o)
                ctx.data.spiked = true
                decide(ctx, LOST)
                return "hit"
            elseif g.hp ~= nil and g.dazed > 0 then

                if touch == "stomped" and m.vel.y < 0 then m.vel.y = 20 end
            elseif touch == "stomped" and g.hp ~= nil and g.hp > 1 then
                g.hp = g.hp - 1
                g.dazed = KING_DAZE
                g.scale = g.scale * KING_SHRINK
                if not gone(g.o) then
                    OF.util.optional("obj_scale_xyz", nil, g.o, g.scale, g.scale * 0.45, g.scale)
                end
                m.vel.y = KING_BOUNCE
                sound(SOUND_OBJ_KING_BOBOMB_JUMP or SOUND_OBJ_STOMPED, g.o)
            elseif touch == "stomped" then
                g.squished = 0
                if not gone(g.o) then
                    OF.util.optional("obj_scale_xyz", nil, g.o, g.scale,
                        g.scale * 0.3, g.scale)
                end
                if m.action ~= ACT_GROUND_POUND then m.vel.y = 30 end
                sound(SOUND_OBJ_STOMPED, g.o)
                left = left - 1
            elseif touch == "punched" then
                local away = yaw_to(m.pos.x, m.pos.z, g.x, g.z) * math.pi / 32768
                g.x = g.x + math.sin(away) * GOOMBA_KNOCK
                g.z = g.z + math.cos(away) * GOOMBA_KNOCK
                g.dazed = GOOMBA_DAZE
                sound(SOUND_ACTION_HIT or SOUND_GENERAL_BOING1, g.o)
            elseif touch == "hit" then
                decide(ctx, LOST)
                return "hit"
            end
        end
    end
    if left == 0 and #walkers > 0 and not wave then decide(ctx, WON) end
    return left
end

add_game({
    key = "stomp", shape = "do", floor = 2.5, keepsRunning = true,
    hint = "a Goomba of your own walks at you - land on it (never on the Spiny)",
    word = function() return "STOMP!" end,
    cue = function(ctx)
        return { text = "JUMP {A} AND LAND ON ITS HEAD", hot = { A = true },
            under = ctx.level >= 3 and "the Goombas - never the Spiny" or nil,
            underTone = "warn" }
    end,
    start = function(ctx, m)
        ctx.data.walkers = {}
        local n = goomba_count(ctx)
        for i = 1, n do
            local side = n == 1 and 0 or (i == 1 and -260 or 260)
            local g = spawn_goomba(ctx, side)
            if g ~= nil then table.insert(ctx.data.walkers, g) end
        end
        if ctx.level >= 3 then
            local sp = spawn_spiny(ctx, GOOMBA_AHEAD + 160, 0)
            if sp ~= nil then table.insert(ctx.data.walkers, sp) end
        end
        sound(SOUND_OBJ_GOOMBA_ALERT, nil)
    end,
    frame = function(ctx, m)
        goombas_frame(ctx, m, ctx.data.walkers, ctx.level >= 2)
    end,
    draw = function(ctx)

        for _, g in ipairs(ctx.data.walkers or {}) do
            if g.spiny and ctx.verdict == UNDECIDED then
                OF.util.zone_ring({ x = g.x, y = g.y + 4, z = g.z }, 80, 20, 3,
                    255, 90, 90, 200)
            end
        end
    end,
    status = function(ctx)
        if ctx.verdict == WON then return "Squished", "good" end
        if ctx.verdict == LOST and ctx.data.spiked then return "Spiked - not the Spiny", "bad" end
        if ctx.verdict == LOST then return "It got you", "bad" end
        return "Land on top - a punch only pushes it", "warn"
    end,
})

local SQUISH_COUNT = { 3, 5, 7 }

local function squish_count(ctx) return SQUISH_COUNT[math.min(ctx.level, #SQUISH_COUNT)] or 3 end
X.squish_count = squish_count

add_game({
    key = "squish", shape = "do", long = true, floor = 5.0, keepsRunning = true,
    hint = "Goombas round you - stomp every one",
    word = function() return "SQUISH THEM ALL!" end,
    cue = function(ctx)
        local done = 0
        for _, g in ipairs(ctx.data.walkers or {}) do if g.squished ~= nil then done = done + 1 end end
        return { text = "JUMP {A} ONTO EVERY ONE", pips = { done, squish_count(ctx) } }
    end,
    start = function(ctx, m)
        ctx.data.walkers = {}
        local n = squish_count(ctx)
        for i = 1, n do
            local a = ((i - 0.5) / n - 0.5) * 2.4 + (hash01(ctx.seed, ctx.me, 120 + i) - 0.5) * 0.3
            local reach = 380 + hash01(ctx.seed, ctx.me, 140 + i) * 260
            local x, y, z = from_slot(ctx, math.cos(a) * reach, math.sin(a) * reach)
            local g = spawn_goomba_at(ctx, x, y, z)
            if g ~= nil then table.insert(ctx.data.walkers, g) end
        end
        sound(SOUND_OBJ_GOOMBA_ALERT, nil)
    end,
    frame = function(ctx, m)
        goombas_frame(ctx, m, ctx.data.walkers, ctx.level >= 3)
    end,
    status = function(ctx)
        local left = 0
        for _, g in ipairs(ctx.data.walkers or {}) do if g.squished == nil then left = left + 1 end end
        if ctx.verdict == WON then return "Every one", "good" end
        if ctx.verdict == LOST then return "One got you", "bad" end
        return OF.lang.fill("@ to go - land on them", tostring(left)), "warn"
    end,
})

local HUGE_SCALE = 3.5
local HORDE_WAVES = {
    { { n = 6 }, { n = 4, hops = true }, { king = 2 } },
    { { n = 7 }, { n = 5, hops = true }, { king = 3, n = 2 } },
    { { n = 8 }, { n = 5, hops = true, spiny = 1 }, { king = 3, n = 3 } },
}

local HORDE_NEAR, HORDE_FAR, HORDE_CLEAR = 300, 1100, 380

local function horde_plan(ctx) return HORDE_WAVES[math.min(ctx.level, #HORDE_WAVES)] end
X.horde_plan = horde_plan

local function horde_wave(ctx, m, index)
    local d = ctx.data
    local w = horde_plan(ctx)[index]
    local at = ctx.at
    local count = (w.n or 0) + (w.king ~= nil and 1 or 0) + (w.spiny or 0)
    for i = 1, count do
        local salt = 160 + index * 40 + i
        local a = (i - 1) / count * 2 * math.pi + (hash01(ctx.seed, ctx.me, salt) - 0.5) * 0.5
        local reach = HORDE_NEAR + hash01(ctx.seed, ctx.me, salt + 20) * (HORDE_FAR - HORDE_NEAR)
        local x, z = at.x + math.sin(a) * reach, at.z + math.cos(a) * reach

        local dm = flat_distance(x, z, m.pos.x, m.pos.z)
        if dm < HORDE_CLEAR then
            x = m.pos.x + (x - m.pos.x) / math.max(dm, 1) * HORDE_CLEAR
            z = m.pos.z + (z - m.pos.z) / math.max(dm, 1) * HORDE_CLEAR
        end
        local y = floor_under(x, z, at.y)
        local g
        if w.king ~= nil and i == 1 then
            g = spawn_goomba_at(ctx, x, y, z, HUGE_SCALE)
            if g ~= nil then g.hp, g.king = w.king, true end
        elseif w.spiny ~= nil and i > count - w.spiny then
            local o = prop(ctx, E_MODEL_SPINY, x, y, z, 0)
            if o ~= nil then
                dress(o, "spiny_seg5_anims_05016EAC", 0, 1.0)
                g = { o = o, x = x, y = y, z = z, dazed = 0, hop = 0, scale = 1.0,
                    size = SPINY_SIZE, spiny = true }
            end
        else
            g = spawn_goomba_at(ctx, x, y, z)
            if g ~= nil then g.hops = w.hops end
        end
        if g ~= nil then g.wave = index table.insert(d.walkers, g) end
    end
    d.wave = index
    sound(index == #horde_plan(ctx) and (SOUND_OBJ_KING_BOBOMB_TALK or SOUND_OBJ_GOOMBA_ALERT)
        or SOUND_OBJ_GOOMBA_ALERT, nil)
end

local function wave_count(ctx)
    local done, all = 0, 0
    for _, g in ipairs(ctx.data.walkers or {}) do
        if g.wave == ctx.data.wave and not g.spiny then
            all = all + 1
            if g.squished ~= nil then done = done + 1 end
        end
    end
    return done, all
end

local function the_king(ctx)
    for _, g in ipairs(ctx.data.walkers or {}) do
        if g.king and g.squished == nil then return g end
    end
    return nil
end
X.the_king = the_king

add_game({
    key = "horde", shape = "boss", keepsRunning = true,
    hint = "the boss - three waves of Goombas, the last with a King that takes three stomps",
    word = function() return "GOOMBA HORDE!" end,
    cue = function(ctx)
        local done, all = wave_count(ctx)
        local waves = #horde_plan(ctx)
        local king = the_king(ctx)
        local under = OF.lang.fill("wave @ of @ - a touch loses", tostring(ctx.data.wave or 1),
            tostring(waves))
        if king ~= nil then
            return { text = OF.lang.fill("THE KING - JUMP {A} ON IT @ MORE TIMES", tostring(king.hp)),
                pips = { done, all }, under = under, underTone = "warn" }
        end
        return { text = "JUMP {A} ONTO EVERY ONE", pips = { done, all }, under = under,
            underTone = "warn" }
    end,
    start = function(ctx, m)
        ctx.data.walkers = {}
        horde_wave(ctx, m, 1)
    end,
    frame = function(ctx, m)
        local d = ctx.data
        local last = (d.wave or 1) >= #horde_plan(ctx)
        local left = goombas_frame(ctx, m, d.walkers, false, not last)
        if left == 0 and not last and ctx.verdict == UNDECIDED then
            horde_wave(ctx, m, (d.wave or 1) + 1)
        end
    end,
    draw = function(ctx)
        if ctx.verdict ~= UNDECIDED then return end

        for _, g in ipairs(ctx.data.walkers or {}) do
            if g.squished == nil and g.king then
                OF.util.zone_ring({ x = g.x, y = g.y + 4, z = g.z }, 260, 32, 3, 255, 215, 0,
                    g.dazed > 0 and 120 or 220)
            elseif g.squished == nil and g.spiny then
                OF.util.zone_ring({ x = g.x, y = g.y + 4, z = g.z }, 80, 20, 3, 255, 90, 90, 200)
            end
        end
    end,
    status = function(ctx)
        if ctx.verdict == WON then return "The horde is flat - and the King", "good" end
        if ctx.verdict == LOST then return "The horde got you", "bad" end
        local done, all = wave_count(ctx)
        return OF.lang.fill("Wave @ - @ to go", tostring(ctx.data.wave or 1),
            tostring(all - done)), "warn"
    end,
})
end

do

local BOX_SCALE = 2.0
local BOX_HALF = 103

local HIT_HEIGHT = { 290, 420, 560 }

local HIT_AHEAD = 260

local function hit_height(ctx)
    return HIT_HEIGHT[math.min(ctx.level, #HIT_HEIGHT)] or 290
end
X.hit_height = hit_height

local function hit_from_below(m, bx, by, bz)
    if not is_air(m) or m.vel.y < -8 then return false end
    if math.abs(m.pos.x - bx) > BOX_HALF + 20 or math.abs(m.pos.z - bz) > BOX_HALF + 20 then
        return false
    end
    local head = body_top(m)
    return head >= by - 30 and head <= by + 50
end

add_game({
    key = "hit", shape = "do", floor = 2.5,
    hint = "a ! block hangs over you - jump into it from below",
    word = function() return "HIT!" end,
    cue = function(ctx)
        local need = ({ "{A}", "{A} {A} - A DOUBLE JUMP", "{A} {A} {A} OR {Z} + {A}" })[
            math.min(ctx.level, 3)]
        return { text = "STAND UNDER IT, THEN " .. need }
    end,
    start = function(ctx, m)
        local x, y, z = from_slot(ctx, HIT_AHEAD, 0)
        local by = y + hit_height(ctx)
        local col = gGlobalObjectCollisionData ~= nil
            and gGlobalObjectCollisionData.exclamation_box_outline_seg8_collision_08025F78 or nil
        local o = prop(ctx, E_MODEL_EXCLAMATION_BOX, x, by, z, 0, col)
        if o ~= nil then
            o.oAnimState = 3
            OF.util.optional("obj_scale", nil, o, BOX_SCALE)
        end
        ctx.data.box = { o = o, x = x, y = by, z = z, floor = y }
    end,
    frame = function(ctx, m)
        local b = ctx.data.box
        if b == nil then return end

        if ctx.t == 3 then
            local under = OF.util.optional("find_ceil_height", nil, b.x, b.floor + 60, b.z)
            if type(under) == "number" and under > b.y - 150 and under <= b.y + 20 then
                b.y = under
            end
        end
        if hit_from_below(m, b.x, b.y, b.z) then
            retire(ctx, b.o, BREAK_ME)
            sound(SOUND_GENERAL_BREAK_BOX, b.o)
            if m.vel.y > 0 then m.vel.y = 0 end
            decide(ctx, WON)
        end
    end,
    draw = function(ctx)
        local b = ctx.data.box
        if b == nil or ctx.verdict ~= UNDECIDED then return end
        OF.util.zone_ring({ x = b.x, y = b.floor + 4, z = b.z }, BOX_HALF, 24, 2,
            255, 230, 90, 160)
    end,
    status = function(ctx)
        if ctx.verdict == WON then return "Hit", "good" end
        local need = ({ "a jump", "a double jump", "a triple jump or a backflip" })[
            math.min(ctx.level, 3)]
        return OF.lang.fill("From below - @ reaches it", need), "warn"
    end,
})
end

do

local THWOMP_HALF = 140
local THWOMP_HOVER = 900
X.THWOMP_HALF, X.THWOMP_HOVER = THWOMP_HALF, THWOMP_HOVER

local THWOMP_GRAVITY = 10
local THWOMP_FASTEST = 80

local THWOMP_SITS = 15
local THWOMP_CLIMB = 12

local THWOMP_PLAN = {
    { lock = 0.0, drop = 0.5 },
    { lock = 0.42, drop = 0.7 },
    { lock = 0.6, drop = 0.86 },
}

local function thwomp_count(ctx)
    return math.min(ctx.level, #THWOMP_PLAN)
end

local function thwomp_on(m, x, z, bottom)
    if math.abs(m.pos.x - x) > THWOMP_HALF + MARIO_RADIUS then return false end
    if math.abs(m.pos.z - z) > THWOMP_HALF + MARIO_RADIUS then return false end
    return bottom < body_top(m) and bottom > m.pos.y - 40
end
X.thwomp_on = thwomp_on

add_game({
    key = "dodge", shape = "survive", floor = 2.0, keepsRunning = true,
    hint = "a Thwomp's shadow lands on you - be somewhere else",
    word = function() return "DODGE!" end,
    cue = function(ctx)
        return { text = "RUN OUT FROM UNDER THE RED SHADOW" }
    end,
    start = function(ctx, m)

        ctx.lock = { x = ctx.slot.x, z = ctx.slot.z, y = ctx.slot.y, r = 480 }
        ctx.data.thwomps = {}
        for i = 1, thwomp_count(ctx) do
            table.insert(ctx.data.thwomps, { plan = THWOMP_PLAN[i], state = "wait" })
        end
    end,
    frame = function(ctx, m)
        local share = ctx.t / math.max(1, ctx.playF)
        for _, w in ipairs(ctx.data.thwomps) do
            if w.state == "wait" and share >= w.plan.lock then
                if w.plan.lock == 0 then
                    w.x, w.z = ctx.slot.x, ctx.slot.z
                else
                    w.x, w.z = m.pos.x, m.pos.z
                end
                w.floor = floor_under(w.x, w.z, ctx.slot.y)
                w.y = w.floor + THWOMP_HOVER
                w.vy = 0
                w.o = prop(ctx, E_MODEL_THWOMP, w.x, w.y, w.z, ctx.slot.yaw)
                w.state = "hover"
            end
            if w.state == "hover" and share >= w.plan.drop then
                w.state = "fall"
            end
            if w.state == "fall" then
                w.vy = math.min(THWOMP_FASTEST * ctx.pace, w.vy + THWOMP_GRAVITY * ctx.pace)
                w.y = math.max(w.floor, w.y - w.vy)
                if thwomp_on(m, w.x, w.z, w.y) and ctx.verdict == UNDECIDED then
                    decide(ctx, LOST)
                end
                if w.y <= w.floor then
                    w.state = "sat"
                    w.sat = 0
                    sound(SOUND_OBJ_THWOMP, w.o)
                    OF.util.optional("set_camera_shake_from_point", nil,
                        SHAKE_POS_SMALL or 1, w.x, w.floor, w.z)
                end
            elseif w.state == "sat" then
                w.sat = w.sat + 1
                if w.sat > THWOMP_SITS then
                    w.y = math.min(w.floor + THWOMP_HOVER, w.y + THWOMP_CLIMB)
                end
            end
            if w.o ~= nil then place(w.o, w.x, w.y, w.z) end
        end
    end,
    draw = function(ctx)
        for _, w in ipairs(ctx.data.thwomps or {}) do
            if w.state == "hover" or w.state == "fall" then
                local near = 1 - math.max(0, math.min(1, (w.y - w.floor) / THWOMP_HOVER))
                OF.util.zone_ring({ x = w.x, y = w.floor + 4, z = w.z },
                    THWOMP_HALF, 24, 3, 255, 90, 90, math.floor(120 + 135 * near))
            end
        end
    end,
    status = function(ctx)
        if ctx.verdict == LOST then return "Flattened", "bad" end
        return "Get out from under the shadow", "warn"
    end,
})
end

do

local STAR_DROP = 1000
local STAR_LANDS = 0.8
local STAR_FROM = 0.08

local STAR_AHEAD_LEAST, STAR_AHEAD_MOST = 180, 480
local STAR_SIDE = 380

local STAR_REACH = 90

local STAR_DRIFT = 320

local function star_point(ctx, salt)
    local ahead = STAR_AHEAD_LEAST + hash01(ctx.seed, ctx.me, salt) * (STAR_AHEAD_MOST - STAR_AHEAD_LEAST)
    local side = (hash01(ctx.seed, ctx.me, salt + 1) * 2 - 1) * STAR_SIDE
    return from_slot(ctx, ahead, side)
end

local function caught(m, x, y, z)
    if flat_distance(m.pos.x, m.pos.z, x, z) > STAR_REACH then return false end
    return y >= m.pos.y - 30 and y <= body_top(m) + 30
end

add_game({
    key = "catch", shape = "do", floor = 2.5,
    hint = "a star falls near you - be under it before it lands",
    word = function() return "CATCH!" end,
    cue = function(ctx)
        return { text = "RUN UNDER THE STAR - STAND IN ITS RING" }
    end,
    start = function(ctx, m)
        ctx.data.stars = {}
        local x, y, z = star_point(ctx, 11)

        local drift = ctx.level >= 2 and (hash01(ctx.seed, ctx.me, 15) < 0.5 and -1 or 1)
            * STAR_DRIFT or 0
        local fx, fz = math.sin(ctx.slot.yawRad), math.cos(ctx.slot.yawRad)
        table.insert(ctx.data.stars, { x = x, floor = y, z = z, real = true,
            lx = x, lz = z, dx = fz * drift, dz = -fx * drift,
            o = prop(ctx, E_MODEL_STAR, x, y + STAR_DROP, z, 0) })

        if ctx.level >= 3 then
            local fx, fy, fz
            for salt = 21, 41, 4 do
                fx, fy, fz = star_point(ctx, salt)
                if flat_distance(fx, fz, x, z) > 260 then break end
            end
            table.insert(ctx.data.stars, { x = fx, floor = fy, z = fz, real = false,
                o = prop(ctx, E_MODEL_TRANSPARENT_STAR or E_MODEL_STAR, fx,
                    fy + STAR_DROP, fz, 0) })
        end
    end,
    frame = function(ctx, m)
        local from = STAR_FROM * ctx.playF
        local share = math.max(0, math.min(1,
            (ctx.t - from) / math.max(1, STAR_LANDS * ctx.playF - from)))
        for _, st in ipairs(ctx.data.stars) do
            if not st.done then
                st.y = st.floor + STAR_DROP * (1 - share)
                if st.lx ~= nil then
                    st.x = st.lx + st.dx * (1 - share)
                    st.z = st.lz + st.dz * (1 - share)
                end
                place(st.o, st.x, st.y, st.z)
                if not gone(st.o) then
                    st.o.oFaceAngleYaw = (st.o.oFaceAngleYaw + math.floor(0x800 * ctx.pace)) % 65536
                end
                if caught(m, st.x, st.y, st.z) then
                    st.done = true
                    retire(ctx, st.o, POOF_ME)
                    if st.real then
                        sound(SOUND_GENERAL_STAR_APPEARS or SOUND_GENERAL_COLLECT_1UP, nil)
                        decide(ctx, WON)
                    else
                        decide(ctx, LOST)
                    end
                elseif share >= 1 and st.real then
                    st.done = true
                    decide(ctx, LOST)
                end
            end
        end
    end,
    draw = function(ctx)
        for _, st in ipairs(ctx.data.stars or {}) do
            if not st.done then
                OF.util.zone_ring({ x = st.x, y = st.floor + 4, z = st.z }, 70, 20, 3,
                    255, 230, 90, 210)
            end
        end
    end,
    status = function(ctx)
        if ctx.verdict == WON then return "Caught", "good" end
        if ctx.verdict == LOST then return "Missed", "bad" end
        if ctx.level >= 3 then return "Under its shadow - not the see-through one", "warn" end
        return "Stand under its shadow", "warn"
    end,
})
end

do

add_game({
    key = "get", shape = "do", floor = 3.0,
    hint = "coins of your own appear - get every one (never the lobby's coins)",
    word = function() return "GET!" end,
    cue = function(ctx)
        local got = 0
        for _, coin in ipairs(ctx.data.coins or {}) do if coin.got then got = got + 1 end end
        return { text = "RUN THROUGH EVERY COIN", pips = { got, #(ctx.data.coins or {}) } }
    end,
    start = function(ctx, m)
        ctx.data.coins = {}
        local spots = {}
        if ctx.level <= 1 then
            for _, ahead in ipairs(COIN_ROW) do table.insert(spots, { ahead, 0, 0 }) end
        else
            for i = 1, 5 do
                local ahead = 160 + hash01(ctx.seed, ctx.me, 30 + i) * 380
                local side = (hash01(ctx.seed, ctx.me, 40 + i) * 2 - 1) * 380
                local lift = (ctx.level >= 3 and i <= 2) and COIN_LIFT or 0
                table.insert(spots, { ahead, side, lift })
            end
        end
        for _, spot in ipairs(spots) do
            local x, y, z = from_slot(ctx, spot[1], spot[2])
            y = y + 60 + spot[3]
            table.insert(ctx.data.coins, { x = x, y = y, z = z,
                o = coin_prop(ctx, E_MODEL_YELLOW_COIN, x, y, z) })
        end
    end,
    frame = function(ctx, m)
        local left = coins_frame(ctx, m, ctx.data.coins, SOUND_GENERAL_COIN)
        if left == 0 then decide(ctx, WON) end
    end,
    status = function(ctx)
        local got = 0
        for _, coin in ipairs(ctx.data.coins or {}) do if coin.got then got = got + 1 end end
        if ctx.verdict == WON then return "Every coin", "good" end
        return OF.lang.fill("@ of @ coins", tostring(got), tostring(#(ctx.data.coins or {}))), "warn"
    end,
})
end

do

local CORK_HALF = 100
local CORK_TALL = 200
local CORK_AHEAD = 330
local CORK_REACH = 80

local function breaks_box(m, x, y, z)
    local dx, dz = math.abs(m.pos.x - x), math.abs(m.pos.z - z)

    if (m.action == ACT_GROUND_POUND_LAND or m.action == ACT_GROUND_POUND)
        and dx <= CORK_HALF + 20 and dz <= CORK_HALF + 20
        and m.pos.y >= y + CORK_TALL - 30 and m.pos.y <= y + CORK_TALL + 60 then
        return true
    end

    if math.max(dx, dz) > CORK_HALF + CORK_REACH then return false end
    if m.pos.y > y + CORK_TALL or body_top(m) < y then return false end
    return attacking_towards(m, x, z)
end

add_game({
    key = "break", shape = "do", floor = 2.0,
    hint = "a cork box stands in front of you - punch, kick or pound it",
    word = function() return "BREAK!" end,
    cue = function(ctx)
        local done, all = 0, #(ctx.data.boxes or {})
        for _, box in ipairs(ctx.data.boxes or {}) do if box.broken then done = done + 1 end end
        return { text = "PUNCH IT WITH {B} - OR {A} ONTO IT AND {Z}", pips = { done, all } }
    end,
    start = function(ctx, m)
        local col = gGlobalObjectCollisionData
        local cork = col ~= nil and col.breakable_box_seg8_collision_08012D70 or nil
        local metal = col ~= nil and col.metal_box_seg8_collision_08024C28 or nil
        ctx.data.boxes = {}
        local sides = ctx.level >= 3 and { -260, 0, 260 } or { 0 }
        for _, side in ipairs(sides) do
            local x, y, z = from_slot(ctx, CORK_AHEAD, side)
            table.insert(ctx.data.boxes, { x = x, y = y, z = z,
                o = prop(ctx, E_MODEL_BREAKABLE_BOX, x, y, z, ctx.slot.yaw, cork) })
        end
        if ctx.level == 2 then
            local side = hash01(ctx.seed, ctx.me, 51) < 0.5 and -260 or 260
            local x, y, z = from_slot(ctx, CORK_AHEAD, side)
            ctx.data.metal = { x = x, y = y, z = z,
                o = prop(ctx, E_MODEL_METAL_BOX, x, y, z, ctx.slot.yaw, metal) }
        end
    end,
    frame = function(ctx, m)
        local left = 0
        for _, box in ipairs(ctx.data.boxes) do
            if not box.broken then
                if breaks_box(m, box.x, box.y, box.z) then
                    box.broken = true
                    retire(ctx, box.o, BREAK_ME)
                    sound(SOUND_GENERAL_BREAK_BOX, box.o)
                else
                    left = left + 1
                end
            end
        end
        local metal = ctx.data.metal
        if metal ~= nil and not metal.rang and breaks_box(m, metal.x, metal.y, metal.z) then

            metal.rang = true
            sound(SOUND_ACTION_METAL_BONK or SOUND_GENERAL_BOING1, metal.o)
        end
        if metal ~= nil and metal.rang and not breaks_box(m, metal.x, metal.y, metal.z) then
            metal.rang = false
        end
        if left == 0 then decide(ctx, WON) end
    end,
    status = function(ctx)
        if ctx.verdict == WON then return "Smashed", "good" end
        if ctx.level == 2 then return "The cork one - metal does not break", "warn" end
        if ctx.level >= 3 then return "All three", "warn" end
        return "Punch, kick or pound it", "warn"
    end,
})
end

do

local STRIP_NEAR = 260
local STRIP_DEEP = { 420, 560, 700 }
local STRIP_SIDE = 340
local STRIP_SPACING = 170

local function strip_deep(ctx)
    return STRIP_DEEP[math.min(ctx.level, #STRIP_DEEP)] or 420
end
X.strip_deep = strip_deep

local function strip_coords(ctx, m)
    local s = ctx.slot
    local fx, fz = math.sin(s.yawRad), math.cos(s.yawRad)
    local dx, dz = m.pos.x - s.x, m.pos.z - s.z
    return dx * fx + dz * fz, dx * fz - dz * fx
end
X.strip_coords = strip_coords

add_game({
    key = "strip", shape = "do", floor = 2.5, keepsRunning = true,
    hint = "a strip of fire - clear it in one long jump",
    word = function() return "LONG JUMP!" end,
    cue = function(ctx)
        return { text = "RUN AT IT, HOLD {Z}, THEN {A} - A LONG JUMP" }
    end,
    start = function(ctx, m)
        ctx.data.flames = {}
        local deep = strip_deep(ctx)
        local rows = math.floor(deep / STRIP_SPACING) + 1
        local cols = math.floor(STRIP_SIDE * 2 / STRIP_SPACING) + 1
        for r = 0, rows - 1 do
            local ahead = STRIP_NEAR + deep * r / math.max(1, rows - 1)
            for col = 0, cols - 1 do
                local side = -STRIP_SIDE + STRIP_SIDE * 2 * col / math.max(1, cols - 1)
                local x, y, z = from_slot(ctx, ahead, side)
                table.insert(ctx.data.flames, { o = flame_prop(ctx, x, y, z, 0.6) })
            end
        end
        ctx.data.lastAhead = nil
        ctx.data.leapt = false
    end,
    frame = function(ctx, m)
        flames_turn(ctx.data.flames, ctx.t)
        if ctx.verdict ~= UNDECIDED then return end
        local ahead, side = strip_coords(ctx, m)
        local far = STRIP_NEAR + strip_deep(ctx)
        local across = math.abs(side) <= STRIP_SIDE + MARIO_RADIUS
        local grounded = not is_air(m)

        if grounded and across and ahead >= STRIP_NEAR - MARIO_RADIUS
            and ahead <= far + MARIO_RADIUS then
            sound(SOUND_MOVING_LAVA_BURN or SOUND_OBJ_FLAME_BLOWN, nil)
            decide(ctx, LOST)
            return
        end

        local last = ctx.data.lastAhead
        if last ~= nil and last < STRIP_NEAR and ahead >= STRIP_NEAR and across then
            ctx.data.leapt = m.action == ACT_LONG_JUMP
        end
        ctx.data.lastAhead = ahead
        if grounded and ahead > far and ctx.data.leapt then decide(ctx, WON) end
    end,
    status = function(ctx)
        if ctx.verdict == WON then return "Cleared it", "good" end
        if ctx.verdict == LOST then return "Burnt", "bad" end
        return "Run, crouch with Z, then A - over the fire", "warn"
    end,
})
end

do

local LINE_HALF = 1400
local LINE_FROM = 1300
local LINE_SPACING = 200
local LINE_START, LINE_END = 0.12, 0.95

local LINE_CLEAR = 30

local function sweeps_of(ctx)
    return math.min(ctx.level, 3)
end

local function line_at(ctx, t)
    local from, to = LINE_START * ctx.playF, LINE_END * ctx.playF
    if t < from or t > to then return nil end
    local n = sweeps_of(ctx)
    local each = (to - from) / n
    local k = math.min(n - 1, math.floor((t - from) / each))
    local share = (t - from - k * each) / each
    if k % 2 == 1 then share = 1 - share end
    return -LINE_FROM + 2 * LINE_FROM * share
end
X.line_at = line_at

local function line_axes(ctx)
    local a = hash01(ctx.seed, 0, 61) * 2 * math.pi
    return math.sin(a), math.cos(a), math.cos(a), -math.sin(a)
end
X.line_axes = line_axes

add_game({
    key = "jump", shape = "survive", floor = 2.5, keepsRunning = true,
    hint = "a line of fire sweeps the arena - be in the air as it passes you",
    word = function() return "JUMP!" end,
    cue = function(ctx)
        return { text = "{A} AS THE FIRE REACHES YOU", hot = { A = true } }
    end,
    start = function(ctx, m)
        ctx.data.flames = {}
        local at = ctx.at

        ctx.lock = { x = at.x, z = at.z, y = floor_under(at.x, at.z, at.y),
                     r = math.min(LINE_HALF, LINE_FROM) - 150 }
        for k = -LINE_HALF, LINE_HALF, LINE_SPACING do
            table.insert(ctx.data.flames, { k = k,
                o = flame_prop(ctx, at.x, at.y, at.z, 0.8) })
        end
        ctx.data.side = nil
    end,
    frame = function(ctx, m)
        local at = ctx.at
        local nx, nz, lx, lz = line_axes(ctx)
        local d = line_at(ctx, ctx.t)
        flames_turn(ctx.data.flames, ctx.t)
        for _, f in ipairs(ctx.data.flames) do
            if d == nil then
                place(f.o, at.x, at.y - 3000, at.z)
            else
                local x = at.x + nx * d + lx * f.k
                local z = at.z + nz * d + lz * f.k
                place(f.o, x, floor_under(x, z, at.y), z)
            end
        end
        if d == nil then ctx.data.side = nil return end
        local dx, dz = m.pos.x - at.x, m.pos.z - at.z
        local along = dx * nx + dz * nz - d
        local side = along >= 0
        local was = ctx.data.side
        ctx.data.side = side
        if math.abs(along) < 300 and not ctx.data.heard then
            ctx.data.heard = true
            sound(SOUND_OBJ_FLAME_BLOWN, nil)
        end
        if math.abs(along) > 300 then ctx.data.heard = false end
        if was == nil or was == side then return end

        local floor = floor_under(m.pos.x, m.pos.z, at.y)
        if not is_air(m) or m.pos.y < floor + LINE_CLEAR then
            decide(ctx, LOST)
        end
    end,
    status = function(ctx)
        if ctx.verdict == LOST then return "Singed", "bad" end
        return "Jump as the fire reaches you", "warn"
    end,
})
end

do

local GROUP_RADIUS = 300
local GROUP_LEAST = 6

local function group_size(ctx)
    local low = ctx.level >= 2 and 3 or 2
    return low + math.floor(hash01(ctx.seed, 0, 71) * 2)
end
X.group_size = group_size

local function grouped_exactly(entries, want)
    local n = #entries
    local group = {}
    for i = 1, n do group[i] = i end
    local function root(i)
        while group[i] ~= i do i = group[i] end
        return i
    end
    for i = 1, n do
        for j = i + 1, n do
            local a, b = gMarioStates[entries[i].localIndex], gMarioStates[entries[j].localIndex]
            if a ~= nil and b ~= nil and flat_distance(a.pos.x, a.pos.z, b.pos.x, b.pos.z) <= GROUP_RADIUS
                and math.abs(a.pos.y - b.pos.y) <= GROUP_RADIUS then
                group[root(i)] = root(j)
            end
        end
    end
    local sizes = {}
    for i = 1, n do
        local r = root(i)
        sizes[r] = (sizes[r] or 0) + 1
    end
    local won = {}
    for i = 1, n do
        if sizes[root(i)] == want then won[entries[i].np.globalIndex] = true end
    end
    return won
end
X.grouped_exactly = grouped_exactly

local function near_me(m)
    local count = 1
    for _, entry in ipairs(contenders()) do
        if entry.localIndex ~= 0 then
            local o = gMarioStates[entry.localIndex]
            if o ~= nil and flat_distance(o.pos.x, o.pos.z, m.pos.x, m.pos.z) <= GROUP_RADIUS then
                count = count + 1
            end
        end
    end
    return count
end

add_game({
    key = "groups", shape = "room", long = true, floor = 5.0, minAlive = GROUP_LEAST,
    deckName = "GROUPS OF 3!",
    hint = "a number is called - stand in a group of exactly that many",
    word = function(ctx) return "GROUPS OF " .. group_size(ctx) .. "!" end,
    cue = function(ctx)
        return { text = OF.lang.fill("GET EXACTLY @ OF YOU IN ONE RING",
            tostring(group_size(ctx))) }
    end,
    frame = function(ctx, m) ctx.data.near = near_me(m) end,
    judge = function(st, players)
        local c = { seed = st.seed, level = st.level }
        return grouped_exactly(players, group_size(c))
    end,
    draw = function(ctx)
        local m = gMarioStates[0]
        if m == nil then return end
        local good = (ctx.data.near or 1) == group_size(ctx)
        OF.util.zone_ring({ x = m.pos.x, y = m.pos.y + 4, z = m.pos.z }, GROUP_RADIUS,
            32, 2, good and 140 or 255, good and 255 or 200, good and 150 or 120, 150)
    end,
    status = function(ctx)
        local near = ctx.data.near or 1
        local want = group_size(ctx)
        local tone = near == want and "good" or "warn"
        return OF.lang.fill("@ in your group - @ wanted", tostring(near), tostring(want)), tone
    end,
})
end

do

local FIND_COUNT = 5
local FIND_AHEAD = 380
local FIND_SPREAD = 0.9
local FIND_LIFT = 100
local FIND_REACH = 90

add_game({
    key = "find", shape = "do", floor = 3.0,
    hint = "five stars, four fakes - touch the real one",
    word = function() return "FIND!" end,
    cue = function(ctx)
        return { text = "RUN INTO THE REAL STAR - A FAKE LOSES" }
    end,
    start = function(ctx, m)
        ctx.data.stars = {}
        local real = math.floor(hash01(ctx.seed, ctx.me, 101) * FIND_COUNT) + 1
        ctx.data.real = real
        for i = 1, FIND_COUNT do
            local a = (i - (FIND_COUNT + 1) / 2) / ((FIND_COUNT - 1) / 2) * FIND_SPREAD
            local x, y, z = from_slot(ctx, FIND_AHEAD * math.cos(a), FIND_AHEAD * math.sin(a))
            local fake = i ~= real
            local model = E_MODEL_STAR
            if fake and ctx.level == 2 then model = E_MODEL_TRANSPARENT_STAR or E_MODEL_STAR end
            table.insert(ctx.data.stars, { x = x, y = y + FIND_LIFT, z = z, floor = y,
                real = not fake, o = prop(ctx, model, x, y + FIND_LIFT, z, 0) })
        end
    end,
    frame = function(ctx, m)
        for _, st in ipairs(ctx.data.stars) do

            if not gone(st.o) and (st.real or ctx.level >= 2) then
                st.o.oFaceAngleYaw = (st.o.oFaceAngleYaw + 0x600) % 65536
            end
            if flat_distance(m.pos.x, m.pos.z, st.x, st.z) <= FIND_REACH
                and st.y >= m.pos.y - 40 and st.y <= body_top(m) + 40 then
                retire(ctx, st.o, POOF_ME)
                if st.real then
                    sound(SOUND_GENERAL_STAR_APPEARS or SOUND_GENERAL_COIN, nil)
                    decide(ctx, WON)
                else
                    decide(ctx, LOST)
                end
                return
            end
        end
    end,
    draw = function(ctx)
        if ctx.level < 3 then return end
        local st = ctx.data.stars[ctx.data.real]
        if st == nil then return end
        OF.util.zone_ring({ x = st.x, y = st.floor + 4, z = st.z }, 60, 20, 3, 40, 40, 40, 220)
    end,
    status = function(ctx)
        if ctx.verdict == WON then return "The real one", "good" end
        if ctx.verdict == LOST then return "A fake", "bad" end
        local tell = ({ "The real one turns", "The real one is solid gold",
            "The real one casts a shadow" })[math.min(ctx.level, 3)]
        return tell, "warn"
    end,
})
end

do

local HEAD_REACH = 70
local HEAD_BAND_LOW, HEAD_BAND_HIGH = -30, 60
local HEAD_BOUNCE = 40

local function head_under(m)
    if not is_air(m) or m.vel.y > 0 then return nil end
    for _, entry in ipairs(OF.util.connected_players()) do
        local i = entry.localIndex
        if i ~= 0 and OF.gamemodes.distance(0, i) ~= nil then
            local o = gMarioStates[i]
            if o ~= nil and flat_distance(o.pos.x, o.pos.z, m.pos.x, m.pos.z) <= HEAD_REACH then
                local head = o.pos.y + 160
                local gap = m.pos.y - head
                if gap >= HEAD_BAND_LOW and gap <= HEAD_BAND_HIGH then return entry end
            end
        end
    end
    return nil
end
X.head_under = head_under

add_game({
    key = "headstomp", shape = "do", floor = 3.0, minAlive = 4,
    hint = "land on another player's head - being landed on costs nothing",
    word = function() return "STOMP SOMEONE!" end,
    cue = function(ctx)
        return { text = "JUMP {A} AND COME DOWN ON SOMEBODY'S HEAD", hot = { A = true } }
    end,
    frame = function(ctx, m)
        local under = head_under(m)
        if under == nil then return end
        m.vel.y = HEAD_BOUNCE
        sound(SOUND_ACTION_BOUNCE_OFF_OBJECT or SOUND_GENERAL_BOING1, nil)
        ctx.data.who = under.np ~= nil and under.np.name or nil
        decide(ctx, WON)
    end,
    status = function(ctx)
        if ctx.verdict == WON then
            return OF.lang.fill("Stomped @", ctx.data.who or "somebody"), "good"
        end
        return "Jump onto somebody's head", "warn"
    end,
})
end

do

local AMP_CIRCLE = 260
local AMP_LIFT = 70
local AMP_LAP = 2.4
local AMP_REACH = 45 + MARIO_RADIUS
local AMP_ANIMS = "amp_seg8_anims_08004034"
X.AMP_LIFT, X.AMP_REACH, X.AMP_ANIMS = AMP_LIFT, AMP_REACH, AMP_ANIMS

local AMP_BAND = 45
X.AMP_BAND = AMP_BAND

local function amp_count(ctx) return math.min(ctx.level, 3) end

local function amp_at(ctx, i, n, t)
    local cx, cy, cz = from_slot(ctx, AMP_CIRCLE, 0)
    local s = ctx.slot
    local back = math.atan(s.x - cx, s.z - cz)
    local lap = AMP_LAP / ctx.pace * FPS
    local a = back + 2 * math.pi * ((i - 1) / n + t / lap + 0.08)
    local x, z = cx + math.sin(a) * AMP_CIRCLE, cz + math.cos(a) * AMP_CIRCLE
    return x, floor_under(x, z, s.y) + AMP_LIFT, z
end
X.amp_at = amp_at

add_game({
    key = "avoid", shape = "survive", floor = 0, keepsRunning = true,
    hint = "Amps circle the ring you stand on - run ahead of them or jump one",
    word = function() return "AVOID!" end,
    cue = function(ctx)
        return { text = "RUN AHEAD OF THEM OR {A} OVER ONE", hot = { A = true } }
    end,
    start = function(ctx, m)
        local cx, cy, cz = from_slot(ctx, AMP_CIRCLE, 0)
        ctx.lock = { x = cx, z = cz, y = cy, r = AMP_CIRCLE + AMP_BAND,
                     inner = AMP_CIRCLE - AMP_BAND }
        ctx.data.amps = {}
        local n = amp_count(ctx)
        for i = 1, n do
            local x, y, z = amp_at(ctx, i, n, 0)
            local o = prop(ctx, E_MODEL_AMP, x, y, z, 0)
            dress(o, AMP_ANIMS, 0, 1.0)
            table.insert(ctx.data.amps, { o = o, x = x, y = y, z = z })
        end
    end,
    frame = function(ctx, m)
        local n = #ctx.data.amps
        for i, amp in ipairs(ctx.data.amps) do
            amp.x, amp.y, amp.z = amp_at(ctx, i, n, ctx.t)
            place(amp.o, amp.x, amp.y, amp.z)
            if not gone(amp.o) then
                amp.o.oFaceAngleYaw = yaw_to(amp.x, amp.z, m.pos.x, m.pos.z)
                OF.gamemodes.round_sound_from(amp.o, SOUND_AIR_AMP_BUZZ)
            end
            if ctx.verdict == UNDECIDED
                and flat_distance(amp.x, amp.z, m.pos.x, m.pos.z) <= AMP_REACH
                and amp.y + 40 >= m.pos.y and amp.y - 40 <= body_top(m) then
                decide(ctx, LOST)
            end
        end
    end,
    draw = function(ctx)
        local cx, cy, cz = from_slot(ctx, AMP_CIRCLE, 0)
        OF.util.zone_ring({ x = cx, y = cy + 4, z = cz }, AMP_CIRCLE, 32, 2,
            160, 210, 255, 140)
    end,
    status = function(ctx)
        if ctx.verdict == LOST then return "Zapped", "bad" end
        return "Run ahead of them or jump one", "warn"
    end,
})
end

do

local BILL_RADIUS = 45

local BILL_HIGH = 180
local BILL_LOW = 55
local BILL_FROM = 1500
local BILL_AIM = 0.3
local BILL_PASSES = 0.65

local DUCK_PEN = 30
X.DUCK_PEN = DUCK_PEN

local function bill_height(ctx)
    return ctx.level >= 3 and BILL_LOW or BILL_HIGH
end
X.bill_height = bill_height

add_game({
    key = "duck", shape = "survive", floor = 2.0, keepsRunning = true,
    hint = "a Bullet Bill flies at your head - crouch under it",
    word = function(ctx) return ctx.level >= 3 and "JUMP IT!" or "DUCK!" end,
    cue = function(ctx)
        if ctx.level >= 3 then return { text = "{A} OVER IT AS IT COMES", hot = { A = true } } end
        return { text = "HOLD {Z} AS IT COMES", hot = { Z = true } }
    end,
    deckName = "DUCK!",
    start = function(ctx, m)
        local side = hash01(ctx.seed, ctx.me, 111) < 0.5 and -1 or 1
        ctx.data.bill = { side = side, aimed = false }
        ctx.lock = { x = ctx.slot.x, z = ctx.slot.z, y = ctx.slot.y, r = DUCK_PEN }
    end,
    frame = function(ctx, m)
        local b = ctx.data.bill
        local share = ctx.t / math.max(1, ctx.playF)
        if not b.aimed and share >= BILL_AIM then

            b.aimed = true
            local s = ctx.slot
            b.fx, b.fz = math.sin(s.yawRad), math.cos(s.yawRad)
            b.lx, b.lz = b.fz, -b.fx
            b.cx, b.cz = m.pos.x, m.pos.z
            b.floor = floor_under(m.pos.x, m.pos.z, s.y)
            b.o = prop(ctx, E_MODEL_BULLET_BILL, b.cx - b.lx * BILL_FROM * b.side,
                b.floor + bill_height(ctx), b.cz - b.lz * BILL_FROM * b.side,
                yaw_to(0, 0, b.lx * b.side, b.lz * b.side))
            b.last = nil
            sound(SOUND_OBJ_POUNDING_CANNON, nil)
        end
        if not b.aimed then return end

        local k = (share - BILL_AIM) / (BILL_PASSES - BILL_AIM)
        local along = -BILL_FROM + BILL_FROM * k
        local x = b.cx + b.lx * along * b.side
        local z = b.cz + b.lz * along * b.side
        local y = b.floor + bill_height(ctx)
        place(b.o, x, y, z)

        local mine = (m.pos.x - b.cx) * b.lx * b.side + (m.pos.z - b.cz) * b.lz * b.side
        local off = math.abs((m.pos.x - b.cx) * b.fx + (m.pos.z - b.cz) * b.fz)
        local ahead = along - mine
        if b.last ~= nil and b.last < 0 and ahead >= 0 and off <= BILL_RADIUS + MARIO_RADIUS then
            if y + BILL_RADIUS > m.pos.y and y - BILL_RADIUS < body_top(m) then
                decide(ctx, LOST)
            end
        end
        b.last = ahead
    end,
    status = function(ctx)
        if ctx.verdict == LOST then return "Hit", "bad" end
        if ctx.level >= 3 then return "It flies low - jump over it", "warn" end
        return "Hold Z as it comes", "warn"
    end,
})
end

do

local CHOMP_SCALE = 1.5
local CHOMP_RADIUS = 120
local CHAIN = { 520, 620, 720 }
local CHOMP_LUNGE = 0.6
local CHOMP_LUNGE_FRAMES = 12
local CHOMP_ANIMS = "chain_chomp_seg6_anims_06025178"
local function chain_of(ctx) return CHAIN[math.min(ctx.level, #CHAIN)] or 520 end
X.chain_of = chain_of

local function lunges_of(ctx)
    if ctx.level >= 3 then
        return { { at = 0.42, chain = chain_of(ctx) }, { at = 0.82, chain = chain_of(ctx) + 220 } }
    end
    return { { at = CHOMP_LUNGE, chain = chain_of(ctx) } }
end
X.chomp_lunges = lunges_of

add_game({
    key = "escape", shape = "survive", floor = 2.0, keepsRunning = true,
    hint = "a Chain Chomp is chained to your slot - get out of its reach",
    word = function() return "ESCAPE!" end,
    cue = function(ctx)
        local c = ctx.data.chomp
        if c ~= nil and c.next ~= nil and c.next > 1 then
            return { text = "IT GOES AGAIN - KEEP RUNNING, OUT OF THE BIG RING" }
        end
        return { text = "RUN OUT OF THE RED RING BEFORE IT LUNGES",
            under = ctx.level >= 3 and "it lunges twice" or nil, underTone = "warn" }
    end,
    start = function(ctx, m)
        local s = ctx.slot
        local c = { px = s.x, py = s.y, pz = s.z, x = s.x, z = s.z, state = "bounce", next = 1 }
        c.post = prop(ctx, E_MODEL_WOODEN_POST, s.x, s.y, s.z, 0)
        c.o = prop(ctx, E_MODEL_CHAIN_CHOMP, s.x, s.y, s.z, s.yaw)
        OF.util.optional("obj_scale", nil, c.o, CHOMP_SCALE)
        dress(c.o, CHOMP_ANIMS, 0, 1.0)
        ctx.data.chomp = c
        sound(SOUND_GENERAL_CHAIN_CHOMP2, c.o)
    end,
    frame = function(ctx, m)
        local c = ctx.data.chomp
        local share = ctx.t / math.max(1, ctx.playF)
        local plan = lunges_of(ctx)
        local lunge = plan[math.min(c.next or 1, #plan)]
        local chain = c.chain or lunge.chain
        local y = c.py
        if c.state == "bounce" then

            local a = ctx.t * 0.15
            c.x = c.px + math.sin(a) * 90
            c.z = c.pz + math.cos(a) * 90
            y = c.py + math.abs(math.sin(ctx.t * 0.3)) * 60
            if (c.next or 1) <= #plan and share >= lunge.at then
                c.chain = lunge.chain
                chain = c.chain
                c.state = "lunge"
                c.at = ctx.t
                c.dir = math.atan(m.pos.x - c.px, m.pos.z - c.pz)
                sound(SOUND_GENERAL_CHAIN_CHOMP1, c.o)
            end
        elseif c.state == "lunge" then
            local k = math.min(1, (ctx.t - c.at) / CHOMP_LUNGE_FRAMES)
            c.x = c.px + math.sin(c.dir) * chain * k
            c.z = c.pz + math.cos(c.dir) * chain * k

            if k >= 1 then
                c.state = "back"
                c.at = ctx.t
                local d = flat_distance(m.pos.x, m.pos.z, c.px, c.pz)
                if d <= chain + CHOMP_RADIUS and ctx.verdict == UNDECIDED then
                    decide(ctx, LOST)
                end
            end
        elseif c.state == "done" then
            c.x, c.z = c.px, c.pz
        else
            local k = math.max(0, 1 - (ctx.t - c.at) / (CHOMP_LUNGE_FRAMES * 3))
            c.x = c.px + math.sin(c.dir) * chain * k
            c.z = c.pz + math.cos(c.dir) * chain * k

            if k <= 0 then
                c.next = (c.next or 1) + 1
                c.chain = nil
                if c.next <= #plan then
                    c.state = "bounce"
                    sound(SOUND_GENERAL_CHAIN_CHOMP2, c.o)
                else
                    c.state = "done"
                end
            end
        end
        place(c.o, c.x, y, c.z)
        if not gone(c.o) then
            c.o.oFaceAngleYaw = yaw_to(c.x, c.z, m.pos.x, m.pos.z)
        end
    end,
    draw = function(ctx)
        local c = ctx.data.chomp
        if c == nil then return end
        OF.util.world_line({ x = c.px, y = c.py + 60, z = c.pz },
            { x = c.x, y = c.py + 80, z = c.z }, 4, 120, 120, 130, 230)

        local plan = lunges_of(ctx)
        local lunge = plan[math.min(c.next or 1, #plan)]
        if c.state ~= "done" then
            OF.util.zone_ring({ x = c.px, y = c.py + 4, z = c.pz },
                (c.chain or lunge.chain) + CHOMP_RADIUS, 40, 3, 255, 120, 120, 170)
        end
    end,
    status = function(ctx)
        if ctx.verdict == LOST then return "Chomped", "bad" end
        return "Out of the red ring before it lunges", "warn"
    end,
})
end

do

local POST_AHEAD = 300
local POST_SINK = 190
local POST_REACH = 90

local function pounds_of(ctx) return math.min(ctx.level, 3) end
X.pounds_of = pounds_of

add_game({
    key = "pound", shape = "do", floor = 3.0,
    hint = "a wooden post - ground pound it into the floor",
    word = function() return "POUND!" end,
    cue = function(ctx)
        local p = ctx.data.post or { sunk = 0 }
        return { text = "JUMP {A} ON TOP, THEN {Z}", pips = { p.sunk, pounds_of(ctx) } }
    end,
    start = function(ctx, m)
        local x, y, z = from_slot(ctx, POST_AHEAD, 0)
        local col = gGlobalObjectCollisionData ~= nil
            and gGlobalObjectCollisionData.poundable_pole_collision_06002490 or nil
        ctx.data.post = { x = x, base = y, z = z, sunk = 0, top = y + POST_SINK,
            o = prop(ctx, E_MODEL_WOODEN_POST, x, y, z, 0, col), was = false }
    end,
    frame = function(ctx, m)
        local p = ctx.data.post

        if ctx.t == 3 then
            local top = OF.util.optional("find_floor_height", nil, p.x, p.base + 600, p.z)
            if type(top) == "number" and top > p.base + 40 and top < p.base + 600 then
                p.top = top
            end
        end
        local landing = m.action == ACT_GROUND_POUND_LAND
        if landing and not p.was
            and flat_distance(m.pos.x, m.pos.z, p.x, p.z) <= POST_REACH
            and m.pos.y >= p.top - 30 then
            p.sunk = p.sunk + 1
            local drop = POST_SINK / pounds_of(ctx)
            p.base = p.base - drop
            p.top = p.top - drop
            place(p.o, p.x, p.base, p.z)
            sound(SOUND_GENERAL_POUND_WOOD_POST, p.o)
            if p.sunk >= pounds_of(ctx) then decide(ctx, WON) end
        end
        p.was = landing
    end,
    status = function(ctx)
        if ctx.verdict == WON then return "Flush", "good" end
        local p = ctx.data.post or { sunk = 0 }
        return OF.lang.fill("Jump on it, then Z - @ of @", tostring(p.sunk),
            tostring(pounds_of(ctx))), "warn"
    end,
})
end

do

local PLAT_AHEAD = 280
local PLAT_HIGH = { 150, 270, 420 }
local PLAT_REACH = 150

local function plat_high(ctx) return PLAT_HIGH[math.min(ctx.level, #PLAT_HIGH)] or 150 end

local function on_platform(m, p)
    if is_air(m) then return false end
    if flat_distance(m.pos.x, m.pos.z, p.x, p.z) > PLAT_REACH then return false end
    return math.abs(m.pos.y - p.top) <= 30
end

add_game({
    key = "getup", shape = "do", floor = 3.0,
    hint = "a platform over the floor - be standing on it at the end",
    word = function() return "GET UP!" end,
    cue = function(ctx)
        local need = ({ "{A}", "{A} {A} - A DOUBLE JUMP", "{A} {A} {A} OR {Z} + {A}" })[
            math.min(ctx.level, 3)]
        return { text = "UP ONTO THE PLATFORM - " .. need }
    end,
    start = function(ctx, m)
        local x, y, z = from_slot(ctx, PLAT_AHEAD, 0)
        local col = gGlobalObjectCollisionData ~= nil
            and gGlobalObjectCollisionData.checkerboard_platform_seg8_collision_0800D710 or nil
        local py = y + plat_high(ctx)
        ctx.data.plat = { x = x, y = py, z = z, top = py, floor = y,
            o = prop(ctx, E_MODEL_CHECKERBOARD_PLATFORM, x, py, z, ctx.slot.yaw, col) }
    end,
    frame = function(ctx, m)
        local p = ctx.data.plat
        if ctx.t == 3 then
            local top = OF.util.optional("find_floor_height", nil, p.x, p.y + 300, p.z)
            if type(top) == "number" and top >= p.y - 60 and top <= p.y + 120 then
                p.top = top
            end
        end
        ctx.data.on = on_platform(m, p)

        if ctx.t >= ctx.playF - 1 then decide(ctx, ctx.data.on and WON or LOST) end
    end,
    draw = function(ctx)
        local p = ctx.data.plat
        if p == nil then return end
        OF.util.zone_ring({ x = p.x, y = p.floor + 4, z = p.z }, PLAT_REACH, 24, 2,
            200, 200, 255, 120)
    end,
    status = function(ctx)
        if ctx.verdict == WON then return "On top", "good" end
        if ctx.verdict == LOST then return "Not on it", "bad" end
        if ctx.data.on then return "On it - stay there", "good" end
        local need = ({ "a jump", "a double jump", "a triple jump or a backflip" })[
            math.min(ctx.level, 3)]
        return OF.lang.fill("Up there - @ reaches it", need), "warn"
    end,
})
end

do

local APART_REACH = 350
local HUDDLE_REACH = 250

local function apart_call(ctx)
    return hash01(ctx.seed, 0, 201) < 0.5 and "apart" or "huddle"
end
X.apart_call = apart_call

local function apart_ok(ctx, m)
    local near = nearest_other(m)
    if apart_call(ctx) == "apart" then return near == nil or near > APART_REACH end
    return near ~= nil and near <= HUDDLE_REACH
end

add_game({
    key = "apart", shape = "do", floor = 3.0, minAlive = 3,
    deckName = "KEEP AWAY! / HUDDLE!",
    hint = "nobody near you - or somebody right beside you, as called",
    word = function(ctx) return apart_call(ctx) == "apart" and "KEEP AWAY!" or "HUDDLE!" end,
    cue = function(ctx)
        if apart_call(ctx) == "apart" then return { text = "GET AWAY FROM EVERYBODY" } end
        return { text = "STAND RIGHT NEXT TO SOMEBODY" }
    end,
    frame = function(ctx, m)
        ctx.data.ok = apart_ok(ctx, m)
        if ctx.t >= ctx.playF - 1 then decide(ctx, ctx.data.ok and WON or LOST) end
    end,
    draw = function(ctx)
        local m = gMarioStates[0]
        if m == nil then return end
        local reach = apart_call(ctx) == "apart" and APART_REACH or HUDDLE_REACH
        local ok = ctx.data.ok
        OF.util.zone_ring({ x = m.pos.x, y = m.pos.y + 4, z = m.pos.z }, reach, 32, 2,
            ok and 140 or 255, ok and 255 or 160, ok and 150 or 120, 150)
    end,
    status = function(ctx)
        if ctx.verdict == WON then return "Done", "good" end
        if ctx.verdict == LOST then return "Not when it counted", "bad" end
        if apart_call(ctx) == "apart" then
            return ctx.data.ok and "Clear - stay clear" or "Somebody is too close", ctx.data.ok and "good" or "warn"
        end
        return ctx.data.ok and "Together - stay there" or "Get next to somebody", ctx.data.ok and "good" or "warn"
    end,
})
end

do

local RING_WIDE, RING_TIGHT = 700, 260
local RING_REACH = 650

local function ring_of(ctx)
    local at = ctx.at
    local a = hash01(ctx.seed, 0, 211) * 2 * math.pi
    local d = hash01(ctx.seed, 0, 212) * RING_REACH
    local x, z = at.x + math.sin(a) * d, at.z + math.cos(a) * d
    return x, floor_under(x, z, at.y), z
end
X.ring_of = ring_of

local function ring_radius(ctx, t)
    local share = math.min(1, t / math.max(1, ctx.playF * 0.85))
    return RING_WIDE + (RING_TIGHT - RING_WIDE) * share
end

add_game({
    key = "ring", shape = "do", floor = 3.0,
    hint = "a ring appears and closes - be inside it at the end",
    word = function() return "STAY IN!" end,
    cue = function(ctx)
        return { text = "RUN INTO THE RING BEFORE IT CLOSES" }
    end,
    frame = function(ctx, m)
        local x, _, z = ring_of(ctx)
        ctx.data.inside = flat_distance(m.pos.x, m.pos.z, x, z) <= ring_radius(ctx, ctx.t)
        if ctx.t >= ctx.playF - 1 then decide(ctx, ctx.data.inside and WON or LOST) end
    end,
    draw = function(ctx)
        local x, y, z = ring_of(ctx)
        local inside = ctx.data.inside
        OF.util.zone_ring({ x = x, y = y + 4, z = z }, ring_radius(ctx, ctx.t), 48, 4,
            inside and 140 or 255, inside and 255 or 220, inside and 150 or 120, 220, "edge")
    end,
    status = function(ctx)
        if ctx.verdict == WON then return "Inside", "good" end
        if ctx.verdict == LOST then return "Outside", "bad" end
        if ctx.data.inside then return "Inside - it is closing", "good" end
        return "Get inside the ring", "warn"
    end,
})
end

do

local QUARTERS = {
    { name = "RED", r = 255, g = 90, b = 90 },
    { name = "BLUE", r = 110, g = 150, b = 255 },
    { name = "GREEN", r = 110, g = 230, b = 120 },
    { name = "YELLOW", r = 255, g = 220, b = 80 },
}
local QUARTER_CORE = 150
local QUARTER_DRAWN = 1200

local function quarter_turn(ctx) return hash01(ctx.seed, 0, 221) * 2 * math.pi end

local function called(ctx)
    return math.floor(hash01(ctx.seed, 0, 222) * #QUARTERS) + 1
end
X.match_called = called

local function quarter_at(ctx, x, z)
    local at = ctx.at
    if flat_distance(x, z, at.x, at.z) < QUARTER_CORE then return nil end
    local a = (math.atan(x - at.x, z - at.z) - quarter_turn(ctx)) % (2 * math.pi)
    return math.floor(a / (math.pi / 2)) % 4 + 1
end
X.quarter_at = quarter_at

local function quarter_point(ctx, q, reach)
    local at = ctx.at
    local a = quarter_turn(ctx) + (q - 0.5) * math.pi / 2
    return at.x + math.sin(a) * reach, at.z + math.cos(a) * reach
end
X.quarter_point = quarter_point

add_game({
    key = "match", shape = "do", floor = 2.5,
    deckName = "MATCH!",
    hint = "four coloured quarters - be on the one called",
    word = function(ctx) return "MATCH " .. QUARTERS[called(ctx)].name .. "!" end,
    cue = function(ctx)
        return { text = OF.lang.fill("RUN ONTO THE @ QUARTER", QUARTERS[called(ctx)].name) }
    end,
    frame = function(ctx, m)
        ctx.data.on = quarter_at(ctx, m.pos.x, m.pos.z)
        if ctx.t >= ctx.playF - 1 then
            decide(ctx, ctx.data.on == called(ctx) and WON or LOST)
        end
    end,
    draw = function(ctx)
        local at = ctx.at
        for q, colour in ipairs(QUARTERS) do
            local a0 = quarter_turn(ctx) + (q - 1) * math.pi / 2
            local from = { x = at.x + math.sin(a0) * QUARTER_CORE, y = at.y + 4,
                z = at.z + math.cos(a0) * QUARTER_CORE }
            local to = { x = at.x + math.sin(a0) * QUARTER_DRAWN, y = at.y + 4,
                z = at.z + math.cos(a0) * QUARTER_DRAWN }
            OF.util.world_line(from, to, 3, 255, 255, 255, 200)

            for k = 0, 5 do
                local b0 = a0 + k / 6 * math.pi / 2
                local b1 = a0 + (k + 1) / 6 * math.pi / 2
                OF.util.world_line(
                    { x = at.x + math.sin(b0) * 700, y = at.y + 4, z = at.z + math.cos(b0) * 700 },
                    { x = at.x + math.sin(b1) * 700, y = at.y + 4, z = at.z + math.cos(b1) * 700 },
                    6, colour.r, colour.g, colour.b, 230)
            end
            local x, z = quarter_point(ctx, q, 700)
            label_at(x, at.y + 150, z, colour.name, colour.r, colour.g, colour.b)
        end
    end,
    status = function(ctx)
        local want = QUARTERS[called(ctx)]
        if ctx.verdict == WON then return OF.lang.fill("On @", want.name), "good" end
        if ctx.verdict == LOST then return OF.lang.fill("Not on @", want.name), "bad" end
        if ctx.data.on == called(ctx) then return OF.lang.fill("On @ - stay", want.name), "good" end
        return OF.lang.fill("Get onto @", want.name), "warn"
    end,
})
end

do

local HALVES = {
    { name = "RED", r = 255, g = 90, b = 90 },
    { name = "BLUE", r = 110, g = 150, b = 255 },
}

local function split_axis(seed)
    local a = hash01(seed, 0, 231) * 2 * math.pi
    return math.sin(a), math.cos(a)
end

local function half_at(at, seed, x, z)
    local nx, nz = split_axis(seed)
    return ((x - at.x) * nx + (z - at.z) * nz) >= 0 and 1 or 2
end
X.half_at = half_at
X.split_axis = split_axis

local function odd_winners(at, seed, players)
    local sides = { {}, {} }
    for _, entry in ipairs(players) do
        local o = gMarioStates[entry.localIndex]
        if o ~= nil then
            table.insert(sides[half_at(at, seed, o.pos.x, o.pos.z)], entry.np.globalIndex)
        end
    end
    local won = {}
    local small = #sides[1] < #sides[2] and 1 or (#sides[2] < #sides[1] and 2 or nil)
    for s = 1, 2 do
        if small == nil or s == small then
            for _, g in ipairs(sides[s]) do won[g] = true end
        end
    end
    return won
end
X.odd_winners = odd_winners

add_game({
    key = "odd", shape = "room", floor = 3.0, minAlive = 4,
    hint = "red half, blue half - the side with fewer players wins",
    word = function() return "ODD ONE OUT!" end,
    cue = function(ctx)
        return { text = "PICK THE HALF FEWER PLAYERS STAND ON" }
    end,
    frame = function(ctx, m) ctx.data.side = half_at(ctx.at, ctx.seed, m.pos.x, m.pos.z) end,
    judge = function(st, players)
        local at = arena_at()
        if at == nil then return {} end
        return odd_winners(at, st.seed, players)
    end,
    draw = function(ctx)
        local at = ctx.at
        local nx, nz = split_axis(ctx.seed)
        local lx, lz = nz, -nx
        OF.util.world_line({ x = at.x - lx * 1400, y = at.y + 4, z = at.z - lz * 1400 },
            { x = at.x + lx * 1400, y = at.y + 4, z = at.z + lz * 1400 }, 4, 255, 255, 255, 220)
        for s, half in ipairs(HALVES) do
            local sign = s == 1 and 1 or -1
            label_at(at.x + nx * 600 * sign, at.y + 150, at.z + nz * 600 * sign,
                half.name, half.r, half.g, half.b)
        end
    end,
    status = function(ctx)
        local half = HALVES[ctx.data.side or 1]
        return OF.lang.fill("You are on @ - fewer wins", half.name), "warn"
    end,
})
end

do

local SEAT_SHARE = 0.75
local SEAT_RING = 550
local SEAT_RADIUS = 120

local function seats_for(alive)
    return math.max(1, math.min(16, math.ceil(alive * SEAT_SHARE)))
end
X.seats_for = seats_for

local function seat_count(seed) return seed % 16 + 1 end

local function seat_points(at, seed)
    local n = seat_count(seed)
    local turn = hash01(seed, 0, 241) * 2 * math.pi
    local list = {}
    for i = 1, n do
        local a = turn + (i - 1) / n * 2 * math.pi
        local x, z = at.x + math.sin(a) * SEAT_RING, at.z + math.cos(a) * SEAT_RING
        table.insert(list, { x = x, y = floor_under(x, z, at.y), z = z })
    end
    return list
end
X.seat_points = seat_points

local function seated_alone(at, seed, players)
    local won = {}
    for _, seat in ipairs(seat_points(at, seed)) do
        local on = {}
        for _, entry in ipairs(players) do
            local o = gMarioStates[entry.localIndex]
            if o ~= nil and flat_distance(o.pos.x, o.pos.z, seat.x, seat.z) <= SEAT_RADIUS then
                table.insert(on, entry.np.globalIndex)
            end
        end
        if #on == 1 then won[on[1]] = true end
    end
    return won
end

add_game({
    key = "seat", shape = "room", floor = 3.0, minAlive = 4,
    hint = "fewer seats than players - be alone on one at the end",
    word = function() return "GET A SEAT!" end,
    cue = function(ctx)
        return { text = "STAND ALONE ON A GOLD SEAT" }
    end,
    seed_for = function(alive, seed)
        return math.floor(seed / 16) * 16 + seats_for(alive) - 1
    end,
    frame = function(ctx, m) end,
    judge = function(st, players)
        local at = arena_at()
        if at == nil then return {} end
        return seated_alone(at, st.seed, players)
    end,
    draw = function(ctx)
        local m = gMarioStates[0]
        for _, seat in ipairs(seat_points(ctx.at, ctx.seed)) do
            local mine = m ~= nil and flat_distance(m.pos.x, m.pos.z, seat.x, seat.z) <= SEAT_RADIUS
            OF.util.zone_ring({ x = seat.x, y = seat.y + 4, z = seat.z }, SEAT_RADIUS, 24, 4,
                mine and 140 or 255, mine and 255 or 215, mine and 150 or 90, 230)
        end
    end,
    status = function(ctx)
        return OF.lang.fill("@ seats - alone on one wins", tostring(seat_count(ctx.seed))), "warn"
    end,
})
end

do

local PICK_RING = 600
local PICK_RADIUS = 160

local function pick_points(at, seed)
    local turn = hash01(seed, 0, 251) * 2 * math.pi
    local list = {}
    for i = 1, 3 do
        local a = turn + (i - 1) / 3 * 2 * math.pi
        local x, z = at.x + math.sin(a) * PICK_RING, at.z + math.cos(a) * PICK_RING
        table.insert(list, { x = x, y = floor_under(x, z, at.y), z = z })
    end
    return list
end
X.pick_points = pick_points

local function pick_of(x, z, points)
    for i, p in ipairs(points) do
        if flat_distance(x, z, p.x, p.z) <= PICK_RADIUS then return i end
    end
    return nil
end

local function pick_winners(at, seed, players, bad)
    local points = pick_points(at, seed)
    local won = {}
    for _, entry in ipairs(players) do
        local o = gMarioStates[entry.localIndex]
        if o ~= nil then
            local on = pick_of(o.pos.x, o.pos.z, points)
            if on ~= nil and on ~= bad then won[entry.np.globalIndex] = true end
        end
    end
    return won
end
X.pick_winners = pick_winners

add_game({
    key = "pick", shape = "room", floor = 3.0, minAlive = 4,
    hint = "three spots, one turns out bad - luck, and rare",
    word = function() return "PICK ONE!" end,
    cue = function(ctx)
        return { text = "STAND ON 1, 2 OR 3 - ONE TURNS OUT BAD" }
    end,
    frame = function(ctx, m)
        ctx.data.on = pick_of(m.pos.x, m.pos.z, pick_points(ctx.at, ctx.seed))
    end,
    judge = function(st, players)
        local at = arena_at()
        if at == nil then return {} end
        return pick_winners(at, st.seed, players, math.random(3))
    end,
    draw = function(ctx)
        for i, p in ipairs(pick_points(ctx.at, ctx.seed)) do
            local mine = ctx.data.on == i
            OF.util.zone_ring({ x = p.x, y = p.y + 4, z = p.z }, PICK_RADIUS, 24, 4,
                mine and 140 or 230, mine and 255 or 230, mine and 150 or 230, 230)
            label_at(p.x, p.y + 140, p.z, tostring(i), 255, 255, 255)
        end
    end,
    status = function(ctx)
        if ctx.data.on == nil then return "Stand on a spot", "warn" end
        return OF.lang.fill("On spot @ - and hope", tostring(ctx.data.on)), "warn"
    end,
})
end

do

local STOP_AHEAD = 260
local STOP_LOW, STOP_TRAVEL = 40, 420
local STOP_BAND_AT = 260
local STOP_BAND = { 38, 30, 24 }
local STOP_PERIOD = 1.4

local function band_of(ctx) return STOP_BAND[math.min(ctx.level, #STOP_BAND)] or 38 end

local function coin_height(ctx, t)
    local period = STOP_PERIOD / ctx.pace * FPS
    return STOP_LOW + STOP_TRAVEL * (0.5 - 0.5 * math.cos(2 * math.pi * t / period))
end
X.stop_height = coin_height
X.stop_band = function(ctx) return STOP_BAND_AT, band_of(ctx) end

add_game({
    key = "stop", shape = "judge", floor = 2.0, holds = true,
    hint = "a coin rides a pole - press A while it is in the gold band",
    word = function() return "STOP!" end,
    cue = function(ctx)
        return { text = "{A} WHEN THE COIN IS IN THE GOLD BAND", hot = { A = true } }
    end,
    start = function(ctx, m)
        local x, y, z = from_slot(ctx, STOP_AHEAD, 0)
        ctx.data.pole = { x = x, y = y, z = z }
        ctx.data.coin = coin_prop(ctx, E_MODEL_YELLOW_COIN, x, y + STOP_LOW, z)
        ctx.data.down = nil
    end,
    frame = function(ctx, m)
        local p = ctx.data.pole
        local h = coin_height(ctx, ctx.t)
        if ctx.verdict == UNDECIDED then
            place(ctx.data.coin, p.x, p.y + h, p.z)
            if not gone(ctx.data.coin) then
                ctx.data.coin.oAnimState = (ctx.data.coin.oAnimState + 1) % 8
            end
        end
        local rose = presses(ctx, m)
        if ctx.verdict ~= UNDECIDED or not rose[A_BUTTON] then return end
        if math.abs(h - STOP_BAND_AT) <= band_of(ctx) then
            sound(SOUND_GENERAL_COIN, ctx.data.coin)
            decide(ctx, WON)
        else
            decide(ctx, LOST)
        end
    end,
    draw = function(ctx)
        local p = ctx.data.pole
        if p == nil then return end
        OF.util.world_line({ x = p.x, y = p.y, z = p.z },
            { x = p.x, y = p.y + STOP_LOW + STOP_TRAVEL + 40, z = p.z }, 3, 180, 180, 180, 200)
        local band = band_of(ctx)
        for _, dy in ipairs({ -band, band }) do
            OF.util.zone_ring({ x = p.x, y = p.y + STOP_BAND_AT + dy, z = p.z }, 60, 20, 3,
                255, 215, 0, 240)
        end
    end,
    status = function(ctx)
        if ctx.verdict == WON then return "Right in the band", "good" end
        if ctx.verdict == LOST then return "Missed the band", "bad" end
        return "A when the coin is between the gold rings", "warn"
    end,
})
end

do

local LOOK_AWAY = 850
local LOOK_LIFT = 320
local LOOK_CONE = math.rad(9)
local LOOK_HOLD = 24

local function look_off(x, y, z)
    local l = gLakituState
    if l == nil or l.pos == nil or l.focus == nil then return nil end
    local vx, vy, vz = l.focus.x - l.pos.x, l.focus.y - l.pos.y, l.focus.z - l.pos.z
    local sx, sy, sz = x - l.pos.x, y - l.pos.y, z - l.pos.z
    local lv = math.sqrt(vx * vx + vy * vy + vz * vz)
    local ls = math.sqrt(sx * sx + sy * sy + sz * sz)
    if lv < 1 or ls < 1 then return nil end
    local dot = (vx * sx + vy * sy + vz * sz) / (lv * ls)
    return math.acos(math.max(-1, math.min(1, dot)))
end
X.look_off = look_off

add_game({
    key = "look", shape = "do", floor = 2.5,
    hint = "a star hangs off to one side - turn the camera onto it and hold",
    word = function() return "LOOK!" end,
    cue = function(ctx)
        return { text = "TURN THE CAMERA - {C-LEFT} {C-RIGHT} - ONTO THE STAR",
            share = math.min(1, (ctx.data.held or 0) / LOOK_HOLD) }
    end,
    start = function(ctx, m)

        local turn = (0.25 + hash01(ctx.seed, ctx.me, 271) * 0.25) * math.pi
        if hash01(ctx.seed, ctx.me, 272) < 0.5 then turn = -turn end
        local a = ctx.slot.yawRad + turn
        local x = m.pos.x + math.sin(a) * LOOK_AWAY
        local z = m.pos.z + math.cos(a) * LOOK_AWAY
        local y = m.pos.y + LOOK_LIFT
        ctx.data.star = { x = x, y = y, z = z, o = prop(ctx, E_MODEL_STAR, x, y, z, 0) }
        ctx.data.held = 0
    end,
    frame = function(ctx, m)
        local st = ctx.data.star
        if not gone(st.o) then st.o.oFaceAngleYaw = (st.o.oFaceAngleYaw + 0x500) % 65536 end
        local off = look_off(st.x, st.y, st.z)
        if off ~= nil and off <= LOOK_CONE then
            ctx.data.held = ctx.data.held + 1
        else
            ctx.data.held = 0
        end
        if ctx.data.held >= LOOK_HOLD then
            sound(SOUND_GENERAL_STAR_APPEARS or SOUND_GENERAL_COIN, nil)
            decide(ctx, WON)
        end
    end,
    status = function(ctx)
        if ctx.verdict == WON then return "Seen", "good" end
        if (ctx.data.held or 0) > 0 then return "Hold it there", "good" end
        return "Turn the camera onto the star", "warn"
    end,
})
end

do

local COUNT_LEAST, COUNT_MOST = 3, 7
local COUNT_RUN = 0.55
local COUNT_AHEAD = 520
local COUNT_SIDE = 900
local COUNT_SPOT_AHEAD, COUNT_SPOT_SIDE, COUNT_SPOT_RADIUS = 230, 300, 110

local function count_of(ctx)
    return COUNT_LEAST + math.floor(hash01(ctx.seed, ctx.me, 281) * (COUNT_MOST - COUNT_LEAST + 1))
end
X.count_of = count_of

local function count_options(ctx)
    local n = count_of(ctx)
    local opts = { n - 1, n, n + 1 }
    local shift = math.floor(hash01(ctx.seed, ctx.me, 282) * 3)
    return { opts[shift % 3 + 1], opts[(shift + 1) % 3 + 1], opts[(shift + 2) % 3 + 1] }
end

local function count_spots(ctx)
    local list = {}
    for i, number in ipairs(count_options(ctx)) do
        local x, y, z = from_slot(ctx, COUNT_SPOT_AHEAD, (i - 2) * COUNT_SPOT_SIDE)
        table.insert(list, { x = x, y = y, z = z, number = number })
    end
    return list
end
X.count_spots = count_spots

local COUNT_BOMB_ANIMS = "bobomb_seg8_anims_0802396C"
local function bombs_of(ctx)
    if ctx.level < 2 then return 0 end
    return ctx.level - 1 + math.floor(hash01(ctx.seed, ctx.me, 283) * 2)
end
X.count_bombs = bombs_of

local function count_queue(ctx)
    local list = {}
    for _ = 1, count_of(ctx) do table.insert(list, "goomba") end
    for j = 1, bombs_of(ctx) do
        local at = math.floor(hash01(ctx.seed, ctx.me, 284 + j) * (#list + 1)) + 1
        table.insert(list, at, "bomb")
    end
    return list
end
X.count_queue = count_queue

add_game({
    key = "count", shape = "do", long = true, floor = 5.0,
    hint = "Goombas run past - stand on the number of them (only the Goombas)",
    word = function(ctx)
        if ctx.level >= 2 then return "COUNT THE GOOMBAS!" end
        return "COUNT!"
    end,
    deckName = "COUNT!",
    cue = function(ctx)
        if (ctx.t or 0) < COUNT_RUN * (ctx.playF or 1) then
            if ctx.level >= 2 then
                return { text = "COUNT THE GOOMBAS", under = "not the Bob-ombs", underTone = "warn" }
            end
            return { text = "COUNT THE GOOMBAS" }
        end
        return { text = "STAND ON YOUR ANSWER" }
    end,
    start = function(ctx, m)
        ctx.data.runners = {}
        for i, kind in ipairs(count_queue(ctx)) do
            local o
            if kind == "bomb" then
                o = prop(ctx, E_MODEL_BLACK_BOBOMB, ctx.slot.x, ctx.slot.y - 3000, ctx.slot.z, 0)
                dress(o, COUNT_BOMB_ANIMS, 0, 2.0)
            else
                o = prop(ctx, E_MODEL_GOOMBA, ctx.slot.x, ctx.slot.y - 3000, ctx.slot.z, 0)
                OF.util.optional("obj_scale", nil, o, 1.5)
                dress(o, "goomba_seg8_anims_0801DA4C", 0, 2.0)
            end
            table.insert(ctx.data.runners, { o = o, i = i, kind = kind })
        end
    end,
    frame = function(ctx, m)
        local n = #ctx.data.runners
        local run = COUNT_RUN * ctx.playF
        for _, r in ipairs(ctx.data.runners) do

            local each = run / (n + 1)
            local k = (ctx.t - (r.i - 1) * each * 0.8) / (each * 1.6)
            if k > 0 and k < 1 then
                local x, y, z = from_slot(ctx, COUNT_AHEAD, -COUNT_SIDE + 2 * COUNT_SIDE * k)
                place(r.o, x, y, z)
                if not gone(r.o) then r.o.oFaceAngleYaw = (ctx.slot.yaw + 0x4000) % 65536 end
            else
                place(r.o, ctx.slot.x, ctx.slot.y - 3000, ctx.slot.z)
            end
        end
        if ctx.t >= ctx.playF - 1 then
            local answer = nil
            for _, spot in ipairs(count_spots(ctx)) do
                if flat_distance(m.pos.x, m.pos.z, spot.x, spot.z) <= COUNT_SPOT_RADIUS then
                    answer = spot.number
                end
            end
            decide(ctx, answer == count_of(ctx) and WON or LOST)
        end
    end,
    draw = function(ctx)
        if ctx.t < COUNT_RUN * ctx.playF then return end
        for _, spot in ipairs(count_spots(ctx)) do
            OF.util.zone_ring({ x = spot.x, y = spot.y + 4, z = spot.z }, COUNT_SPOT_RADIUS,
                24, 3, 230, 230, 230, 220)
            label_at(spot.x, spot.y + 120, spot.z, tostring(spot.number), 255, 255, 255)
        end
    end,
    status = function(ctx)
        if ctx.verdict == WON then return "Counted right", "good" end
        if ctx.verdict == LOST then return OF.lang.fill("It was @", tostring(count_of(ctx))), "bad" end
        if ctx.t < COUNT_RUN * ctx.playF then return "Count them", "warn" end
        return "Stand on the number", "warn"
    end,
})
end

do

local BALL_RADIUS, BALL_TALL = 100, 150
local BOWL_PEN = 240
local BOWL_FROM = 1000
local BOWL_SPEED = 34
local BOWL_FIRST = 0.12
local BOWL_GAP = 14
X.BOWL_PEN, X.BOWL_FROM = BOWL_PEN, BOWL_FROM

local function balls_of(ctx) return math.min(4, 1 + ctx.level) end
X.balls_of = balls_of

local function bowled_at(ctx, i)
    local n = balls_of(ctx)
    local speed = BOWL_SPEED * (ctx.pace or 1)
    local travel = 2 * BOWL_FROM / speed
    local first = BOWL_FIRST * ctx.playF
    local room = ctx.playF - first - travel * 0.6
    local gap = n > 1 and math.max(BOWL_GAP, room / (n - 1)) or 0
    return math.floor(first + (i - 1) * gap)
end
X.bowled_at = bowled_at

local function ball_at(ctx, i, t)
    local b = ctx.data.balls ~= nil and ctx.data.balls[i] or nil
    if b == nil or b.ax == nil then return nil end
    local speed = BOWL_SPEED * (ctx.pace or 1)
    local along = -BOWL_FROM + (t - b.at) * speed
    if along > BOWL_FROM then return nil end
    local x = b.ax + b.dx * along
    local z = b.az + b.dz * along
    return x, floor_under(x, z, ctx.slot.y), z
end
X.ball_at = ball_at

add_game({
    key = "bowling", shape = "survive", floor = 2.5, keepsRunning = true,
    hint = "bowling balls come at you from both sides - step out of the line or jump",
    word = function() return "BOWLING!" end,
    cue = function(ctx)
        return { text = "STEP OUT OF ITS LINE OR {A} OVER IT", hot = { A = true } }
    end,
    start = function(ctx, m)
        ctx.lock = { x = ctx.slot.x, z = ctx.slot.z, y = ctx.slot.y, r = BOWL_PEN }
        ctx.data.balls = {}
        local s = ctx.slot
        local lx, lz = math.cos(s.yawRad), -math.sin(s.yawRad)
        for i = 1, balls_of(ctx) do
            local o = prop(ctx, E_MODEL_BOWLING_BALL, s.x, s.y - 3000, s.z, 0)
            if o ~= nil then
                OF.util.optional("obj_set_billboard", nil, o)
                o.oGraphYOffset = 130
            end

            local side = (i % 2 == 1) and 1 or -1
            if hash01(ctx.seed, ctx.me, 311) < 0.5 then side = -side end
            table.insert(ctx.data.balls, { o = o, at = bowled_at(ctx, i),
                dx = lx * side, dz = lz * side })
        end
    end,
    frame = function(ctx, m)
        for i, b in ipairs(ctx.data.balls) do
            if b.ax == nil and ctx.t >= b.at then

                b.ax, b.az = m.pos.x, m.pos.z
                sound(SOUND_OBJ_POUNDING_CANNON, nil)
            end
            local x, y, z = ball_at(ctx, i, ctx.t)
            if x == nil then
                place(b.o, ctx.slot.x, ctx.slot.y - 3000, ctx.slot.z)
            else
                place(b.o, x, y, z)
                OF.gamemodes.round_sound_throttled("fzbowl" .. i, 12,
                    SOUND_GENERAL_QUIET_POUND1 or SOUND_GENERAL_BOING1, b.o)
                if ctx.verdict == UNDECIDED
                    and flat_distance(m.pos.x, m.pos.z, x, z) <= BALL_RADIUS + MARIO_RADIUS
                    and m.pos.y < y + BALL_TALL and body_top(m) > y then
                    decide(ctx, LOST)
                end
            end
        end
    end,
    status = function(ctx)
        if ctx.verdict == LOST then return "Bowled over", "bad" end
        return "Out of its line, or over it", "warn"
    end,
})
end

do

local KICK_BALL_RADIUS = 70
local KICK_BALL_AHEAD = 260
local KICK_GOAL_AHEAD = 680
local KICK_GOAL = { { radius = 170, side = 0 }, { radius = 140, side = 200 },
    { radius = 115, side = 300 } }
local KICK_FRICTION = 0.97
local KICK_NUDGE, KICK_SHOT = 1.3, 45

local function kick_goal(ctx)
    local g = KICK_GOAL[math.min(ctx.level, #KICK_GOAL)]
    local side = g.side
    if side ~= 0 and hash01(ctx.seed, ctx.me, 301) < 0.5 then side = -side end
    local x, y, z = from_slot(ctx, KICK_GOAL_AHEAD, side)
    return x, y, z, g.radius
end
X.kick_goal = kick_goal

local KEEPER_SCALE, KEEPER_RADIUS, KEEPER_LAP = 1.5, 70, 1.8

local function keeper_at(ctx, t)
    local gx, _, gz, gr = kick_goal(ctx)
    local s = ctx.slot
    local fx, fz = math.sin(s.yawRad), math.cos(s.yawRad)
    local lap = KEEPER_LAP / ctx.pace * FPS
    local across = math.sin(2 * math.pi * t / lap) * (gr + 60)
    local x = gx - fx * (gr + KEEPER_RADIUS) + fz * across
    local z = gz - fz * (gr + KEEPER_RADIUS) - fx * across
    return x, floor_under(x, z, s.y), z
end
X.keeper_at = keeper_at
X.KEEPER_RADIUS = KEEPER_RADIUS

add_game({
    key = "kick", shape = "do", long = true, floor = 4.0,
    hint = "a ball and a goal ring - kick the ball into the ring",
    word = function() return "KICK!" end,
    cue = function(ctx)
        return { text = "RUN INTO IT - {B} KICKS IT - INTO THE GREEN RING" }
    end,
    start = function(ctx, m)
        local x, y, z = from_slot(ctx, KICK_BALL_AHEAD, 0)
        local model, scale = E_MODEL_BOWLING_BALL, 0.7
        if OF.util.asks(OF.ball, "model") then model, scale = OF.ball.model(KICK_BALL_RADIUS) end
        local b = { x = x, z = z, y = y, vx = 0, vz = 0, roll = 0 }
        b.o = prop(ctx, model, x, y + KICK_BALL_RADIUS, z, 0)
        OF.util.optional("obj_scale", nil, b.o, scale)
        ctx.data.ball = b
        if ctx.level >= 3 then
            local gx, gy, gz = kick_goal(ctx)
            local o = prop(ctx, E_MODEL_GOOMBA, gx, gy, gz, ctx.slot.yaw)
            OF.util.optional("obj_scale", nil, o, KEEPER_SCALE)
            dress(o, "goomba_seg8_anims_0801DA4C", 0, 1.5)
            ctx.data.keeper = { o = o, x = gx, y = gy, z = gz }
        end
    end,
    frame = function(ctx, m)
        local b = ctx.data.ball
        local k = ctx.data.keeper
        if k ~= nil then
            k.x, k.y, k.z = keeper_at(ctx, ctx.t)
            place(k.o, k.x, k.y, k.z)

            local kd = flat_distance(b.x, b.z, k.x, k.z)
            if kd < KICK_BALL_RADIUS + KEEPER_RADIUS then
                local nx, nz = (b.x - k.x) / math.max(kd, 1), (b.z - k.z) / math.max(kd, 1)
                local along = b.vx * nx + b.vz * nz
                if along < 0 then
                    b.vx, b.vz = b.vx - 2 * along * nx, b.vz - 2 * along * nz
                    sound(SOUND_GENERAL_BOING1, k.o)
                    ctx.data.saved = (ctx.data.saved or 0) + 1
                end
                b.x = k.x + nx * (KICK_BALL_RADIUS + KEEPER_RADIUS)
                b.z = k.z + nz * (KICK_BALL_RADIUS + KEEPER_RADIUS)
            end
        end

        local d = flat_distance(m.pos.x, m.pos.z, b.x, b.z)
        local reach = KICK_BALL_RADIUS + MARIO_RADIUS + 10
        if d < reach and m.pos.y < b.y + KICK_BALL_RADIUS * 2 and body_top(m) > b.y then
            local dx, dz = (b.x - m.pos.x) / math.max(d, 1), (b.z - m.pos.z) / math.max(d, 1)
            local speed = math.max(math.abs(m.forwardVel or 0) * KICK_NUDGE, 12)
            if OF.util.has_flag(m.action or 0, ACT_FLAG_ATTACKING or 0) then
                speed = math.max(speed, KICK_SHOT)
                if not ctx.data.thud then
                    ctx.data.thud = true
                    sound(SOUND_ACTION_HIT or SOUND_GENERAL_BOING1, b.o)
                end
            end
            b.vx, b.vz = dx * speed, dz * speed

            b.x, b.z = m.pos.x + dx * reach, m.pos.z + dz * reach
        else
            ctx.data.thud = false
        end
        b.x, b.z = b.x + b.vx, b.z + b.vz
        b.vx, b.vz = b.vx * KICK_FRICTION, b.vz * KICK_FRICTION
        b.y = floor_under(b.x, b.z, ctx.slot.y)
        local moving = math.sqrt(b.vx * b.vx + b.vz * b.vz)
        b.roll = (b.roll + moving * 300) % 65536
        place(b.o, b.x, b.y + KICK_BALL_RADIUS, b.z)
        if not gone(b.o) then
            b.o.oFaceAnglePitch = math.floor(b.roll)
            if moving > 0.5 then b.o.oFaceAngleYaw = yaw_to(0, 0, b.vx, b.vz) end
        end
        local gx, _, gz, gr = kick_goal(ctx)
        if flat_distance(b.x, b.z, gx, gz) <= gr then
            sound(SOUND_GENERAL_COIN, b.o)
            decide(ctx, WON)
        end
    end,
    draw = function(ctx)
        local gx, gy, gz, gr = kick_goal(ctx)
        OF.util.zone_ring({ x = gx, y = gy + 4, z = gz }, gr, 32, 4, 140, 255, 150, 230)
    end,
    status = function(ctx)
        if ctx.verdict == WON then return "Goal", "good" end
        if (ctx.data.saved or 0) > 0 then return "Saved - time it past the keeper", "warn" end
        if ctx.data.keeper ~= nil then return "Past the keeper, into the green ring", "warn" end
        return "Into the green ring - kick it with B", "warn"
    end,
})
end

do

local SNEAK_BOO_AHEAD, SNEAK_STAR_AHEAD = 330, 640
local SNEAK_LIFT, SNEAK_STAR_LIFT = 150, 90
local SNEAK_STAR_REACH = 100

local SNEAK_AWAY = { 34, 26, 20 }
local SNEAK_TURN, SNEAK_LOOK = 8, 24

local SNEAK_GRACE = 5
local SNEAK_STILL = 3

local SNEAK_PUSH = 6

local function sneak_phase(ctx, t)
    local away0 = SNEAK_AWAY[math.min(ctx.level, #SNEAK_AWAY)] / ctx.pace
    local turn = math.max(5, SNEAK_TURN / ctx.pace)
    local look = math.max(14, SNEAK_LOOK / ctx.pace)
    local at = 0
    for k = 1, 60 do
        local away = away0 * (0.7 + 0.6 * hash01(ctx.seed, ctx.me, 400 + k))
        if t < at + away then return "away", t - at end
        at = at + away
        if t < at + turn then return "turn", t - at end
        at = at + turn
        if t < at + look then return "look", t - at end
        at = at + look
    end
    return "away", 0
end
X.sneak_phase = sneak_phase

add_game({
    key = "sneak", shape = "do", long = true, floor = 6.0, keepsRunning = true,
    hint = "a Boo between you and a star - move while it looks away, freeze when it looks",
    word = function() return "SNEAK!" end,
    cue = function(ctx)
        local phase = sneak_phase(ctx, ctx.t or 0)
        if ctx.verdict ~= UNDECIDED then return { text = "SNEAK!" } end
        if phase == "away" then return { text = "GO - CREEP UP TO THE STAR" } end
        return { text = "FREEZE!", size = "headline" }
    end,
    start = function(ctx, m)
        local bx, by, bz = from_slot(ctx, SNEAK_BOO_AHEAD, 0)
        local sx, sy, sz = from_slot(ctx, SNEAK_STAR_AHEAD, 0)
        ctx.data.boo = { x = bx, y = by + SNEAK_LIFT, z = bz,
            o = prop(ctx, E_MODEL_BOO, bx, by + SNEAK_LIFT, bz, ctx.slot.yaw) }
        ctx.data.star = { x = sx, y = sy + SNEAK_STAR_LIFT, z = sz,
            o = prop(ctx, E_MODEL_STAR, sx, sy + SNEAK_STAR_LIFT, sz, 0) }
        ctx.data.lastX, ctx.data.lastZ = m.pos.x, m.pos.z
    end,
    frame = function(ctx, m)
        local d = ctx.data
        local phase, into = sneak_phase(ctx, ctx.t)
        local b = d.boo

        if not gone(b.o) then
            local away = ctx.slot.yaw
            local toward = (ctx.slot.yaw + 32768) % 65536
            local yaw, opacity = away, 120
            if phase == "turn" then
                local k = into / math.max(5, SNEAK_TURN / ctx.pace)
                yaw = math.floor(away + 32768 * k) % 65536
                opacity = math.floor(120 + 135 * k)
            elseif phase == "look" then
                yaw, opacity = toward, 255
            end
            b.o.oFaceAngleYaw = yaw
            b.o.oOpacity = opacity
            place(b.o, b.x, b.y + math.sin(ctx.t * 0.12) * 18, b.z)
        end
        if phase == "look" and d.was ~= "look" then
            sound(SOUND_OBJ_BOO_LAUGH_SHORT or SOUND_GENERAL_BOING1, b.o)
        end
        d.was = phase
        if not gone(d.star.o) then
            d.star.o.oFaceAngleYaw = (d.star.o.oFaceAngleYaw + 0x600) % 65536
        end
        local moved = flat_distance(m.pos.x, m.pos.z, d.lastX or m.pos.x, d.lastZ or m.pos.z)
        local speed = math.abs(m.forwardVel or 0)
        local coasting = speed < (d.lastSpeed or speed) - 0.01
        d.lastX, d.lastZ, d.lastSpeed = m.pos.x, m.pos.z, speed
        if ctx.verdict ~= UNDECIDED then return end

        local pushing = (m.intendedMag or 0) > SNEAK_PUSH
        if phase == "look" and into >= SNEAK_GRACE
            and (pushing or is_air(m) or (moved > SNEAK_STILL and not coasting)) then
            d.seen = true
            sound(SOUND_OBJ_BOO_LAUGH_LONG or SOUND_GENERAL_BOING1, b.o)
            decide(ctx, LOST)
            return
        end
        local st = d.star
        if flat_distance(m.pos.x, m.pos.z, st.x, st.z) <= SNEAK_STAR_REACH
            and st.y >= m.pos.y - 40 and st.y <= body_top(m) + 60 then
            retire(ctx, st.o, POOF_ME)
            decide(ctx, WON)
        end
    end,
    draw = function(ctx)
        local m = gMarioStates[0]
        if m == nil or ctx.verdict ~= UNDECIDED then return end
        local phase = sneak_phase(ctx, ctx.t)
        if phase ~= "away" then

            OF.util.zone_ring({ x = m.pos.x, y = m.pos.y + 4, z = m.pos.z }, 90, 20, 3,
                255, 90, 90, phase == "look" and 230 or 120)
        end
    end,
    status = function(ctx)
        if ctx.verdict == WON then return "Not a sound", "good" end
        if ctx.verdict == LOST then return "It saw you move", "bad" end
        if sneak_phase(ctx, ctx.t) == "away" then return "Its back is turned - go", "good" end
        return "It is looking - do not move", "bad"
    end,
})
end

do

local MEMO_KEYS = { PRESS_BUTTONS[6], PRESS_BUTTONS[7], PRESS_BUTTONS[8], PRESS_BUTTONS[9] }
local MEMO_LENGTH = { 3, 4, 5 }

local MEMO_SHOW, MEMO_GAP = 16, 5

local function memo_list(ctx)
    local list = {}
    for i = 1, MEMO_LENGTH[math.min(ctx.level, #MEMO_LENGTH)] do
        local pick = math.floor(hash01(ctx.seed, ctx.me, 420 + i) * #MEMO_KEYS) + 1

        if i > 1 and MEMO_KEYS[pick] == list[i - 1] then pick = pick % #MEMO_KEYS + 1 end
        list[i] = MEMO_KEYS[pick]
    end
    return list
end
X.memo_list = memo_list

local function memo_step(ctx)
    return math.max(9, math.floor(MEMO_SHOW / ctx.pace)), math.max(3, math.floor(MEMO_GAP / ctx.pace))
end

local function memo_showing(ctx, t)
    local show, gap = memo_step(ctx)
    local list = memo_list(ctx)
    local k = math.floor(t / (show + gap)) + 1
    if k > #list then return nil, true end
    if t - (k - 1) * (show + gap) < show then return k, false end
    return nil, false
end
X.memo_showing = memo_showing

add_game({
    key = "remember", shape = "judge", long = true, floor = 6.0, holds = true,
    hint = "C buttons light up one by one - then press them back in the same order",
    word = function() return "REMEMBER!" end,
    cue = function(ctx)
        local list = memo_list(ctx)
        if not ctx.started then return { text = "WATCH THE C BUTTONS" } end
        local k, over = memo_showing(ctx, ctx.t or 0)
        if not over then
            if k == nil then return { text = "...", pips = { 0, #list } } end
            return { text = "{" .. list[k].name .. "}", hot = { [list[k].name] = true },
                size = "headline", pips = { k, #list } }
        end
        local at = ctx.data.at or 1
        return { text = "YOUR TURN - IN THE SAME ORDER", pips = { at - 1, #list } }
    end,
    start = function(ctx, m) ctx.data.down = nil ctx.data.at = 1 ctx.data.lastShown = nil end,
    frame = function(ctx, m)
        local list = memo_list(ctx)
        local k, over = memo_showing(ctx, ctx.t)
        if k ~= nil and k ~= ctx.data.lastShown then
            sound(SOUND_MENU_CHANGE_SELECT or SOUND_GENERAL_COIN, nil)
        end
        ctx.data.lastShown = k
        local rose = presses(ctx, m)
        if not over or next(rose) == nil then return end
        local want = list[ctx.data.at]
        if want == nil or not rose[want.flag] then decide(ctx, LOST) return end
        ctx.data.at = ctx.data.at + 1
        if ctx.data.at > #list then
            decide(ctx, WON)
        else
            sound(SOUND_GENERAL_COIN, nil)
        end
    end,
    status = function(ctx)
        if ctx.verdict == WON then return "Every one", "good" end
        if ctx.verdict == LOST then return "Not that one", "bad" end
        local _, over = memo_showing(ctx, ctx.t)
        if not over then return "Watch", "warn" end
        return "Play it back", "warn"
    end,
})
end

do

local RUN_FROM = 420
local RUN_SPEED = 7
local RUN_BLAST = 380
local RUN_GOES = 0.8
local RUN_BOMB_ANIMS = "bobomb_seg8_anims_0802396C"
local BLAST_FRAMES, BLAST_SCALE = 9, 4.0

local function bombs_for(ctx) return math.min(ctx.level, 3) end

local function run_start(ctx, i, n)
    local side = n == 1 and 0 or ((i - 1) / (n - 1) - 0.5) * 2 * 380
    return from_slot(ctx, RUN_FROM, side)
end

add_game({
    key = "run", shape = "survive", floor = 3.0, keepsRunning = true,
    hint = "lit Bob-ombs walk at you - be out of the blast when they go off",
    word = function() return "RUN!" end,

    lockRadius = 900,
    cue = function(ctx)
        return { text = "RUN - OUT OF THE RED RINGS BEFORE THEY BLOW",
            share = math.max(0, 1 - (ctx.t or 0) / math.max(1, RUN_GOES * (ctx.playF or 1))) }
    end,
    start = function(ctx, m)
        ctx.data.bombs = {}
        local n = bombs_for(ctx)
        for i = 1, n do
            local x, y, z = run_start(ctx, i, n)
            local o = prop(ctx, E_MODEL_BLACK_BOBOMB, x, y, z, (ctx.slot.yaw + 32768) % 65536)
            dress(o, RUN_BOMB_ANIMS, 0, 2.0)
            table.insert(ctx.data.bombs, { o = o, x = x, y = y, z = z })
        end
    end,
    frame = function(ctx, m)
        local d = ctx.data
        local goes = math.floor(RUN_GOES * ctx.playF)
        for i, b in ipairs(d.bombs) do
            if ctx.t < goes then

                local yaw = yaw_to(b.x, b.z, m.pos.x, m.pos.z)
                local rad = yaw * math.pi / 32768
                b.x = b.x + math.sin(rad) * RUN_SPEED * ctx.pace
                b.z = b.z + math.cos(rad) * RUN_SPEED * ctx.pace
                b.y = floor_under(b.x, b.z, ctx.slot.y)
                place(b.o, b.x, b.y, b.z)
                if not gone(b.o) then b.o.oFaceAngleYaw = yaw end
                OF.gamemodes.round_sound_throttled("fzfuse" .. i, 15,
                    SOUND_AIR_BOBOMB_LIT_FUSE or SOUND_GENERAL_BOING1, b.o)
            elseif not b.blown then

                b.blown = true
                retire(ctx, b.o, GO_ME)
                b.blast = prop(ctx, E_MODEL_EXPLOSION, b.x, b.y + 60, b.z, 0)
                OF.util.optional("obj_set_billboard", nil, b.blast)
                OF.util.optional("obj_scale", nil, b.blast, BLAST_SCALE)
                b.at = ctx.t
                if i == 1 then
                    sound(SOUND_GENERAL2_BOBOMB_EXPLOSION or SOUND_GENERAL_BOWSER_BOMB_EXPLOSION, nil)
                    OF.util.optional("set_camera_shake_from_point", nil,
                        SHAKE_POS_MEDIUM or 2, b.x, b.y, b.z)
                end
                if ctx.verdict == UNDECIDED
                    and flat_distance(m.pos.x, m.pos.z, b.x, b.z) <= RUN_BLAST then
                    d.caught = true
                    decide(ctx, LOST)
                end
            elseif b.blast ~= nil and not gone(b.blast) then
                local f = math.floor((ctx.t - b.at) / 2)
                if f >= BLAST_FRAMES then
                    retire(ctx, b.blast, GO_ME)
                    b.blast = nil
                else
                    b.blast.oAnimState = f
                end
            end
        end
    end,
    draw = function(ctx)
        local goes = RUN_GOES * ctx.playF
        if ctx.t >= goes then return end

        local burn = math.min(1, ctx.t / math.max(1, goes))
        for _, b in ipairs(ctx.data.bombs or {}) do
            OF.util.zone_ring({ x = b.x, y = b.y + 4, z = b.z }, RUN_BLAST, 32, 3,
                255, math.floor(200 - 120 * burn), 90, math.floor(120 + 120 * burn))
        end
    end,
    status = function(ctx)
        if ctx.verdict == LOST then return "Blown up", "bad" end
        if ctx.t >= RUN_GOES * ctx.playF then return "Clear of the blast", "good" end
        return "Away from them - out of the red rings", "warn"
    end,
})
X.RUN_BLAST, X.RUN_GOES = RUN_BLAST, RUN_GOES
end

do

local MORE_AHEAD, MORE_SIDE, MORE_RING = 300, 340, 180
local MORE_LEAST = 4

local function more_piles(ctx)
    local gap = ctx.level >= 2 and 1 or 2
    local small = MORE_LEAST + math.floor(hash01(ctx.seed, ctx.me, 440) * 5)
    local big = small + gap
    local bigLeft = hash01(ctx.seed, ctx.me, 441) < 0.5
    local function pile(worth, salt)
        local list = {}
        if ctx.level >= 3 then

            local reds = math.min(3, math.floor(hash01(ctx.seed, ctx.me, salt) * 4))
            reds = math.min(reds, math.floor(worth / 2))
            for _ = 1, reds do table.insert(list, { red = true }) end
            for _ = 1, worth - reds * 2 do table.insert(list, { red = false }) end
        else
            for _ = 1, worth do table.insert(list, { red = false }) end
        end
        return list
    end
    local left = pile(bigLeft and big or small, 442)
    local right = pile(bigLeft and small or big, 443)
    return left, right, bigLeft and 1 or 2
end
X.more_piles = more_piles

local function more_worth(list)
    local n = 0
    for _, c in ipairs(list) do n = n + (c.red and 2 or 1) end
    return n
end
X.more_worth = more_worth

local function more_spot(ctx, side)
    return from_slot(ctx, MORE_AHEAD, side == 1 and -MORE_SIDE or MORE_SIDE)
end
X.more_spot = more_spot

add_game({
    key = "more", shape = "do", floor = 3.0,
    hint = "two piles of coins - stand by the bigger one (a red coin counts two at the top level)",
    word = function(ctx) return ctx.level >= 3 and "MORE MONEY!" or "MORE!" end,
    deckName = "MORE!",
    cue = function(ctx)
        return { text = "STAND IN THE RING BY THE BIGGER PILE",
            under = ctx.level >= 3 and "a red coin is worth two" or nil, underTone = "warn" }
    end,
    start = function(ctx, m)
        local left, right = more_piles(ctx)
        ctx.data.coins = {}
        for side, list in ipairs({ left, right }) do
            local cx, cy, cz = more_spot(ctx, side)
            for i, c in ipairs(list) do

                local ring = math.floor((i - 1) / 6)
                local a = (i - 1) % 6 / 6 * 2 * math.pi + hash01(ctx.seed, ctx.me, 450 + side) * 6
                local r = ring == 0 and 55 or 105
                local x, z = cx + math.sin(a) * r, cz + math.cos(a) * r
                local y = cy + 40 + ring * 45 + (i % 2) * 12
                local o = coin_prop(ctx, c.red and E_MODEL_RED_COIN or E_MODEL_YELLOW_COIN, x, y, z)
                table.insert(ctx.data.coins, { o = o })
            end
        end
    end,
    frame = function(ctx, m)
        for _, c in ipairs(ctx.data.coins) do
            if not gone(c.o) then c.o.oAnimState = (c.o.oAnimState + 1) % 8 end
        end
        local _, _, winner = more_piles(ctx)
        local on = nil
        for side = 1, 2 do
            local x, _, z = more_spot(ctx, side)
            if flat_distance(m.pos.x, m.pos.z, x, z) <= MORE_RING then on = side end
        end
        ctx.data.on = on
        if ctx.t >= ctx.playF - 1 then decide(ctx, on == winner and WON or LOST) end
    end,
    draw = function(ctx)
        for side = 1, 2 do
            local x, y, z = more_spot(ctx, side)
            local mine = ctx.data.on == side
            OF.util.zone_ring({ x = x, y = y + 4, z = z }, MORE_RING, 28, 3,
                mine and 140 or 230, mine and 255 or 230, mine and 150 or 230, 220)
        end
    end,
    status = function(ctx)
        if ctx.verdict == WON then return "The bigger pile", "good" end
        if ctx.verdict == LOST then return "Not the bigger pile", "bad" end
        if ctx.data.on == nil then return "Into a ring by one pile", "warn" end
        return "Judged at the end", "warn"
    end,
})
end

do

local RED_COUNT = 8
local RED_NEAR, RED_FAR = 300, 1250

local function red_spots(ctx, count)
    local at = ctx.at
    local spots = {}
    count = count or RED_COUNT
    for i = 1, count do
        for try = 0, 5 do
            local angle = (i - 1) / count * 2 * math.pi
                + (hash01(ctx.seed, ctx.me, 80 + i * 7 + try) - 0.5) * 0.6
            local reach = RED_FAR - (RED_FAR - RED_NEAR) * (try / 5)
                * hash01(ctx.seed, ctx.me, 90 + i)
            if i % 2 == 0 then reach = RED_NEAR + (reach - RED_NEAR) * 0.55 end
            local x = at.x + math.sin(angle) * reach
            local z = at.z + math.cos(angle) * reach
            local y = OF.util.optional("find_floor_height", nil, x, at.y + 400, z)
            if type(y) == "number" and y > at.y - 300 and y < at.y + 500 then
                table.insert(spots, { x = x, y = y + 60, z = z })
                break
            end
        end
    end
    return spots
end

local RUSH_NEAR, RUSH_FAR = 350, 1150
local RUSH_LAP = 7.0
local RUSH_GRACE = 45
local RUSH_TAKES = 2
local RUSH_LIFT = 200
local AMP_LIFT, AMP_REACH, AMP_ANIMS = X.AMP_LIFT, X.AMP_REACH, X.AMP_ANIMS

local function rush_amps(ctx) return 2 + math.min(ctx.level, 3) end

local function rush_amp_at(ctx, i, t)
    local n = rush_amps(ctx)
    local at = ctx.at
    local r = RUSH_NEAR + (RUSH_FAR - RUSH_NEAR) * (i - 1) / math.max(1, n - 1)
    local lap = (RUSH_LAP - i * 0.5) * (ctx.level >= 3 and 0.8 or 1.0) * FPS
    local way = i % 2 == 0 and -1 or 1
    local a = hash01(ctx.seed, 0, 500 + i) * 2 * math.pi + way * 2 * math.pi * t / lap
    local x, z = at.x + math.sin(a) * r, at.z + math.cos(a) * r
    return x, floor_under(x, z, at.y) + AMP_LIFT, z
end
X.rush_amp_at, X.rush_amps = rush_amp_at, rush_amps

add_game({
    key = "redcoins", shape = "boss",
    hint = "the boss - eight red coins of your own over the arena, Amps on guard",
    word = function() return "RED COIN RUSH!" end,
    cue = function(ctx)
        local got = 0
        for _, coin in ipairs(ctx.data.coins or {}) do if coin.got then got = got + 1 end end
        return { text = "RUN TO EVERY RED COIN - KEEP OFF THE AMPS",
            pips = { got, #(ctx.data.coins or {}) },
            under = "an Amp takes two coins back", underTone = "warn" }
    end,
    start = function(ctx, m)
        local d = ctx.data

        d.coins, d.order, d.amps, d.grace, d.zapped = {}, {}, {}, RUSH_GRACE, 0
        for i, spot in ipairs(red_spots(ctx)) do
            if ctx.level >= 2 and i % 3 == 0 then spot.y = spot.y + RUSH_LIFT end
            spot.o = coin_prop(ctx, E_MODEL_RED_COIN, spot.x, spot.y, spot.z)
            table.insert(d.coins, spot)
        end
        for i = 1, rush_amps(ctx) do
            local x, y, z = rush_amp_at(ctx, i, 0)
            local o = prop(ctx, E_MODEL_AMP, x, y, z, 0)
            dress(o, AMP_ANIMS, 0, 1.0)
            table.insert(d.amps, { o = o, x = x, y = y, z = z })
        end
    end,
    frame = function(ctx, m)
        local d = ctx.data

        for _, coin in ipairs(d.coins) do
            local had = coin.got
            if not had then
                coins_frame(ctx, m, { coin }, SOUND_GENERAL_RED_COIN)
                if coin.got then table.insert(d.order, coin) end
            end
        end
        d.grace = math.max(0, d.grace - 1)
        for i, amp in ipairs(d.amps) do
            amp.x, amp.y, amp.z = rush_amp_at(ctx, i, ctx.t)
            place(amp.o, amp.x, amp.y, amp.z)
            if not gone(amp.o) then amp.o.oFaceAngleYaw = yaw_to(amp.x, amp.z, m.pos.x, m.pos.z) end
            if d.grace == 0 and ctx.verdict == UNDECIDED
                and flat_distance(amp.x, amp.z, m.pos.x, m.pos.z) <= AMP_REACH
                and amp.y + 40 >= m.pos.y and amp.y - 40 <= body_top(m) then

                d.grace = RUSH_GRACE
                d.zapped = d.zapped + 1
                for _ = 1, RUSH_TAKES do
                    local coin = table.remove(d.order)
                    if coin ~= nil then
                        coin.got = false
                        coin.o = coin_prop(ctx, E_MODEL_RED_COIN, coin.x, coin.y, coin.z)
                    end
                end
                OF.util.optional("set_mario_action", nil, m, ACT_BACKWARD_AIR_KB, 0)
                m.vel.y, m.forwardVel = 30, -28
                sound(SOUND_AIR_AMP_BUZZ or SOUND_GENERAL_BOING1, amp.o)
                OF.gamemodes.cue("bad", nil, "fzzapped")
            end
        end
        if #d.order >= #d.coins and #d.coins > 0 then decide(ctx, WON) end
    end,
    draw = function(ctx)
        for _, coin in ipairs(ctx.data.coins or {}) do
            if not coin.got then
                OF.util.zone_ring({ x = coin.x, y = floor_under(coin.x, coin.z, coin.y) + 4,
                    z = coin.z }, 60, 16, 2, 255, 90, 90, 170)
            end
        end
    end,
    status = function(ctx)
        local got = #(ctx.data.order or {})
        if ctx.verdict == WON then return "All eight - a life back", "good" end
        if (ctx.data.grace or 0) > 0 then return "Zapped - two coins went back", "bad" end
        return OF.lang.fill("@ of @ red coins", tostring(got), tostring(#(ctx.data.coins or {}))), "warn"
    end,
})

local RED_SMALL = 5

add_game({
    key = "reds", shape = "do", long = true, floor = 6.0,
    hint = "five red coins of your own across the arena - get them all",
    word = function() return "RED COINS!" end,
    cue = function(ctx)
        local got = 0
        for _, coin in ipairs(ctx.data.coins or {}) do if coin.got then got = got + 1 end end
        return { text = "RUN TO EVERY RED COIN", pips = { got, #(ctx.data.coins or {}) } }
    end,
    start = function(ctx, m)
        ctx.data.coins = {}
        for _, spot in ipairs(red_spots(ctx, RED_SMALL)) do
            spot.o = coin_prop(ctx, E_MODEL_RED_COIN, spot.x, spot.y, spot.z)
            table.insert(ctx.data.coins, spot)
        end
    end,
    frame = function(ctx, m)
        local left = coins_frame(ctx, m, ctx.data.coins, SOUND_GENERAL_RED_COIN)
        if left == 0 and #ctx.data.coins > 0 then decide(ctx, WON) end
    end,
    draw = function(ctx)
        for _, coin in ipairs(ctx.data.coins or {}) do
            if not coin.got then
                OF.util.zone_ring({ x = coin.x, y = coin.y - 56, z = coin.z }, 60, 16, 2,
                    255, 90, 90, 170)
            end
        end
    end,
    status = function(ctx)
        local got = 0
        for _, coin in ipairs(ctx.data.coins or {}) do if coin.got then got = got + 1 end end
        if ctx.verdict == WON then return "All five", "good" end
        return OF.lang.fill("@ of @ red coins", tostring(got), tostring(#(ctx.data.coins or {}))), "warn"
    end,
})
end

do

local GAUNT_BILL_AT, GAUNT_BILL_FROM, GAUNT_BILL_HIGH = 110, 900, 150
local GAUNT_BILL_EVERY = { 2.6, 2.1, 1.7 }
local GAUNT_BILL_CROSS = 0.8
local GAUNT_THWOMP_AT = 220
local GAUNT_THWOMP_EVERY = { 1.6, 1.35, 1.15 }
local GAUNT_STRIP_NEAR, GAUNT_STRIP_DEEP = 330, 200
local GAUNT_STRIP_SIDE = 260

local GAUNT_BURN_ON, GAUNT_BURN_OFF = 1.3, 0.9
local GAUNT_AMP_AT, GAUNT_AMP_CIRCLE = 560, 130
local GAUNT_AMP_LAP = { 1.2, 1.0, 0.85 }
local GAUNT_STAR_REACH = 100
local BILL_RADIUS = 45

local THWOMP_HALF, THWOMP_HOVER, thwomp_on = X.THWOMP_HALF, X.THWOMP_HOVER, X.thwomp_on
local AMP_LIFT, AMP_REACH, AMP_ANIMS = X.AMP_LIFT, X.AMP_REACH, X.AMP_ANIMS

local function by_level(list, ctx) return list[math.min(ctx.level, #list)] end

local function lane_coords(ctx, x, z)
    local s = ctx.slot
    local fx, fz = math.sin(s.yawRad), math.cos(s.yawRad)
    local dx, dz = x - s.x, z - s.z
    return dx * fx + dz * fz, dx * fz - dz * fx
end

local function lane_point(ctx, along, across)
    return from_slot(ctx, along, across)
end

local function back_to_start(ctx, m, why)
    local s = ctx.slot
    OF.net.snap_to(s.x, s.y + 20, s.z, s.yaw)
    OF.util.camera_behind_soon()
    ctx.data.sentBack = (ctx.data.sentBack or 0) + 1
    ctx.data.why = why
    OF.gamemodes.cue("bad", nil, "fzgauntlet")
end

local function gauntlet_thwomp(ctx, t)
    local cycle = by_level(GAUNT_THWOMP_EVERY, ctx) * FPS
    local k = (t % cycle) / cycle
    if k < 0.55 then return THWOMP_HOVER * 0.6, false end
    if k < 0.65 then return THWOMP_HOVER * 0.6 * (1 - (k - 0.55) / 0.1), true end
    if k < 0.8 then return 0, false end
    return THWOMP_HOVER * 0.6 * (k - 0.8) / 0.2, false
end

local function strip_burns(ctx, t)
    if ctx.level < 2 then return true end
    local cycle = (GAUNT_BURN_ON + GAUNT_BURN_OFF) * FPS
    return (t % cycle) < GAUNT_BURN_ON * FPS
end
X.gauntlet_burns = strip_burns

local function bill_across(ctx, t)
    local every = by_level(GAUNT_BILL_EVERY, ctx) * FPS
    local cross = GAUNT_BILL_CROSS * FPS
    local k = t % every
    if k >= cross then return nil end
    local pass = math.floor(t / every)
    local way = pass % 2 == 0 and 1 or -1
    return way * (-GAUNT_BILL_FROM + 2 * GAUNT_BILL_FROM * k / cross), way
end
X.gauntlet_bill = bill_across

add_game({
    key = "gauntlet", shape = "boss", keepsRunning = true,
    hint = "the boss - your own lane of four timed gates to a star in the middle",
    word = function() return "THE GAUNTLET!" end,
    cue = function(ctx)
        local back = ctx.data.sentBack or 0
        return { text = "DOWN THE LANE TO THE STAR - {Z} UNDER THE BILL, {A} OVER THE FIRE",
            under = back > 0 and OF.lang.fill("sent back @ times", tostring(back)) or nil,
            underTone = "warn" }
    end,
    start = function(ctx, m)
        local d = ctx.data
        local tx, ty, tz = lane_point(ctx, GAUNT_THWOMP_AT, 0)
        d.thwomp = { x = tx, floor = ty, z = tz,
            o = prop(ctx, E_MODEL_THWOMP, tx, ty + THWOMP_HOVER * 0.6, tz, ctx.slot.yaw) }
        d.flames = {}
        for r = 0, 1 do
            for col = 0, 3 do
                local x, y, z = lane_point(ctx, GAUNT_STRIP_NEAR + GAUNT_STRIP_DEEP * r,
                    -GAUNT_STRIP_SIDE + GAUNT_STRIP_SIDE * 2 * col / 3)
                table.insert(d.flames, { x = x, y = y, z = z, o = flame_prop(ctx, x, y, z, 0.6) })
            end
        end
        local ax, ay, az = lane_point(ctx, GAUNT_AMP_AT, 0)
        d.ampAt = { x = ax, y = ay, z = az }
        d.amp = prop(ctx, E_MODEL_AMP, ax, ay + AMP_LIFT, az, 0)
        dress(d.amp, AMP_ANIMS, 0, 1.0)
        local bx, by, bz = lane_point(ctx, GAUNT_BILL_AT, 0)
        d.bill = { floor = by, o = prop(ctx, E_MODEL_BULLET_BILL, bx, by - 3000, bz, 0) }
        local at = ctx.at
        d.star = { x = at.x, y = floor_under(at.x, at.z, at.y) + 120, z = at.z }
        d.starO = prop(ctx, E_MODEL_STAR, d.star.x, d.star.y, d.star.z, 0)
    end,
    frame = function(ctx, m)
        local d = ctx.data

        local burns = strip_burns(ctx, ctx.t)
        flames_turn(d.flames, ctx.t)
        for _, f in ipairs(d.flames) do
            place(f.o, f.x, burns and f.y or f.y - 3000, f.z)
        end
        if burns ~= d.burned then
            d.burned = burns
            if burns and ctx.level >= 2 then sound(SOUND_OBJ_FLAME_BLOWN, nil) end
        end

        local lift, falling = gauntlet_thwomp(ctx, ctx.t)
        local w = d.thwomp
        place(w.o, w.x, w.floor + lift, w.z)
        if lift <= 0 and not w.landed then
            w.landed = true
            sound(SOUND_OBJ_THWOMP, w.o)
        elseif lift > 0 then
            w.landed = false
        end

        local a = ctx.t / (by_level(GAUNT_AMP_LAP, ctx) * FPS) * 2 * math.pi
        local amx = d.ampAt.x + math.sin(a) * GAUNT_AMP_CIRCLE
        local amz = d.ampAt.z + math.cos(a) * GAUNT_AMP_CIRCLE
        local amy = floor_under(amx, amz, d.ampAt.y) + AMP_LIFT
        place(d.amp, amx, amy, amz)

        local across, way = bill_across(ctx, ctx.t)
        local b = d.bill
        if across ~= nil then
            local bx, _, bz = lane_point(ctx, GAUNT_BILL_AT, across)
            place(b.o, bx, b.floor + GAUNT_BILL_HIGH, bz)
            if not gone(b.o) then
                local fx, fz = math.sin(ctx.slot.yawRad), math.cos(ctx.slot.yawRad)
                b.o.oFaceAngleYaw = yaw_to(0, 0, fz * way, -fx * way)
            end
            if not b.flying then
                b.flying = true
                sound(SOUND_OBJ_POUNDING_CANNON, nil)
            end
        else
            b.flying = false
            place(b.o, ctx.slot.x, b.floor - 3000, ctx.slot.z)
        end
        if not gone(d.starO) then
            d.starO.oFaceAngleYaw = (d.starO.oFaceAngleYaw + 0x600) % 65536
        end
        if ctx.verdict ~= UNDECIDED then return end

        if (falling or (lift <= 0 and w.landed))
            and thwomp_on(m, w.x, w.z, w.floor + lift) then
            back_to_start(ctx, m, "thwomp")
            return
        end
        local along, side = lane_coords(ctx, m.pos.x, m.pos.z)
        if burns and not is_air(m) and math.abs(side) <= GAUNT_STRIP_SIDE + MARIO_RADIUS
            and along >= GAUNT_STRIP_NEAR - MARIO_RADIUS
            and along <= GAUNT_STRIP_NEAR + GAUNT_STRIP_DEEP + MARIO_RADIUS then
            back_to_start(ctx, m, "fire")
            return
        end
        if flat_distance(amx, amz, m.pos.x, m.pos.z) <= AMP_REACH
            and amy + 40 >= m.pos.y and amy - 40 <= body_top(m) then
            back_to_start(ctx, m, "amp")
            return
        end
        if across ~= nil and math.abs(along - GAUNT_BILL_AT) <= BILL_RADIUS + MARIO_RADIUS
            and math.abs(side - across) <= BILL_RADIUS + MARIO_RADIUS then
            local y = b.floor + GAUNT_BILL_HIGH
            if y + BILL_RADIUS > m.pos.y and y - BILL_RADIUS < body_top(m) then
                back_to_start(ctx, m, "bill")
                return
            end
        end

        if flat_distance(m.pos.x, m.pos.z, d.star.x, d.star.z) <= GAUNT_STAR_REACH
            and d.star.y >= m.pos.y - 40 and d.star.y <= body_top(m) + 60 then
            retire(ctx, d.starO, POOF_ME)
            sound(SOUND_GENERAL_STAR_APPEARS or SOUND_GENERAL_COLLECT_1UP, nil)
            decide(ctx, WON)
        end
    end,
    draw = function(ctx)
        local w = ctx.data.thwomp
        if w ~= nil then
            OF.util.zone_ring({ x = w.x, y = w.floor + 4, z = w.z }, THWOMP_HALF, 24, 3,
                255, 90, 90, 200)
        end

        local across = bill_across(ctx, ctx.t)
        if across ~= nil and ctx.verdict == UNDECIDED then
            local x1, y1, z1 = lane_point(ctx, GAUNT_BILL_AT, -GAUNT_STRIP_SIDE - 120)
            local x2, y2, z2 = lane_point(ctx, GAUNT_BILL_AT, GAUNT_STRIP_SIDE + 120)
            OF.util.world_line({ x = x1, y = y1 + 4, z = z1 }, { x = x2, y = y2 + 4, z = z2 },
                3, 255, 160, 90, 200)
        end
    end,
    status = function(ctx)
        if ctx.verdict == WON then return "The star - a life back", "good" end
        local why = ctx.data.why
        if why ~= nil then
            local said = ({ thwomp = "Flattened", fire = "Burnt", amp = "Zapped",
                bill = "Shot" })[why] or "Hit"
            return OF.lang.fill("@ - back to the start", said), "warn"
        end
        return "Through the lane to the star in the middle", "warn"
    end,
})
X.GAUNT_BILL_AT = GAUNT_BILL_AT
end

do

local BREATH_INNER, BREATH_OUTER = 260, 1400
local BREATH_LAP = { 4.0, 3.5, 3.0 }
local BREATH_QUICKER = 0.8
local BREATH_PHASES = { 7, 14 }
local BREATH_SPACING = 115
local BREATH_THWOMP_EVERY = 3.5

local RAIN_EVERY = { 0, 1.6, 1.2 }
local RAIN_RADIUS, RAIN_WARN, RAIN_FROM = 150, 0.8, 900
local BOWSER_ANIMS = "bowser_seg6_anims_06057690"
local THWOMP_HALF, THWOMP_HOVER, thwomp_on = X.THWOMP_HALF, X.THWOMP_HOVER, X.thwomp_on

local function lap_of(ctx) return BREATH_LAP[math.min(ctx.level, #BREATH_LAP)] * FPS end

local function breath_phase(ctx, t)
    if t < BREATH_PHASES[1] * FPS then return 1 end
    if t < BREATH_PHASES[2] * FPS then return 2 end
    return 3
end
X.breath_phase = breath_phase

local function breath_angle(ctx, t)
    local start = hash01(ctx.seed, 0, 261) * 2 * math.pi
    local slow = 2 * math.pi / lap_of(ctx)
    local quick = slow / BREATH_QUICKER
    local t1, t2 = BREATH_PHASES[1] * FPS, BREATH_PHASES[2] * FPS
    local a = start + math.min(t, t1) * slow
    a = a - math.max(0, math.min(t, t2) - t1) * quick
    a = a + math.max(0, t - t2) * quick
    return a
end
X.breath_angle = breath_angle

local function breath_arms(ctx, t)
    local a = breath_angle(ctx, t)
    if breath_phase(ctx, t) >= 3 then return { a, a + math.pi } end
    return { a }
end
X.breath_arms = breath_arms

local function off_arm(ctx, a, x, z)
    local at = ctx.at
    local d = math.atan(x - at.x, z - at.z) - a
    return (d + math.pi) % (2 * math.pi) - math.pi
end

add_game({
    key = "breath", shape = "boss", survives = true, keepsRunning = true,
    hint = "the boss - Bowser's fire sweeps the arena in three phases and a Thwomp hunts you",
    word = function() return "BOWSER'S BREATH!" end,
    cue = function(ctx)
        local phase = breath_phase(ctx, ctx.t or 0)
        local under = ({ "phase 1 of 3 - one arm",
            "phase 2 of 3 - it turns back, quicker", "phase 3 of 3 - both ways at once" })[phase]
        if ctx.level >= 2 then under = under .. " - and fire from above" end
        return { text = "{A} OVER THE FIRE - RUN OUT OF THE SHADOW", hot = { A = true },
            under = under, underTone = phase >= 2 and "warn" or "info",
            share = math.max(0, 1 - (ctx.t or 0) / math.max(1, ctx.playF or 1)) }
    end,
    start = function(ctx, m)
        local d = ctx.data
        local at = ctx.at

        ctx.lock = { x = at.x, z = at.z, y = floor_under(at.x, at.z, at.y),
                     r = BREATH_OUTER, inner = BREATH_INNER }
        d.bowser = prop(ctx, E_MODEL_BOWSER, at.x, floor_under(at.x, at.z, at.y), at.z, 0)
        dress(d.bowser, BOWSER_ANIMS, 6, 1.0)

        d.arms = {}
        for arm = 1, 2 do
            local list = {}
            for r = BREATH_INNER, BREATH_OUTER, BREATH_SPACING do
                table.insert(list, { r = r, o = flame_prop(ctx, at.x, at.y - 3000, at.z, 0.8) })
            end
            d.arms[arm] = list
        end
        d.off = {}
        d.thwomp = { state = "wait" }
        d.rain = {}
        sound(SOUND_OBJ_BOWSER_LAUGH, d.bowser)
    end,
    frame = function(ctx, m)
        local d = ctx.data
        local at = ctx.at
        local arms = breath_arms(ctx, ctx.t)
        local phase = breath_phase(ctx, ctx.t)
        if phase ~= d.phase then
            if d.phase ~= nil then
                sound(SOUND_OBJ_BOWSER_LAUGH, d.bowser)
                OF.gamemodes.cue("hazard", nil, "fzbreath")
            end
            d.phase = phase
        end
        for arm = 1, 2 do
            local a = arms[arm]
            flames_turn(d.arms[arm], ctx.t)
            for _, f in ipairs(d.arms[arm]) do
                if a == nil then
                    place(f.o, at.x, at.y - 3000, at.z)
                else
                    local x, z = at.x + math.sin(a) * f.r, at.z + math.cos(a) * f.r
                    place(f.o, x, floor_under(x, z, at.y) + 20, z)
                end
            end
        end
        if not gone(d.bowser) then
            d.bowser.oFaceAngleYaw = math.floor(arms[1] * 32768 / math.pi) % 65536
        end
        OF.gamemodes.round_sound_throttled("fzbreath", 20, SOUND_AIR_BOWSER_SPIT_FIRE, d.bowser)

        local reach = flat_distance(m.pos.x, m.pos.z, at.x, at.z)
        local floor = floor_under(m.pos.x, m.pos.z, at.y)
        for arm, a in ipairs(arms) do
            local off = off_arm(ctx, a, m.pos.x, m.pos.z)
            local was = d.off[arm]
            d.off[arm] = off
            if was ~= nil and ((was > 0 and off <= 0) or (was < 0 and off >= 0))
                and math.abs(off - was) < 1
                and reach >= BREATH_INNER - MARIO_RADIUS and reach <= BREATH_OUTER + MARIO_RADIUS then
                if (not is_air(m) or m.pos.y < floor + 30) and ctx.verdict == UNDECIDED then
                    d.burnt = true
                    decide(ctx, LOST)
                end
            end
        end
        if #arms < 2 then d.off[2] = nil end

        local w = d.thwomp
        local cycle = BREATH_THWOMP_EVERY * FPS
        local k = (ctx.t % cycle) / cycle
        if k < 0.05 and w.state ~= "hover" then
            w.state = "hover"
            w.x, w.z = m.pos.x, m.pos.z
            w.floor = floor_under(w.x, w.z, at.y)
            w.y = w.floor + THWOMP_HOVER
            w.vy = 0
            if gone(w.o) then w.o = prop(ctx, E_MODEL_THWOMP, w.x, w.y, w.z, 0) end
        elseif w.state == "hover" and k >= 0.45 then
            w.state = "fall"
        end
        if w.state == "fall" then
            w.vy = math.min(80, w.vy + 10)
            w.y = math.max(w.floor, w.y - w.vy)
            if thwomp_on(m, w.x, w.z, w.y) and ctx.verdict == UNDECIDED then
                d.flat = true
                decide(ctx, LOST)
            end
            if w.y <= w.floor then
                w.state = "sat"
                sound(SOUND_OBJ_THWOMP, w.o)
            end
        elseif w.state == "sat" and k > 0.7 then
            w.y = math.min(w.floor + THWOMP_HOVER, w.y + 25)
        end
        if w.x ~= nil then place(w.o, w.x, w.y, w.z) end

        local every = RAIN_EVERY[math.min(ctx.level, #RAIN_EVERY)] * FPS
        if every > 0 and ctx.t > 0 and ctx.t % math.floor(every) == 0 then
            local x, z = m.pos.x, m.pos.z
            local y = floor_under(x, z, at.y)
            table.insert(d.rain, { x = x, y = y, z = z, at = ctx.t,
                o = flame_prop(ctx, x, y + RAIN_FROM, z, 1.2) })
        end
        local warn = RAIN_WARN * FPS
        for i = #d.rain, 1, -1 do
            local r = d.rain[i]
            local s = (ctx.t - r.at) / warn
            if s >= 1 then
                if ctx.verdict == UNDECIDED and flat_distance(m.pos.x, m.pos.z, r.x, r.z) <= RAIN_RADIUS
                    and m.pos.y < r.y + 160 then
                    d.burnt = true
                    decide(ctx, LOST)
                end
                sound(SOUND_GENERAL_FLAME_OUT or SOUND_OBJ_FLAME_BLOWN, r.o)
                retire(ctx, r.o, GO_ME)
                table.remove(d.rain, i)
            else
                place(r.o, r.x, r.y + RAIN_FROM * (1 - s), r.z)
            end
        end
        flames_turn(d.rain, ctx.t)
    end,
    draw = function(ctx)
        local w = ctx.data.thwomp
        if w ~= nil and (w.state == "hover" or w.state == "fall") then
            OF.util.zone_ring({ x = w.x, y = w.floor + 4, z = w.z }, THWOMP_HALF, 24, 3,
                255, 90, 90, 220)
        end
        for _, r in ipairs(ctx.data.rain or {}) do
            OF.util.zone_ring({ x = r.x, y = r.y + 4, z = r.z }, RAIN_RADIUS, 24, 3,
                255, 150, 60, 230)
        end
    end,
    status = function(ctx)
        if ctx.verdict == LOST and ctx.data.flat then return "Flattened", "bad" end
        if ctx.verdict == LOST then return "Burnt", "bad" end
        return "Jump the fire, leave the shadow", "warn"
    end,
})
X.RAIN_RADIUS, X.RAIN_WARN = RAIN_RADIUS, RAIN_WARN
X.BREATH_INNER, X.BREATH_OUTER = BREATH_INNER, BREATH_OUTER
end

do

local CLIMB_COUNT = 7
local CLIMB_RADIUS, CLIMB_TURN, CLIMB_RISE = 450, math.rad(50), 170
local CLIMB_CENTRE = 450
local CLIMB_FIRST = math.rad(40)
local CLIMB_TOP = 26
local CLIMB_STAR_LIFT, CLIMB_STAR_REACH = 130, 100

local CLIMB_GIVE = { nil, { every = 3.2, out = 0.9 }, { every = 2.6, out = 1.2 } }
local CLIMB_SHAKE, CLIMB_RIPPLE = 0.5, 0.45

local CLIMB_SETTLE = 1.5

local function climb_spot(ctx, i)
    local cx, _, cz = from_slot(ctx, CLIMB_CENTRE, 0)
    local s = ctx.slot
    local back = math.atan(s.x - cx, s.z - cz)
    local a = back + CLIMB_FIRST + (i - 1) * CLIMB_TURN
    local x, z = cx + math.sin(a) * CLIMB_RADIUS, cz + math.cos(a) * CLIMB_RADIUS
    local y = s.y + i * CLIMB_RISE - CLIMB_TOP
    return x, y, z, math.floor((a - math.pi / 2) * 32768 / math.pi) % 65536
end
X.climb_spot = climb_spot

local function climb_there(ctx, i, t)
    local give = CLIMB_GIVE[math.min(ctx.level, #CLIMB_GIVE)]
    if give == nil or i >= CLIMB_COUNT then return true, false end
    local every = give.every * FPS
    local settle = CLIMB_SETTLE * FPS
    if t < settle then return true, false end

    local since = t - settle - (i - 1) * CLIMB_RIPPLE * FPS
    if since < 0 then return true, false end
    local k = since % every

    local shakeAt = every - (give.out + CLIMB_SHAKE) * FPS
    local outAt = every - give.out * FPS
    if k >= outAt then return false, false end
    return true, k >= shakeAt
end
X.climb_there = climb_there

add_game({
    key = "climb", shape = "boss", keepsRunning = true,
    hint = "the boss - a spiral stair of platforms up to a star; from level two they give way",
    word = function() return "SKY CLIMB!" end,
    cue = function(ctx)
        return { text = "JUMP {A} UP THE PLATFORMS TO THE STAR",
            pips = { ctx.data.best or 0, CLIMB_COUNT },
            under = ctx.level >= 2 and "a shaking platform is about to drop" or nil,
            underTone = "warn" }
    end,
    start = function(ctx, m)
        local d = ctx.data
        local col = gGlobalObjectCollisionData ~= nil
            and gGlobalObjectCollisionData.checkerboard_platform_seg8_collision_0800D710 or nil
        d.plats, d.best = {}, 0
        for i = 1, CLIMB_COUNT do
            local x, y, z, yaw = climb_spot(ctx, i)
            table.insert(d.plats, { x = x, y = y, z = z, yaw = yaw,
                o = prop(ctx, E_MODEL_CHECKERBOARD_PLATFORM, x, y, z, yaw, col) })
        end
        local top = d.plats[CLIMB_COUNT]
        d.star = { x = top.x, y = top.y + CLIMB_TOP + CLIMB_STAR_LIFT, z = top.z }
        d.starO = prop(ctx, E_MODEL_STAR, d.star.x, d.star.y, d.star.z, 0)
    end,
    frame = function(ctx, m)
        local d = ctx.data
        for i, p in ipairs(d.plats) do
            local there, shakes = climb_there(ctx, i, ctx.t)
            local jiggle = shakes and math.sin(ctx.t * 2.1) * 12 or 0
            place(p.o, p.x + jiggle, there and p.y or p.y - 3000, p.z)
            if there ~= p.there and p.there ~= nil and not there then
                sound(SOUND_GENERAL_PLATFORM or SOUND_GENERAL_BOING1, p.o)
            end
            p.there = there

            if there and not is_air(m) and math.abs(m.pos.y - (p.y + CLIMB_TOP)) <= 30
                and flat_distance(m.pos.x, m.pos.z, p.x, p.z) <= 300 and i > d.best then
                d.best = i
                sound(SOUND_MENU_CHANGE_SELECT or SOUND_GENERAL_COIN, nil)
            end
        end
        if not gone(d.starO) then
            d.starO.oFaceAngleYaw = (d.starO.oFaceAngleYaw + 0x600) % 65536
        end
        if ctx.verdict ~= UNDECIDED then return end
        local st = d.star
        if flat_distance(m.pos.x, m.pos.z, st.x, st.z) <= CLIMB_STAR_REACH
            and st.y >= m.pos.y - 40 and st.y <= body_top(m) + 60 then
            retire(ctx, d.starO, POOF_ME)
            sound(SOUND_GENERAL_STAR_APPEARS or SOUND_GENERAL_COLLECT_1UP, nil)
            decide(ctx, WON)
        end
    end,
    draw = function(ctx)
        if ctx.verdict ~= UNDECIDED then return end

        for i, p in ipairs(ctx.data.plats or {}) do
            local _, shakes = climb_there(ctx, i, ctx.t)
            if shakes then
                OF.util.zone_ring({ x = p.x, y = p.y + CLIMB_TOP + 4, z = p.z }, 200, 24, 3,
                    255, 90, 90, 220)
            end
        end
    end,
    status = function(ctx)
        if ctx.verdict == WON then return "The top - a life back", "good" end
        if ctx.verdict == LOST then return "Not up there in time", "bad" end
        return OF.lang.fill("Up to platform @ of @", tostring(ctx.data.best or 0),
            tostring(CLIMB_COUNT)), "warn"
    end,
})
X.CLIMB_COUNT, X.CLIMB_RISE, X.CLIMB_TOP = CLIMB_COUNT, CLIMB_RISE, CLIMB_TOP
end

local leftOut = {}
local OFF_WIDTH = 2

local function packed_off()
    local pieces = {}
    for index, game in ipairs(GAMES) do
        if leftOut[game.key] then
            local digits = tostring(index)
            while #digits < OFF_WIDTH do digits = "0" .. digits end
            table.insert(pieces, digits)
        end
    end
    return table.concat(pieces)
end

local offRaw, offParsed = nil, {}

local function off_now()
    local text = gGlobalSyncTable[OFF_KEY]
    if type(text) ~= "string" then text = "" end
    if text ~= offRaw then
        offRaw = text
        offParsed = {}
        for at = 1, #text - (OFF_WIDTH - 1), OFF_WIDTH do
            local index = tonumber(string.sub(text, at, at + OFF_WIDTH - 1))
            if index ~= nil and GAMES[index] ~= nil then offParsed[index] = true end
        end
    end
    return offParsed
end

local frame = 0
local ctx = nil
local heardText = nil
local myLives, myWins, myPoints = nil, 0, 0
local lastSerial = nil
local resultFor = nil
local tempoHeld = nil

local function my_role()
    return OF.gamemodes.role(0)
end

local function am_in() return my_role() == ROLE_IN end

local function plays_here()
    local role = my_role()
    if role ~= ROLE_IN and not (role == ROLE_OUT and ghost_play()) then
        return false
    end
    if not OF.util.can_play(0) then return false end
    local at = arena_at()
    if at == nil then return false end
    local np = gNetworkPlayers[0]
    return np ~= nil and np.currLevelNum == at.level and np.currAreaIndex == at.area
end

local function seated()
    local list = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        local role = OF.gamemodes.role(entry.localIndex)
        if role == ROLE_IN or role == ROLE_OUT then table.insert(list, entry) end
    end
    table.sort(list, function(a, b) return a.np.globalIndex < b.np.globalIndex end)
    return list
end

local function slot_for(localIndex, at)
    if at == nil then return nil end
    local list = seated()
    local rank, count = 0, math.max(1, #list)
    for at_, entry in ipairs(list) do
        if entry.localIndex == localIndex then rank = at_ - 1 end
    end
    local angle = 2 * math.pi * rank / count
    local x = at.x + math.sin(angle) * SLOT_RADIUS
    local z = at.z + math.cos(angle) * SLOT_RADIUS
    local yaw = yaw_to(x, z, at.x, at.z)
    return { x = x, y = floor_under(x, z, at.y), z = z, yaw = yaw,
        yawRad = math.atan(at.x - x, at.z - z) }
end

local function timing(game, paceStep, card)
    local pace = pace_of(paceStep)
    local t = {}
    t.card = (card ~= nil and card ~= CARD_NONE) and math.floor(CARD_SECONDS * FPS) or 0
    t.word = math.floor(math.max(WORD_FLOOR, WORD_SECONDS / pace) * FPS)
    if game ~= nil and game.shape == "boss" then
        t.play = math.floor(BOSS_SECONDS * FPS)
    else
        local base = (game ~= nil and game.long) and LONG_SECONDS or SHORT_SECONDS
        local floor = game ~= nil and game.floor or 0
        t.play = math.floor(math.max(floor, base / pace) * FPS)
    end
    t.settle = math.floor(SETTLE_SECONDS * FPS)
    t.result = math.floor(math.max(RESULT_FLOOR, RESULT_SECONDS / pace) * FPS)
    t.total = t.card + t.word + t.play + t.settle + t.result
    return t
end

local function publish_row(serial, verdict)
    lastSerial = serial
    OF.util.publish_row(0, ROW_KEY, string.format("%.0f %.0f %.0f %.0f %.0f",
        serial or 0, verdict or 0, myLives or 0, myWins or 0, myPoints or 0))
end

local function go_out()
    if not am_in() then return end
    OF.gamemodes.set_role(0, ROLE_OUT)
    OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
    OF.gamemodes.set_ghost(true)

end

local function apply_verdict(c, verdict)
    local game = c.game
    local ghost = not am_in()
    resultFor = { verdict = verdict, ghost = ghost, boss = game.shape == "boss",
        lifeBack = false }
    if ghost then
        publish_row(c.serial, verdict)
        return
    end
    if verdict == WON then
        myWins = myWins + 1
        myPoints = myPoints + (game.shape == "boss" and 3 or 1)
        if game.shape == "boss" and has_lives() and c.level < NO_LIFE_FROM_LEVEL
            and (myLives or 0) < lives_start() then
            myLives = myLives + 1
            resultFor.lifeBack = true
        end
    elseif has_lives() then
        myLives = math.max(0, (myLives or 0) - 1)
    end
    publish_row(c.serial, verdict)
    if has_lives() and myLives <= 0 then go_out() end
end

local function tempo_update(paceStep)
    if SEQ_PLAYER_LEVEL == nil then return end
    if OF.util.binding("sequence_player_set_tempo") == nil then return end
    local now = OF.util.optional("sequence_player_get_tempo", nil, SEQ_PLAYER_LEVEL)
    if type(now) ~= "number" or now <= 0 then return end
    if tempoHeld == nil then tempoHeld = { base = now, wrote = nil } end
    if tempoHeld.wrote == nil or now ~= tempoHeld.wrote then tempoHeld.base = now end
    local want = math.max(1, math.floor(tempoHeld.base * pace_of(paceStep)))
    if want ~= now then
        tempoHeld.wrote = want
        OF.util.optional("sequence_player_set_tempo", nil, SEQ_PLAYER_LEVEL, want)
    else
        tempoHeld.wrote = now
    end
end

local function tempo_give_back()
    if tempoHeld == nil then return end

    local now = OF.util.optional("sequence_player_get_tempo", nil, SEQ_PLAYER_LEVEL)
    if tempoHeld.wrote ~= nil and now == tempoHeld.wrote then
        OF.util.optional("sequence_player_set_tempo", nil, SEQ_PLAYER_LEVEL,
            tempoHeld.base)
    end
    tempoHeld = nil
end

local function reset_to_slot(c, m)
    local s = c.slot
    if s == nil or m == nil then return end
    if flat_distance(m.pos.x, m.pos.z, s.x, s.z) > RESET_SLACK
        or math.abs(m.pos.y - s.y) > 200 then
        OF.net.snap_to(s.x, s.y + 20, s.z, s.yaw)
    else
        m.faceAngle.y = s.yaw
        m.intendedYaw = s.yaw
    end
    OF.util.camera_behind_soon()
end

local function begin_step(st, m)
    local game = GAMES[st.game]
    if game == nil then return nil end
    local at = arena_at()
    local np = gNetworkPlayers[0]
    local c = {
        serial = st.serial, game = game, level = st.level,
        paceStep = st.paceStep, pace = pace_of(st.paceStep), card = st.card,
        seed = st.seed, me = np ~= nil and np.globalIndex or 0,
        at = at, slot = slot_for(0, at),
        heardAt = frame, verdict = UNDECIDED, phase = "card",
        props = {}, data = {}, t = 0, judged = false, started = false,
        ghost = not am_in(),
    }
    local tm = timing(game, st.paceStep, st.card)
    c.timing = tm
    c.playF = tm.play
    return c
end

local function end_step(c)
    if c == nil then return end
    if c.game.stop ~= nil and c.started and not c.cleaned then c.game.stop(c) end
    c.cleaned = true
    drop_all(c)
end

local function phase_of(c)
    local e = frame - c.heardAt
    local tm = c.timing
    if e < tm.card then return "card" end
    if e < tm.card + tm.word then return "word" end
    if e < tm.card + tm.word + tm.play then return "play" end
    return "after"
end

local function close_window(c)
    if c.judged then return end
    if c.game.shape == "room" then
        local set = judged_set(c.serial)
        if set == nil then return end
        local v = set[c.me] and WON or LOST
        c.verdict = UNDECIDED
        decide(c, v)
    elseif c.verdict == UNDECIDED then
        c.verdict = default_for(c.game)
        if c.verdict == WON then OF.gamemodes.cue("good", nil, "fzwon") end
        if c.verdict == LOST then OF.gamemodes.cue("bad", nil, "fzlost") end
    end
    c.judged = true
    apply_verdict(c, c.verdict)
end

local host = nil

local function host_reset()
    host = {
        serial = 0, dealAt = math.floor(SETTLE_SECONDS * FPS),
        level = 1, paceStep = 1, sinceBoss = 0, dealt = 0,
        bag = {}, last = nil, shapes = {}, lastWasBoss = false,
        judgeAt = nil, judgeSerial = nil, aliveAtDeal = {}, started = false,
    }
end

local function dealable(index, alive)
    local game = GAMES[index]
    if game == nil or game.shape == "boss" then return false end
    if off_now()[index] then return false end
    if game.minAlive ~= nil and alive < game.minAlive then return false end
    if game.shape == "survive" then
        local n = #host.shapes
        if n >= 2 and host.shapes[n] == "survive" and host.shapes[n - 1] == "survive" then
            return false
        end
    end
    return true
end

local function draw_game(alive)
    for _ = 1, 2 do
        local options = {}
        for at, index in ipairs(host.bag) do
            if index ~= host.last and dealable(index, alive) then
                table.insert(options, at)
            end
        end
        if #options > 0 then
            local at = options[math.random(#options)]
            local index = table.remove(host.bag, at)
            return index
        end
        host.bag = {}
        for index, game in ipairs(GAMES) do
            if game.shape ~= "boss" then table.insert(host.bag, index) end
        end
    end

    for index in ipairs(GAMES) do
        if dealable(index, alive) then return index end
    end
    return nil
end

local function boss_index()
    local options = {}
    for index, game in ipairs(GAMES) do
        if game.shape == "boss" and not off_now()[index] then
            table.insert(options, index)
        end
    end
    if #options == 0 then return nil end
    return options[math.random(#options)]
end

local function best_of(list, score)
    local best, names = nil, {}
    for _, entry in ipairs(list) do
        local s = score(entry)
        if best == nil or s > best then
            best, names = s, { entry.np.name }
        elseif s == best then
            table.insert(names, entry.np.name)
        end
    end
    return names
end

local function lives_of(localIndex)
    local row = row_of(localIndex)
    return row ~= nil and row.lives or 0
end

local function wins_of(localIndex)
    local row = row_of(localIndex)
    return row ~= nil and row.wins or 0
end

local function points_of(localIndex)
    local row = row_of(localIndex)
    return row ~= nil and row.points or 0
end

local function finish_names(names, template)
    if #names == 1 then
        OF.gamemodes.finish("@ won.", names[1], names[1])
    elseif #names > 1 then
        OF.gamemodes.finish(template or "@ players share it.", { names = names },
            tostring(#names))
    else
        OF.gamemodes.finish("Nobody is left.")
    end
end

local function everyone()
    local list = {}
    for _, entry in ipairs(seated()) do table.insert(list, entry) end
    return list
end

local function by_points(entry)
    return points_of(entry.localIndex) * 1000 + wins_of(entry.localIndex)
end

local function by_lives(entry)
    return lives_of(entry.localIndex) * 1000 + wins_of(entry.localIndex)
end

local function host_ending()
    local alive = contenders()
    local mode = scoring()
    if mode == SCORING_POINTS then
        if host.dealt >= run_length() then
            finish_names(best_of(everyone(), by_points), "@ players share the most points.")
            return true
        end
        return false
    end
    if #alive == 1 then
        if mode == SCORING_BOTH then
            finish_names(best_of(everyone(), by_points), "@ players share the most points.")
        else
            local np = alive[1].np
            OF.gamemodes.finish("@ won.", np.name, np.name)
        end
        return true
    end
    if #alive == 0 then

        local names = {}
        for _, name in ipairs(host.aliveAtDeal) do table.insert(names, name) end
        if mode == SCORING_BOTH then
            finish_names(best_of(everyone(), by_points), "@ players share the most points.")
        else
            finish_names(names, "@ players went out together and share it.")
        end
        return true
    end
    if mode == SCORING_BOTH and host.dealt >= run_length() then
        finish_names(best_of(everyone(), by_points), "@ players share the most points.")
        return true
    end
    return false
end

local function host_room_judge(st)
    local game = GAMES[st.game]
    if game == nil or game.judge == nil then return end
    local players = OF.gamemodes.landed(contenders())
    local winners = game.judge(st, players) or {}
    local bits = 0
    for g in pairs(winners) do bits = bits + 2 ^ g end
    OF.util.publish(JUDGE_KEY, string.format("%.0f %x", st.serial, math.floor(bits)))
end

local function host_deal()
    local alive = #contenders()
    local card, index = CARD_NONE, nil

    if host.force ~= nil then
        index = host.force
        host.force = nil
    elseif host.lastWasBoss then
        host.lastWasBoss = false
        host.sinceBoss = 0
        if host.level < TOP_LEVEL then
            host.level = host.level + 1
            card = CARD_LEVEL
        else
            host.paceStep = math.min(PACE_CAP, host.paceStep + 1)
            card = CARD_SPEED
        end
    elseif host.sinceBoss >= GAMES_TO_BOSS then
        local boss = bosses_on() and boss_index() or nil
        if boss ~= nil then
            index = boss
            card = CARD_BOSS
            host.lastWasBoss = true
        else

            host.sinceBoss = 0
            if host.level < TOP_LEVEL then
                host.level = host.level + 1
                card = CARD_LEVEL
            else
                host.paceStep = math.min(PACE_CAP, host.paceStep + 1)
                card = CARD_SPEED
            end
        end
    elseif host.sinceBoss > 0 and host.sinceBoss % speed_every() == 0 then
        host.paceStep = math.min(PACE_CAP, host.paceStep + 1)
        card = CARD_SPEED
    end
    if index == nil then index = draw_game(alive) end
    if index == nil then
        host.dealAt = math.floor(SETTLE_SECONDS * FPS)
        return
    end
    local game = GAMES[index]
    if game.shape ~= "boss" then
        host.sinceBoss = host.sinceBoss + 1
        host.dealt = host.dealt + 1
        host.last = index
        table.insert(host.shapes, game.shape)
        if #host.shapes > 4 then table.remove(host.shapes, 1) end
    end
    host.serial = host.serial % 999 + 1
    local seed = math.random(0, 99999)

    if game.seed_for ~= nil then seed = game.seed_for(alive, seed) end
    host.aliveAtDeal = {}
    for _, entry in ipairs(contenders()) do
        table.insert(host.aliveAtDeal, entry.np.name)
    end
    OF.util.publish(STEP_KEY, string.format("%.0f %.0f %.0f %.0f %.0f %.0f",
        host.serial, index, host.level, host.paceStep, card, seed))
    local tm = timing(game, host.paceStep, card)
    host.dealAt = tm.total
    if game.shape == "room" then
        host.judgeAt = tm.card + tm.word + tm.play + math.floor(ROOM_WAIT_SECONDS * FPS)
        host.judgeStep = { serial = host.serial, game = index, level = host.level,
            paceStep = host.paceStep, card = card, seed = seed }
    else
        host.judgeAt = nil
    end
end

local mode = {
    key = "frenzy",
    name = "Microgame Frenzy",
    blurb = "one word, a few seconds, the whole lobby at once - faster and faster",
    aims = { [ROLE_IN] = "Do what the word says before the fuse runs out." },
    how = "A word goes up, like STOMP or CATCH, and you have\n"
        .. "a few seconds to do it, each player with their own things.\n"
        .. "A lost game costs a life; a boss gives one back.\n"
        .. "It speeds up as it goes. Last one with lives wins.",
    minPlayers = 2,
    maps = OF.PARTY_ARENAS,
    saysOut = true,
    room = { sweep = { "cannons" }, rules = { interactions = 0 } },

    music = SEQ_MENU_FILE_SELECT,
    defaultLimit = 600,
    resultsBy = "survival",
    teams = false,
    lensRole = ROLE_OUT,
    options = {
        { key = "score", name = "Scoring",
          help = "how the round is won",
          choices = {
              { key = "survival", name = "survival",
                help = "lives; a lost game costs one; the last one in wins" },
              { key = "points", name = "points",
                help = "no lives; a won game scores, a boss scores three" },
              { key = "both", name = "points with lives",
                help = "lives as Survival, most points wins" },
          } },

        { key = "lives", name = "Lives",
          help = "how many lost games put a player out",
          shownIf = { score = { "survival", "both" } },
          choices = {
              { key = "four", name = "four", help = "as many as the original gives" },
              { key = "three", name = "three", help = "a shorter round" },
              { key = "two", name = "two", help = "hardly any margin" },
              { key = "one", name = "one", help = "a single miss ends it" },
          } },
        { key = "start", name = "Starting speed",
          help = "how fast the first games are",
          choices = {
              { key = "normal", name = "normal", help = "five seconds a game" },
              { key = "quick", name = "quick", help = "two speed-ups in already" },
              { key = "frantic", name = "frantic", help = "four speed-ups in already" },
          } },
        { key = "every", name = "Speed up every",
          help = "how many games between two speed-ups",
          choices = {
              { key = "five", name = "five games", help = "the original's rhythm" },
              { key = "three", name = "three games", help = "faster sooner" },
              { key = "eight", name = "eight games", help = "a gentler climb" },
          } },
        { key = "length", name = "Run length",
          help = "how many games a points round lasts",
          shownIf = { score = { "points", "both" } },
          choices = {
              { key = "thirty", name = "thirty games", help = "about five minutes" },
              { key = "twenty", name = "twenty games", help = "a quick round" },
              { key = "fifty", name = "fifty games", help = "a long evening's round" },
          } },
        { key = "boss", name = "Bosses",
          help = "a long game every fifteen, a life back for winning it",
          choices = {
              { key = "on", name = "on", help = "a boss every fifteen games" },
              { key = "off", name = "off", help = "microgames only" },
          } },
        { key = "ghost", name = "Ghost play",
          help = "out players keep getting the games, for fun",
          shownIf = { score = { "survival", "both" } },
          choices = {
              { key = "on", name = "on", help = "out players keep playing, counted for nothing" },
              { key = "off", name = "off", help = "out players only watch" },
          } },
    },

    presets = {
        { key = "classic", name = "Classic", help = "lives, the last one in wins", sets = {} },
        { key = "party", name = "Party", help = "points, twenty games",
          sets = { score = "points", length = "twenty" } },
        { key = "marathon", name = "Marathon", help = "points with lives, fifty games",
          sets = { score = "both", length = "fifty" } },
    },
}

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_IN)
    end
    OF.util.publish(STEP_KEY, nil)
    OF.util.publish(JUDGE_KEY, nil)

    OF.util.publish(OFF_KEY, packed_off())

    if scoring() == SCORING_POINTS and (options == nil or tonumber(options.limit) == nil) then
        OF.util.publish("ofGmLimit", run_length() * 12 + 60)
    end
    if OF.util.asks(OF.util, "seed_random") then OF.util.seed_random() end
end

function mode.pin()
    local here = OF.gamemodes.here_place(0)
    if here == nil then return end

    local y = here.y
    local floor = OF.util.optional("find_floor_height", nil, here.x, here.y + 100, here.z)
    if type(floor) == "number" and floor > here.y - 2000 and floor <= here.y + 100 then
        y = floor
    end
    OF.util.publish(AT_KEY, string.format("%.0f %.0f %.0f %.0f %.0f",
        here.level or 0, here.area or 0, here.x, y, here.z))
end

mode.leadPin = { keys = { AT_KEY } }

function mode.late_join(localIndex)
    if scoring() == SCORING_POINTS then return ROLE_IN end
    return ROLE_OUT
end

function mode.on_start()
    frame = 0
    if ctx ~= nil then end_step(ctx) end
    ctx = nil
    heardText = nil
    myLives = nil
    myWins, myPoints = 0, 0
    lastSerial = nil
    resultFor = nil

    host_reset()
    saidStep, saidPhase = nil, nil

end

function mode.out_cause() return OF.lang.t("Out of lives") end

local function ensure_tallies()
    if myLives ~= nil then return end
    if has_lives() and am_in() then myLives = lives_start() else myLives = 0 end
    publish_row(0, UNDECIDED)
end

local function wants_hold(c, phase)
    if phase == "card" or phase == "word" then return true end
    if phase == "play" then return c.game.holds == true end
    if phase == "after" and c.game.shape == "room" then return true end
    return false
end

local function no_dozing(m, c)
    if c ~= nil and c.game.key == "sleep" and phase_of(c) == "play" then return end
    if m.action == ACT_START_SLEEPING or m.action == ACT_SLEEPING then
        set_mario_action(m, ACT_IDLE, 0)
    end
end

local function fell_off(m, c)
    local at = arena_at()
    if at == nil or m.pos.y > at.y - FELL_DROP then return false end
    local s = c ~= nil and c.slot or slot_for(0, at)
    if s == nil then return false end
    OF.net.snap_to(s.x, s.y + 20, s.z, s.yaw)
    OF.util.camera_behind_soon()
    if c ~= nil and phase_of(c) == "play" then decide(c, LOST) end
    return true
end

function mode.before_mario_update(m)
    local role = my_role()
    if role ~= ROLE_IN and role ~= ROLE_OUT then return end
    frame = frame + 1
    ensure_tallies()

    local st = step_now()
    tempo_update(st ~= nil and st.paceStep or start_step())

    if st ~= nil and st.text ~= heardText then
        heardText = st.text
        if ctx ~= nil then
            if not ctx.judged and ctx.started then close_window(ctx) end
            end_step(ctx)
        end
        ctx = nil
        resultFor = nil
        if plays_here() then ctx = begin_step(st, m) end
    end

    if ctx == nil then
        if role == ROLE_IN or ghost_play() then
            no_dozing(m, nil)
            if plays_here() then fell_off(m, nil) end
        end
        return
    end
    local c = ctx
    local phase = phase_of(c)

    if phase == "card" and not c.carded then
        c.carded = true
        if c.card == CARD_BOSS then
            OF.gamemodes.cue("hazard", nil, "fzcard")
        elseif c.card ~= CARD_NONE then
            OF.gamemodes.cue("chime", nil, "fzcard")
        end
    end
    if phase == "word" and c.phase ~= "word" then
        reset_to_slot(c, m)
        OF.gamemodes.round_sound(OF.sounds.COUNT)
    end
    if phase == "play" and not c.started then
        c.started = true
        c.t = 0
        if c.game.lockRadius ~= nil and c.slot ~= nil then
            c.lock = { x = c.slot.x, z = c.slot.z, y = c.slot.y, r = c.game.lockRadius }
        end
        if c.game.start ~= nil then c.game.start(c, m) end
    end
    c.phase = phase

    fx_frame(c)
    no_dozing(m, c)

    if phase == "play" then
        c.t = frame - c.heardAt - c.timing.card - c.timing.word
        if not fell_off(m, c) then
            if c.lock ~= nil then X.hold_lock(m, c.lock) end
            if c.verdict == UNDECIDED or c.game.keepsRunning then
                c.game.frame(c, m)
            end
            if c.data ~= nil and c.data.readsC then OF.input.claim_camera(m) end
        end
        OF.gamemodes.tick_down(math.ceil((c.playF - c.t) / FPS))
    elseif phase == "after" then
        fell_off(m, c)
        if c.started and not c.judged then close_window(c) end

        if c.judged and not c.cleaned then
            c.cleaned = true
            if c.game.stop ~= nil then c.game.stop(c) end
            drop_all(c)
        end
    else
        fell_off(m, c)
    end

    if wants_hold(c, phase) then OF.input.hold(m) end
end

function mode.update()
end

function mode.host_update()
    if host == nil then host_reset() end
    if host.judgeAt ~= nil then
        host.judgeAt = host.judgeAt - 1
        if host.judgeAt <= 0 then
            host.judgeAt = nil
            if host.judgeStep ~= nil then host_room_judge(host.judgeStep) end
        end
    end
    host.dealAt = host.dealAt - 1
    if host.dealAt > 0 then return end
    if host.started and host_ending() then return end
    host.started = true
    host_deal()
end

function mode.on_timeout()
    if scoring() == SCORING_POINTS or scoring() == SCORING_BOTH then
        finish_names(best_of(everyone(), by_points), "Time - @ players share the most points.")
        return
    end
    local alive = contenders()
    if #alive == 0 then
        OF.gamemodes.finish("Time - nobody is left.")
        return
    end
    finish_names(best_of(alive, by_lives), "Time - @ players share the most lives.")
end

function mode.cleanup()
    if ctx ~= nil then end_step(ctx) end
    ctx = nil
    heardText = nil
    resultFor = nil
    tempo_give_back()
    if OF.util.is_host() then
        OF.util.publish(STEP_KEY, nil)
        OF.util.publish(AT_KEY, nil)
        OF.util.publish(JUDGE_KEY, nil)
        OF.util.publish(OFF_KEY, nil)
    end
    OF.util.publish_row(0, ROW_KEY, "")
end

function mode.terms()
    local said = OF.gamemodes.option_showing(mode.key, "score")
    if said == SCORING_POINTS then
        return "the most points when the games run out"
    end
    local lives = LIVES_STOPS[OF.gamemodes.option_showing(mode.key, "lives") or "four"] or 4
    if said == SCORING_BOTH then
        return OF.lang.fill("the most points - @ lives each", tostring(lives))
    end
    return OF.lang.fill("the last one with lives left - @ each", tostring(lives))
end

function mode.standing(localIndex)
    if scoring() == SCORING_POINTS then return tostring(points_of(localIndex)) end
    if OF.gamemodes.role(localIndex) == ROLE_OUT then return "OUT" end
    if not OF.util.can_play(localIndex) then return "AWAY" end
    return tostring(lives_of(localIndex))
end

function OF.gm_frenzy_left_out(key)
    if BY_KEY[key] == nil then return nil end
    return leftOut[key] == true
end

function OF.gm_frenzy_leave_out(key, off)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    if BY_KEY[key] == nil then return false, "No such microgame." end
    if off then
        local left = 0
        for _, game in ipairs(GAMES) do
            if game.key ~= key and not leftOut[game.key] and game.shape ~= "boss" then
                left = left + 1
            end
        end
        if left == 0 and GAMES[BY_KEY[key]].shape ~= "boss" then
            return false, "Microgame Frenzy needs at least one microgame."
        end
    end
    if off == true then leftOut[key] = true else leftOut[key] = nil end
    return true
end

function mode.build_rows(panel)
    local rows = {}
    local inDeck = 0
    for _, game in ipairs(GAMES) do
        if not leftOut[game.key] then inDeck = inDeck + 1 end
    end
    table.insert(rows, panel.with_right(
        panel.sub_header_row(OF.lang.t("Which microgames come up")),
        OF.lang.fill("@ of @", tostring(inDeck), tostring(#GAMES))))
    for _, game in ipairs(GAMES) do
        do
            local key = game.key
            local on = leftOut[key] ~= true
            local name = game.deckName or game.word({ seed = 0, me = 0, level = 1,
                paceStep = 1, playF = 150, data = {} })
            table.insert(rows, panel.with_key(panel.with_help(
                panel.gated_row("speedrun",
                    panel.tick(on, OF.lang.t(name)), 255, 220, 120,
                    function()
                        local ok, why, feature = OF.gm_frenzy_leave_out(key, on)
                        OF.util.report(ok, why, feature)
                    end),
                OF.lang.t(game.hint or "")),
                "gamemode:frenzydeck:" .. key))
        end
    end
    return rows
end

local BOARD = { scale = 0.85, columns = 1 }

local saidStep, saidPhase = nil, nil

local function draw_board(above)
    local list = {}
    for _, entry in ipairs(seated()) do
        local value
        if scoring() == SCORING_POINTS then
            value = tostring(points_of(entry.localIndex))
        elseif OF.gamemodes.role(entry.localIndex) == ROLE_OUT then
            value = "OUT"
        else
            value = tostring(lives_of(entry.localIndex))
        end
        table.insert(list, { name = entry.np.name, localIndex = entry.localIndex,
            right = value, sort = OF.gamemodes.role(entry.localIndex) == ROLE_OUT
                and -1 or (scoring() == SCORING_POINTS and points_of(entry.localIndex)
                or lives_of(entry.localIndex)) })
    end
    table.sort(list, function(a, b)
        if a.sort ~= b.sort then return a.sort > b.sort end
        return a.name < b.name
    end)
    local title = scoring() == SCORING_POINTS and "Points" or "Lives"
    local x = djui_hud_get_screen_width() * 0.03
    local top = OF.util.board_top(x, djui_hud_get_screen_height() * 0.24)
    local bottom = OF.util.board_bottom()
    if type(above) == "number" and above - 4 < bottom then bottom = above - 4 end

    if OF.util.asks(OF.gamemodes, "board_cap") then
        list = OF.gamemodes.board_cap(list, OF.gamemodes.SIDE_BOARD_ROWS or 4)
    end
    BOARD.scale, BOARD.columns = OF.util.board_fit(#list, 1, top - 5, bottom)
    OF.util.board(x, top, OF.lang.t(title), list, BOARD)
end

local function in_the_room()
    local at = arena_at()
    local np = gNetworkPlayers[0]
    if at == nil or np == nil then return true end
    return np.currLevelNum == at.level and np.currAreaIndex == at.area
end

function mode.clock()
    return frame
end

function mode.raise(c, phase, word, ghost)
    if not OF.util.asks(OF.hud, "banner") then return nil end
    if phase == "card" then
        local text = CARD_WORDS[c.card]
        if text == nil or text == "" then return nil end
        return OF.hud.banner("roundstate", OF.lang.t(text), nil, { quiet = true })
    elseif phase == "word" or phase == "play" then

        local tm = c.timing
        local left = tm.card + tm.word - (frame - c.heardAt)
        if left < 1 then return nil end
        return OF.hud.banner("call", OF.lang.t(word), nil,
            { hold = left, tone = ghost and "mute" or "warn", quiet = true })
    end
    return nil
end

function mode.status_repeats(status, spec)
    if type(status) ~= "string" or type(spec) ~= "table" or type(spec.text) ~= "string" then
        return false
    end
    local cue = " " .. string.lower((string.gsub(OF.lang.t(spec.text), "{([^}]*)}", " %1 "))) .. " "
    cue = string.gsub(cue, "[^%a%d]+", " ")
    local any = false
    for w in string.gmatch(string.lower(OF.util.plain(status)), "[%a%d]+") do
        any = true
        if not string.find(cue, " " .. w .. " ", 1, true) then return false end
    end
    return any
end

function mode.hud()
    local role = my_role()
    if role ~= ROLE_IN and role ~= ROLE_OUT then return end
    local c = ctx
    local ghost = not am_in()
    local stripTop = nil
    local state = OF.util.asks(OF.hud, "state_line") and OF.hud.state_line or function() end

    if ghost and not ghost_play() then
        OF.gamemodes.out_banner()
        draw_board()
        return
    end

    if not in_the_room() then
        OF.gamemodes.away_banner("The games are in the arena - you are somewhere else")
        draw_board()
        return
    end

    if ghost then
        state("fun", OF.lang.t("For fun"), { prio = 30, tone = "mute" })
    elseif myLives ~= nil and scoring() ~= SCORING_POINTS then
        state("lives", nil, { prio = 20, icons = mode.life_icons() })
    end

    if c == nil then
        if not ghost then state("ready", OF.lang.t("Get ready"), { prio = 25, tone = "mute" }) end
        draw_board()
        return
    end

    local phase = c.phase
    local word = c.game.word(c)

    local key = phase == "play" and "word" or phase
    if c ~= saidStep or key ~= saidPhase then
        if not (phase == "play" and c == saidStep and saidPhase == "word") then
            mode.raise(c, phase, word, ghost)
        end
        saidStep, saidPhase = c, key
    end

    if phase == "word" then

        stripTop = CUE.draw(c, CUE.of(c), frame, ghost)
    elseif phase == "play" then
        local spec = CUE.of(c)
        stripTop = CUE.draw(c, spec, frame, ghost)
        if c.game.status ~= nil then
            local text, tone = c.game.status(c)
            if text ~= nil and not (stripTop ~= nil and mode.status_repeats(OF.lang.t(text), spec)) then
                state("status", OF.lang.t(text), { prio = 50, tone = ghost and "mute" or (tone or "ink") })
            end
        end

        if c.lock ~= nil and c.phase == "play" then X.draw_lock(c.lock) end
        if c.game.draw ~= nil then c.game.draw(c) end
    end

    if phase ~= "card" and c.judged and c.medalSaid ~= true then
        c.medalSaid = true
        local v = c.verdict
        if v == WON and OF.util.asks(OF.hud, "banner") then
            local life = resultFor ~= nil and resultFor.lifeBack
            OF.hud.banner("medal", OF.lang.t(life and "A LIFE BACK" or "WON!"), nil,
                { tone = ghost and "ink2" or "good", quiet = true })
        elseif v == LOST and OF.util.asks(OF.hud, "banner") then
            OF.hud.banner("medal", OF.lang.t("LOST!"), nil, { tone = ghost and "ink2" or "bad", quiet = true })
        end
    end
    draw_board(stripTop)
end

function mode.life_icons()
    local items = {}
    local most = math.max(lives_start(), myLives or 0)
    for i = 1, most do
        items[i] = { icon = "heart", tone = "bad", empty = i > (myLives or 0) }
    end
    return items
end

OF.gm_frenzy = {
    GAMES = GAMES, BY_KEY = BY_KEY, PACE = PACE, PACE_CAP = PACE_CAP,
    WON = WON, LOST = LOST, UNDECIDED = UNDECIDED,
    CARD_SPEED = CARD_SPEED, CARD_BOSS = CARD_BOSS, CARD_LEVEL = CARD_LEVEL,
    GAMES_TO_BOSS = GAMES_TO_BOSS, SLOT_RADIUS = SLOT_RADIUS,
    timing = timing, pace_of = pace_of, row_of = row_of, slot_for = slot_for,
    step_now = step_now, arena_at = arena_at, hash01 = hash01,
    context = function() return ctx end,
    lives = function() return myLives end,
    host = function() return host end,
    tempo = function() return tempoHeld end,
    presses = presses, press_button = X.press_button, move_of = X.move_of,
    shoot_at = X.shoot_at, shoot_allow = X.shoot_allow, pump_target = X.pump_target,
    spin_turns = X.spin_turns, decide = decide, phase_of = phase_of,
    GOOMBA_TALL = X.GOOMBA_TALL, hit_height = X.hit_height, X = X,

    cue_of = function(c) return CUE.of(c) end,
    cue_segments = CUE.segments,
    draw_game = function(alive) return draw_game(alive) end,

    force = function(key)
        if host == nil or BY_KEY[key] == nil then return false end
        host.force = BY_KEY[key]
        host.dealAt = 1
        return true
    end,
}

OF.gamemodes.register(mode)
