OF = OF or {}
OF.zombies = OF.zombies or {}

local zombies = OF.zombies

local lastSurvivors = nil
local lastInfected = nil

local burnedOut = false

local startedInfected = false

local redeemTags = 0
local redeemSeen = {}

local roundSecs = nil

local CLOCK_CAP = 2

local REDEEM_TAGS = 2

local ROLE_SURVIVOR = "surviving"
local ROLE_INFECTED = "infected"
local LIST_X = 0.03
local LIST_Y = 0.24

local STACKED = { scale = 0.85, columns = 1 }

zombies.RULES = {
    holdSeconds   = 15,

    surviveSecs   = 2 * 60,
    groundGain    = 1.18,
    groundCap     = 42,

    catchRadius   = 140,

    fireRest      = 45,
}

local BLACK = { r = 20, g = 20, b = 24 }

local PLAIN_METAL = { r = 255, g = 255, b = 255 }
local METAL_PART = CAP or 6

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

    if OF.util.asks(OF.modifiers, "fade_forget") then
        OF.modifiers.fade_forget("fog")
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
                np, part, part == METAL_PART and PLAIN_METAL or BLACK)
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
        OF.gamemodes.round_sound(SOUND_GENERAL_FLAME_OUT)
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

function zombies.can_see(localIndex)

    local _ = localIndex
    return false
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

local mode = {

    lobbyRules = { nametags = 0, knockback = 20 },
    key = "zombies",

    marking = { players = false },

    allActs = true,

    catchers = { [ROLE_INFECTED] = true },
    name = "Zombies",
    blurb = "outlast the horde, or join it",

    aims = {
        ["surviving"] = "Stay away from the infected until the clock runs out.",
        ["infected"]  = "Touch the survivors - every one you catch joins you.",
    },

    noDozing = true,

    cheatsGiven = OF.gamemodes.water_rule("hide"),

    room = { rules = { interactions = 0 } },

    how = "One in four of you starts infected. The rest are running.\n"
        .. "A catch is an attack - punch, kick, dive, slide, pound.\n"
        .. "On a pole or in water, a touch is enough.\n"
        .. "Taken once - whether fire cures you is set below.\n"
        .. "Every catch puts the survivors' clock back.\n"
        .. "Arrive part way through and you arrive infected.\n"
        .. "Survivors outlast the clock; the horde takes all.",
    minPlayers = 2,

    music = SEQ_LEVEL_SPOOKY,
    defaultLimit = zombies.RULES.surviveSecs,

    target = { name = "seconds to outlast",
               asks = "How long to outlast the horde",
               help = "each catch sets the clock back",
               clock = true,
               default = zombies.RULES.surviveSecs,
               min = 60, max = 300, step = 30 },

    caps = { tiebreak = false },

    roleBanner = false,
    lastWord = "LAST SURVIVOR",

    noSweep = true,

    inertStarsAndCaps = true,

    enemiesBack = 10,

    maps = "anywhere",

    roomsOut = OF.gm_single_level_rooms_out({ "tower", "wmotr", "bowser1", "bowser2", "bowser3",
        "the_plate", "ice_donut", "desert_cage", "igloo", "wigglercave",
        "aquarium",

        "volcano" }),

    mainCourses = true,

    mods = "night=2,dark=2,fog=1",

    options = {

        { key = "pace", name = "How fast the horde is",
          help = "how much quicker the infected run, on the ground",
          choices = {
              { key = "quick", name = "a little faster",
                help = "a fifth faster than you: run down over a long straight" },
              { key = "even", name = "same speed",
                help = "the horde runs at your speed; cornered, not outrun" },
              { key = "fast", name = "much faster",
                help = "nobody outruns the horde; it is doors, drops and height" },
          } },

        { key = "back", name = "A zombie turns human again",
          help = "how one of the horde can come back",
          choices = {
              { key = "never", name = "never",
                help = "a fireball sends a zombie to the start, still a zombie" },
              { key = "fire", name = "hit by a fireball",
                help = "a survivor's fireball turns one back, at the level's start" },
              { key = "tags", name = "after two tags",
                help = "catch two humans and you are one again" },
              { key = "either", name = "either",
                help = "a fireball or two tags" },
          } },

        { key = "replay", name = "Replay at the end",
          help = "the seconds before the round was decided, again",
          choices = {
              { key = "short", name = "the last three seconds",
                help = "played inside the ending - no extra wait" },
              { key = "long", name = "the last six seconds",
                help = "the ending waits three seconds more" },
              { key = "off", name = "no replay",
                help = "the winner's line over the world, as before" },
          } },
    },
}

