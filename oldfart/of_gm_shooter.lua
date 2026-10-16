local shooter = {}

local TARGET_KEY = "ofShootTo"
local SPAWN_KEY = "ofShootAt"
local SPAWN_WANT = 16

local ROLE_SHOOTING = "shooting"
local DEFAULT_KILLS = 25

local CHARGE_FULL = 30
local THROW_LOB_SPEED = 8
local THROW_LOB_LIFT = 30
local THROW_SPEED = 60
local THROW_LIFT = 55
local GRENADE_REACH = 560
local GRENADE_WAIT = 240

local THROW_RANGE = 2600
local THROW_GRAVITY = 2.5
local THROW_FRAMES_MIN = 12
local THROW_VY_MAX = 75 + THROW_GRAVITY

local NADE_FLYING = BOBOMB_ACT_LAUNCHED or 1

local NADE_MARK_FIELD = "oBobombBuddyCannonStatus"
local NADE_MARK = 0x4F464E01

local SPRINT_TOP = 48

local BOLT_STOPS = { measured = 2, slow = 1, fast = 3 }
local BOLT_DEFAULT = "measured"
local QUAD = { key = "ofDmQuad", lasts = 10 * 30, respawn = 120 * 30,
               firstMid = 45 * 30, reach = 150, mineUntil = -9999,
               model = function() return E_MODEL_MARIOS_METAL_CAP end }

local function bolt_stop()

    if QUAD.mine() then return BOLT_STOPS.fast end
    return BOLT_STOPS[OF.gamemodes.option_now("bolt") or BOLT_DEFAULT]
        or BOLT_STOPS[BOLT_DEFAULT]
end

local function grenades_on()
    return not OF.gamemodes.option_is("nade", "none")
end

local FLASH_LOB = 300
local FLASH_FAR = 2600
local FLASH_RANGE = FLASH_FAR
local function flash_nuts()
    return not OF.gamemodes.option_is("nut", "off")
end

local GRENADE_BUTTON = Y_BUTTON or 0x0080
local NUT_BUTTON = X_BUTTON or 0x0040

local function sprint_on()
    return not OF.gamemodes.option_is("sprint", "off")
end

local charging = nil

local nutCharging = nil
local flying = {}
local grenadeReadyAt = -9999
local sprinting = false

local marks = {}

function shooter.mark_ours(obj, model)
    if obj == nil then return nil end
    marks[obj] = { model = model, sync = obj.oSyncID,
                   x = obj.oHomeX, y = obj.oHomeY, z = obj.oHomeZ }
    return obj
end

local function stamped(obj, model)
    local mark = marks[obj]
    if mark == nil or mark.model ~= model then return false end
    if mark.sync ~= nil and mark.sync ~= 0 then return obj.oSyncID == mark.sync end
    return mark.x ~= nil and obj.oHomeX == mark.x and obj.oHomeY == mark.y
        and obj.oHomeZ == mark.z
end

function shooter.still_ours(obj, bhv, model)
    if obj == nil or not OF.util.alive(obj) then return false end
    if obj.activeFlags == nil or obj.activeFlags == 0 then return false end
    if bhv ~= nil and OF.util.optional("obj_has_behavior_id", 1, obj, bhv) == 0 then
        return false
    end
    if model ~= nil and stamped(obj, model) then return true end
    if model ~= nil
        and OF.util.optional("obj_has_model_extended", 1, obj, model) == 0 then
        return false
    end
    return true
end

local boltWas = 0

local SHOT_KEY = "ofShotFar"
local lastRange = nil

local lastKillWasMate = false

local killSeq = 0

local otherStandsDown = nil

local respawnPending = false

local heardNade = { near = false }

local PROTECT_FRAMES = 60

local xWasDown = false

local yWasDown = false

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

local KIT_ROWS = {

    { key = "bolt", name = "Fire rate",
      help = "how long the rifle waits between shots",
      choices = {
          { key = "measured", name = "normal",
            help = "a beat and a half between shots; a miss gives a turn" },
          { key = "slow", name = "slow",
            help = "a second and a half of nothing; every shot decides" },
          { key = "fast", name = "fast",
            help = "a firefight rather than a duel" },
      } },
    { key = "nade", name = "Grenades",
      help = "whether Y throws a bob-omb that goes off where it lands",
      choices = {
          { key = "on", name = "thrown on Y",
            help = "hold for a longer throw, let go to throw it" },
          { key = "none", name = "no grenades",
            help = "rifles only; nothing clears a corner for you" },
      } },

    { key = "nut", name = "Flashbangs",
      help = "thrown on X: blinds and stuns where it lands - no kill",
      choices = {
          { key = "on", name = "on",
            help = "at the crosshair with L held, ahead of you without" },
          { key = "off", name = "off",
            help = "nothing blinds anybody this round" },
      } },
    { key = "sprint", name = "Sprinting",
      help = "whether A runs, and whether the rifle stands down",
      choices = {
          { key = "on", name = "A runs",
            help = "ground only, and the rifle will not fire while you run" },
          { key = "off", name = "everybody moves the same",
            help = "no run; position is won by where you already stood" },
      } },
}

