OF = OF or {}
OF.zombies = OF.zombies or {}

local zombies = OF.zombies

local lastSurvivors = nil
local lastInfected = nil

local roundSecs = nil

local CLOCK_CAP = 3

local ROLE_SURVIVOR = "surviving"
local ROLE_INFECTED = "infected"
local LIST_X = 0.03
local LIST_Y = 0.24

zombies.RULES = {
    holdSeconds   = 15,

    surviveSecs   = 2 * 60,
    groundGain    = 1.18,
    groundCap     = 42,
    catchRadius   = 140,

    fireRest      = 45,

    blindSeconds  = 3,
}

local BLACK = { r = 20, g = 20, b = 24 }

local METAL = 0x200

local function is_infected(localIndex)
    return OF.gamemodes.role(localIndex) == ROLE_INFECTED
end

local function running()
    local mode = OF.gamemodes.current()
    if mode == nil or mode.key ~= "zombies" then return false end
    return OF.gamemodes.is_running()
end

zombies.is_infected = is_infected

function zombies.held()
    if OF.gamemodes.state() == OF.gamemodes.COUNTDOWN then return true end
    return OF.gamemodes.elapsed() < zombies.RULES.holdSeconds
end

function zombies.hold_seconds_left()
    return math.max(0, zombies.RULES.holdSeconds - OF.gamemodes.elapsed())
end

local borrowed = nil

function zombies.forget_borrow()
    borrowed = nil
    zombies.forget_look()
end

zombies.ROOM_LOOK = "an old photograph"
zombies.HORDE_LOOK = "a photo negative"
function zombies.negative_eyes()
    return OF.settings ~= nil and OF.settings.negativeEyes == true
end

function zombies.my_look()
    if zombies.negative_eyes() and is_infected(0) then
        return zombies.HORDE_LOOK
    end
    return zombies.ROOM_LOOK
end

local wearing = nil

function zombies.forget_look()
    wearing = nil
end

local function dress_the_screen()
    local want = zombies.my_look()
    if want == wearing then return end
    wearing = want
    if OF.util.asks(OF.modifiers, "look_over")
        and OF.util.asks(OF.modifiers, "look_named") then
        OF.modifiers.look_over(OF.modifiers.look_named(want))
    end
end

local function take_the_room()
    if borrowed ~= nil then return end
    borrowed = true
    dress_the_screen()
end

local function restore(np)
    if OF.util.asks(OF.charselect, "restore_palette") then
        OF.charselect.restore_palette(np)
        return
    end
    OF.util.optional("network_player_reset_override_palette", nil, np)
end

local function give_the_room_back()
    if borrowed == nil then return end

    if OF.util.asks(OF.modifiers, "look_over") then
        zombies.forget_look()
        OF.modifiers.look_over(nil)
    end

    if OF.util.asks(OF.modifiers, "clear_fog") then
        OF.modifiers.clear_fog()
    end

    if OF.util.asks(OF.modifiers, "clear_dark") then
        OF.modifiers.clear_dark()
    end
    zombies.drop_all_torches()
    borrowed = nil

    for _, entry in ipairs(OF.util.connected_players()) do
        local np = gNetworkPlayers[entry.localIndex]
        if np ~= nil then
            restore(np)
        end
    end
end

local painted = {}

local function paint(localIndex, infected)
    if painted[localIndex] == infected then return end
    painted[localIndex] = infected

    local np = gNetworkPlayers[localIndex]
    if np == nil then return end
    if infected then
        for part = 0, 7 do
            OF.util.optional("network_player_set_override_palette_color", nil,
                np, part, BLACK)
        end
    else
        restore(np)
    end
end

function zombies.draw_one(m)
    if m == nil then return end
    local infected = is_infected(m.playerIndex)
    paint(m.playerIndex, infected)

    if not infected then return end
    local body = m.marioBodyState
    if body == nil or body.modelState == nil then return end

    if not OF.util.has_flag(body.modelState, METAL) then
        body.modelState = body.modelState + METAL
    end
end