local PACE_STOPS = { even = 1.0, fast = 1.5 }

function zombies.cures()
    local back = OF.gamemodes.option_now("back")
    return back == "fire" or back == "either"
end
function zombies.redeems()
    local back = OF.gamemodes.option_now("back")
    return back == "tags" or back == "either"
end

local releaseSaid = false
function zombies.say(word, sub)
    if not OF.util.asks(OF.hud, "banner") then return nil end
    return OF.hud.banner("role", OF.lang.t(word), sub and OF.lang.t(sub) or nil)
end

function zombies.horde_gain()
    local said = OF.gamemodes.option_now("pace")
    if said == nil or said == "quick" then return zombies.RULES.groundGain end
    return PACE_STOPS[said] or zombies.RULES.groundGain
end

local function horde_wins(text)
    local names = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_INFECTED)) do
        local np = entry.np
        if np ~= nil and np.name ~= nil then names[#names + 1] = np.name end
    end
    if #names == 0 then
        OF.gamemodes.finish(text)
        return
    end
    OF.gamemodes.finish(text, { names = names })
end
mode.horde_wins = horde_wins

function mode.setup(players, options)

    local howMany = OF.gamemodes.fair_minority(#players, math.floor(#players / 4))
    local it = OF.gamemodes.deal_fair(players, howMany, "horde")

    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex,
            it[entry.localIndex] and ROLE_INFECTED or ROLE_SURVIVOR)
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
        { key = "knockback", value = 20 },
    }, "zombies"))
end

function mode.on_start()
    zombies.heardBand = 0

    take_the_room()

    roundSecs = gGlobalSyncTable.ofGmLimit
    if type(roundSecs) ~= "number" or roundSecs <= 0 then
        roundSecs = zombies.RULES.surviveSecs
    end

    painted = {}
    fireCooldown = 0
    lastSurvivors = nil
    lastInfected = nil
    burnedOut = false

    startedInfected = OF.gamemodes.role(0) == ROLE_INFECTED
    redeemTags = 0
    redeemSeen = {}

    releaseSaid = false

end

function mode.cleanup()
    zombies.heardBand = 0

    OF.rules.give_back("nametags", "zombies")
    OF.rules.give_back("knockback", "zombies")

    roundSecs = nil
    give_the_room_back()
    painted = {}

    OF.util.publish_row(0, "ofCaughtBy", nil)
    startedInfected = false
    redeemTags = 0
    redeemSeen = {}
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
            OF.util.speed_up(m, math.min(m.forwardVel * zombies.horde_gain(),
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

    local band = zombies.terror_band()
    local rank = band == "onyou" and 2 or (band == "close" and 1 or 0)
    if rank > (zombies.heardBand or 0) then OF.gamemodes.cue("hazard") end
    zombies.heardBand = rank

    take_the_room()

    dress_the_screen()

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

        if zombies.check_redeem() then return end
        local hit = fireball_touching(gMarioStates[0])
        if hit ~= nil then zombies.burned_by() end
        zombies.claim_bites()
        return
    end

    if OF.gamemodes.role(0) ~= ROLE_SURVIVOR then return end
    if not OF.util.can_play(0) then return end

    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_INFECTED)) do
        if OF.gamemodes.tag_lands(entry.localIndex, 0, zombies.RULES.catchRadius) then
            zombies.caught_by(entry.localIndex)
            return
        end
    end
end

function zombies.claim_bites()
    if not OF.gamemodes.tag_move(0) then return 0 end
    local sent = 0
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_SURVIVOR)) do
        local li = entry.localIndex
        if li ~= 0 then
            local away = OF.gamemodes.distance(li, 0)
            if away ~= nil and away < zombies.RULES.catchRadius
                and OF.gamemodes.send_hit_claim(li) then
                sent = sent + 1
            end
        end
    end
    return sent
end

local function back_to_the_start()
    local np = gNetworkPlayers[0]
    if np == nil then return end
    OF.net.warp_local(np.currLevelNum, np.currAreaIndex, np.currActNum)
end

