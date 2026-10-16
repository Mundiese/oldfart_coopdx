OF = OF or {}

OF.SLOT_NEEDS = OF.SLOT_NEEDS or {}
table.insert(OF.SLOT_NEEDS, function() return { E_MODEL_BULLET_BILL } end)

local ROLE_SHOOTING = "shooting"
local TARGET_KEY = "ofRktTarget"
local SHOT_KEY = "ofRktShot"
local BLAST_KEY = "ofRktBlast"
local DOWN_KEY = "ofRktDownBy"
local GRAB_KEY = "ofRktGrab"
local PICK_PTS_KEY = "ofRktPickPts"
local PICK_AT_KEY = "ofRktPickAt"
local DEFAULT_KILLS = 15
local SCALED_MOST = 25

local ROLE_OUT = "out"
local ROCKET_SPEED = 130

local ROCKET_LIFE = 90

local ROCKET_COOLDOWN = 46

local DIRECT_HIT_REACH = 90

local BODY_MID = 80
local BODY_TALL = 170

local ROCKET_LOOK = 0.3

local TRAIL_EVERY = 2

local SPLASH_STOPS = {
    standard = { hurt = 400, push = 700 },
    tight    = { hurt = 280, push = 500 },
    wide     = { hurt = 520, push = 950 },
}
local SPLASH_DEFAULT = "standard"
local DOOMED = 0x100

local POWER_SCALE = 2
local rocketJumping = false

local CREDIT_FRAMES = 5 * 30

local KICK_MIN = 26
local KICK_MAX = 64
local PUSH_MAX = 46

local SELF_KICK_MIN = 55
local SELF_KICK_MAX = 95
local SELF_PUSH_MAX = 60

local POWER_REACH = 1.5

local PICKUP_WANT = 8
local PICKUP_REACH = 100
local PICKUP_KINDS = { "health", "speed", "health", "power" }
local HEAL_QUARTERS = 12
local FULL_HEALTH = 0x880
local HEALTH_RESPAWN = 20 * 30
local SPEED_RESPAWN = 45 * 30
local POWER_RESPAWN = 60 * 30
local BOOST_DURATION = 12 * 30
local POWER_DURATION = 10 * 30

local BOOST_SPEED_SCALE = 1.6

local BOOST_TOP = 64

local POWER_FIRST_MID = 45 * 30
local POWER_FIRST_SPREAD = 15

local DENIED_REACH = 550
local DENIED_COS = 0.4

local BOBOMB_SMOKE_RISE = 100
local PUFF_FRAMES = 9

local function now_frame()
    return OF.util.optional("get_global_timer", 0) or 0
end

local function target_kills()
    local want = gGlobalSyncTable[TARGET_KEY]
    if type(want) ~= "number" or want <= 0 then return DEFAULT_KILLS end
    return math.floor(OF.util.clamp(want, 5, 100))
end

local function score_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    return (row ~= nil and row.ofScore) or 0
end

local TARGET_PER_PLAYER = DEFAULT_KILLS / 5

local function scaled_target(count, teams)
    local n = math.max(count, 1)
    if teams then
        return math.floor(OF.util.clamp(OF.gamemodes.round_to(5 * n, 5), 20, 80))
    end
    return math.floor(OF.util.clamp(OF.gamemodes.round_to(8 + n, 5), 10, SCALED_MOST))
end

local respawnPending = false
local flying = {}
local shotSerial = 0
local rocketReadyAt = -9999
local aimingRocket = false
local bWasDown = false
local seenBlast = {}
local lastHurtBy = nil
local lastHurtAt = -9999
local downSerial = 0
local pictures = {}
local seenShot = {}
local shownBlast = {}
local puffs = {}
local seenDown = {}
local pickupPointsRaw = nil
local pickupPoints = nil
local pickAvailAt = {}
local clientAvailAt = {}
local seenGrab = {}
local grabSerial = 0
local boostUntil = -9999
local powerUntil = -9999
local markers = {}
local markerModel = {}
local rowsRead = false

local dq = { grabsHeard = {}, powerUp = {} }

local STRAFE = { gain = 0.7, ceiling = 64, turn = 0x180, lo = 0x38E,
                 hi = 0x4000, hop = 5 }

local RUNE = { key = "ofRktRunes", kinds = { "haste", "speed", "reach" },
               haste = 30, idle = 120 * 30, slack = 3, lift = 100,
               grab = 8, drop = 9, ask = 15 }
local runes = {}

local mode = {
    key = "rocketarena",

    tagRule = "shooter",

    noLeaderMark = true,
    name = "Rocket Arena",
    blurb = "rockets, splash and a rocket jump - the arena shooter",
    blurbTeams = "rockets, splash and a rocket jump - team against team",
    how = "Hold L to aim, press B to fire a rocket.\n"
        .. "Any hit kills, direct or splash.\n"
        .. "Fire at your feet to rocket jump - your blast spares you.\n"
        .. "Run faster and jump higher all round.\n"
        .. "Grab health, speed and a wider blast.\n"
        .. "First to the count wins; on the clock, the most.",
    aims = { [ROLE_SHOOTING] =
        "Rockets only. Blow them up - don't stand in it." },
    minPlayers = 4,

    maps = "surveyed", openCourses = true,

    roomsOut = {
        { level = LEVEL_SL, area = 2 }, { level = LEVEL_THI, area = 3 },
        { level = LEVEL_BITDW, area = 1 }, { level = LEVEL_BITFS, area = 1 },

        { level = LEVEL_RR, area = 1 }, { level = LEVEL_TTC, area = 1 },
        { level = LEVEL_LLL, area = 1 }, { level = LEVEL_LLL, area = 2 },

        { level = LEVEL_TTM, area = 1 }, { level = LEVEL_THI, area = 2 },
    },

    surveyOut = { { level = LEVEL_PSS, area = 1 }, { level = LEVEL_VCUTM, area = 1 },
        { level = LEVEL_TTC, area = 1 }, { level = LEVEL_RR, area = 1 },
        { level = LEVEL_BITDW, area = 1 }, { level = LEVEL_BITFS, area = 1 } },

    spreadOpening = true,

    weapon = "launcher",
    surveyKeys = { "points" },
    room = { sweep = { "cannons" }, rules = { bubble = 0 } },

    cheatsGiven = { triples = 1 },

    mods = "quick=2",
    roundKills = true,
    defaultLimit = 180,
    music = SEQ_LEVEL_BOSS_KOOPA,
    teams = true,
    target = { name = "kills to win",
               asks = "How many kills win the round",
               default = DEFAULT_KILLS,

               shownIf = { play = "kills" },
               min = 5, max = 100, step = 5 },
    options = {

        { key = "play", name = "How the round is played",
          help = "respawns and a kill count, or one life each",
          choices = {
              { key = "kills", name = "first to the count",
                help = "respawn, pickups, the most kills wins" },
              { key = "arena", name = "last one standing",
                help = "one life, no pickups - with sides, Clan Arena" },
          } },

        { key = "rockets", name = "How a rocket flies",
          help = "straight, or one turn at the nearest like a Missile Bill",
          choices = {
              { key = "straight", name = "straight",
                help = "where you aim is where it goes" },
              { key = "missile", name = "one turn, like a Missile Bill",
                help = "half a second out it turns once at the nearest rival" },
          } },
        { key = "splash", name = "Splash size",
          help = "how far a rocket's blast carries",
          choices = {
              { key = "standard", name = "normal",
                help = "a solid hurt radius and a wide shove" },
              { key = "tight", name = "close quarters",
                help = "you have to be nearly on top of it" },
              { key = "wide", name = "wide open",
                help = "a rocket clears more of the arena" },
          } },

        { key = "pickups", name = "Pickups",
          help = "health, speed and a wider blast at spread points",
          shownIf = { play = "kills" },
          choices = {
              { key = "quake3", name = "Quake 3's way",
                help = "the wider blast first after 30-60 s, announced" },
              { key = "atgo", name = "all at GO",
                help = "everything ready from the start, nothing announced" },
              { key = "off", name = "none",
                help = "just rockets - nothing on the ground to grab" },
          } },

        { key = "strafe", name = "Air strafing",
          help = "steer at an angle in the air to build speed",
          choices = {
              { key = "off", name = "off",
                help = "Mario's own air control" },
              { key = "on", name = "on",
                help = "faster sideways; jump on landing to keep it" },
          } },

        { key = "runes", name = "Runes",
          help = "Rapid fire, Speed and Reach, kept until you go down",
          shownIf = { play = "kills" },
          choices = {
              { key = "off", name = "none",
                help = "no runes" },
              { key = "on", name = "three runes",
                help = "one each; dropped where you fall" },
          } },

        { key = "medals", name = "Medals",
          help = "Excellent for two kills in three seconds, told to you",
          choices = {
              { key = "on", name = "on",
                help = "two kills in three seconds" },
              { key = "off", name = "off",
                help = "a kill is a kill, nothing more said" },
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
        { key = "killcam", name = "Kill cam",
          help = "the seconds before you went down, from their side",
          choices = {
              { key = "on", name = "shown while you fall",
                help = "no extra wait - it plays through the death" },
              { key = "off", name = "no kill cam",
                help = "you watch yourself fall, as before" },
          } },
    },
}

local function side_point(side)
    local here = OF.gamemodes.here_place(0)
    if here == nil then return nil end
    local points = OF.gamemodes.surveyed_list(here, "points")
    if points == nil then return nil end
    local at = (side == "blue") and 2 or 1
    if points[3] ~= nil then
        local level = here.level or 0
        local favoured = (level % 2 == 0) and "red" or "blue"
        if side == favoured then at = 3 end
    end
    return points[at] or points[1]
end

local function arena_play()
    return OF.gamemodes.option_is("play", "arena")
end

local function am_out()
    return OF.gamemodes.role(0) == ROLE_OUT
end

local function pickups_on()
    return not OF.gamemodes.option_is("pickups", "off") and not arena_play()
end

local function pickups_quake3()
    return OF.gamemodes.option_is("pickups", "quake3")
end

local function still_in()
    local list = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_SHOOTING)) do
        if OF.gamemodes.in_contention(entry.localIndex) then
            table.insert(list, entry)
        end
    end
    return list