local mode = {
    key = "shooter",

    tagRule = "shooter",

    noLeaderMark = true,
    name = "Deathmatch",
    blurb = "a rifle, a grenade, and everybody against everybody",
    blurbTeams = "a rifle, a grenade, and the side with the most",
    how = "Hold L to aim, press B to fire - one shot, one kill.\n"
        .. "Miss and the bolt takes a moment; that is the balance.\n"
        .. "Y throws a grenade - hold it longer to throw it further.\n"
        .. "X: a flash nut that blinds and stuns; hold to throw far.\n"
        .. "Hold L as you throw and it lands at the crosshair.\n"
        .. "Sprint with A held - but the rifle will not fire.\n"
        .. "First to the count wins; on the clock, the most.",

    aims = { [ROLE_SHOOTING] = "Put them down. One shot is enough." },

    minPlayers = 2,

    maps = "surveyed", openCourses = true,

    roomsOut = {
        { level = LEVEL_SL, area = 2 }, { level = LEVEL_THI, area = 3 },
        { level = LEVEL_BITDW, area = 1 }, { level = LEVEL_BITFS, area = 1 },

        { level = LEVEL_RR, area = 1 }, { level = LEVEL_TTC, area = 1 },
        { level = LEVEL_LLL, area = 1 }, { level = LEVEL_LLL, area = 2 },

        { level = LEVEL_TTM, area = 1 }, { level = LEVEL_THI, area = 2 },

        { level = LEVEL_SSL, area = 2 }, { level = LEVEL_COTMC, area = 1 },

        { level = LEVEL_CASTLE_GROUNDS, area = 1 },
    },

    surveyOut = { { level = LEVEL_PSS, area = 1 }, { level = LEVEL_VCUTM, area = 1 },
        { level = LEVEL_TTC, area = 1 }, { level = LEVEL_RR, area = 1 },
        { level = LEVEL_BITDW, area = 1 }, { level = LEVEL_BITFS, area = 1 } },

    spreadOpening = true,

    surveyKeys = { "points" },

    room = { sweep = { "cannons" }, rules = { bubble = 0 } },

    cheatsGiven = { sniper = bolt_stop },

    roundKills = true,
    defaultLimit = 300,
    music = SEQ_LEVEL_BOSS_KOOPA,

    teams = true,
    target = { name = "kills to win",
               asks = "How many kills win the round",
               default = DEFAULT_KILLS,
               min = 5, max = 100, step = 5 },

    options = {

        KIT_ROWS[1], KIT_ROWS[2], KIT_ROWS[3], KIT_ROWS[4],

        { key = "medals", name = "Medals",
          help = "Excellent and Humiliation, told to the two players involved",
          choices = {
              { key = "on", name = "on",
                help = "two kills in three seconds; a kill with the fists" },
              { key = "off", name = "off",
                help = "a kill is a kill, nothing more said" },
          } },

        { key = "quad", name = "Quad damage",
          help = "a pickup that takes the bolt away for ten seconds",
          choices = {
              { key = "off", name = "off",
                help = "nothing on the ground" },
              { key = "on", name = "on",
                help = "first up after 30-60 s, back two minutes after" },
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

function shooter.kit_here()
    local cur = OF.gamemodes.current()
    return cur ~= nil and (cur == mode or cur.shooterKit == true)
end

function shooter.kit_allows(kind)
    local cur = OF.gamemodes.current()
    if cur == nil or cur == mode or type(cur.kit_allows) ~= "function" then return true end
    local ok, said = pcall(cur.kit_allows, kind)
    return not ok or said ~= false
end

function shooter.kit_spent(kind)
    local cur = OF.gamemodes.current()
    if cur == nil or cur == mode or type(cur.kit_spent) ~= "function" then return end
    pcall(cur.kit_spent, kind)
end

local TARGET_PER_PLAYER = DEFAULT_KILLS / 4

local function scaled_target(count, teams)
    local n = math.max(count, 1)
    if teams then
        return math.floor(OF.util.clamp(OF.gamemodes.round_to(TARGET_PER_PLAYER * n, 5), 20, 100))
    end
    return math.floor(OF.util.clamp(OF.gamemodes.round_to(12 + n, 5), 15, 30))
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
    { key = "snipers", name = "Snipers", help = "slow rifles, no grenades, no flashbangs",
      sets = { bolt = "slow", nade = "none", nut = "off" } },
    { key = "arena", name = "Arena", help = "fast rifles, quad damage, high jumps",
      sets = { bolt = "fast", quad = "on", jump = "high" } },
}

function shooter.kit_start()
    charging = nil
    shooter.hand_the_nut()
    for at = #flying, 1, -1 do flying[at] = nil end
    grenadeReadyAt = -9999
    sprinting = false
    boltWas = 0
    yWasDown = false
    lastKillWasMate = false
    respawnPending = false
    xWasDown = false
    nutCharging = nil
end

function mode.on_start()
    shooter.kit_start()
    OF.util.publish_row(0, "ofScore", 0)

    OF.util.publish_row(0, SHOT_KEY, 0)
    lastRange = nil
    QUAD.forget()
    return true
end

hook_event(HOOK_ON_DEATH, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if not shooter.kit_here() then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    respawnPending = true
end)

function mode.late_join(localIndex)
    OF.gamemodes.set_role(localIndex, ROLE_SHOOTING)
    return ROLE_SHOOTING
end

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

local function ffa_points()
    local text = gGlobalSyncTable[SPAWN_KEY]
    if type(text) ~= "string" or text == "" then return nil end
    local list = OF.gamemodes.unpack_points(text)
    if list[1] == nil then return nil end
    return list
end

shooter.draw = function(count) return math.random(count) end

local function ffa_opponents()
    local list = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        if entry.localIndex ~= 0 then
            local o = gMarioStates[entry.localIndex]
            if o ~= nil and o.pos ~= nil and OF.util.can_play(entry.localIndex)
                and OF.util.optional("is_player_active", 0, o) ~= 0 then
                table.insert(list, { x = o.pos.x, y = o.pos.y, z = o.pos.z })
            end
        end
    end
    return list
end
local function ffa_spawn_point()
    local points = ffa_points()
    if points == nil then return nil end
    local ranked = OF.gamemodes.rank_spawns(points,
        { enemies = ffa_opponents(), from = OF.gamemodes.died_at() })
    local half = math.max(1, math.floor(#ranked / 2))
    local pick = math.floor(shooter.draw(half) or 1)
    if pick < 1 or pick > half then pick = 1 end
    return ranked[pick].spot
end

function mode.team_home(side)
    if not OF.teams.in_play() then return nil end
    return side_point(side)
end

function shooter.side_point(side)
    return side_point(side)
end

function mode.death_place(from)
    if OF.teams.in_play() then
        return OF.gamemodes.team_respawn(OF.teams.of(0), from, mode)
    end
    return ffa_spawn_point()
end

function mode.pin()
    if OF.teams.in_play() then
        OF.util.publish(SPAWN_KEY, nil)
        return
    end
    local here = OF.gamemodes.here_place(0)
    if here == nil then return end

    local players = math.max(#OF.gamemodes.with_role(ROLE_SHOOTING), 1)
    local list = OF.gamemodes.surveyed_list(here, "points", SPAWN_WANT)
    if list == nil or #list < players then
        OF.util.publish(SPAWN_KEY, nil)
        return
    end
    OF.util.publish(SPAWN_KEY, OF.gamemodes.pack_points(shooter.deal(list)))
end

function shooter.publish_ffa_points(role)
    if OF.teams.in_play() then
        OF.util.publish(SPAWN_KEY, nil)
        return
    end
    local here = OF.gamemodes.here_place(0)
    if here == nil then return end

    local players = math.max(#OF.gamemodes.with_role(role), 1)
    local list = OF.gamemodes.surveyed_list(here, "points", SPAWN_WANT)
    if list == nil or #list < players then
        OF.util.publish(SPAWN_KEY, nil)
        return
    end
    OF.util.publish(SPAWN_KEY, OF.gamemodes.pack_points(shooter.deal(list)))
end

function shooter.ffa_respawn_point()
    if OF.teams.in_play() then return nil end
    return ffa_spawn_point()
end

function shooter.deal(list)
    local out = {}
    for index, spot in ipairs(list or {}) do out[index] = spot end
    for index = #out, 2, -1 do
        local other = math.floor(shooter.draw(index) or index)
        if other < 1 or other > index then other = index end
        out[index], out[other] = out[other], out[index]
    end
    return out
end

local OPENING_WAIT = 45

local OPENING_RING = 160

local OPENING_WINDOW = 5

local opened = { done = false, waited = 0 }

function shooter.opening_spot(mode)
    local np = gNetworkPlayers[0]
    if np == nil then return nil end
    local mine = np.globalIndex
    local order = {}
    for _, entry in ipairs(OF.gamemodes.participants()) do
        if entry.np ~= nil then table.insert(order, entry.np.globalIndex) end
    end
    table.sort(order)
    local slot = nil
    for index, globalIndex in ipairs(order) do
        if globalIndex == mine then slot = index end
    end
    if slot == nil then return nil end

    if OF.teams.in_play() then

        local side = OF.teams.of(0)
        local zone, group = OF.gamemodes.team_split(side,
            OF.gamemodes.team_home(side, mode), nil, mode)
        if zone ~= nil then
            order, slot = group, nil
            for index, globalIndex in ipairs(group) do
                if globalIndex == mine then slot = index end
            end
            if slot == nil then return nil end
        end
        local ok, at = true, zone
        if at == nil then
            if type(mode.death_place) ~= "function" then return nil end
            ok, at = pcall(mode.death_place)
        end
        if not ok or type(at) ~= "table" or type(at.x) ~= "number" then
            return nil
        end
        local count = math.max(#order, 1)
        local angle = (2 * math.pi * (slot - 1)) / count
        local x = at.x + math.sin(angle) * OPENING_RING
        local z = at.z + math.cos(angle) * OPENING_RING
        local floorY = OF.util.optional("find_floor_height", nil, x, at.y + 160, z)
        if type(floorY) ~= "number" or floorY < at.y - 300 then
            return { x = at.x, y = at.y, z = at.z }
        end
        return { x = x, y = at.y, z = z }
    end

    local points = ffa_points()
    if points == nil then return nil end
    return points[slot] or ffa_spawn_point()
end

function shooter.work_the_opening()
    local mode = OF.gamemodes.current()
    if mode == nil or mode.spreadOpening ~= true
        or OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then
        opened.done, opened.waited = false, 0
        return false
    end
    if opened.done then return false end
    if not OF.util.can_play(0) then return false end

    local np = gNetworkPlayers[0]
    if np == nil or np.currAreaSyncValid == false then return false end
    local place = OF.gamemodes.round_place()
    if place ~= nil and (np.currLevelNum ~= place.level
        or np.currAreaIndex ~= place.area) then
        return false
    end

    local elapsed = tonumber(gGlobalSyncTable.ofGmElapsed) or 0
    local at = nil
    if elapsed <= OPENING_WINDOW then
        at = shooter.opening_spot(mode)
    else
        at = ffa_spawn_point()
    end
    if at == nil then
        opened.waited = opened.waited + 1
        if opened.waited > OPENING_WAIT then opened.done = true end
        return false
    end

    opened.done = true
    local m = gMarioStates[0]
    if m == nil or not OF.util.asks(OF.doorways, "put_at") then return false end
    local put = OF.doorways.put_at(m, at.x, at.y, at.z) == true

    if put then OF.util.camera_behind_soon() end
    return put
end

function shooter.opened()
    return opened.done
end

hook_event(HOOK_UPDATE, shooter.work_the_opening)

do
    local DEATHS = {}
    for _, name in ipairs({ "ACT_STANDING_DEATH", "ACT_DEATH_ON_BACK",
        "ACT_DEATH_ON_STOMACH", "ACT_QUICKSAND_DEATH", "ACT_ELECTROCUTION",
        "ACT_SUFFOCATION", "ACT_DROWNING", "ACT_WATER_DEATH", "ACT_EATEN_BY_BUBBA",
        "ACT_DEATH_EXIT", "ACT_FALLING_DEATH_EXIT", "ACT_SPECIAL_DEATH_EXIT" }) do
        local id = _G[name]
        if type(id) == "number" then DEATHS[id] = true end
    end
    function shooter.dying(m)
        if m == nil then return false end
        if (m.health or 0x880) < 0x100 then return true end
        return DEATHS[m.action or 0] == true
    end
end

function shooter.may_throw()
    if not shooter.kit_here() then return false end
    if not shooter.kit_allows("grenade") then return false end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false end
    if not OF.util.can_play(0) then return false end
    if shooter.dying(gMarioStates[0]) then return false end
    return now_frame() >= grenadeReadyAt
end

function shooter.charge_share()
    if charging == nil then return nil end
    return OF.util.clamp((now_frame() - charging) / CHARGE_FULL, 0, 1)
end

function shooter.nut_share()
    if nutCharging == nil then return nil end
    return OF.util.clamp((now_frame() - nutCharging) / CHARGE_FULL, 0, 1)
end

function shooter.nut_reach(share)
    local k = OF.util.clamp(tonumber(share) or 1, 0, 1)
    return FLASH_LOB + (FLASH_FAR - FLASH_LOB) * k
end
shooter.FLASH_LOB, shooter.FLASH_FAR = FLASH_LOB, FLASH_FAR

function shooter.grenade_cooldown()
    local left = grenadeReadyAt - now_frame()
    if left < 0 then return 0 end
    return left
end

local function in_this_round(localIndex)
    if not OF.util.asks(OF.roundscope, "inside") then return true end
    local modes = OF.gamemodes
    if not OF.util.asks(modes, "state") or modes.state() == modes.OFF then
        return true
    end
    return OF.roundscope.inside(localIndex) == true
end

function shooter.blast_reaches(x, y, z)
    local out = {}
    if type(x) ~= "number" then return out end
    for _, entry in ipairs(OF.util.connected_players()) do
        local o = gMarioStates[entry.localIndex]
        if o ~= nil and o.pos ~= nil
            and OF.util.can_play(entry.localIndex)
            and in_this_round(entry.localIndex)
            and OF.util.optional("is_player_active", 0, o) ~= 0 then
            local dx, dy, dz = o.pos.x - x, o.pos.y - y, o.pos.z - z
            if math.sqrt(dx * dx + dy * dy + dz * dz) <= GRENADE_REACH then
                table.insert(out, entry)
            end
        end
    end
    return out
end

local KILL_ENDING = "standing"
local function seat_for(globalIndex)
    for _, entry in ipairs(OF.util.connected_players()) do
        if entry.np ~= nil and entry.np.globalIndex == globalIndex then
            return entry
        end
    end
    return nil
end

function shooter.death_card(cause, killer)
    local _ = cause
    return "@ got you", (type(killer) == "string" and killer ~= "") and killer or "?"
end

function shooter.put_down(globalIndex, melee, cause)
    if type(globalIndex) ~= "number" then return false end
    if not OF.util.asks(OF.powerups, "give") then return false end

    lastKillWasMate = false
    local seat = seat_for(globalIndex)
    if seat ~= nil then
        lastKillWasMate = OF.teams.in_play()
            and OF.teams.same(0, seat.localIndex)
        local cur = OF.gamemodes.current()
        if lastKillWasMate and cur ~= nil and cur.noFriendlyFire == true
            and seat.localIndex ~= 0 then
            return false
        end
        if not OF.util.can_play(seat.localIndex) then return false end
        local o = gMarioStates[seat.localIndex]
        local action = o ~= nil and o.action or nil
        local already = OF.util.action_group(action)
            == OF.util.action_group(ACT_GROUP_CUTSCENE)
        if already then return false end
        if o ~= nil and (o.invincTimer or 0) > 0 then return false end
    end

    shooter.note_the_range(globalIndex)

    if seat ~= nil and seat.localIndex ~= 0 and shooter.round_kills() then
        OF.util.send_to_player(seat.localIndex, OF.packet_stamp({ ofp = shooter.PACKET_SHOT,
            k = network_global_index_from_local(0), v = globalIndex,
            m = melee == true and 1 or 0, c = cause }))
        return false, "sent"
    end

    local ok, why = OF.powerups.give(globalIndex, KILL_ENDING, { q = 1 },
        network_global_index_from_local(0), true)
    OF.util.report(ok, why)

    if ok == true and globalIndex == network_global_index_from_local(0) then
        OF.notify.show("You blew yourself up", "bad")
        if OF.util.asks(OF.lobbytalk, "feed_self") then
            OF.lobbytalk.feed_self(globalIndex)
        end
        return true
    end
    if ok == true and OF.util.asks(OF.cheats, "mark_a_hit") then
        OF.cheats.mark_a_hit()
    end
    if ok == true then shooter.paid(globalIndex, melee, cause) end
    return ok == true
end

function shooter.round_kills()
    local cur = OF.gamemodes.current()
    return cur ~= nil and cur.roundKills == true
        and OF.gamemodes.state() == OF.gamemodes.ACTIVE
end

shooter.PACKET_SHOT = "shkill"
shooter.PACKET_DOWN = "shdown"
function shooter.hear_kill(data)
    local me = gNetworkPlayers[0]
    if me == nil or data.v ~= me.globalIndex then return false end
    if not shooter.round_kills() then return false end
    if not OF.util.can_play(0) then return false end
    local m = gMarioStates[0]
    if m == nil then return false end
    if OF.util.action_group(m.action) == OF.util.action_group(ACT_GROUP_CUTSCENE) then return false end
    if (m.invincTimer or 0) > 0 then return false end
    local killer = OF.util.local_from_global(data.k)
    if killer == nil or killer == 0 then return false end
    local cur = OF.gamemodes.current()
    if cur.noFriendlyFire == true and OF.teams.in_play() and OF.teams.same(0, killer) then
        return false
    end
    if not OF.util.asks(OF.powerups, "apply") then return false end
    OF.powerups.apply(KILL_ENDING, { q = 1 })
    OF.util.send_to_player(killer, OF.packet_stamp({ ofp = shooter.PACKET_DOWN,
        k = data.k, v = data.v, m = data.m, c = data.c }))
    return true
end

function shooter.hear_down(data)
    local me = gNetworkPlayers[0]
    if me == nil or data.k ~= me.globalIndex then return false end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false end
    local seat = seat_for(data.v)
    lastKillWasMate = seat ~= nil and OF.teams.in_play() and OF.teams.same(0, seat.localIndex)

    if OF.util.asks(OF.cheats, "mark_a_hit") then OF.cheats.mark_a_hit() end
    shooter.paid(data.v, data.m == 1, data.c)

    shooter.credit_a_kill()
    return true
end

OF.packet_kind(shooter.PACKET_SHOT, { round = true,
    fields = { k = "gi", v = "gi", m = "int?", c = "str?" } }, shooter.hear_kill)
OF.packet_kind(shooter.PACKET_DOWN, { round = true,
    fields = { k = "gi", v = "gi", m = "int?", c = "str?" } }, shooter.hear_down)

function shooter.paid(globalIndex, melee, cause)
    do

        killSeq = killSeq + 1

        OF.gamemodes.cue("good")

        local how = melee == true and "fists" or cause
            or (OF.gamemodes.current() ~= nil and OF.gamemodes.current().killCause) or "rifle"
        local card, killer = shooter.death_card(how, gNetworkPlayers[0].name)
        OF.notify.send_to(globalIndex, card, "bad", nil, killer)

        local theirLocal = OF.util.local_from_global(globalIndex)
        local theirName = theirLocal ~= nil and gNetworkPlayers[theirLocal] ~= nil
            and gNetworkPlayers[theirLocal].name or "?"
        OF.notify.show(OF.lang.fill("You got @", theirName), "good")
        if OF.util.asks(OF.hud, "banner") then OF.hud.banner("medal", "+1", nil, { tone = "good" }) end

        if OF.util.asks(OF.replay, "tell_victim") then
            OF.replay.tell_victim(globalIndex)
        end

        if OF.util.asks(OF.lobbytalk, "feed_globals") then
            OF.lobbytalk.feed_globals(network_global_index_from_local(0), globalIndex, nil, how)
        end
        shooter.medal(globalIndex, melee == true)
    end
    return true
end

local MEDALS = { lastAt = -9999, window = 3 * 30 }

function shooter.medal(victimGlobal, melee)
    if not OF.gamemodes.option_is("medals", "on") then return nil end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return nil end
    local now = now_frame()
    local won = {}

    local say = OF.util.asks(OF.hud, "banner") and OF.hud.banner or function() end
    if melee then
        table.insert(won, "humiliation")
        say("medal", OF.lang.t("HUMILIATION"), nil, { tone = "good" })
    end
    if now - MEDALS.lastAt <= MEDALS.window then
        table.insert(won, "excellent")
        say("medal", OF.lang.t("EXCELLENT"), nil, { tone = "good" })
    end
    MEDALS.lastAt = now
    if #won == 0 then return nil end
    OF.gamemodes.round_sound(SOUND_MENU_STAR_SOUND)
    return table.concat(won, " ")
end

function QUAD.on()
    return OF.gamemodes.option_is("quad", "on")
end

function QUAD.read(text)
    if type(text) ~= "string" then return nil end
    local x, y, z, up, holder, serial = text:match(
        "^(%-?%d+),(%-?%d+),(%-?%d+) (%d) (%-?%d+) (%d+)$")
    if x == nil then return nil end
    return { x = tonumber(x), y = tonumber(y), z = tonumber(z),
             up = up == "1", holder = tonumber(holder),
             serial = tonumber(serial) }
end

local function quad_say(h)
    OF.util.publish(QUAD.key, string.format("%.0f,%.0f,%.0f %.0f %.0f %.0f",
        h.x, h.y, h.z, h.up and 1 or 0, h.holder, h.serial))
end

function QUAD.mine()
    if not QUAD.on() then return false end
    local line = QUAD.read(gGlobalSyncTable[QUAD.key])
    local me = gNetworkPlayers[0] and gNetworkPlayers[0].globalIndex
    if line == nil or me == nil or line.holder ~= me then return false end
    return now_frame() < QUAD.mineUntil
end

local function quad_point()
    local here = OF.gamemodes.here_place(0)
    if here == nil then return nil end
    local list = OF.gamemodes.surveyed_list(here, "points", 16)
    if list == nil or list[1] == nil then return nil end
    local cx, cy, cz = 0, 0, 0
    for _, p in ipairs(list) do cx, cy, cz = cx + p.x, cy + p.y, cz + p.z end
    cx, cy, cz = cx / #list, cy / #list, cz / #list
    local best, bestD = list[1], nil
    for _, p in ipairs(list) do
        local d = (p.x - cx) ^ 2 + (p.y - cy) ^ 2 + (p.z - cz) ^ 2
        if bestD == nil or d < bestD then best, bestD = p, d end
    end
    return best
end

function QUAD.host(now)
    if not QUAD.on() then return end
    local h = QUAD.h

    local standing = QUAD.read(gGlobalSyncTable[QUAD.key])
    if h == nil and standing ~= nil then
        h = standing
        h.takenAt, h.untilAt = now, now + QUAD.lasts
        h.upAt = now + QUAD.firstMid
        QUAD.h = h
    end
    if h == nil then
        local spot = quad_point()
        if spot == nil then return end
        h = { x = spot.x, y = spot.y, z = spot.z, up = false, holder = -1,
              serial = 0,
              upAt = now + QUAD.firstMid + 30 * math.random(-15, 15) }
        QUAD.h = h
        quad_say(h)
        return
    end
    if h.holder ~= -1 then
        local seat = seat_for(h.holder)
        local o = seat and gMarioStates[seat.localIndex]
        local gone = seat == nil or o == nil
            or (o.health or 0) < 0x100 or now >= (h.untilAt or 0)
        if gone then
            h.holder = -1
            h.upAt = (h.takenAt or now) + QUAD.respawn
            quad_say(h)
        end
        return
    end
    if not h.up then
        if now >= (h.upAt or 0) then
            h.up = true
            quad_say(h)
        end
        return
    end
    local best, bestD = nil, QUAD.reach * QUAD.reach
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_SHOOTING)) do
        local o = gMarioStates[entry.localIndex]
        if o ~= nil and o.pos ~= nil and OF.util.can_play(entry.localIndex)
            and (o.health or 0) >= 0x100 and entry.np ~= nil then
            local d = (o.pos.x - h.x) ^ 2 + (o.pos.y - h.y) ^ 2
                + (o.pos.z - h.z) ^ 2
            if d <= bestD then best, bestD = entry, d end
        end
    end
    if best == nil then return end
    h.up, h.holder, h.serial = false, best.np.globalIndex, h.serial + 1
    h.takenAt, h.untilAt = now, now + QUAD.lasts
    quad_say(h)
end

shooter.SPAWN_KEY = SPAWN_KEY
mode.leadPin = {
    keys = { SPAWN_KEY, QUAD.key },
    run = function()
        mode.pin()
        if not QUAD.on() then return end
        local spot = quad_point()
        if spot == nil then return end
        quad_say({ x = spot.x, y = spot.y, z = spot.z, up = false, holder = -1,
                   serial = 0 })
    end,
}

function QUAD.hear()
    if not QUAD.on() then
        QUAD.drop_mark()
        return nil
    end
    local line = QUAD.read(gGlobalSyncTable[QUAD.key])
    if line == nil then
        QUAD.drop_mark()
        return nil
    end
    local said = nil
    local me = gNetworkPlayers[0] and gNetworkPlayers[0].globalIndex
    if QUAD.heardSerial ~= nil and line.serial ~= QUAD.heardSerial
        and line.holder ~= -1 then
        local seat = seat_for(line.holder)

        local _ = seat
        if line.holder == me then
            QUAD.mineUntil = now_frame() + QUAD.lasts
            if OF.util.asks(OF.hud, "banner") then
                OF.hud.banner("objective", OF.lang.t("QUAD"), OF.lang.t("Ten seconds"), { side = "us" })
            end
            said = "mine"
        else
            if OF.util.asks(OF.hud, "banner") then
                OF.hud.banner("objective", OF.lang.t("QUAD TAKEN"), nil, { side = "them" })
            end
            said = "taken"
        end
    elseif QUAD.heardUp == false and line.up then
        if OF.util.asks(OF.hud, "banner") then
            OF.hud.banner("objective", OF.lang.t("QUAD"), OF.lang.t("On the map"))
        end
        said = "up"
    end
    QUAD.heardSerial, QUAD.heardUp = line.serial, line.up

    if line.up then
        local obj = QUAD.mark
        if not shooter.still_ours(obj, nil, QUAD.model()) then
            obj = OF.slots.spawn_non_sync(id_bhvStaticObject, QUAD.model(),
                line.x, line.y + 60, line.z, nil, true)
            shooter.mark_ours(obj, QUAD.model())
            QUAD.mark = obj
        end
        if obj ~= nil then
            local now = now_frame()
            obj.oFaceAngleYaw = (now * 0x300) & 0xFFFF
            obj.oPosY = line.y + 60 + 12 * math.sin(now / 10)
        end
    else
        QUAD.drop_mark()
    end
    return said
end

function QUAD.drop_mark()
    if QUAD.mark ~= nil and shooter.still_ours(QUAD.mark, nil, QUAD.model()) then
        OF.util.optional("obj_mark_for_deletion", nil, QUAD.mark)
    end
    QUAD.mark = nil
end

function QUAD.forget()
    QUAD.drop_mark()
    QUAD.h, QUAD.heardSerial, QUAD.heardUp = nil, nil, nil
    QUAD.mineUntil = -9999
end

function mode.scenery()
    return QUAD.hear()
end

function shooter.kill_seq()
    return killSeq
end

function shooter.set_off(x, y, z, throwerGlobalIndex)
    local thrower = throwerGlobalIndex
    if type(thrower) ~= "number" or thrower < 0 then
        thrower = network_global_index_from_local(0)
    end
    local killed = 0
    for _, entry in ipairs(shooter.blast_reaches(x, y, z)) do

        local mate = OF.teams.in_play()
            and OF.teams.same(0, entry.localIndex)
        local isThrower = entry.np ~= nil and entry.np.globalIndex == thrower

        local down, how = shooter.put_down(entry.np.globalIndex, false, "grenade")
        if (down or how == "sent") and not mate and not isThrower then
            killed = killed + 1
        end
    end
    return killed
end

function shooter.throw_aim(m, reach)
    if m == nil or m.pos == nil then return nil end
    if not OF.util.asks(OF.util, "view_axis") then return nil end
    local ex, ey, ez, dx, dy, dz = OF.util.view_axis()
    if ex == nil then return nil end
    reach = (type(reach) == "number" and reach > 0) and reach or THROW_RANGE
    local hx, hy, hz = m.pos.x, m.pos.y + 60, m.pos.z
    local own = (m.pos.x - ex) * dx + (m.pos.y - ey) * dy + (m.pos.z - ez) * dz
    if own < 0 then own = 0 end

    local far = own + reach
    local tx, ty, tz = ex + dx * far, ey + dy * far, ez + dz * far
    local body = nil
    if OF.util.asks(OF.cheats, "rifle_target") then
        local hit, along = OF.cheats.rifle_target(ex, ey, ez, dx, dy, dz)
        if hit ~= nil and type(along) == "number" and along <= far then
            local them = gMarioStates[hit.localIndex]
            if them ~= nil and them.pos ~= nil then
                tx, ty, tz = them.pos.x, them.pos.y, them.pos.z
                body = hit
            end
        end
    end
    if body == nil then
        local sx, sy, sz = ex + dx * own, ey + dy * own, ez + dz * own
        local span = far - own
        local wall = OF.util.optional("collision_find_surface_on_ray", nil,
            sx, sy, sz, dx * span, dy * span, dz * span)
        if wall ~= nil and wall.surface ~= nil and wall.hitPos ~= nil then
            tx, ty, tz = wall.hitPos.x, wall.hitPos.y, wall.hitPos.z
        end
    end
    local ax, ay, az = tx - hx, ty - hy, tz - hz
    local d = math.sqrt(ax * ax + ay * ay + az * az)
    if d > reach then
        local k = reach / d
        tx, ty, tz = hx + ax * k, hy + ay * k, hz + az * k
    end
    return tx, ty, tz, body
end

function shooter.throw_velocity(sx, sy, sz, tx, ty, tz)
    local ax, az = tx - sx, tz - sz
    local flat = math.sqrt(ax * ax + az * az)
    local rise = ty - sy
    local g = THROW_GRAVITY
    local n = math.max(THROW_FRAMES_MIN, math.ceil(flat / THROW_SPEED))
    if rise > 0 then
        n = math.max(n, math.ceil(math.sqrt(2 * rise / g)))
    end
    local vy = (rise + g * n * (n + 1) / 2) / n
    if vy > THROW_VY_MAX then vy = THROW_VY_MAX end
    local yaw = OF.util.optional("atan2s", nil, az, ax)
    if type(yaw) ~= "number" then
        yaw = math.floor(math.atan(ax, az) * 0x8000 / math.pi)
    end
    return yaw, flat / n, vy, n
end

function shooter.nade_leaves_the_hand(bomb)
    if bomb == nil then return false end
    local ok, mark = pcall(function() return bomb[NADE_MARK_FIELD] end)
    if not ok or mark ~= NADE_MARK then return false end
    local hand = tonumber(bomb.oHomeY)
    if hand == nil or bomb.oPosY == nil then return false end
    local floor = OF.util.optional("find_floor_height", nil, bomb.oHomeX or 0, hand + 200,
        bomb.oHomeZ or 0)
    if type(floor) ~= "number" then return false end
    bomb.oPosY = hand + (bomb.oPosY - floor)
    if bomb.oAction ~= NADE_FLYING then bomb.oAction = NADE_FLYING end
    return true
end

if id_bhvBobomb ~= nil and type(hook_behavior) == "function" then
    hook_behavior(id_bhvBobomb, OBJ_LIST_DESTRUCTIVE or 2, false,
        shooter.nade_leaves_the_hand, nil)
end

function shooter.throw_from(m, aimed, share)
    if m == nil or m.pos == nil then return nil end
    local yaw = m.faceAngle ~= nil and m.faceAngle.y or 0
    local k = OF.util.clamp(tonumber(share) or 1, 0, 1)
    local speed = THROW_LOB_SPEED + (THROW_SPEED - THROW_LOB_SPEED) * k
    local lift = THROW_LOB_LIFT + (THROW_LIFT - THROW_LOB_LIFT) * k
    local tx, ty, tz = nil, nil, nil
    if aimed == true then tx, ty, tz = shooter.throw_aim(m, THROW_RANGE) end
    if tx ~= nil then
        yaw, speed, lift = shooter.throw_velocity(m.pos.x, m.pos.y + 60,
            m.pos.z, tx, ty, tz)
    end

    local throwerGlobal = network_global_index_from_local(m.playerIndex or 0)
    local function setup(o)
        o.oBehParams = 0x100
        o.oBehParams2ndByte = throwerGlobal or -1
        o.oAction = NADE_FLYING
        o.oMoveAngleYaw = yaw
        o.oForwardVel = speed
        o.oVelY = lift

        o[NADE_MARK_FIELD] = NADE_MARK
    end
    local nade = OF.util.optional("spawn_sync_object", nil,
        id_bhvBobomb, E_MODEL_BLACK_BOBOMB,
        m.pos.x, m.pos.y + 60, m.pos.z, setup)
    if nade == nil then return nil end

    setup(nade)
    shooter.mark_ours(nade, E_MODEL_BLACK_BOBOMB)
    grenadeReadyAt = now_frame() + GRENADE_WAIT
    return nade
end

local function aiming(m)
    return m ~= nil and m.controller ~= nil
        and OF.util.has_flag(m.controller.buttonDown or 0, L_TRIG)
end

function shooter.work_the_fuse(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    local pad = m.controller
    local held = pad ~= nil and OF.util.has_flag(pad.buttonDown or 0, GRENADE_BUTTON)
    local fresh = held and not yWasDown
    yWasDown = held
    if not shooter.kit_here() then
        charging = nil
        return false
    end

    if not grenades_on() then
        charging = nil
        return false
    end
    if pad == nil then return false end

    if charging == nil then
        if fresh and shooter.may_throw() then
            charging = now_frame()
        end
        return false
    end
    if held then return false end

    local share = shooter.charge_share()
    charging = nil

    m.invincTimer = 0
    local nade = shooter.throw_from(m, aiming(m), share)
    if nade ~= nil then shooter.kit_spent("grenade") end

    if nade ~= nil then table.insert(flying, nade) end
    return true, 0
end

function shooter.throw_flash(m)
    if m == nil or m.playerIndex ~= 0 or m.controller == nil then return false end
    local held = OF.util.has_flag(m.controller.buttonDown or 0, NUT_BUTTON)
    local edge = held and not xWasDown
    xWasDown = held

    if not shooter.kit_here() or not flash_nuts() or not shooter.kit_allows("flash")
        or OF.gamemodes.state() ~= OF.gamemodes.ACTIVE or not OF.util.can_play(0)
        or shooter.dying(m)
        or not OF.util.asks(OF.zelda, "throw_nut") then
        nutCharging = nil
        return false
    end
    if nutCharging == nil then
        if edge then nutCharging = now_frame() end
        return false
    end
    if held then return false end
    local share = shooter.nut_share()
    nutCharging = nil
    shooter.hand_the_nut()
    local aimed = aiming(m)
    local reach = aimed and FLASH_FAR or shooter.nut_reach(share)
    local ok = OF.zelda.throw_nut(m, reach, aimed) == true

    if ok then
        m.invincTimer = 0
        shooter.kit_spent("flash")
    end
    return ok
end

function shooter.holds_the_nut(globalIndex)
    if not shooter.kit_here() then return false end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false end
    if not flash_nuts() then return false end
    local li = OF.util.local_from_global(globalIndex)
    return li ~= nil and OF.util.can_play(li)
end

function shooter.hand_the_nut()

    if type(OF.zelda) ~= "table" or type(OF.zelda.hand_out) ~= "function" then
        return false
    end
    return OF.zelda.hand_out("nut", shooter.holds_the_nut)
end
shooter.hand_the_nut()

function shooter.watch_the_air()
    local killed = 0
    for at = #flying, 1, -1 do
        local nade = flying[at]

        local gone = not shooter.still_ours(nade, id_bhvBobomb,
            E_MODEL_BLACK_BOBOMB)
        if gone or nade.oAction ~= NADE_FLYING then
            if not gone and nade.oPosX ~= nil then
                killed = killed + shooter.set_off(nade.oPosX, nade.oPosY,
                    nade.oPosZ, nade.oBehParams2ndByte)
            end
            table.remove(flying, at)
        end
    end
    return killed
end

local NADE_HEARD = GRENADE_REACH + 200
function shooter.hear_the_grenades(m)
    local near = false
    local me = gNetworkPlayers[0] ~= nil and gNetworkPlayers[0].globalIndex or nil
    if m ~= nil and m.pos ~= nil and OF.util.can_play(0) then
        local o = OF.util.optional("obj_get_first_with_behavior_id", nil, id_bhvBobomb)
        while o ~= nil and not near do
            local by = o.oBehParams2ndByte
            if o.oAction == NADE_FLYING and by ~= nil and by >= 0 and by ~= me then
                local from = OF.util.local_from_global(by)
                local mate = from ~= nil and OF.teams.in_play() and OF.teams.same(0, from)
                local dx, dy, dz = (o.oPosX or 0) - m.pos.x, (o.oPosY or 0) - m.pos.y,
                    (o.oPosZ or 0) - m.pos.z
                if not mate and dx * dx + dy * dy + dz * dz <= NADE_HEARD * NADE_HEARD then
                    near = true
                end
            end
            o = OF.util.optional("obj_get_next_with_same_behavior_id", nil, o)
        end
    end
    local warned = near and not heardNade.near
    if warned then OF.gamemodes.cue("hazard") end
    heardNade.near = near
    return warned
end

function shooter.track_flying(nade)
    if nade == nil then return false end
    table.insert(flying, nade)
    return true
end

function shooter.sprinting()
    return sprinting
end
shooter.SPRINT_TOP = SPRINT_TOP

function shooter.work_the_sprint(m)
    if not sprint_on() then
        sprinting = false
        return false
    end
    if m == nil or m.playerIndex ~= 0 then return false end
    if not shooter.kit_here() then
        sprinting = false
        return false
    end
    local pad = m.controller
    if pad == nil then
        sprinting = false
        return false
    end

    sprinting = m.action == ACT_WALKING and OF.util.has_flag(pad.buttonDown, A_BUTTON)
    if not sprinting then return false end

    if OF.util.asks(OF.moves, "sprint_step") then
        OF.moves.sprint_step(m, true, { stamina = false })
    end
    return true
end

function shooter.set_stands_down(fn)
    otherStandsDown = fn
end

function shooter.rifle_stands_down()

    if OF.gamemodes.is_running() and shooter.dying(gMarioStates[0]) then return true end
    if not shooter.kit_here() then
        if otherStandsDown ~= nil then return otherStandsDown() end
        return false
    end
    if otherStandsDown ~= nil and otherStandsDown() then return true end
    return sprinting
end

function shooter.credit_a_kill()
    if OF.gamemodes.current() ~= mode then return false end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false end
    if lastKillWasMate then return false end
    OF.util.publish_row(0, "ofScore", score_of(0) + 1)
    shooter.keep_the_longest()
    return true
end

shooter.SHAPES = {
    rifle    = { thick = 0.09, long = 0.60, ahead = 55, down = 14 },

    launcher = { thick = 0.24, long = 0.66, ahead = 45, down = 36 },
}

local HAND_STRAY = 400
local rifles = {}

local shapeOf = {}

local walkedAt = {}

function shooter.hand_of(m)
    if m == nil or m.pos == nil then return nil end
    local hx = OF.util.optional("get_hand_foot_pos_x", nil, m, 0)
    local hy = OF.util.optional("get_hand_foot_pos_y", nil, m, 0)
    local hz = OF.util.optional("get_hand_foot_pos_z", nil, m, 0)
    if type(hx) ~= "number" or type(hy) ~= "number"
        or type(hz) ~= "number" then
        return nil
    end
    local dx, dy, dz = hx - m.pos.x, hy - m.pos.y, hz - m.pos.z
    if dx * dx + dy * dy + dz * dz > HAND_STRAY * HAND_STRAY then
        return nil
    end
    return hx, hy, hz
end

local function our_box(obj)
    return shooter.still_ours(obj, id_bhvStaticObject, E_MODEL_METAL_BOX)
end

local function put_the_rifle_down(localIndex)
    local obj = rifles[localIndex]
    if our_box(obj) then
        OF.util.optional("obj_mark_for_deletion", nil, obj)
    end
    rifles[localIndex] = nil
    shapeOf[localIndex] = nil
    walkedAt[localIndex] = nil
end

function shooter.weapon_of(seat)
    if not OF.util.can_play(seat) then return nil end
    if OF.gamemodes.is_running() then
        local mode = OF.gamemodes.current()
        if mode ~= nil then
            local shape = mode.weapon
            if type(shape) == "function" then
                local ok, answer = pcall(shape, seat)
                shape = ok and answer or nil
            elseif shape == nil and type(mode.cheatsGiven) == "table"
                and mode.cheatsGiven.sniper ~= nil then
                shape = "rifle"
            end
            if shape ~= nil then
                return shooter.SHAPES[shape] ~= nil and shape or nil
            end
            if mode.weapon ~= nil then return nil end
        end

        local worn = shooter.cheat_weapon(seat)
        if worn == nil then return nil end
        if OF.util.asks(OF.cheats, "round_holds")
            and OF.cheats.round_holds("sniper") then
            return nil
        end
        return worn
    end
    return shooter.cheat_weapon(seat)
end

function shooter.cheat_weapon(seat)
    if not OF.util.asks(OF.cheats, "is_on") then return nil end
    if seat == 0 then
        return OF.cheats.is_on("sniper") and "rifle" or nil
    end
    if OF.util.asks(OF.cheats, "room_on") and OF.cheats.room_on("sniper") then
        return "rifle"
    end
    if not OF.util.asks(OF.cheats, "worn_set") then return nil end
    local worn = OF.cheats.worn_set(seat)
    return (worn ~= nil and worn.sniper ~= nil) and "rifle" or nil
end

function shooter.grip_point(shape, hx, hy, hz, yaw)
    local spec = shooter.SHAPES[shape] or shooter.SHAPES.rifle
    local fx = OF.util.optional("sins", nil, yaw)
    local fz = OF.util.optional("coss", nil, yaw)
    if type(fx) ~= "number" or type(fz) ~= "number" then
        local turn = (yaw or 0) * math.pi / 0x8000
        fx, fz = math.sin(turn), math.cos(turn)
    end
    return hx + fx * spec.ahead, hy - spec.down, hz + fz * spec.ahead
end

local function set_the_box(obj, m, hx, hy, hz, dx, dy, dz, shape)
    local yaw = m.faceAngle ~= nil and m.faceAngle.y or 0
    local x, y, z = shooter.grip_point(shape, hx + dx, hy + dy, hz + dz, yaw)
    obj.oPosX, obj.oPosY, obj.oPosZ = x, y, z

    obj.oFaceAngleYaw = yaw
    obj.oMoveAngleYaw = yaw

    local gfx = obj.header ~= nil and obj.header.gfx or nil
    if gfx ~= nil and gfx.pos ~= nil then
        gfx.pos.x, gfx.pos.y, gfx.pos.z = x, y, z
        if gfx.angle ~= nil then gfx.angle.y = yaw end
    end
    return x, y, z
end

function shooter.carry_the_rifles()
    local carried = 0

    local wanted = nil

    local running = OF.gamemodes.is_running()
    for _, entry in ipairs(OF.util.connected_players()) do
        local seat = entry.localIndex
        if running or shooter.cheat_weapon(seat) ~= nil then
        local m = gMarioStates[seat]
        local hx, hy, hz = shooter.hand_of(m)
        local shape = nil

        local replaying = OF.util.asks(OF.replay, "playing")
            and OF.replay.playing() ~= nil
        if hx ~= nil and not replaying
            and OF.util.optional("is_player_active", 0, m) ~= 0 then
            shape = shooter.weapon_of(seat)
        end
        if shape ~= nil then
            wanted = wanted or {}
            wanted[seat] = true
            local spec = shooter.SHAPES[shape]
            local obj = rifles[seat]
            if not our_box(obj) then
                obj = OF.util.optional("spawn_non_sync_object", nil,
                    id_bhvStaticObject, E_MODEL_METAL_BOX, hx, hy, hz, nil)
                shooter.mark_ours(obj, E_MODEL_METAL_BOX)
                rifles[seat] = obj
                shapeOf[seat] = nil
            end
            if obj ~= nil then
                if shapeOf[seat] ~= shape then
                    OF.util.optional("obj_scale_xyz", nil, obj,
                        spec.thick, spec.thick, spec.long)
                    shapeOf[seat] = shape
                end
                set_the_box(obj, m, hx, hy, hz, 0, 0, 0, shape)
                walkedAt[seat] = { x = m.pos.x, y = m.pos.y, z = m.pos.z }
                carried = carried + 1
            end
        end
        end
    end

    for seat in pairs(rifles) do
        if not (wanted ~= nil and wanted[seat]) then put_the_rifle_down(seat) end
    end
    return carried
end

function shooter.hold_the_weapon(m)
    if m == nil or m.pos == nil then return false end
    local seat = m.playerIndex or 0
    local obj = rifles[seat]
    local at = walkedAt[seat]
    if at == nil or not our_box(obj) then return false end
    local hx, hy, hz = shooter.hand_of(m)
    if hx == nil then return false end
    local dx, dy, dz = m.pos.x - at.x, m.pos.y - at.y, m.pos.z - at.z
    if dx * dx + dy * dy + dz * dz > HAND_STRAY * HAND_STRAY then return false end
    set_the_box(obj, m, hx, hy, hz, dx, dy, dz, shapeOf[seat] or "rifle")
    return true
end

function shooter.drop_the_rifles()
    local dropped = 0
    for seat in pairs(rifles) do
        put_the_rifle_down(seat)
        dropped = dropped + 1
    end
    return dropped
end

function shooter.weapon_obj(seat)
    return rifles[seat], shapeOf[seat]
end

function shooter.forget_the_handles()
    local forgot = 0
    for seat, obj in pairs(rifles) do
        if our_box(obj) then
            OF.util.optional("obj_mark_for_deletion", nil, obj)
        end
        rifles[seat] = nil
        forgot = forgot + 1
    end
    for seat in pairs(shapeOf) do shapeOf[seat] = nil end
    for seat in pairs(walkedAt) do walkedAt[seat] = nil end
    for at = #flying, 1, -1 do
        if not shooter.still_ours(flying[at], id_bhvBobomb,
            E_MODEL_BLACK_BOBOMB) then
            table.remove(flying, at)
            forgot = forgot + 1
        end
    end

    local kept = {}
    for _, nade in ipairs(flying) do kept[nade] = marks[nade] end
    marks = kept

    QUAD.mark = nil
    charging = nil
    return forgot
end

hook_event(HOOK_UPDATE, function() shooter.carry_the_rifles() end)
hook_event(HOOK_MARIO_UPDATE, shooter.hold_the_weapon)
hook_event(HOOK_ON_LEVEL_INIT, function() shooter.forget_the_handles() end)
hook_event(HOOK_ON_WARP, function() shooter.forget_the_handles() end)

local SHOT_MOST = 20000

local function range_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    local far = row ~= nil and row[SHOT_KEY] or 0
    if type(far) ~= "number" or far ~= far or far < 0 then return 0 end
    if far > SHOT_MOST then return SHOT_MOST end
    return far
end

function shooter.note_the_range(globalIndex)
    lastRange = nil
    local me = gMarioStates[0]
    if me == nil or me.pos == nil then return nil end
    local seat = seat_for(globalIndex)
    if seat == nil then return nil end
    local them = gMarioStates[seat.localIndex]
    if them == nil or them.pos == nil then return nil end
    local dx = them.pos.x - me.pos.x
    local dy = them.pos.y - me.pos.y
    local dz = them.pos.z - me.pos.z
    lastRange = math.sqrt(dx * dx + dy * dy + dz * dz)
    return lastRange
end

function shooter.keep_the_longest()
    if lastRange == nil then return false end
    local far = math.floor(math.min(lastRange, SHOT_MOST))
    lastRange = nil
    if far <= range_of(0) then return false end
    OF.util.publish_row(0, SHOT_KEY, far)
    return true
end

function shooter.longest_shot()
    local best, who = 0, nil
    for _, entry in ipairs(OF.util.connected_players()) do
        local far = range_of(entry.localIndex)
        if far > best then best, who = far, entry.np end
    end
    if who == nil then return nil end
    return who.name, best
end

function shooter.most_kills()
    local best, who = 0, nil
    for _, entry in ipairs(OF.util.connected_players()) do
        local kills = score_of(entry.localIndex)
        if kills > best then best, who = kills, entry.np end
    end
    if who == nil then return nil end
    return who.name, best
end

function shooter.tally_lines()
    local lines = {}
    local far, range = shooter.longest_shot()
    if far ~= nil and range > 0 then
        table.insert(lines, OF.lang.fill("Longest shot: @ at @",
            OF.util.shorten(OF.util.plain(far), 14),
            tostring(math.floor(range))))
    end
    local top, kills = shooter.most_kills()
    if top ~= nil and kills > 0 then
        table.insert(lines, OF.lang.fill("Most kills: @ with @",
            OF.util.shorten(OF.util.plain(top), 14), tostring(kills)))
    end

    return lines
end

function shooter.draw_tally()
    if OF.gamemodes.current() ~= mode then return false end
    local state = OF.gamemodes.state()
    if state ~= OF.gamemodes.MOMENT and state ~= OF.gamemodes.RESULTS then
        return false
    end
    if OF.util.menu_has_screen() then return false end
    local lines = shooter.tally_lines()
    if #lines == 0 then return false end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    local head = table.remove(lines, 1)
    local opts = { accent = OF.GOLD }
    if #lines > 0 then

        local under = {}
        for _, line in ipairs(lines) do
            table.insert(under, { text = line })
        end
        opts.under = under
    end
    OF.util.round_line_low(head, "line", "gold", opts)
    return true
end

function shooter.controls_lines()
    local shape = shooter.weapon_of(0)

    if shape == nil then return {} end
    local here = OF.gamemodes.is_running() and shooter.kit_here()
    local nades = here and grenades_on()
    local nuts = here and flash_nuts()
    local lines = {}
    if nades or nuts then
        table.insert(lines, OF.lang.t("Hold L - aim (throws land at the crosshair)"))
    else
        table.insert(lines, OF.lang.t("Hold L - aim"))
    end
    if shape == "launcher" then
        table.insert(lines, OF.lang.t("L + B - fire a rocket"))
        table.insert(lines, OF.lang.t("L + B at your feet - rocket jump"))
    else
        table.insert(lines, OF.lang.t("L + B - fire"))
    end
    if nades then
        table.insert(lines, OF.lang.t("Y - hold for a longer throw, let go to throw"))
    end
    if nuts then
        table.insert(lines, OF.lang.t("X - throw a flash nut"))
    end
    if here and sprint_on() then
        table.insert(lines, OF.lang.t("Hold A - sprint, and the rifle waits"))
    end
    local cur = OF.gamemodes.current()
    if cur == nil or cur.may_attack == nil then
        table.insert(lines, OF.lang.t("Without L: B punches"))
    end
    return lines
end

function shooter.draw_controls()
    local m = gMarioStates[0]
    if m == nil or m.controller == nil then return false end
    if not OF.util.can_play(0) then return false end
    local inRound = OF.gamemodes.state() == OF.gamemodes.ACTIVE
    if not inRound and not OF.util.has_flag(m.controller.buttonDown or 0, L_TRIG) then
        return false
    end
    return OF.util.legend(shooter.controls_lines()) == true
end

hook_event(HOOK_ON_HUD_RENDER, function()
    shooter.draw_tally()
    shooter.draw_controls()
end)

function shooter.watch_the_bolt()
    local cold = 0
    if OF.util.asks(OF.cheats, "rifle_cooldown") then
        cold = OF.cheats.rifle_cooldown()
    end
    local fired = cold > 0 and boltWas <= 0
    boltWas = cold
    return fired
end

local MARK_EVERY = 4

local MARK_MISS = 3000
local MARK_DOT = 3
local markAt = nil
local markReach = MARK_MISS
local markOnBody = false

function shooter.mark_world(ox, oy, oz, dx, dy, dz, reach)
    if type(ox) ~= "number" or type(oy) ~= "number"
        or type(oz) ~= "number" then
        return nil
    end
    if type(dx) ~= "number" or type(dy) ~= "number"
        or type(dz) ~= "number" then
        return nil
    end
    if type(reach) ~= "number" or reach <= 0 then return nil end
    return { x = ox + dx * reach, y = oy + dy * reach, z = oz + dz * reach }
end

function shooter.mark_reach(ex, ey, ez, dx, dy, dz)
    local now = now_frame()

    if markAt ~= nil and now >= markAt and now - markAt < MARK_EVERY then
        return markReach, markOnBody
    end
    markAt = now
    markReach, markOnBody = MARK_MISS, false
    if not OF.util.asks(OF.cheats, "rifle_target") then
        return markReach, markOnBody
    end
    local hit, along = OF.cheats.rifle_target(ex, ey, ez, dx, dy, dz)
    if hit ~= nil and type(along) == "number" and along > 0 then
        markReach, markOnBody = along, true
        return markReach, markOnBody
    end
    if OF.util.asks(OF.cheats, "shot_reaches") then
        local far = OF.cheats.shot_reaches(ex, ey, ez, dx, dy, dz, nil)
        if type(far) == "number" and far > 0 then markReach = far end
    end
    return markReach, markOnBody
end

function shooter.crosshair_world(ox, oy, oz)
    if not shooter.kit_here() then return nil end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return nil end
    if not OF.util.can_play(0) then return nil end
    if not OF.util.asks(OF.cheats, "rifle_is_aimed") then return nil end
    if not OF.cheats.rifle_is_aimed() then return nil end
    if not OF.util.asks(OF.util, "view_axis") then return nil end

    local ex, ey, ez, dx, dy, dz = OF.util.view_axis()
    if ex == nil then return nil end
    local reach, onBody = shooter.mark_reach(ex, ey, ez, dx, dy, dz)
    if type(ox) ~= "number" then ox, oy, oz = ex, ey, ez end
    return shooter.mark_world(ox, oy, oz, dx, dy, dz, reach), onBody
end

function shooter.draw_crosshair(ox, oy, oz)
    if djui_hud_render_rect == nil or djui_hud_set_color == nil then
        return false
    end
    local at, onBody = shooter.crosshair_world(ox, oy, oz)
    if at == nil then return false end
    if not OF.util.asks(OF.util, "world_screen") then return false end

    local out = { x = 0, y = 0, z = 0 }
    if not OF.util.world_screen(at, out) then return false end

    local cold = OF.util.asks(OF.cheats, "rifle_cooldown")
        and OF.cheats.rifle_cooldown() > 0
    local red, green, blue = 255, 255, 255
    if cold then
        red, green, blue = 230, 90, 70
    elseif onBody then
        red, green, blue = 90, 255, 90
    end
    djui_hud_set_color(red, green, blue, 215)
    djui_hud_render_rect(out.x - MARK_DOT / 2, out.y - MARK_DOT / 2,
        MARK_DOT, MARK_DOT)
    return true
end

local FADE_NEAR = 300

local function fade_near_camera(m)
    if not (OF.util.asks(OF.cheats, "rifle_is_aimed")
        and OF.cheats.rifle_is_aimed()) then
        return false
    end
    local eye = gLakituState
    if eye == nil or eye.pos == nil or m.marioBodyState == nil then
        return false
    end
    local dx = eye.pos.x - m.pos.x
    local dy = eye.pos.y - m.pos.y
    local dz = eye.pos.z - m.pos.z
    if dx * dx + dy * dy + dz * dz >= FADE_NEAR * FADE_NEAR then return false end
    m.marioBodyState.modelState =
        (m.marioBodyState.modelState or 0) | MODEL_STATE_NOISE_ALPHA
    return true
end

local FIRE_SLOW = 0.75

function shooter.shot_feedback(m)
    OF.gamemodes.round_sound(SOUND_OBJ_SNUFIT_SHOOT)
    OF.util.optional("set_camera_shake_from_point", nil,
        SHAKE_POS_BOWLING_BALL, m.pos.x, m.pos.y, m.pos.z)
end

function shooter.kit_controls(owner, fireWord)

    local here = OF.gamemodes.current() == owner and shooter.kit_here()
    local swapped = owner ~= nil and OF.input ~= nil and type(OF.input.SPACE_JUMP_MODES) == "table"
        and OF.input.SPACE_JUMP_MODES[owner.key] == true
    local list = { { "move", "Move" }, { swapped and "spacejump" or "jump", "Jump" }, { "aim", "Aim" },
        { "fire", fireWord or "Fire" } }
    if here and grenades_on() then list[#list + 1] = { "grenade", "Throw a grenade" } end
    if here and flash_nuts() then list[#list + 1] = { "flash", "Throw a flash nut" } end

    if owner == nil or owner.may_attack == nil then list[#list + 1] = { "attack", "Punch" } end
    return list
end

function mode.pauseControls()
    return shooter.kit_controls(mode)
end

function shooter.work_the_kit(m)

    if respawnPending then
        local group = OF.util.action_group(m.action)
        if group ~= OF.util.action_group(ACT_GROUP_CUTSCENE) then
            respawnPending = false
            m.invincTimer = PROTECT_FRAMES
        end
    end

    shooter.work_the_sprint(m)
    fade_near_camera(m)

    local fired = shooter.watch_the_bolt()
    if fired then

        shooter.shot_feedback(m)

        m.invincTimer = 0

        if OF.util.optional("mario_is_in_air_action", 0, m) == 0 then
            m.forwardVel = (m.forwardVel or 0) * FIRE_SLOW
        end
    end
    shooter.throw_flash(m)
    shooter.hear_the_grenades(m)

    shooter.work_the_fuse(m)
    return shooter.watch_the_air()
end

function mode.lobby_update()
    local m = gMarioStates[0]
    if m == nil then return end
    if shooter.watch_the_bolt() then shooter.shot_feedback(m) end
end

function mode.may_attack(attacker, victim)
    local _ = attacker
    local _v = victim
    return false
end

function mode.update()
    local m = gMarioStates[0]
    if m == nil then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if not OF.util.can_play(0) then return end

    shooter.work_the_kit(m)
end

function mode.host_update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    QUAD.host(now_frame())
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
    return #OF.gamemodes.with_role(ROLE_SHOOTING) >= 2
end

function mode.on_timeout()
    if OF.teams.in_play() then
        OF.gamemodes.finish(OF.teams.result_text(),
            OF.gamemodes.team_winner(OF.teams.leader()))
        return
    end
    local best, names = OF.gamemodes.best_of(
        OF.gamemodes.with_role(ROLE_SHOOTING),
        function(entry) return score_of(entry.localIndex) end)
    if best == nil or best <= 0 then
        OF.gamemodes.finish("Nobody landed a shot.")
    elseif #names > 1 then
        OF.gamemodes.finish("Time - a draw at @ kills.", nil, tostring(best))
    else
        OF.gamemodes.finish("@ won with @ kills.", names[1], names[1],
            tostring(best))
    end
end

function mode.terms()
    if OF.gamemodes.option_showing(mode.key, "nade") == "none" then
        return OF.lang.fill("first to @ kills - one shot, one kill, no grenades",
            tostring(target_kills()))
    end
    return OF.lang.fill("first to @ kills - one shot, one kill",
        tostring(target_kills()))
end

function shooter.kit_stop()

    shooter.drop_the_rifles()

    for at = #flying, 1, -1 do
        local nade = flying[at]
        if shooter.still_ours(nade, id_bhvBobomb, E_MODEL_BLACK_BOBOMB) then
            OF.util.optional("obj_mark_for_deletion", nil, nade)
        end
        flying[at] = nil
    end
    charging = nil
    grenadeReadyAt = -9999
    sprinting = false
    boltWas = 0
    lastKillWasMate = false
    respawnPending = false
    xWasDown = false
    nutCharging = nil
    yWasDown = false
end

function mode.cleanup()

    shooter.kit_stop()

    if OF.util.is_host() then
        OF.util.publish(TARGET_KEY, nil)
        OF.util.publish(SPAWN_KEY, nil)
        OF.util.publish(QUAD.key, nil)
    end
    QUAD.forget()

    OF.util.publish_row(0, SHOT_KEY, nil)
    return true
end

local BAR_WIDTH, BAR_HEIGHT = 120, 8
function shooter.draw_throw_bar()
    local share = shooter.charge_share()
    if share == nil then share = shooter.nut_share() end
    if share == nil then return false end
    local m = gMarioStates[0]
    if aiming(m) then return false end
    djui_hud_set_resolution(RESOLUTION_DJUI)
    local x = djui_hud_get_screen_width() * 0.5 - BAR_WIDTH * 0.5
    local y = djui_hud_get_screen_height() * 0.86
    OF.util.round_plate(x - 5, y - 5, BAR_WIDTH + 10, BAR_HEIGHT + 10)
    OF.util.meter(x, y, BAR_WIDTH, BAR_HEIGHT, share,
        OF.util.gold(), { r = 40, g = 40, b = 40 })
    return true
end

function shooter.kit_hud()
    shooter.draw_crosshair()
    shooter.draw_throw_bar()
end

function mode.hud()
    shooter.draw_crosshair()
    shooter.draw_throw_bar()

    local state = OF.util.asks(OF.hud, "state_line") and OF.hud.state_line or function() end
    if QUAD.mine() then
        state("quad", OF.lang.t("Quad"), { prio = 60, tone = "target",
            figure = math.ceil((QUAD.mineUntil - now_frame()) / 30) })
    elseif QUAD.on() then
        local line = QUAD.read(gGlobalSyncTable[QUAD.key])
        local seat = line and line.holder ~= -1 and seat_for(line.holder)
        if seat and seat.np then
            state("quad", OF.lang.fill("@ has quad", OF.util.shorten(OF.util.plain(seat.np.name), 10)),
                { prio = 50, tone = "warn" })
        end
    end
    if grenades_on() and shooter.grenade_cooldown() > 0 and shooter.charge_share() == nil then
        state("nade", OF.lang.t("No grenade"), { prio = 20, tone = "dim" })
    end
end

function shooter.alive_pips(side)
    local alive, total = 0, 0
    for _, entry in ipairs(OF.gamemodes.participants()) do
        if OF.teams.of(entry.localIndex) == side then
            total = total + 1
            local m = gMarioStates[entry.localIndex]
            if OF.util.can_play(entry.localIndex) and m ~= nil and (m.health or 0) > 0xFF then
                alive = alive + 1
            end
        end
    end
    return { alive = alive, total = total }
end

function shooter.with_pips(out)
    if out == nil then return nil end
    for _, side in ipairs({ out.left, out.right }) do
        if side ~= nil and (side.key == "red" or side.key == "blue") then
            side.pips = shooter.alive_pips(side.key)
        end
    end
    return out
end

function mode.cluster()
    return shooter.with_pips(OF.gamemodes.side_cluster(function(key) return OF.teams.score(key) end,
        target_kills()))
end

shooter.KIT_ROWS = KIT_ROWS
shooter.bolt_stop = bolt_stop
function shooter.lend_kit(other)
    if type(other) ~= "table" or other == mode then return end
    other.maps = "surveyed"
    other.surveyKeys = mode.surveyKeys
    other.surveyOut = mode.surveyOut
    other.cheatsGiven = other.cheatsGiven or {}
    other.cheatsGiven.sniper = bolt_stop
    other.options = other.options or {}
    for _, row in ipairs(other.options) do
        if row == KIT_ROWS[1] then return end
    end
    for n = #KIT_ROWS, 1, -1 do table.insert(other.options, 1, KIT_ROWS[n]) end
end

OF.shooter = shooter
if OF.gamemodes.BY_KEY ~= nil then
    for _, other in pairs(OF.gamemodes.BY_KEY) do
        if type(other) == "table" and other.kitFrom == "shooter" then shooter.lend_kit(other) end
    end
end

mode.target_now = target_kills

OF.gamemodes.register(mode)