local function credits_to_me()
    local mine = network_global_index_from_local(0)
    local out = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_INFECTED)) do
        if entry.localIndex ~= 0 then
            local globalIndex = network_global_index_from_local(entry.localIndex)
            if globalIndex ~= nil then
                local row = gPlayerSyncTable[entry.localIndex]
                if row ~= nil and row.ofCaughtBy == mine then
                    out[globalIndex] = true
                end
            end
        end
    end
    return out
end

function zombies.check_redeem()
    if not zombies.redeems() then return false end

    if startedInfected then return false end

    local stillInfected = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_INFECTED)) do
        if entry.localIndex ~= 0 then
            local globalIndex = network_global_index_from_local(entry.localIndex)
            if globalIndex ~= nil then stillInfected[globalIndex] = true end
        end
    end

    for globalIndex in pairs(redeemSeen) do
        if not stillInfected[globalIndex] then redeemSeen[globalIndex] = nil end
    end

    for globalIndex in pairs(credits_to_me()) do
        if not redeemSeen[globalIndex] then
            redeemSeen[globalIndex] = true
            redeemTags = redeemTags + 1
        end
    end

    if redeemTags < REDEEM_TAGS then return false end

    OF.gamemodes.set_role(0, ROLE_SURVIVOR)
    redeemTags = 0
    redeemSeen = {}
    zombies.say("CURED", "Two tags")
    OF.notify.send_all("@ tagged two and came back.", "warn", 5,
        gNetworkPlayers[0] ~= nil and gNetworkPlayers[0].name or "?")
    OF.gamemodes.cue("good")

    back_to_the_start()
    return true
end

function zombies.burned_by()

    if zombies.cures() then
        OF.gamemodes.set_role(0, ROLE_SURVIVOR)
        zombies.say("CURED", "Back to the start")
        OF.gamemodes.cue("good")
        back_to_the_start()
        return
    end

    if OF.util.asks(OF.hud, "banner") then
        OF.hud.banner("objective", OF.lang.t("BURNED"), OF.lang.t("Back to the start"),
            { side = "them" })
    end
    OF.gamemodes.round_sound(SOUND_GENERAL_FLAME_OUT)

    back_to_the_start()
end

function zombies.caught_by(localIndex)
    OF.gamemodes.set_role(0, ROLE_INFECTED)
    if OF.util.asks(OF.lobbytalk, "feed") then OF.lobbytalk.feed(localIndex, 0) end
    local np = gNetworkPlayers[localIndex]
    zombies.say("INFECTED", OF.lang.fill("Caught by @", np ~= nil and np.name or "?"))

    local catcherGlobalIndex = network_global_index_from_local(localIndex)
    if catcherGlobalIndex ~= nil then
        OF.util.publish_row(0, "ofCaughtBy", catcherGlobalIndex)
    end

    redeemTags = 0
    redeemSeen = credits_to_me()

    back_to_the_start()
end