end

local function dress_results()
    if arena_play() then mode.resultsBy = "survival" else mode.resultsBy = nil end
end

local function go_out_if_one_life()
    if not arena_play() then return false end
    if am_out() then return false end
    OF.gamemodes.set_role(0, ROLE_OUT)
    OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())

    return true
end

local function arena_ending()
    if OF.teams.in_play() then
        local side = OF.teams.last_side_standing(function(localIndex)
            return OF.gamemodes.role(localIndex) == ROLE_SHOOTING
                and OF.gamemodes.in_contention(localIndex)
        end)
        if side ~= nil then
            OF.gamemodes.finish(OF.teams.survival_text(side),
                OF.gamemodes.team_winner(side))
            return true
        end
        return false
    end
    local alive = still_in()
    if #alive == 1 and #OF.gamemodes.still_here() > 1 then
        OF.gamemodes.finish("@ won.", alive[1].np.name, alive[1].np.name)
        return true
    elseif #alive == 0 then
        OF.gamemodes.finish("Everyone went down at once.")
        return true
    end
    return false
end

local function splash_stop()
    return SPLASH_STOPS[OF.gamemodes.option_now("splash") or SPLASH_DEFAULT]
        or SPLASH_STOPS[SPLASH_DEFAULT]
end

local function global_of(localIndex)
    local np = gNetworkPlayers[localIndex]
    return np ~= nil and np.globalIndex or nil
end

local function seat_of_global(globalIndex)
    for _, entry in ipairs(OF.util.connected_players()) do
        if entry.np ~= nil and entry.np.globalIndex == globalIndex then
            return entry
        end
    end
    return nil
end

local function name_of(localIndex)
    local np = gNetworkPlayers[localIndex]
    return np ~= nil and np.name or "?"
end

local homes = {}

local function spawn_local(bhv, model, x, y, z, fn)
    if type(bhv) ~= "number" or type(model) ~= "number" then return nil end
    local obj = OF.slots.spawn_non_sync(bhv, model, x, y, z, fn, true)

    if obj ~= nil and bhv == id_bhvStaticObject then
        homes[obj] = { obj.oHomeX, obj.oHomeY, obj.oHomeZ }
    end
    return obj
end

local function ours(obj, model)
    if obj == nil or not OF.util.alive(obj) or obj.activeFlags == 0 then
        return false
    end
    local home = homes[obj]
    if home ~= nil and obj.oHomeX == home[1] and obj.oHomeY == home[2]
        and obj.oHomeZ == home[3]
        and OF.util.optional("obj_has_behavior_id", 1, obj, id_bhvStaticObject) ~= 0 then
        return true
    end
    if not OF.util.asks(OF.shooter, "still_ours") then return false end
    return OF.shooter.still_ours(obj, id_bhvStaticObject, model)
end

local function drop_object(obj, model)
    if ours(obj, model) then
        OF.util.optional("obj_mark_for_deletion", nil, obj)
    end
    if obj ~= nil then homes[obj] = nil end
end

local function sound_at(sound, x, y, z)
    if sound == nil then return nil end

    if not OF.gamemodes.hears_round() then return nil end
    return spawn_local(id_bhvSoundSpawner, E_MODEL_NONE, x, y, z,
        function(o) o.oSoundEffectUnkF4 = sound end)
end

mode.target.auto = function(n, teams)
    return scaled_target(n, teams)
end

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_SHOOTING)
    end
    local target = math.floor(tonumber(OF.gamemodes.auto_target(mode, players,
        options or { target = DEFAULT_KILLS })) or DEFAULT_KILLS)
    OF.util.publish(TARGET_KEY, target)
    return true
end

mode.presets = {
    { key = "classic", name = "Classic", help = "the usual round", sets = {} },
    { key = "quake", name = "Quake duel", help = "air strafing and Quake 3's pickups",
      sets = { strafe = "on" } },
    { key = "clan", name = "Clan Arena", help = "one life each, no pickups",
      sets = { play = "arena" } },
    { key = "missile", name = "Missile mayhem", help = "Missile Bills with a wide splash",
      sets = { rockets = "missile", splash = "wide" } },
}

function mode.late_join(localIndex)
    if arena_play() and OF.gamemodes.state() == OF.gamemodes.ACTIVE then
        OF.gamemodes.set_role(localIndex, ROLE_OUT)
        return ROLE_OUT
    end
    OF.gamemodes.set_role(localIndex, ROLE_SHOOTING)
    return ROLE_SHOOTING
end

local function pack_at(list)
    local parts = {}
    for i = 1, #list do parts[i] = string.format("%.0f", list[i] or 0) end
    return table.concat(parts, " ")
end

local function unpack_at(text)
    local out = {}
    if type(text) ~= "string" then return out end
    local i = 0
    for tok in text:gmatch("%S+") do
        i = i + 1
        out[i] = tonumber(tok) or 0
    end
    return out
end

local function read_shot(packed)
    if type(packed) ~= "string" or packed == "" then return nil end
    local x, y, z, dx, dy, dz, s, turn = packed:match(
        "^(%S+) (%S+) (%S+) (%S+) (%S+) (%S+) (%S+) ?(%S*)$")
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    dx, dy, dz, s = tonumber(dx), tonumber(dy), tonumber(dz), tonumber(s)
    if x == nil or y == nil or z == nil or dx == nil or dy == nil
        or dz == nil or s == nil then return nil end
    return { x = x, y = y, z = z, dx = dx, dy = dy, dz = dz, serial = s,
             turn = tonumber(turn) or 0 }
end
mode.read_shot = read_shot

local function read_blast(packed)
    if type(packed) ~= "string" or packed == "" then return nil end
    local x, y, z, s, p, rest = packed:match("^(%S+) (%S+) (%S+) (%S+) (%S+)(.*)$")
    x, y, z, s, p = tonumber(x), tonumber(y), tonumber(z), tonumber(s),
        tonumber(p)
    if x == nil or y == nil or z == nil or s == nil or p == nil then
        return nil
    end
    local direct = tonumber((rest or ""):match("^ (%S+)$") or "")
    if direct ~= nil and direct < 0 then direct = nil end
    return { x = x, y = y, z = z, serial = s,
             power = OF.util.clamp(p, 1, POWER_SCALE), direct = direct }
end

local function read_down(packed)
    if type(packed) ~= "string" or packed == "" then return nil end
    local g, s = packed:match("^(%S+) (%S+)$")
    g, s = tonumber(g), tonumber(s)
    if g == nil or s == nil then return nil end
    return { by = g, serial = s }
end