local FIRE_BEHAVIOUR = "id_bhvBouncingFireballFlame"
local FIRE_REACH = 110
local FIRE_AHEAD = 90

local FIRE_HINT_SCALE = 0.4

local FIRE_HINT_GAP = 6

local fireCooldown = 0

local function ahead_of(m, distance)
    return m.pos.x + sins(m.faceAngle.y) * distance,
           m.pos.z + coss(m.faceAngle.y) * distance
end

function zombies.shoot(m)
    if m == nil then return false end
    if fireCooldown > 0 then return false end
    fireCooldown = zombies.RULES.fireRest

    local x, z = ahead_of(m, FIRE_AHEAD)
    local mine = network_global_index_from_local(0)

    local spawned = OF.util.optional("spawn_sync_object", nil,
        _G[FIRE_BEHAVIOUR], E_MODEL_RED_FLAME, x, m.pos.y + 40, z,
        function(o)

            o.oIntangibleTimer = -1
            o.oMoveAngleYaw = m.faceAngle.y
            o.oFaceAngleYaw = m.faceAngle.y

            o.oAction = 1
            o.oTimer = 0

            o.oBehParams = mine
        end)

    if spawned ~= nil then
        play_sound(SOUND_GENERAL_FLAME_OUT, m.marioObj.header.gfx.cameraToObject)
    end
    return spawned ~= nil
end

local function fireball_touching(m)
    local first = OF.util.optional("obj_get_first_with_behavior_id", nil,
        _G[FIRE_BEHAVIOUR])
    local seen = 0
    while first ~= nil and seen < 64 do
        seen = seen + 1
        if first.activeFlags ~= 0 then
            local dx = first.oPosX - m.pos.x
            local dy = first.oPosY - m.pos.y
            local dz = first.oPosZ - m.pos.z
            if (dx * dx + dy * dy + dz * dz) < FIRE_REACH * FIRE_REACH then
                return first
            end
        end
        first = OF.util.optional("obj_get_next_with_same_behavior_id", nil, first)
    end
    return nil
end

zombies.fireball_touching = fireball_touching

function zombies.fire_charge()
    local rest = zombies.RULES.fireRest
    if rest <= 0 then return 0 end
    return math.max(0, math.min(1, fireCooldown / rest))
end

local SIGHT_RANGE = 3000
local seen = {}
local askNext = 0

local function eye_of(m)
    return m.pos.x, m.pos.y + 120, m.pos.z
end

local function look_at(localIndex)
    local me = gMarioStates[0]
    local them = gMarioStates[localIndex]
    if me == nil or them == nil then return false end

    local here, there = gNetworkPlayers[0], gNetworkPlayers[localIndex]
    if here == nil or there == nil then return false end

    if not there.connected then return false end
    if here.currLevelNum ~= there.currLevelNum then return false end
    if here.currAreaIndex ~= there.currAreaIndex then return false end

    local sx, sy, sz = eye_of(me)
    local tx, ty, tz = eye_of(them)
    local dx, dy, dz = tx - sx, ty - sy, tz - sz
    if (dx * dx + dy * dy + dz * dz) > SIGHT_RANGE * SIGHT_RANGE then return false end

    local hit = OF.util.optional("collision_find_surface_on_ray", nil,
        sx, sy, sz, dx, dy, dz)

    if hit == nil then return false end
    return hit.surface == nil
end

local function watched_role()
    local mine = OF.gamemodes.role(0)
    if mine == ROLE_INFECTED then return ROLE_SURVIVOR end
    if mine == ROLE_SURVIVOR then return ROLE_INFECTED end
    return nil
end

local function tick_sight()
    local list = OF.util.connected_players()
    if #list <= 1 then
        seen = {}
        return
    end
    askNext = askNext + 1
    if askNext > #list then askNext = 1 end
    local who = list[askNext].localIndex
    if who == 0 then return end
    seen[who] = look_at(who)
end

function zombies.sighted(localIndex)
    if not running() then return false end
    if zombies.held() then return false end
    return seen[localIndex] == true
end