function mode.host_update()
    local survivors = #OF.gamemodes.with_role(ROLE_SURVIVOR)
    local infected = #OF.gamemodes.with_role(ROLE_INFECTED)

    if lastSurvivors ~= nil and lastInfected ~= nil then
        local lost = lastSurvivors - survivors
        local gained = infected - lastInfected

        if lost < 0 and gained == lost
            and (zombies.cures() or zombies.redeems()) then
            burnedOut = true
        end
        if lost > 0 and gained == lost then

            zombies.restart_clock()
            OF.notify.send_all("Another one.", "warn", 5)
        end
    end
    lastSurvivors = survivors
    lastInfected = infected

    if OF.gamemodes.role_is_gone(ROLE_INFECTED) and not burnedOut then
        OF.gamemodes.abandon("The horde is gone.")
        return
    end

    if survivors == 0 then
        horde_wins("The horde took everybody.")
        return
    end

    if infected == 0 then
        local left = OF.gamemodes.with_role(ROLE_SURVIVOR)
        if survivors == 1 and left[1] ~= nil and left[1].np ~= nil then
            local name = left[1].np.name
            OF.gamemodes.finish("The horde is gone - @ won.", name, name)
        else

            local names = {}
            for _, entry in ipairs(left) do
                if entry.np ~= nil and entry.np.name ~= nil then
                    table.insert(names, entry.np.name)
                end
            end
            OF.gamemodes.finish(survivors == 1 and "The horde is gone - 1 player won."
                or "The horde is gone - @ players won.", { names = names }, survivors)
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
        horde_wins("The horde took everybody.")
        return
    end
    if #survivors == 1 then
        local name = survivors[1].np.name
        OF.gamemodes.finish("@ won.", name, name)
        return
    end

    local names = {}
    for _, entry in ipairs(survivors) do
        if entry.np ~= nil and entry.np.name ~= nil then
            table.insert(names, entry.np.name)
        end
    end
    OF.gamemodes.finish(#survivors == 1 and "Time - 1 player won." or "Time - @ players won.",
        { names = names }, #survivors)
end

function mode.late_join(localIndex)

    return ROLE_INFECTED
end

function zombies.blind()
    if not running() then return false end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false end
    if not OF.util.can_play(0) then return false end
    if is_infected(0) then return zombies.held() end
    return false
end

local function draw_the_curtain()
    if OF.util.asks(OF.hunt, "draw_curtain") then OF.hunt.draw_curtain() end
end

function mode.hud()
    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()

    if zombies.blind() then
        draw_the_curtain()
        if OF.util.asks(OF.hunt, "blind_number") then
            OF.hunt.blind_number(zombies.hold_seconds_left())
        end
    end

    if running() and OF.gamemodes.state() == OF.gamemodes.ACTIVE then
        if zombies.held() then
            releaseSaid = false
        elseif not releaseSaid then
            releaseSaid = true
            if OF.gamemodes.since_start() > 2 and OF.util.asks(OF.hud, "banner") then
                OF.hud.banner("objective", OF.lang.t("HORDE OUT"), nil,
                    { side = is_infected(0) and "us" or "them" })
            end
        end
    end

    local state = OF.util.asks(OF.hud, "state_line") and OF.hud.state_line or function() end
    if zombies.held() and not is_infected(0) then
        state("held", OF.lang.t("Let go in"), { prio = 70, figure = zombies.hold_seconds_left(),
            tone = "hunter" })
    end
    local band = zombies.terror_band()
    if band == "onyou" then
        state("onyou", OF.lang.t("On you"), { prio = 85, urgent = true, tone = "bad" })
    elseif band == "close" then
        state("close", OF.lang.t("Something close"), { prio = 60, tone = "warn" })
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

    y = OF.util.board_top(x, y)
    STACKED.scale, STACKED.columns = OF.util.board_fit(#horde + #board + 1, 2,
        y - 5, OF.util.board_bottom() - 36)
    y = OF.util.board(x, y, OF.lang.fill("The horde (@)", #horde), horde, STACKED)
    OF.util.board(x, y + 8,
        OF.lang.fill("Still out there (@)", #board), board, STACKED)

    if not is_infected(0) and not zombies.held()
        and OF.gamemodes.state() == OF.gamemodes.ACTIVE then
        local width, height = 120, 8
        local x = screenWidth * 0.5 - width * 0.5
        local y = screenHeight * 0.86

        if OF.util.asks(OF.hud, "meter") then
            OF.hud.meter(x, y, width, 1 - zombies.fire_charge(), { 255, 150, 60 }, { h = height })
        else
            OF.util.round_plate(x - 5, y - 5, width + 10, height + 10)
            OF.util.meter(x, y, width, height, 1 - zombies.fire_charge(),
                { r = 255, g = 150, b = 60 }, { r = 70, g = 45, b = 35 })
        end

        OF.util.legend(mode.controls_lines())
    end
end

function mode.controls_lines()
    if is_infected(0) or zombies.held() then return {} end

    return {
        OF.lang.t("B - throw fire"),
    }
end

function mode.cluster()
    if not OF.util.asks(OF.hunt, "role_cluster") or OF.gamemodes.is_waiting() then return nil end
    return OF.hunt.role_cluster("Horde", #OF.gamemodes.with_role(ROLE_INFECTED), "hunter",
        "Left", #OF.gamemodes.with_role(ROLE_SURVIVOR), "runner")
end

mode.presets = {
    { key = "classic", name = "Classic", help = "the usual round", sets = {} },
    { key = "cure", name = "Cure", help = "a fireball turns a zombie human",
      sets = { back = "fire" } },
    { key = "nightmare", name = "Nightmare", help = "the horde is much faster",
      sets = { pace = "fast" } },
}

function mode.blind() return zombies.blind() == true end

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