function mode.pin()
    OF.shooter.publish_ffa_points(ROLE_SHOOTING)

    local here = OF.gamemodes.here_place(0)
    if here == nil then
        OF.util.publish(PICK_PTS_KEY, nil)
        OF.util.publish(PICK_AT_KEY, nil)
        return
    end
    local list = OF.gamemodes.surveyed_list(here, "points", PICKUP_WANT)
    if list == nil or #list == 0 then
        OF.util.publish(PICK_PTS_KEY, nil)
        OF.util.publish(PICK_AT_KEY, nil)
        return
    end
    if #list > PICKUP_WANT then
        local trimmed = {}
        for i = 1, PICKUP_WANT do trimmed[i] = list[i] end
        list = trimmed
    end
    local zeros = {}
    for i = 1, #list do zeros[i] = 0 end

    if pickups_quake3() then
        for i = 1, #list do
            if PICKUP_KINDS[((i - 1) % #PICKUP_KINDS) + 1] == "power" then
                zeros[i] = 999999999
            end
        end
    end
    pickAvailAt = zeros
    OF.util.publish(PICK_PTS_KEY, OF.gamemodes.pack_points(list))
    OF.util.publish(PICK_AT_KEY, pack_at(zeros))
end

function mode.team_home(side)
    if not OF.teams.in_play() then return nil end
    return side_point(side)
end

function mode.death_place(from)
    if OF.teams.in_play() then
        return OF.gamemodes.team_respawn(OF.teams.of(0), from, mode)
    end
    return OF.shooter.ffa_respawn_point()
end

local function mark_rows_read()
    for _, entry in ipairs(OF.util.connected_players()) do
        local i = entry.localIndex
        local row = gPlayerSyncTable[i]
        local shot = row ~= nil and read_shot(row[SHOT_KEY]) or nil
        local blast = row ~= nil and read_blast(row[BLAST_KEY]) or nil
        local down = row ~= nil and read_down(row[DOWN_KEY]) or nil
        seenShot[i] = shot ~= nil and shot.serial or nil
        seenBlast[i] = blast ~= nil and blast.serial or nil
        shownBlast[i] = blast ~= nil and blast.serial or nil
        seenDown[i] = down ~= nil and down.serial or nil
    end
    rowsRead = true
end

local function history_read()
    if not rowsRead then mark_rows_read() end
end

function mode.on_start()
    respawnPending = false
    for at = #flying, 1, -1 do flying[at] = nil end
    shotSerial = 0
    rocketReadyAt = -9999
    aimingRocket = false
    bWasDown = false
    rocketJumping = false
    lastHurtBy, lastHurtAt = nil, -9999
    downSerial = 0
    for k in pairs(seenBlast) do seenBlast[k] = nil end
    for k in pairs(seenShot) do seenShot[k] = nil end
    for k in pairs(shownBlast) do shownBlast[k] = nil end
    for k in pairs(seenDown) do seenDown[k] = nil end
    for k in pairs(clientAvailAt) do clientAvailAt[k] = nil end
    for k in pairs(seenGrab) do seenGrab[k] = nil end
    grabSerial = 0
    boostUntil = -9999
    powerUntil = -9999
    dq.grabsHeard, dq.powerUp, dq.powerDrawn = {}, {}, false
    dq.airVel, dq.landedAt, dq.landVel = nil, nil, nil
    runes.drop_marks()
    dq.runes, dq.runesSaid, dq.runeHeld, dq.runeAskAt = nil, nil, nil, nil
    OF.util.publish_row(0, "ofScore", 0)
    OF.util.publish_row(0, SHOT_KEY, "")
    OF.util.publish_row(0, BLAST_KEY, "")
    OF.util.publish_row(0, DOWN_KEY, "")
    OF.util.publish_row(0, GRAB_KEY, 0)
    mark_rows_read()
    return true
end

local PROTECT_FRAMES = 60

local function on_my_death(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if OF.gamemodes.current() ~= mode then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if am_out() then return end
    respawnPending = true
    if lastHurtBy ~= nil and now_frame() - lastHurtAt <= CREDIT_FRAMES then
        downSerial = downSerial + 1
        OF.util.publish_row(0, DOWN_KEY, string.format("%.0f %.0f",
            lastHurtBy, downSerial))
    end
    lastHurtBy, lastHurtAt = nil, -9999
    runes.went_down()
    go_out_if_one_life()
end

hook_event(HOOK_ON_DEATH, on_my_death)

local function fire_the_rocket(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    local pad = m.controller
    if pad == nil then return false end
    aimingRocket = OF.util.has_flag(pad.buttonDown, L_TRIG)

    local nowB
    if OF.util.asks(OF.input, "aim_held") then
        nowB = OF.input.aim_held(m, B_BUTTON)
    else
        nowB = OF.util.has_flag(pad.buttonDown, B_BUTTON)
    end
    local pressed = nowB and not bWasDown
    bWasDown = nowB
    if not aimingRocket or not pressed then return false end
    if now_frame() < rocketReadyAt then return false end

    if OF.util.asks(OF.shooter, "dying") and OF.shooter.dying(m) then return false end
    if not OF.util.asks(OF.util, "view_axis") then return false end
    local ex, ey, ez, dx, dy, dz = OF.util.view_axis()
    if ex == nil then return false end

    rocketReadyAt = now_frame() + runes.cooldown()

    m.invincTimer = 0

    local muzzleX, muzzleY, muzzleZ = ex, ey, ez
    if OF.util.asks(OF.cheats, "muzzle_of") then
        muzzleX, muzzleY, muzzleZ = OF.cheats.muzzle_of(m, ex, ey, ez)
    end

    shotSerial = shotSerial + 1
    table.insert(flying, { ox = muzzleX, oy = muzzleY, oz = muzzleZ,
        dx = dx, dy = dy, dz = dz, age = 0, serial = shotSerial })
    OF.util.publish_row(0, SHOT_KEY, string.format(
        "%.0f %.0f %.0f %.4f %.4f %.4f %.0f",
        muzzleX, muzzleY, muzzleZ, dx, dy, dz, shotSerial))
    return true
end

local function predicts_a_hit(x, y, z)
    local reach = splash_stop().hurt
    for _, entry in ipairs(OF.util.connected_players()) do
        local i = entry.localIndex
        local o = gMarioStates[i]
        if i ~= 0 and o ~= nil and o.pos ~= nil and OF.util.can_play(i)
            and OF.util.optional("is_player_active", 0, o) ~= 0
            and (o.invincTimer or 0) <= 0
            and not (OF.teams.in_play() and OF.teams.same(0, i)) then
            local dx, dy, dz = o.pos.x - x, o.pos.y - y, o.pos.z - z
            if dx * dx + dy * dy + dz * dz < reach * reach then return true end
        end
    end
    return false
end

local function burst(entry, hx, hy, hz, directGlobal)
    local power = (powerUntil > now_frame() or runes.mine() == "reach")
        and POWER_SCALE or 1
    OF.util.publish_row(0, BLAST_KEY, string.format(
        "%.0f %.0f %.0f %.0f %.0f %.0f",
        hx, hy, hz, entry.serial, power, directGlobal or -1))
    if predicts_a_hit(hx, hy, hz) and OF.util.asks(OF.cheats, "mark_a_hit") then
        OF.cheats.mark_a_hit()
    end
end

local MISSILE_TURN_AT = 15
mode.MISSILE_TURN_AT = MISSILE_TURN_AT
local function turn_once(entry)
    if entry.turned or (entry.age or 0) ~= MISSILE_TURN_AT then return nil end
    if OF.gamemodes.option_now("rockets") ~= "missile" then return nil end
    entry.turned = true
    local best, bestD, tx, ty, tz = nil, nil, 0, 0, 0
    for _, p in ipairs(OF.util.connected_players()) do
        local i = p.localIndex
        local o = gMarioStates[i]
        if i ~= 0 and o ~= nil and o.pos ~= nil and OF.util.can_play(i)
            and not (OF.teams.in_play() and OF.teams.same(0, i)) then
            local dx, dy, dz = o.pos.x - entry.ox, o.pos.y + BODY_MID - entry.oy, o.pos.z - entry.oz
            local d = dx * dx + dy * dy + dz * dz
            if bestD == nil or d < bestD then
                best, bestD, tx, ty, tz = i, d, dx, dy, dz
            end
        end
    end
    if best == nil or bestD < 1 then return nil end
    local len = math.sqrt(bestD)
    entry.dx, entry.dy, entry.dz = tx / len, ty / len, tz / len
    OF.util.publish_row(0, SHOT_KEY, string.format(
        "%.0f %.0f %.0f %.4f %.4f %.4f %.0f 1",
        entry.ox, entry.oy, entry.oz, entry.dx, entry.dy, entry.dz, entry.serial))
    return best
end
mode.turn_once = turn_once

local function watch_the_rockets()
    for at = #flying, 1, -1 do
        local entry = flying[at]
        turn_once(entry)
        local nx = entry.ox + entry.dx * ROCKET_SPEED
        local ny = entry.oy + entry.dy * ROCKET_SPEED
        local nz = entry.oz + entry.dz * ROCKET_SPEED

        local hx, hy, hz, hit = nx, ny, nz, false
        local struck = nil
        local wall = OF.util.optional("collision_find_surface_on_ray", nil,
            entry.ox, entry.oy, entry.oz,
            nx - entry.ox, ny - entry.oy, nz - entry.oz)
        if wall ~= nil and wall.surface ~= nil and wall.hitPos ~= nil then
            hx, hy, hz, hit = wall.hitPos.x, wall.hitPos.y, wall.hitPos.z, true
        end

        if not hit then
            local segX = nx - entry.ox
            local segY = ny - entry.oy
            local segZ = nz - entry.oz
            local segLenSq = segX * segX + segY * segY + segZ * segZ
            for _, p in ipairs(OF.util.connected_players()) do

                if not hit and p.localIndex ~= 0 then
                    local o = gMarioStates[p.localIndex]
                    if o ~= nil and o.pos ~= nil
                        and OF.util.can_play(p.localIndex)
                        and OF.util.optional("is_player_active", 0, o) ~= 0 then

                        local midY = o.pos.y + BODY_MID
                        local t = 0
                        if segLenSq > 0 then
                            local tx = o.pos.x - entry.ox
                            local ty = midY - entry.oy
                            local tz = o.pos.z - entry.oz
                            t = OF.util.clamp(
                                (tx * segX + ty * segY + tz * segZ)
                                    / segLenSq, 0, 1)
                        end
                        local cx = entry.ox + segX * t
                        local cy = entry.oy + segY * t
                        local cz = entry.oz + segZ * t
                        local dx = o.pos.x - cx
                        local dz = o.pos.z - cz
                        if dx * dx + dz * dz
                                <= DIRECT_HIT_REACH * DIRECT_HIT_REACH
                            and cy >= o.pos.y - 10
                            and cy <= o.pos.y + BODY_TALL then
                            hx, hy, hz, hit = cx, cy, cz, true
                            struck = p.np ~= nil and p.np.globalIndex or nil
                        end
                    end
                end
            end
        end

        entry.age = (entry.age or 0) + 1
        if hit then
            burst(entry, hx, hy, hz, struck)
            table.remove(flying, at)
        elseif entry.age >= ROCKET_LIFE then
            burst(entry, nx, ny, nz)
            table.remove(flying, at)
        else
            entry.ox, entry.oy, entry.oz = nx, ny, nz
        end
    end
end

local function held_in_place(m)
    local action = m.action or 0
    return OF.util.has_flag(action, ACT_FLAG_SWIMMING)
        or OF.util.has_flag(action, ACT_FLAG_ON_POLE)
        or OF.util.has_flag(action, ACT_FLAG_HANGING)
end

local function apply_push(m, bx, by, bz, lethal, hurt, own)
    if m == nil or m.pos == nil or m.vel == nil then return false end
    local splash = splash_stop()
    local dx = m.pos.x - bx
    local dy = m.pos.y - by
    local dz = m.pos.z - bz
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
    if dist > splash.push and not lethal then return false end
    if held_in_place(m) then return false end
    local fall = 1 - OF.util.clamp(dist / splash.push, 0, 1)

    local grounded = OF.util.optional("mario_is_in_air_action", 0, m) == 0
    if lethal or (grounded and hurt) then
        set_mario_action(m, ACT_BACKWARD_AIR_KB, 0)
    elseif grounded then
        set_mario_action(m, ACT_FREEFALL, 0)
    end
    local kick = KICK_MIN + (KICK_MAX - KICK_MIN) * fall
    local shove = PUSH_MAX * fall
    if own then

        kick = SELF_KICK_MIN + (SELF_KICK_MAX - SELF_KICK_MIN) * fall
        shove = SELF_PUSH_MAX * fall
        rocketJumping = true
        m.peakHeight = m.pos.y
    end
    if (m.vel.y or 0) < kick then m.vel.y = kick end

    local horiz = math.sqrt(dx * dx + dz * dz)
    if horiz > 1 and m.faceAngle ~= nil then

        local yaw = math.floor(math.atan(-dx, -dz) * 0x8000 / math.pi + 0.5)
            & 0xFFFF
        m.faceAngle.y = yaw
        OF.util.optional("mario_set_forward_vel", nil, m, -shove)
    end
    return true
end

local function body_distance(m, bx, by, bz)
    local nearY = OF.util.clamp(by, m.pos.y, m.pos.y + BODY_TALL - 10)
    local dx = m.pos.x - bx
    local dy = nearY - by
    local dz = m.pos.z - bz
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function take_a_blast(m, blast, fromLocal)
    if m == nil or m.pos == nil then return 0, false end
    local splash = splash_stop()
    local remaining = (m.health or 0) - 0x40 * (m.hurtCounter or 0)
    if remaining < DOOMED then return 0, false end

    local dist = body_distance(m, blast.x, blast.y, blast.z)
    local mine = fromLocal == 0
    local mate = not mine and OF.teams.in_play()
        and OF.teams.same(0, fromLocal)
    local me = global_of(0)
    local direct = not mine and blast.direct ~= nil and me ~= nil
        and blast.direct == me

    local reach = splash.hurt
    if (blast.power or 1) > 1 then reach = reach * POWER_REACH end
    local dealt = 0
    if not mine and not mate and (m.invincTimer or 0) <= 0
        and (direct or dist < reach) then

        dealt = math.floor((remaining - DOOMED) / 0x40) + 1
    end

    local lethal = dealt > 0 and remaining - 0x40 * dealt < DOOMED
    if dealt > 0 then

        m.hurtCounter = (m.hurtCounter or 0) + dealt
        if lethal then m.health = math.min(m.health or 0, DOOMED - 1) end
        if CHAR_SOUND_ATTACKED ~= nil then
            OF.util.optional("play_character_sound", nil, m, CHAR_SOUND_ATTACKED)
        end
    end
    local pushed = apply_push(m, blast.x, blast.y, blast.z, lethal, dealt > 0,
        mine)

    if not mine and not mate and (dealt > 0 or pushed) then
        local by = global_of(fromLocal)
        if by ~= nil then lastHurtBy, lastHurtAt = by, now_frame() end

        if by ~= nil and OF.util.asks(OF.replay, "note_killer") then
            OF.replay.note_killer(by)
        end
    end
    return dealt, lethal
end

local function take_the_blasts(m)
    history_read()
    for _, entry in ipairs(OF.util.connected_players()) do
        local i = entry.localIndex
        local row = gPlayerSyncTable[i]
        local blast = row ~= nil and read_blast(row[BLAST_KEY]) or nil
        if blast == nil then
            seenBlast[i] = nil
        elseif seenBlast[i] ~= blast.serial then
            seenBlast[i] = blast.serial
            take_a_blast(m, blast, i)
        end
    end
end

local function picture_key(seat, serial)
    return tostring(seat) .. ":" .. tostring(serial)
end

local function drop_picture(key)
    local pic = pictures[key]
    if pic ~= nil then drop_object(pic.obj, E_MODEL_BULLET_BILL) end
    pictures[key] = nil
end

local function launch_picture(seat, shot)
    local obj = spawn_local(id_bhvStaticObject, E_MODEL_BULLET_BILL,
        shot.x, shot.y, shot.z, nil)
    if obj ~= nil then
        OF.util.optional("obj_scale", nil, obj, ROCKET_LOOK)
        local yaw = math.floor(math.atan(shot.dx, shot.dz) * 0x8000 / math.pi
            + 0.5) & 0xFFFF

        local horiz = math.sqrt(shot.dx * shot.dx + shot.dz * shot.dz)
        local pitch = math.floor(math.atan(-shot.dy, horiz) * 0x8000 / math.pi
            + 0.5) & 0xFFFF
        obj.oFaceAngleYaw, obj.oMoveAngleYaw = yaw, yaw
        obj.oFaceAnglePitch = pitch
    end
    pictures[picture_key(seat, shot.serial)] = { obj = obj, seat = seat,
        serial = shot.serial,
        x = shot.x, y = shot.y, z = shot.z,
        dx = shot.dx, dy = shot.dy, dz = shot.dz, age = 0, stopped = false }
    sound_at(SOUND_OBJ_SNUFIT_SHOOT, shot.x, shot.y, shot.z)
end

local function hit_me_on_the_way(pic, nx, ny, nz)
    if pic.seat == nil or pic.seat == 0 or pic.hitMe then return false end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false end
    if not OF.util.can_play(0) then return false end
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return false end
    if OF.util.optional("is_player_active", 1, m) == 0 then return false end
    if (m.invincTimer or 0) > 0 then return false end
    if OF.teams.in_play() and OF.teams.same(0, pic.seat) then return false end
    local segX, segY, segZ = nx - pic.x, ny - pic.y, nz - pic.z
    local segLenSq = segX * segX + segY * segY + segZ * segZ
    local midY = m.pos.y + BODY_MID
    local t = 0
    if segLenSq > 0 then
        t = OF.util.clamp(((m.pos.x - pic.x) * segX + (midY - pic.y) * segY
            + (m.pos.z - pic.z) * segZ) / segLenSq, 0, 1)
    end
    local cx, cy, cz = pic.x + segX * t, pic.y + segY * t, pic.z + segZ * t
    local dx, dz = m.pos.x - cx, m.pos.z - cz
    if dx * dx + dz * dz > DIRECT_HIT_REACH * DIRECT_HIT_REACH then return false end
    if cy < m.pos.y - 10 or cy > m.pos.y + BODY_TALL then return false end
    pic.hitMe = true
    local _, lethal = take_a_blast(m, { x = cx, y = cy, z = cz,
        serial = pic.serial, power = 1, direct = global_of(0) }, pic.seat)
    return lethal
end

local INCOMING_RANGE = 900
function mode.hear_incoming(pic)
    if pic.warned or pic.stopped or pic.seat == nil or pic.seat == 0 then return false end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false end
    if not OF.util.can_play(0) then return false end
    if OF.teams.in_play() and OF.teams.same(0, pic.seat) then return false end
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return false end
    local dx, dy, dz = m.pos.x - pic.x, m.pos.y + BODY_MID - pic.y, m.pos.z - pic.z
    if dx * dx + dy * dy + dz * dz > INCOMING_RANGE * INCOMING_RANGE then return false end
    if dx * pic.dx + dy * pic.dy + dz * pic.dz <= 0 then return false end
    pic.warned = true
    OF.gamemodes.cue("hazard")
    return true
end

local function fly_the_pictures()
    for key, pic in pairs(pictures) do
        pic.age = pic.age + 1
        if pic.age > ROCKET_LIFE + 30 then
            drop_picture(key)
        elseif not pic.stopped then
            local nx = pic.x + pic.dx * ROCKET_SPEED
            local ny = pic.y + pic.dy * ROCKET_SPEED
            local nz = pic.z + pic.dz * ROCKET_SPEED
            local wall = OF.util.optional("collision_find_surface_on_ray", nil,
                pic.x, pic.y, pic.z, nx - pic.x, ny - pic.y, nz - pic.z)
            if wall ~= nil and wall.surface ~= nil and wall.hitPos ~= nil then
                nx, ny, nz = wall.hitPos.x, wall.hitPos.y, wall.hitPos.z
                pic.stopped = true
            end
            mode.hear_incoming(pic)
            hit_me_on_the_way(pic, nx, ny, nz)
            pic.x, pic.y, pic.z = nx, ny, nz
            local obj = pic.obj
            if ours(obj, E_MODEL_BULLET_BILL) then
                obj.oPosX, obj.oPosY, obj.oPosZ = nx, ny, nz
            end

            if pic.age % TRAIL_EVERY == 0 then
                spawn_local(id_bhvBobombFuseSmoke, E_MODEL_SMOKE,
                    nx, ny - BOBOMB_SMOKE_RISE, nz, nil)
            end
        end
    end
end

local function bang_at(x, y, z)
    local obj = spawn_local(id_bhvStaticObject, E_MODEL_EXPLOSION, x, y, z, nil)
    if obj ~= nil then
        OF.util.optional("obj_set_billboard", nil, obj)
        obj.oAnimState = 0
        OF.util.optional("obj_scale", nil, obj, 1.5)
        table.insert(puffs, { obj = obj, age = 0, x = x, y = y, z = z })
    end

    sound_at(SOUND_GENERAL2_BOBOMB_EXPLOSION, x, y, z)
end

local function step_the_bangs()
    for at = #puffs, 1, -1 do
        local puff = puffs[at]
        puff.age = puff.age + 1
        local obj = puff.obj
        if puff.age >= PUFF_FRAMES or not ours(obj, E_MODEL_EXPLOSION) then
            drop_object(obj, E_MODEL_EXPLOSION)
            spawn_local(id_bhvBobombBullyDeathSmoke, E_MODEL_SMOKE,
                puff.x, puff.y, puff.z, nil)
            table.remove(puffs, at)
        else
            obj.oAnimState = puff.age
            OF.util.optional("obj_scale", nil, obj, 1.5 + puff.age / 6)
        end
    end
end

local function watch_the_launches_and_bursts()
    history_read()
    for _, entry in ipairs(OF.util.connected_players()) do
        local i = entry.localIndex
        local row = gPlayerSyncTable[i]
        local shot = row ~= nil and read_shot(row[SHOT_KEY]) or nil
        if shot == nil then
            seenShot[i] = nil
        elseif seenShot[i] ~= shot.serial then
            seenShot[i] = shot.serial
            launch_picture(i, shot)
        elseif shot.turn > 0 then

            local pic = pictures[picture_key(i, shot.serial)]
            if pic ~= nil and not pic.turned then
                pic.turned = true
                pic.x, pic.y, pic.z = shot.x, shot.y, shot.z
                pic.dx, pic.dy, pic.dz = shot.dx, shot.dy, shot.dz
                if ours(pic.obj, E_MODEL_BULLET_BILL) then
                    local yaw = math.floor(math.atan(shot.dx, shot.dz) * 0x8000 / math.pi + 0.5) & 0xFFFF
                    pic.obj.oFaceAngleYaw, pic.obj.oMoveAngleYaw = yaw, yaw
                end
            end
        end
        local blast = row ~= nil and read_blast(row[BLAST_KEY]) or nil
        if blast == nil then
            shownBlast[i] = nil
        elseif shownBlast[i] ~= blast.serial then
            shownBlast[i] = blast.serial
            drop_picture(picture_key(i, blast.serial))
            bang_at(blast.x, blast.y, blast.z)
        end
    end
end

local function watch_the_deaths()
    history_read()
    local active = OF.gamemodes.state() == OF.gamemodes.ACTIVE
    local me = global_of(0)
    for _, entry in ipairs(OF.util.connected_players()) do
        local i = entry.localIndex
        local row = gPlayerSyncTable[i]
        local down = row ~= nil and read_down(row[DOWN_KEY]) or nil
        if down == nil then
            seenDown[i] = nil
        elseif seenDown[i] ~= down.serial then
            seenDown[i] = down.serial
            local killer = seat_of_global(down.by)
            local killerName = killer ~= nil and name_of(killer.localIndex)
                or "?"
            if i == 0 then
                local card, who = OF.shooter.death_card("rocket", killer ~= nil
                    and gNetworkPlayers[killer.localIndex] ~= nil
                    and gNetworkPlayers[killer.localIndex].name or killerName)
                OF.notify.show(card, "bad", nil, who)
            elseif me ~= nil and down.by == me then
                OF.notify.show(OF.lang.fill("You got @", name_of(i)), "good")
                if OF.util.asks(OF.hud, "banner") then
                    OF.hud.banner("medal", "+1", nil, { tone = "good" })
                end
            end
            if active and i ~= 0 and me ~= nil and down.by == me
                and not (OF.teams.in_play() and OF.teams.same(0, i)) then
                OF.util.publish_row(0, "ofScore", score_of(0) + 1)

                OF.gamemodes.cue("good")
                OF.shooter.medal(global_of(i), false)
                if OF.util.asks(OF.lobbytalk, "feed_globals") then
                    OF.lobbytalk.feed_globals(me, global_of(i))
                end
            end
        end
    end
end

local function pickup_kind(index)
    return PICKUP_KINDS[((index - 1) % #PICKUP_KINDS) + 1]
end

local function pickup_respawn(index)
    local kind = pickup_kind(index)
    if kind == "health" then return HEALTH_RESPAWN end
    if kind == "power" then return POWER_RESPAWN end
    return SPEED_RESPAWN
end

local PICKUP_MODELS = {
    health = function() return E_MODEL_HEART end,
    speed = function() return E_MODEL_KOOPA_SHELL end,
    power = function() return E_MODEL_BLACK_BOBOMB end,
}

local function pickup_points()
    local text = gGlobalSyncTable[PICK_PTS_KEY]
    if type(text) ~= "string" or text == "" then
        pickupPointsRaw, pickupPoints = nil, nil
        return nil
    end
    if text == pickupPointsRaw then return pickupPoints end
    pickupPointsRaw = text
    pickupPoints = OF.gamemodes.unpack_points(text)
    if pickupPoints[1] == nil then pickupPoints = nil end
    return pickupPoints
end

local function pickup_avail()
    return unpack_at(gGlobalSyncTable[PICK_AT_KEY])
end

local function pickup_medal(word)
    if OF.util.asks(OF.hud, "banner") then
        OF.hud.banner("medal", OF.lang.t(word), nil, { tone = "good" })
    end
end

local function take_pickup(m, kind, now)
    if kind == "health" then
        local pending = (m.health or 0) + 0x40 * ((m.healCounter or 0)
            - (m.hurtCounter or 0))
        if pending >= FULL_HEALTH then return false end
        m.healCounter = (m.healCounter or 0) + HEAL_QUARTERS
        pickup_medal("HEALTH")
    elseif kind == "power" then
        powerUntil = now + POWER_DURATION
        pickup_medal("DOUBLE DAMAGE")
    else
        boostUntil = now + BOOST_DURATION
        pickup_medal("SPEED")
    end
    return true
end

local function watch_pickups(m)
    if not pickups_on() then return end
    local points = pickup_points()
    if points == nil then return end

    if (m.health or 0) - 0x40 * (m.hurtCounter or 0) < DOOMED then return end
    local avail = pickup_avail()
    local now = now_frame()
    for i, spot in ipairs(points) do
        local hostReady = now >= (avail[i] or 0)
        local clientReady = now >= (clientAvailAt[i] or 0)
        if hostReady and clientReady then
            local dx = m.pos.x - spot.x
            local dy = m.pos.y - spot.y
            local dz = m.pos.z - spot.z
            if dx * dx + dy * dy + dz * dz <= PICKUP_REACH * PICKUP_REACH
                and take_pickup(m, pickup_kind(i), now) then
                clientAvailAt[i] = now + pickup_respawn(i)
                grabSerial = grabSerial + 1
                OF.util.publish_row(0, GRAB_KEY, grabSerial * 10 + (i - 1))
            end
        end
    end
end

local function settle_grabs()
    local points = pickup_points()
    if points == nil then return end
    local now = now_frame()
    local changed = false
    for _, entry in ipairs(OF.util.connected_players()) do
        local row = gPlayerSyncTable[entry.localIndex]
        local v = row ~= nil and row[GRAB_KEY] or 0
        if type(v) == "number" and v ~= (seenGrab[entry.localIndex] or 0) then
            seenGrab[entry.localIndex] = v
            local idx = (v % 10) + 1

            if v % 10 >= RUNE.grab then
                if runes.settle(entry.localIndex, v % 10, now) then
                    runes.say()
                end
            elseif points[idx] ~= nil and now >= (pickAvailAt[idx] or 0) then
                pickAvailAt[idx] = now + pickup_respawn(idx)
                changed = true
            end
        end
    end
    if changed then
        OF.util.publish(PICK_AT_KEY, pack_at(pickAvailAt))
    end
end

local STRAFE_JUMPS = {}
for _, act in ipairs({ ACT_JUMP, ACT_DOUBLE_JUMP, ACT_TRIPLE_JUMP }) do
    if act ~= nil then STRAFE_JUMPS[act] = true end
end

local function angle_off(a, b)
    return ((a - b + 0x8000) % 0x10000) - 0x8000
end

local function air_strafe(m)
    if not OF.gamemodes.option_is("strafe", "on") then return end
    local now = now_frame()
    if not OF.util.has_flag(m.action or 0, ACT_FLAG_AIR or 0x800) then

        if dq.airVel ~= nil then dq.landedAt, dq.landVel = now, dq.airVel end
        dq.airVel = nil
        return
    end

    if dq.landVel ~= nil then
        if now - (dq.landedAt or now) > STRAFE.hop then
            dq.landVel = nil
        elseif STRAFE_JUMPS[m.action] and m.forwardVel < dq.landVel then
            m.forwardVel = math.min(dq.landVel, STRAFE.ceiling)
        end
    end
    if STRAFE_JUMPS[m.action] or m.action == ACT_FREEFALL then
        local off = angle_off(m.intendedYaw or 0, m.faceAngle.y)
        local size = math.abs(off)
        local mag = math.min((m.intendedMag or 0) / 32, 1)
        if mag > 0 and size >= STRAFE.lo and size <= STRAFE.hi
            and m.forwardVel < STRAFE.ceiling then
            m.forwardVel = math.min(m.forwardVel + STRAFE.gain * mag,
                STRAFE.ceiling)
            local turn = math.min(STRAFE.turn, size)
            if off < 0 then turn = -turn end
            m.faceAngle.y = angle_off(m.faceAngle.y + turn, 0)
        end
    end
    dq.airVel = m.forwardVel
end

function runes.on()
    return OF.gamemodes.option_is("runes", "on") and not arena_play()
end

function runes.read(text)
    local list = {}
    if type(text) ~= "string" then return list end
    local k = 0
    for tok in text:gmatch("%S+") do
        k = k + 1
        local g = tok:match("^@(%d+)$")
        if g ~= nil then
            list[k] = { holder = tonumber(g) }
        else
            local x, y, z = tok:match("^(%-?%d+),(%-?%d+),(%-?%d+)$")
            if x ~= nil then
                list[k] = { x = tonumber(x), y = tonumber(y), z = tonumber(z) }
            end
        end
    end
    return list
end

function runes.pack(list)
    local out = {}
    for k = 1, #RUNE.kinds do
        local r = list[k]
        if r == nil then
            out[k] = "-"
        elseif r.holder ~= nil then
            out[k] = "@" .. string.format("%.0f", r.holder)
        else
            out[k] = string.format("%.0f,%.0f,%.0f", r.x, r.y, r.z)
        end
    end
    return table.concat(out, " ")
end

function runes.mine()
    if not runes.on() then return nil end
    local me = global_of(0)
    if me == nil then return nil end
    for k, r in pairs(runes.read(gGlobalSyncTable[RUNE.key])) do
        if r.holder == me then return RUNE.kinds[k] end
    end
    return nil
end

function runes.cooldown()
    if runes.mine() == "haste" then return RUNE.haste end
    return ROCKET_COOLDOWN
end

local function rune_spot()
    local points = pickup_points()
    if points == nil then return nil end
    local spot = points[math.random(1, #points)]
    return { x = spot.x, y = spot.y, z = spot.z }
end

function runes.settle(localIndex, ask, now)
    if not runes.on() or dq.runes == nil then return false end
    local g = global_of(localIndex)
    local o = gMarioStates[localIndex]
    if g == nil or o == nil or o.pos == nil then return false end
    local carries = nil
    for k, r in pairs(dq.runes) do
        if r.holder == g then carries = k end
    end
    if ask == RUNE.drop then
        if carries == nil then return false end
        dq.runes[carries] = { x = o.pos.x, y = o.pos.y, z = o.pos.z, at = now }
        return true
    end
    if carries ~= nil then return false end
    local best, bestD = nil, (PICKUP_REACH * RUNE.slack) ^ 2
    for k, r in pairs(dq.runes) do
        if r.holder == nil then
            local dx, dy, dz = o.pos.x - r.x, o.pos.y - r.y, o.pos.z - r.z
            local d = dx * dx + dy * dy + dz * dz
            if d <= bestD then best, bestD = k, d end
        end
    end
    if best == nil then return false end
    dq.runes[best] = { holder = g }
    return true
end

function runes.say()
    local line = runes.pack(dq.runes)
    if dq.runesSaid ~= line then
        dq.runesSaid = line
        OF.util.publish(RUNE.key, line)
    end
end

function runes.host(now)
    if not runes.on() then return end
    local changed = false
    if dq.runes == nil then
        local standing = gGlobalSyncTable[RUNE.key]
        if type(standing) == "string" and standing ~= "" then
            dq.runes = runes.read(standing)
            dq.runesSaid = standing
            for _, r in pairs(dq.runes) do r.at = now end
        else
            if pickup_points() == nil then return end
            dq.runes = {}
            for k = 1, #RUNE.kinds do
                local spot = rune_spot()
                if spot ~= nil then spot.at = now end
                dq.runes[k] = spot
            end
            changed = true
        end
    end
    for k = 1, #RUNE.kinds do
        local r = dq.runes[k]
        if r ~= nil and r.holder ~= nil then
            local entry = seat_of_global(r.holder)
            local o = entry and gMarioStates[entry.localIndex]
            if entry == nil or o == nil or o.pos == nil then
                local spot = rune_spot()
                if spot ~= nil then spot.at = now end
                dq.runes[k] = spot
                changed = true
            elseif (o.health or 0) < DOOMED then
                dq.runes[k] = { x = o.pos.x, y = o.pos.y, z = o.pos.z, at = now }
                changed = true
            end
        elseif r ~= nil and now - (r.at or now) >= RUNE.idle then
            local spot = rune_spot()
            if spot ~= nil then
                spot.at = now
                dq.runes[k] = spot
                changed = true
            end
        end
    end
    if changed then runes.say() end
end

function runes.watch(m)
    if not runes.on() then return end
    local mine = runes.mine()
    if mine ~= dq.runeHeld then
        dq.runeHeld = mine
        if mine ~= nil and OF.util.asks(OF.hud, "banner") then
            OF.hud.banner("medal", string.upper(OF.lang.t(runes.word(mine))), nil, { tone = "good" })
        end
    end
    if mine ~= nil then return end
    if (m.health or 0) - 0x40 * (m.hurtCounter or 0) < DOOMED then return end
    local now = now_frame()
    if now < (dq.runeAskAt or -9999) then return end
    for _, r in pairs(runes.read(gGlobalSyncTable[RUNE.key])) do
        if r.holder == nil then
            local dx, dy, dz = m.pos.x - r.x, m.pos.y - r.y, m.pos.z - r.z
            if dx * dx + dy * dy + dz * dz <= PICKUP_REACH * PICKUP_REACH then
                dq.runeAskAt = now + RUNE.ask
                grabSerial = grabSerial + 1
                OF.util.publish_row(0, GRAB_KEY, grabSerial * 10 + RUNE.grab)
                return
            end
        end
    end
end

function runes.went_down()
    if runes.mine() == nil then return end
    grabSerial = grabSerial + 1
    OF.util.publish_row(0, GRAB_KEY, grabSerial * 10 + RUNE.drop)
end

local RUNE_MODELS = {
    haste = function() return E_MODEL_MARIOS_WING_CAP end,
    speed = function() return E_MODEL_MARIOS_WINGED_METAL_CAP end,
    reach = function() return E_MODEL_MARIOS_METAL_CAP end,
}

function runes.drop_marks()
    for k, obj in pairs(dq.runeMarks or {}) do
        drop_object(obj, (dq.runeModel or {})[k])
    end
    dq.runeMarks, dq.runeModel = {}, {}
end

function runes.draw()
    if not runes.on() then
        if next(dq.runeMarks or {}) ~= nil then runes.drop_marks() end
        return
    end
    dq.runeMarks = dq.runeMarks or {}
    dq.runeModel = dq.runeModel or {}
    local now = now_frame()
    local list = runes.read(gGlobalSyncTable[RUNE.key])
    for k = 1, #RUNE.kinds do
        local r = list[k]
        local obj = dq.runeMarks[k]
        if r ~= nil and r.holder == nil then
            if not ours(obj, dq.runeModel[k]) then
                local model = RUNE_MODELS[RUNE.kinds[k]]()
                obj = spawn_local(id_bhvStaticObject, model, r.x,
                    r.y + RUNE.lift, r.z, nil)
                dq.runeMarks[k], dq.runeModel[k] = obj, model
            end
            if obj ~= nil then
                obj.oPosX, obj.oPosZ = r.x, r.z
                obj.oFaceAngleYaw = (now * 0x400) & 0xFFFF
                obj.oPosY = r.y + RUNE.lift + 10 * math.sin(now / 8)
            end
        elseif obj ~= nil then
            drop_object(obj, dq.runeModel[k])
            dq.runeMarks[k], dq.runeModel[k] = nil, nil
        end
    end
end

mode.runes = runes

local function quake3_powerups()
    return pickups_quake3() and pickups_on()
end

local function draw_first_power(now)
    if not quake3_powerups() then return false end
    local drew = false
    for i = 1, #pickAvailAt do
        if pickup_kind(i) == "power" then
            pickAvailAt[i] = now + POWER_FIRST_MID
                + 30 * math.random(-POWER_FIRST_SPREAD, POWER_FIRST_SPREAD)
            drew = true
        end
    end
    if drew then OF.util.publish(PICK_AT_KEY, pack_at(pickAvailAt)) end
    return drew
end

local function denied_here(m, spot, takerSeat)
    if m == nil or m.pos == nil or m.faceAngle == nil then return false end
    if takerSeat == 0 then return false end
    if OF.teams.in_play() and OF.teams.same(0, takerSeat) then return false end
    if am_out() or not OF.util.can_play(0) then return false end
    local dx, dz = spot.x - m.pos.x, spot.z - m.pos.z
    local dy = spot.y - m.pos.y
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
    if dist > DENIED_REACH then return false end
    local flat = math.sqrt(dx * dx + dz * dz)
    if flat < 1 then return true end
    local yaw = (m.faceAngle.y or 0) * math.pi / 0x8000
    local facing = (math.sin(yaw) * dx + math.cos(yaw) * dz) / flat
    return facing >= DENIED_COS
end

function mode.hear_the_power()
    local said = nil
    if not quake3_powerups() then return said end
    local points = pickup_points()
    if points == nil then return said end
    local avail = pickup_avail()
    local now = now_frame()
    local hears = OF.gamemodes.hears_round()
    for i in ipairs(points) do
        if pickup_kind(i) == "power" then
            local up = now >= (avail[i] or 0)
            if up and dq.powerUp[i] == false and hears then

                if OF.util.asks(OF.hud, "banner") then
                    OF.hud.banner("objective", OF.lang.t("WIDER BLAST"), OF.lang.t("On the map"))
                else
                    OF.gamemodes.cue("hazard")
                end
                said = "up"
            end
            dq.powerUp[i] = up
        end
    end
    for _, entry in ipairs(OF.util.connected_players()) do
        local seat = entry.localIndex
        local row = gPlayerSyncTable[seat]
        local v = row ~= nil and row[GRAB_KEY] or nil
        if type(v) ~= "number" then v = 0 end
        local was = dq.grabsHeard[seat]
        dq.grabsHeard[seat] = v
        if was ~= nil and v ~= was and v > 0 then
            local idx = (v % 10) + 1
            if points[idx] ~= nil and pickup_kind(idx) == "power" and hears then

                if OF.util.asks(OF.hud, "banner") and seat ~= 0 then
                    OF.hud.banner("objective", OF.lang.t("WIDER BLAST TAKEN"), nil,
                        { side = OF.teams.in_play() and OF.teams.same(0, seat) and "us" or "them" })
                end
                said = "taken"
                if denied_here(gMarioStates[0], points[idx], seat) then
                    if OF.util.asks(OF.hud, "banner") then
                        OF.hud.banner("medal", OF.lang.t("DENIED"), nil, { tone = "bad" })
                    end
                    OF.gamemodes.cue("bad")
                    said = "denied"
                end
            end
        end
    end
    return said
end

local function drop_the_marker(index)
    drop_object(markers[index], markerModel[index])
    markers[index] = nil
    markerModel[index] = nil
end

local function place_markers()
    if not pickups_on() then
        for index in pairs(markers) do drop_the_marker(index) end
        return
    end
    local points = pickup_points()
    if points == nil then
        for index in pairs(markers) do drop_the_marker(index) end
        return
    end
    local avail = pickup_avail()
    local now = now_frame()
    local wanted = {}
    for i, spot in ipairs(points) do
        local hostReady = now >= (avail[i] or 0)
        local clientReady = now >= (clientAvailAt[i] or 0)
        if hostReady and clientReady then
            wanted[i] = true
            local obj = markers[i]
            if not ours(obj, markerModel[i]) then
                local model = PICKUP_MODELS[pickup_kind(i)]()
                obj = spawn_local(id_bhvStaticObject, model, spot.x,
                    spot.y + 60, spot.z, nil)
                markers[i] = obj
                markerModel[i] = model
            end
            if obj ~= nil then
                obj.oFaceAngleYaw = (now * 0x300) & 0xFFFF
                obj.oPosY = spot.y + 60 + 12 * math.sin(now / 10)

                if markerModel[i] == E_MODEL_BLACK_BOBOMB
                    and OF.util.asks(OF.gamemodes, "pose_bobomb") then
                    OF.gamemodes.pose_bobomb(obj, OF.gamemodes.BOBOMB_WALK)
                end
            end
        end
    end
    for index in pairs(markers) do
        if not wanted[index] then drop_the_marker(index) end
    end
end

function mode.scenery()

    if not OF.util.round_screen() then
        for key in pairs(pictures) do drop_picture(key) end
        for at = #puffs, 1, -1 do
            drop_object(puffs[at].obj, E_MODEL_EXPLOSION)
            puffs[at] = nil
        end
        for index in pairs(markers) do drop_the_marker(index) end
        if next(dq.runeMarks or {}) ~= nil then runes.drop_marks() end
        return
    end
    mode.hear_the_power()
    watch_the_launches_and_bursts()
    fly_the_pictures()
    step_the_bangs()
    watch_the_deaths()
    place_markers()
    runes.draw()
end

function mode.update()
    dress_results()
    local m = gMarioStates[0]
    if m == nil then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    if am_out() then return end
    if not OF.util.can_play(0) then return end

    if respawnPending then
        local group = OF.util.action_group(m.action)
        if group ~= OF.util.action_group(ACT_GROUP_CUTSCENE) then
            respawnPending = false
            m.invincTimer = PROTECT_FRAMES
        end
    end

    if (boostUntil > now_frame() or runes.mine() == "speed")
        and OF.util.asks(OF.util, "speed_up") then
        if m.action == ACT_WALKING then
            OF.util.speed_up(m, math.min(BOOST_TOP,
                (m.forwardVel or 0) * BOOST_SPEED_SCALE))
        end
    end

    if OF.util.optional("mario_is_in_air_action", 0, m) ~= 0 then
        m.peakHeight = m.pos.y
    else
        rocketJumping = false
    end

    air_strafe(m)
    runes.watch(m)
    fire_the_rocket(m)
    watch_the_rockets()
    take_the_blasts(m)
    watch_pickups(m)
end

function mode.host_update()
    dress_results()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    runes.host(now_frame())
    settle_grabs()
    if not dq.powerDrawn then
        dq.powerDrawn = true
        draw_first_power(now_frame())
    end

    if arena_play() then
        arena_ending()
        return
    end
    local target = target_kills()
    if OF.teams.in_play() then
        local red = OF.teams.score("red")
        local blue = OF.teams.score("blue")
        if math.max(red or 0, blue or 0) >= target then
            OF.gamemodes.finish(OF.teams.result_text(),
                OF.gamemodes.team_winner(OF.teams.leader()))
        end
        return
    end
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_SHOOTING)) do
        if score_of(entry.localIndex) >= target then
            OF.gamemodes.finish("@ won with @ kills.", entry.np.name,
                entry.np.name, tostring(target))
            return
        end
    end
end

function mode.still_winnable()
    if arena_play() then return #still_in() >= 1 end
    return #OF.gamemodes.with_role(ROLE_SHOOTING) >= 2
end

local function arena_on_timeout()
    if OF.teams.in_play() then
        local left = { red = 0, blue = 0 }
        for _, entry in ipairs(still_in()) do
            local side = OF.teams.of(entry.localIndex)
            if left[side] ~= nil then left[side] = left[side] + 1 end
        end
        OF.gamemodes.finish(OF.teams.result_text(left.red, left.blue),
            OF.gamemodes.team_winner(OF.teams.leader(left.red, left.blue)))
        return
    end
    local best, names = OF.gamemodes.best_of(still_in(),
        function(entry) return score_of(entry.localIndex) end)
    if best == nil then
        OF.gamemodes.finish("Nobody won.")
    elseif #names > 1 then
        OF.gamemodes.finish("Time - a draw among the players still in.")
    else
        OF.gamemodes.finish("@ won with @ kills.", names[1], names[1],
            tostring(best))
    end
end

function mode.on_timeout()
    if arena_play() then
        arena_on_timeout()
        return
    end
    if OF.teams.in_play() then
        OF.gamemodes.finish(OF.teams.result_text(),
            OF.gamemodes.team_winner(OF.teams.leader()))
        return
    end
    local best, names = OF.gamemodes.best_of(
        OF.gamemodes.with_role(ROLE_SHOOTING),
        function(entry) return score_of(entry.localIndex) end)
    if best == nil or best <= 0 then
        OF.gamemodes.finish("Nobody landed a kill.")
    elseif #names > 1 then
        OF.gamemodes.finish("Time - a draw at @ kills.", nil, tostring(best))
    else
        OF.gamemodes.finish("@ won with @ kills.", names[1], names[1],
            tostring(best))
    end
end

function mode.terms()
    if OF.gamemodes.option_showing(mode.key, "play") == "arena" then
        if OF.teams.in_play() then
            return OF.lang.t("one life each - the last side standing wins")
        end
        return OF.lang.t("one life each - the last one standing wins")
    end
    return OF.lang.fill(
        "splash and rocket jumps - first to @ kills",
        tostring(target_kills()))
end

function mode.hud()
    if aimingRocket and not OF.util.menu_has_screen() then
        djui_hud_set_resolution(RESOLUTION_DJUI)
        local midX = djui_hud_get_screen_width() / 2
        local midY = djui_hud_get_screen_height() / 2
        djui_hud_set_color(255, 255, 255, 210)
        djui_hud_render_rect(midX - 1, midY - 8, 2, 6)
        djui_hud_render_rect(midX - 1, midY + 2, 2, 6)
        djui_hud_render_rect(midX - 8, midY - 1, 6, 2)
        djui_hud_render_rect(midX + 2, midY - 1, 6, 2)
    end

    dress_results()

    if am_out() then return end

    if not OF.util.asks(OF.hud, "state_line") then return end
    local state = OF.hud.state_line
    local now = now_frame()
    if powerUntil > now then
        state("power", OF.lang.t("Double damage"), { prio = 60, tone = "warn",
            figure = math.ceil((powerUntil - now) / 30) })
    end
    if boostUntil > now then
        state("boost", OF.lang.t("Speed"), { prio = 55, tone = "cold",
            figure = math.ceil((boostUntil - now) / 30) })
    end
    local rune = runes.mine()
    if rune ~= nil then
        state("rune", OF.lang.t(runes.word(rune)), { prio = 20, tone = "good" })
    end
end

function runes.word(kind)
    if kind == "haste" then return "Rapid fire" end
    if kind == "speed" then return "Speed" end
    return "Reach"
end

function mode.out_cause() return "One life in this round" end

function mode.cluster()
    if not (OF.util.asks(OF.teams, "in_play") and OF.teams.in_play()) then return nil end

    local count = arena_play() and OF.gamemodes.side_still_in
        or function(key) return OF.teams.score(key) end
    local out = OF.gamemodes.side_cluster(count, not arena_play() and target_kills() or nil)
    if OF.util.asks(OF.shooter, "with_pips") then return OF.shooter.with_pips(out) end
    return out
end

function mode.before_mario_update(m)
    if not am_out() then return end
    OF.gamemodes.set_ghost(true)
end

function mode.may_attack(attacker, victim)
    local _ = attacker
    local _v = victim
    return false
end

function mode.pauseControls()
    return OF.shooter.kit_controls(mode, "Fire a rocket")
end

function mode.standing(localIndex)
    if OF.gamemodes.role(localIndex) == ROLE_OUT then return "OUT" end
    return nil
end

function mode.cleanup()
    mode.resultsBy = nil

    for key in pairs(pictures) do drop_picture(key) end
    for at = #puffs, 1, -1 do
        drop_object(puffs[at].obj, E_MODEL_EXPLOSION)
        puffs[at] = nil
    end
    for index in pairs(markers) do drop_the_marker(index) end
    for at = #flying, 1, -1 do flying[at] = nil end

    if OF.util.is_host() then
        OF.util.publish(TARGET_KEY, nil)
        OF.util.publish("ofShootAt", nil)
        OF.util.publish(PICK_PTS_KEY, nil)
        OF.util.publish(PICK_AT_KEY, nil)
        OF.util.publish(RUNE.key, nil)
    end

    respawnPending = false
    shotSerial = 0
    rocketReadyAt = -9999
    aimingRocket = false
    bWasDown = false
    rocketJumping = false
    boostUntil = -9999
    powerUntil = -9999
    lastHurtBy, lastHurtAt = nil, -9999
    downSerial = 0
    for k in pairs(seenBlast) do seenBlast[k] = nil end
    for k in pairs(seenShot) do seenShot[k] = nil end
    for k in pairs(shownBlast) do shownBlast[k] = nil end
    for k in pairs(seenDown) do seenDown[k] = nil end
    for k in pairs(clientAvailAt) do clientAvailAt[k] = nil end
    for k in pairs(seenGrab) do seenGrab[k] = nil end
    pickAvailAt = {}
    pickupPointsRaw, pickupPoints = nil, nil
    rowsRead = false
    dq.grabsHeard, dq.powerUp, dq.powerDrawn = {}, {}, false
    dq.airVel, dq.landedAt, dq.landVel = nil, nil, nil
    runes.drop_marks()
    dq.runes, dq.runesSaid, dq.runeHeld, dq.runeAskAt = nil, nil, nil, nil

    OF.util.publish_row(0, SHOT_KEY, nil)
    OF.util.publish_row(0, BLAST_KEY, nil)
    OF.util.publish_row(0, DOWN_KEY, nil)
    OF.util.publish_row(0, GRAB_KEY, nil)
    return true
end

function mode.forget_the_pictures()
    local forgot = 0
    for key in pairs(pictures) do
        drop_picture(key)
        forgot = forgot + 1
    end
    for at = #puffs, 1, -1 do
        drop_object(puffs[at].obj, E_MODEL_EXPLOSION)
        puffs[at] = nil
        forgot = forgot + 1
    end
    for index in pairs(markers) do
        drop_the_marker(index)
        forgot = forgot + 1
    end
    for _ in pairs(dq.runeMarks or {}) do forgot = forgot + 1 end
    runes.drop_marks()
    for obj in pairs(homes) do homes[obj] = nil end
    return forgot
end

hook_event(HOOK_ON_LEVEL_INIT, function() mode.forget_the_pictures() end)
hook_event(HOOK_ON_WARP, function() mode.forget_the_pictures() end)

mode.target_now = target_kills

OF.gamemodes.register(mode)