function zombies.can_see(localIndex)
    if not is_infected(0) then return false end

    if OF.gamemodes.role(localIndex) ~= ROLE_SURVIVOR then return false end
    return zombies.sighted(localIndex)
end

function zombies.forget_sight()
    seen = {}
    askNext = 0
end

local function other_side()
    local role = watched_role()
    if role == ROLE_SURVIVOR then
        local gold = OF.util.gold()
        return ROLE_SURVIVOR, gold.r, gold.g, gold.b
    end
    if role == ROLE_INFECTED then return ROLE_INFECTED, 255, 90, 90 end
    return nil
end

local SEEN_ARROW_LIFT = 240

local function draw_the_other_side()
    if zombies.held() then return nil end
    local role, r, g, b = other_side()
    if role == nil then return nil end

    local nearest = nil
    for _, entry in ipairs(OF.gamemodes.with_role(role)) do
        local index = entry.localIndex
        local m = gMarioStates[index]

        local watching = OF.util.asks(OF.spectate, "is_spectating")
            and OF.spectate.is_spectating(index)

        local away = nil
        if index ~= 0 and not watching then
            away = OF.gamemodes.distance(0, index)
        end

        if away ~= nil and m ~= nil and m.pos ~= nil
            and zombies.sighted(index) then
            OF.util.world_arrow(
                { x = m.pos.x, y = m.pos.y + SEEN_ARROW_LIFT, z = m.pos.z },
                200, 4, r, g, b, 225)
            if nearest == nil or away < nearest then nearest = away end
        end
    end
    return nearest, role
end

local TERROR_ON_YOU = 700
local TERROR_CLOSE = 1600

function zombies.terror_band()
    if not running() then return nil end
    if zombies.held() then return nil end
    if OF.gamemodes.role(0) ~= ROLE_SURVIVOR then return nil end

    local nearest = nil
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_INFECTED)) do
        local index = entry.localIndex

        local watching = OF.util.asks(OF.spectate, "is_spectating")
            and OF.spectate.is_spectating(index)
        if index ~= 0 and not watching then
            local away = OF.gamemodes.distance(0, index)
            if away ~= nil and (nearest == nil or away < nearest) then
                nearest = away
            end
        end
    end

    if nearest == nil then return nil end
    if nearest <= TERROR_ON_YOU then return "onyou" end
    if nearest <= TERROR_CLOSE then return "close" end
    return nil
end

function zombies.build_screen_row(panel)
    return panel.with_key(panel.with_help(
        panel.row(panel.tick(zombies.negative_eyes(),
            "A photo negative while you are in the Zombies horde"),
            255, 255, 255, function()
                if OF.settings == nil
                    or OF.settings.set_negative_eyes == nil then return end
                OF.settings.set_negative_eyes(not zombies.negative_eyes())
                zombies.forget_look()
            end),
        "your screen only - off by default, because the lobby asked for both "
            .. "halves to see alike"),
        "zombies:negative")
end

local mode = {
    key = "zombies",
    name = "Zombies",
    blurb = "outlast the horde, or join it",

    aims = {
        ["surviving"] = "Stay away from the infected until the clock runs out.",
        ["infected"]  = "Touch the survivors - every one you catch joins you.",
    },

    noDozing = true,

    how = "One starts infected. Everybody else is running.\n"
        .. "A catch is an attack - punch, kick, dive, slide, pound.\n"
        .. "On a pole or in water, a touch is enough.\n"
        .. "Taken once and you join the horde for good.\n"
        .. "Every catch puts the survivors' clock back.\n"
        .. "Arrive part way through and you arrive infected.\n"
        .. "Survivors outlast the clock; the horde takes all.",
    minPlayers = 2,

    music = SEQ_LEVEL_SPOOKY,
    defaultLimit = zombies.RULES.surviveSecs,

    target = { name = "seconds to outlast",
               asks = "How many seconds to outlast",
               default = zombies.RULES.surviveSecs,
               min = 60, max = 300, step = 30 },

    noSweep = true,

    inertStarsAndCaps = true,

    enemiesBack = 10,

    maps = "anywhere",

    mainCourses = true,

    mods = "night=2,dark=2,fog=1",
}

local dealtFrom = 0

local function next_deal(count)
    if count <= 0 then return 1 end
    dealtFrom = dealtFrom + 1
    if dealtFrom > count then dealtFrom = 1 end
    return dealtFrom
end

function mode.setup(players, options)

    local howMany = math.max(1, math.floor(#players / 4))
    local from = next_deal(#players)

    for index, entry in ipairs(players) do

        local place = ((index - from) % #players) + 1
        OF.gamemodes.set_role(entry.localIndex,
            place <= howMany and ROLE_INFECTED or ROLE_SURVIVOR)
    end

    if options == nil or tonumber(options.limit) == nil then
        local want = OF.util.clamp(math.floor(tonumber(options ~= nil
            and options.target) or OF.gamemodes.target_for(mode.key)
            or mode.target.default), mode.target.min, mode.target.max)
        OF.util.publish("ofGmLimit", want)
    end

    roundSecs = gGlobalSyncTable.ofGmLimit
    if type(roundSecs) ~= "number" or roundSecs <= 0 then
        roundSecs = zombies.RULES.surviveSecs
    end

    OF.util.report(OF.rules.lend_many({
        { key = "nametags", value = 0 },
        { key = "interactions", value = PLAYER_INTERACTIONS_SOLID },
        { key = "knockback", value = 20 },
    }, "zombies"))
end

function mode.on_start()

    take_the_room()

    roundSecs = gGlobalSyncTable.ofGmLimit
    if type(roundSecs) ~= "number" or roundSecs <= 0 then
        roundSecs = zombies.RULES.surviveSecs
    end

    painted = {}
    fireCooldown = 0
    zombies.forget_sight()
    lastSurvivors = nil
    lastInfected = nil

    if OF.gamemodes.role(0) == ROLE_INFECTED then
        OF.notify.show("You are the horde. Held for @ seconds.", "bad", 6,
            zombies.RULES.holdSeconds)
    else
        OF.notify.show("Run. @ seconds before they are let go.", "warn", 6,
            zombies.RULES.holdSeconds)
    end
end

function mode.cleanup()

    OF.rules.give_back("nametags", "zombies")
    OF.rules.give_back("interactions", "zombies")
    OF.rules.give_back("knockback", "zombies")

    roundSecs = nil
    give_the_room_back()
    painted = {}
    zombies.forget_sight()
end

function mode.before_mario_update(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if fireCooldown > 0 then fireCooldown = fireCooldown - 1 end

    if not is_infected(0) then

        if OF.gamemodes.state() == OF.gamemodes.ACTIVE and not zombies.held()
            and OF.util.can_play(0)
            and (m.action == ACT_PUNCHING or m.action == ACT_MOVE_PUNCHING
                or m.action == ACT_WATER_PUNCH) then
            zombies.shoot(m)
        end
        return
    end

    if zombies.held() then
        OF.input.hold(m)
        return
    end

    if OF.util.has_flag(m.action, ACT_FLAG_STATIONARY)
        or OF.util.has_flag(m.action, ACT_FLAG_MOVING) then
        if m.forwardVel > 1 then
            OF.util.speed_up(m, math.min(m.forwardVel * zombies.RULES.groundGain,
                zombies.RULES.groundCap))
        end
    end
end

local FOG_CLOSES_OVER = 20

local function fog_amount()
    local elapsed = OF.util.asks(OF.gamemodes, "since_start")
        and OF.gamemodes.since_start() or OF.gamemodes.elapsed()
    local hold = zombies.RULES.holdSeconds

    if hold <= 0 then return 1 end
    return OF.util.clamp(elapsed / hold, 0, 1)
end

local function dark_amount()
    local elapsed = OF.util.asks(OF.gamemodes, "since_start")
        and OF.gamemodes.since_start() or OF.gamemodes.elapsed()
    local since = elapsed - zombies.RULES.holdSeconds
    if since <= 0 then return 0 end
    return OF.util.clamp(since / FOG_CLOSES_OVER, 0, 1)
end

function zombies.fog_ramp()
    return fog_amount()
end

function zombies.dark_ramp()
    return dark_amount()
end

local FOG_PEAK = "hazy"
local NEUTRAL_LIGHT = 127
local DARKEST_LIGHT = 75

local TORCH = { r = 255, g = 200, b = 120, radius = 800, intensity = 2.0 }

local torches = {}

local function drop_torch(localIndex)
    local id = torches[localIndex]
    if id == nil then return end
    torches[localIndex] = nil
    OF.util.optional("le_remove_light", nil, id)
end

function zombies.drop_all_torches()
    for localIndex in pairs(torches) do
        OF.util.optional("le_remove_light", nil, torches[localIndex])
    end
    torches = {}
end

function zombies.torch_of(localIndex)
    return torches[localIndex]
end

function zombies.torch_count()
    local count = 0
    for _ in pairs(torches) do count = count + 1 end
    return count
end

local function torch_spot(localIndex)
    local np = gNetworkPlayers[localIndex]
    local mine = gNetworkPlayers[0]
    if np == nil or mine == nil then return nil end
    if np.currLevelNum ~= mine.currLevelNum then return nil end
    if np.currAreaIndex ~= mine.currAreaIndex then return nil end
    if localIndex ~= 0 and not np.currPositionValid then return nil end

    local m = gMarioStates[localIndex]
    if m == nil or m.pos == nil then return nil end
    return m.pos
end

local function light_the_survivors(lit)
    if not lit then
        zombies.drop_all_torches()
        return
    end

    for _, entry in ipairs(OF.util.connected_players()) do
        local localIndex = entry.localIndex
        local spot = nil
        if OF.gamemodes.role(localIndex) == ROLE_SURVIVOR then
            spot = torch_spot(localIndex)
        end

        if spot == nil then
            drop_torch(localIndex)
        else

            local id = torches[localIndex]
            if id == nil or not OF.util.optional("le_light_exists", false, id) then
                id = OF.util.optional("le_add_light", nil,
                    spot.x, spot.y, spot.z,
                    TORCH.r, TORCH.g, TORCH.b, TORCH.radius, TORCH.intensity)
                torches[localIndex] = id
            end
            if id ~= nil then
                OF.util.optional("le_set_light_pos", nil, id, spot.x, spot.y, spot.z)
            end
        end
    end

    for localIndex in pairs(torches) do
        local np = gNetworkPlayers[localIndex]
        if np == nil or not np.connected then drop_torch(localIndex) end
    end
end

function mode.update()
    if not running() then return end

    OF.gamemodes.count_the_hold(zombies.hold_seconds_left())

    take_the_room()

    dress_the_screen()

    tick_sight()

    local amount = fog_amount()
    local dark = dark_amount()

    if OF.util.asks(OF.modifiers, "set_fog")
        and OF.util.asks(OF.modifiers, "fog_step") then
        OF.modifiers.set_fog(amount * OF.modifiers.fog_step(FOG_PEAK))
    end

    if OF.util.asks(OF.modifiers, "set_dark") then
        if dark <= 0 then
            OF.modifiers.clear_dark()
        else
            OF.modifiers.set_dark(math.floor(NEUTRAL_LIGHT
                - (NEUTRAL_LIGHT - DARKEST_LIGHT) * dark))
        end
    end

    local ourLight = OF.util.asks(OF.modifiers, "owns_lighting")
        and OF.modifiers.owns_lighting()
    light_the_survivors(dark > 0 and ourLight)
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if zombies.held() then return end

    if is_infected(0) and OF.util.can_play(0) then
        local hit = fireball_touching(gMarioStates[0])
        if hit ~= nil then zombies.burned_by() end
        return
    end

    if OF.gamemodes.role(0) ~= ROLE_SURVIVOR then return end
    if not OF.util.can_play(0) then return end

    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_INFECTED)) do
        local away = OF.gamemodes.distance(0, entry.localIndex)
        if away ~= nil and away < zombies.RULES.catchRadius
            and OF.gamemodes.tag_move(entry.localIndex) then
            zombies.caught_by(entry.localIndex)
            return
        end
    end
end

local function back_to_the_start()
    local np = gNetworkPlayers[0]
    if np == nil then return end
    OF.net.warp_local(np.currLevelNum, np.currAreaIndex, np.currActNum)
end

function zombies.burned_by()
    OF.notify.show("Burned. Back to the start.", "bad", 4)
    play_sound(SOUND_GENERAL_FLAME_OUT, gMarioStates[0].marioObj.header.gfx.cameraToObject)

    back_to_the_start()
end

function zombies.caught_by(localIndex)
    OF.gamemodes.set_role(0, ROLE_INFECTED)
    local np = gNetworkPlayers[localIndex]
    OF.notify.show("@ got you. You are one of them now.", "bad", 6,
        np ~= nil and np.name or "?")
    play_sound(SOUND_MENU_CAMERA_BUZZ, gMarioStates[0].marioObj.header.gfx.cameraToObject)

    back_to_the_start()
end

function mode.host_update()

    if OF.gamemodes.role_is_gone(ROLE_INFECTED) then
        OF.gamemodes.abandon("The horde is gone.")
        return
    end

    local survivors = #OF.gamemodes.with_role(ROLE_SURVIVOR)
    local infected = #OF.gamemodes.with_role(ROLE_INFECTED)

    if lastSurvivors ~= nil and lastInfected ~= nil then
        local lost = lastSurvivors - survivors
        local gained = infected - lastInfected
        if lost > 0 and gained == lost then

            zombies.restart_clock()
            OF.notify.send_all("Another one.", "warn", 5)
        end
    end
    lastSurvivors = survivors
    lastInfected = infected

    if survivors == 0 then
        OF.gamemodes.finish("The horde took everybody.")
        return
    end

    if infected == 0 then
        local left = OF.gamemodes.with_role(ROLE_SURVIVOR)
        if survivors == 1 and left[1] ~= nil and left[1].np ~= nil then
            local name = left[1].np.name
            OF.gamemodes.finish("The horde is gone - @ walks out.", name, name)
        else

            local names = {}
            for _, entry in ipairs(left) do
                if entry.np ~= nil and entry.np.name ~= nil then
                    table.insert(names, entry.np.name)
                end
            end
            OF.gamemodes.finish("The horde is gone - @ survivor(s) walk out.",
                { names = names }, survivors)
        end
        return
    end
end

local function opening_length()
    local live = OF.gamemodes.round_seconds()
    if live ~= nil then return live end
    if type(roundSecs) == "number" and roundSecs > 0 then return roundSecs end
    return nil
end

function zombies.round_seconds()
    return opening_length() or zombies.RULES.surviveSecs
end

function zombies.clock_ceiling()
    return zombies.round_seconds() * CLOCK_CAP
end

function zombies.restart_clock()
    if not OF.util.is_host() then return false, 0 end
    local limit = gGlobalSyncTable.ofGmLimit or 0
    if limit <= 0 then return false, 0 end
    local wanted = (gGlobalSyncTable.ofGmElapsed or 0) + zombies.round_seconds()
    local ceiling = zombies.clock_ceiling()
    if wanted > ceiling then wanted = ceiling end
    if wanted <= limit then return false, 0 end
    OF.util.publish("ofGmLimit", wanted)
    return true, wanted - limit
end

function mode.terms()
    return OF.lang.t("outlast the clock - every catch puts it back")
end

function mode.on_timeout()
    local survivors = OF.gamemodes.with_role(ROLE_SURVIVOR)
    if #survivors == 0 then
        OF.gamemodes.finish("The horde took everybody.")
        return
    end
    if #survivors == 1 then
        local name = survivors[1].np.name
        OF.gamemodes.finish("@ was the last one standing.", name, name)
        return
    end

    local names = {}
    for _, entry in ipairs(survivors) do
        if entry.np ~= nil and entry.np.name ~= nil then
            table.insert(names, entry.np.name)
        end
    end
    OF.gamemodes.finish("@ survivor(s) made it out.", { names = names },
        #survivors)
end

function mode.late_join(localIndex)

    return ROLE_INFECTED
end

function zombies.blind()
    if not running() then return false end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false end
    if is_infected(0) then return false end
    if not OF.util.can_play(0) then return false end
    local elapsed = OF.util.asks(OF.gamemodes, "since_start")
        and OF.gamemodes.since_start() or OF.gamemodes.elapsed()
    return elapsed < zombies.RULES.blindSeconds
end

local function draw_the_curtain()
    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()
    OF.util.rect(0, 0, screenWidth + 2, screenHeight + 2, 0, 0, 0, 255)
end

function mode.hud()
    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()

    if zombies.blind() then draw_the_curtain() end

    local text
    if zombies.held() then
        text = OF.lang.fill("The horde is let go in @", zombies.hold_seconds_left())
    elseif is_infected(0) then
        text = OF.lang.t("Hunt them down")
    else
        text = OF.lang.t("Stay alive")
    end
    OF.util.banner(text, 1.0, OF.util.gold().r, OF.util.gold().g, OF.util.gold().b, 255)

    local nearest, side = draw_the_other_side()
    if side ~= nil then
        local line
        if nearest == nil then

            line = side == ROLE_SURVIVOR
                and OF.lang.t("No survivors in sight")
                or OF.lang.t("No zombies in sight")
        else
            line = OF.lang.fill(side == ROLE_SURVIVOR
                    and "Nearest survivor in sight @ away"
                    or "Nearest zombie in sight @ away",
                string.format("%.0f", nearest))
        end
        OF.util.banner(line, 0.9, 235, 235, 235, 255)
    end

    local band = zombies.terror_band()
    if band == "onyou" then
        OF.util.banner(OF.lang.t("The horde is on you"), 0.9, 255, 90, 90, 255)
    elseif band == "close" then
        OF.util.banner(OF.lang.t("Something is close"), 0.9, 255, 190, 110, 255)
    end

    local x = screenWidth * LIST_X
    local y = screenHeight * LIST_Y

    local horde = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_INFECTED)) do
        if entry.np ~= nil then
            table.insert(horde, { name = entry.np.name,
                                  localIndex = entry.localIndex })
        end
    end

    local board = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_SURVIVOR)) do
        if entry.np ~= nil then
            table.insert(board, { name = entry.np.name,
                                  localIndex = entry.localIndex })
        end
    end

    y = OF.util.board(x, y, OF.lang.fill("The horde (@)", #horde), horde)
    OF.util.board(x, y + 8,
        OF.lang.fill("Still out there (@)", #board), board)

    if not is_infected(0) and not zombies.held()
        and OF.gamemodes.state() == OF.gamemodes.ACTIVE then
        local width, height = 120, 8
        local x = screenWidth * 0.5 - width * 0.5
        local y = screenHeight * 0.86
        OF.util.plate(x - 5, y - 5, width + 10, height + 10)

        OF.util.meter(x, y, width, height, 1 - zombies.fire_charge(),
            { r = 255, g = 150, b = 60 }, { r = 70, g = 45, b = 35 })

        local hint = OF.lang.t("B to throw")
        local face = OF.util.hud_face(hint)
        OF.util.in_font(face, function()
            local scale = OF.util.hud_scale(face, FIRE_HINT_SCALE)
            local hintWidth = OF.util.text_size(hint, scale)
            OF.util.text(hint, x + width * 0.5 - hintWidth * 0.5,
                y + height + FIRE_HINT_GAP, scale, 200, 200, 200, 190)
        end)
    end
end

OF.gamemodes.register(mode)

hook_event(HOOK_MARIO_UPDATE, function(m)
    if not running() then return end
    zombies.draw_one(m)
end)

function zombies.rule_count()
    local count = 0
    for _ in pairs(zombies.RULES) do count = count + 1 end
    return count
end
