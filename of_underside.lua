OF = OF or {}
OF.underside = OF.underside or {}

local underside = OF.underside

local HITBOX = 160.0

local GROUND_LOWER_OFFSET, GROUND_LOWER_RADIUS = 30.0, 24.0
local GROUND_UPPER_OFFSET, GROUND_UPPER_RADIUS = 60.0, 50.0
local AIR_UPPER_OFFSET, AIR_UPPER_RADIUS = 150.0, 50.0
local AIR_LOWER_OFFSET, AIR_LOWER_RADIUS = 30.0, 50.0

local LEFT_GROUND_AT = 100.0

local CEIL_BUFFER = 80.0

local GROUND_WALL_LOW, GROUND_WALL_HIGH = 0x2AAA, 0x5555
local AIR_WALL_BONK = 0x6000

local FALL_PER_FRAME = 4.0
local TERMINAL = -75.0

local HALF_TURN = 0x8000

local QUARTER_TURN = 0x4000

underside.QUARTERS = 4
underside.QUERIES_PER_QUARTER = 4

local function is_mine(m)
    return m ~= nil and m.playerIndex == 0
end

local function hitbox_of(m)
    local obj = m ~= nil and m.marioObj or nil
    local height = obj ~= nil and obj.hitboxHeight or nil
    if type(height) ~= "number" or height <= 0 then return HITBOX end
    return height
end

local carryGroups = nil
local releaseGroups = nil
local swaps = nil

local function build_verdicts()
    carryGroups, releaseGroups, swaps = {}, {}, {}

    local function carry(group)
        if group ~= nil then carryGroups[OF.util.action_group(group)] = true end
    end
    local function release(group)
        if group ~= nil then releaseGroups[OF.util.action_group(group)] = true end
    end

    carry(ACT_GROUP_STATIONARY)
    carry(ACT_GROUP_MOVING)
    carry(ACT_GROUP_AIRBORNE)
    carry(ACT_GROUP_OBJECT)

    release(ACT_GROUP_SUBMERGED)
    release(ACT_GROUP_AUTOMATIC)
    release(ACT_GROUP_CUTSCENE)

    local function swap(action, instead)
        if action == nil or instead == nil then return end
        swaps[action] = instead
    end

    swap(ACT_BUTT_SLIDE, ACT_BRAKING)
    swap(ACT_HOLD_BUTT_SLIDE, ACT_BRAKING)
    swap(ACT_CROUCH_SLIDE, ACT_BRAKING)
    swap(ACT_STOMACH_SLIDE, ACT_BRAKING)
    swap(ACT_HOLD_STOMACH_SLIDE, ACT_BRAKING)
    swap(ACT_DIVE_SLIDE, ACT_BRAKING)
end

function underside.forget_verdicts()
    carryGroups, releaseGroups, swaps = nil, nil, nil
end

function underside.verdict(action)
    if type(action) ~= "number" then return "release" end
    if carryGroups == nil then build_verdicts() end
    if swaps[action] ~= nil then return "swap" end
    local group = OF.util.action_group(action)
    if releaseGroups[group] == true then return "release" end
    if carryGroups[group] == true then return "carry" end
    return "release"
end

function underside.swap_for(action)
    if type(action) ~= "number" then return nil end
    if swaps == nil then build_verdicts() end
    return swaps[action]
end

function underside.stand_is_on(m)
    if not is_mine(m) then return false end
    if not OF.util.asks(OF.warp, "direction") then return false end
    local dir = OF.warp.direction()
    if dir == nil or dir.up ~= true then return false end

    if OF.util.asks(OF.warp, "fall_is_owned") and OF.warp.fall_is_owned() then
        return false
    end
    return true
end

function underside.claims(m)
    if not underside.stand_is_on(m) then return false end
    if type(m.action) ~= "number" then return false end

    if OF.util.has_flag(m.action, ACT_FLAG_INTANGIBLE) then return false end
    return underside.verdict(m.action) == "carry"
end

local roofed = false

function underside.roofed()
    return roofed
end

function underside.forget_roof()
    roofed = false
end

function underside.held(m)
    if not underside.claims(m) then return false end
    return roofed
end

local queries = 0

function underside.queries()
    return queries
end

function underside.forget_queries()
    queries = 0
end

function underside.world_at(x, y, z)
    queries = queries + 2
    local supportHeight, support = find_ceil(x, y, z)
    local headHeight, head = find_floor(x, supportHeight - CEIL_BUFFER, z)
    return supportHeight, support, headHeight, head
end

function underside.foot_of(supportHeight, hitbox)
    return supportHeight - hitbox
end

function underside.floor_angle(surface)
    if surface == nil or surface.normal == nil then return 0 end
    local angle = atan2s(surface.normal.z, surface.normal.x) + HALF_TURN
    angle = math.floor(angle) % 0x10000
    if angle >= 0x8000 then angle = angle - 0x10000 end
    return angle
end

function underside.step_scale(surface)
    if surface == nil or surface.normal == nil then return 1.0 end
    local ny = surface.normal.y
    if type(ny) ~= "number" then return 1.0 end
    return math.abs(ny)
end

local standing = nil

function underside.standing()
    return standing
end

function underside.forget_standing()
    standing = nil
end

function underside.plant(m, support, foot)
    if m == nil or support == nil then return false end
    standing = support

    m.floor = support
    m.terrainSoundAddend = mario_get_terrain_sound_addend(m)
    local flat = OF.util.optional("get_water_surface_pseudo_floor", nil)
    if flat == nil then

        return false
    end
    m.floor = flat
    m.floorHeight = foot
    return true
end

function underside.geometry_frame(m)

    if not underside.claims(m) then return end
    local pos = m.pos
    if pos == nil or type(pos.y) ~= "number" then
        roofed = false
        return
    end

    local hitbox = hitbox_of(m)
    local supportHeight, support, headHeight, head =
        underside.world_at(pos.x, pos.y, pos.z)

    if support == nil then
        roofed = false
        return
    end
    roofed = true

    local foot = underside.foot_of(supportHeight, hitbox)

    if not underside.plant(m, support, foot) then
        roofed = false
        return
    end
    m.floorAngle = underside.floor_angle(support)

    m.ceil = head
    m.ceilHeight = foot + (supportHeight - headHeight)

    if type(m.input) == "number" then

        if INPUT_OFF_FLOOR ~= nil and foot - pos.y > LEFT_GROUND_AT
            and not OF.util.has_flag(m.input, INPUT_OFF_FLOOR) then
            m.input = m.input + INPUT_OFF_FLOOR
        end

        if INPUT_SQUISHED ~= nil and SURFACE_FLAG_DYNAMIC ~= nil
            and OF.util.has_flag(support.flags or 0, SURFACE_FLAG_DYNAMIC) then
            local gap = supportHeight - headHeight
            if gap >= 0.0 and gap <= 150.0
                and not OF.util.has_flag(m.input, INPUT_SQUISHED) then
                m.input = m.input + INPUT_SQUISHED
            end
        end
    end

    m.waterLevel = find_water_level(pos.x, pos.z)

    return false
end

function underside.jump_is_cut(m)
    if MARIO_UNKNOWN_08 == nil then return false end
    if not OF.util.has_flag(m.flags, MARIO_UNKNOWN_08) then return false end
    if OF.util.has_flag(m.action, ACT_FLAG_INTANGIBLE)
        or OF.util.has_flag(m.action, ACT_FLAG_INVULNERABLE) then
        return false
    end
    if OF.util.has_flag(m.input, INPUT_A_DOWN) then return false end
    local vel = m.vel
    if vel == nil or type(vel.y) ~= "number" or vel.y <= 20.0 then return false end
    return OF.util.has_flag(m.action, ACT_FLAG_CONTROL_JUMP_HEIGHT)
end

function underside.is_fluttering(m)
    if MARIO_WING_CAP == nil then return false end
    if not OF.util.has_flag(m.flags, MARIO_WING_CAP) then return false end
    local vel = m.vel
    if vel == nil or type(vel.y) ~= "number" or vel.y >= 0.0 then return false end
    return OF.util.has_flag(m.input, INPUT_A_DOWN)
end

function underside.gravity_frame(m)
    local vel = m.vel
    if vel == nil or type(vel.y) ~= "number" then return end
    local action = m.action
    if type(action) ~= "number" then return end

    if ACT_TWIRLING ~= nil and action == ACT_TWIRLING and vel.y < 0.0 then
        local heaviness = 1.0
        local spin = m.angleVel ~= nil and m.angleVel.y or nil
        if type(spin) == "number" and spin > 1024 then heaviness = 1024.0 / spin end
        vel.y = vel.y - FALL_PER_FRAME * heaviness
        local bottom = TERMINAL * heaviness
        if vel.y < bottom then vel.y = bottom end
        return
    end

    local pull, bottom = FALL_PER_FRAME, TERMINAL

    if ACT_SHOT_FROM_CANNON ~= nil and action == ACT_SHOT_FROM_CANNON then
        pull = 1.0
    elseif (ACT_LONG_JUMP ~= nil and action == ACT_LONG_JUMP)
        or (ACT_SLIDE_KICK ~= nil and action == ACT_SLIDE_KICK)
        or (ACT_BBH_ENTER_SPIN ~= nil and action == ACT_BBH_ENTER_SPIN) then
        pull = 2.0
    elseif (ACT_LAVA_BOOST ~= nil and action == ACT_LAVA_BOOST)
        or (ACT_FALL_AFTER_STAR_GRAB ~= nil and action == ACT_FALL_AFTER_STAR_GRAB) then
        pull, bottom = 3.2, -65.0
    elseif ACT_GETTING_BLOWN ~= nil and action == ACT_GETTING_BLOWN then
        pull = type(m.unkC4) == "number" and m.unkC4 or FALL_PER_FRAME
    elseif underside.jump_is_cut(m) then

        vel.y = vel.y / 4.0
        return
    elseif OF.util.has_flag(action, ACT_FLAG_METAL_WATER) then
        pull, bottom = 1.6, -16.0
    elseif underside.is_fluttering(m) then

        local body = m.marioBodyState
        if body ~= nil then body.wingFlutter = true end
        vel.y = vel.y - 2.0
        if vel.y < -37.5 then
            vel.y = vel.y + 4.0
            if vel.y > -37.5 then vel.y = -37.5 end
        end
        return
    end

    vel.y = vel.y - pull
    if vel.y < bottom then vel.y = bottom end
end

local function push_off_walls(spot, offset, radius, hitbox)
    queries = queries + 1
    local found = {}

    local wcd = collision_get_temp_wall_collision_data()
    if wcd == nil then

        local wall = resolve_and_return_wall_collisions(spot, hitbox - offset, radius)
        if wall ~= nil then found[1] = wall end
        return found
    end

    resolve_and_return_wall_collisions_data(spot, hitbox - offset, radius, wcd)

    local count = wcd.numWalls or 0
    for index = 0, math.min(count, 4) - 1 do
        local wall = get_surface_from_wcd_index(wcd, index)
        if wall ~= nil then found[#found + 1] = wall end
    end
    return found
end

local function pick_wall(walls, m)
    local count = #walls
    if count == 0 then return nil end

    if gLevelValues == nil then return walls[count] end
    if OF.util.flag(gLevelValues.fixCollisionBugs) == 0
        or OF.util.flag(gLevelValues.fixCollisionBugsPickBestWall) == 0 then
        return walls[count]
    end

    local pitch = m.faceAngle ~= nil and m.faceAngle.x or 0
    local yaw = m.faceAngle ~= nil and m.faceAngle.y or 0
    local fx, fy, fz = coss(pitch) * sins(yaw), sins(pitch), coss(pitch) * coss(yaw)

    local chosen = walls[1]
    for index = 2, count do
        local here = walls[index]
        if chosen == nil then
            chosen = here
        elseif here ~= nil and chosen.normal ~= nil and here.normal ~= nil then
            local a, b = chosen.normal, here.normal
            if a.x * fx + a.y * fy + a.z * fz > b.x * fx + b.y * fy + b.z * fz then
                chosen = here
            end
        end
    end
    return chosen
end

local function walls_to_read(walls)

    if gLevelValues ~= nil
        and OF.util.flag(gLevelValues.fixCollisionBugs) == 1 then
        return walls
    end
    if #walls == 0 then return walls end
    return { walls[#walls] }
end

local function wall_dyaw(wall, facing)
    if wall == nil or wall.normal == nil then return nil end
    local dyaw = atan2s(wall.normal.z, wall.normal.x) - facing
    dyaw = math.floor(dyaw) % 0x10000
    if dyaw >= 0x8000 then dyaw = dyaw - 0x10000 end
    return dyaw
end

local function ground_wall_stops(wall, facing)
    local dyaw = wall_dyaw(wall, facing)
    if dyaw == nil then return false end
    if dyaw >= GROUND_WALL_LOW and dyaw <= GROUND_WALL_HIGH then return false end
    if dyaw <= -GROUND_WALL_LOW and dyaw >= -GROUND_WALL_HIGH then return false end
    return true
end

local function air_wall_bonks(wall, facing)
    local dyaw = wall_dyaw(wall, facing)
    if dyaw == nil then return false end
    return dyaw < -AIR_WALL_BONK or dyaw > AIR_WALL_BONK
end

function underside.ground_quarter(m, spot, hitbox)
    push_off_walls(spot, GROUND_LOWER_OFFSET, GROUND_LOWER_RADIUS, hitbox)
    local upper = push_off_walls(spot, GROUND_UPPER_OFFSET, GROUND_UPPER_RADIUS, hitbox)

    local supportHeight, support, headHeight = underside.world_at(spot.x, spot.y, spot.z)

    if support == nil then
        m.pos.x, m.pos.y, m.pos.z = spot.x, spot.y, spot.z
        return GROUND_STEP_LEFT_GROUND
    end

    local foot = underside.foot_of(supportHeight, hitbox)

    if foot - spot.y > LEFT_GROUND_AT then

        if spot.y <= headHeight then return GROUND_STEP_HIT_WALL_STOP_QSTEPS end
        m.pos.x, m.pos.y, m.pos.z = spot.x, spot.y, spot.z
        underside.plant(m, support, foot)
        return GROUND_STEP_LEFT_GROUND
    end

    if foot <= headHeight then return GROUND_STEP_HIT_WALL_STOP_QSTEPS end

    m.pos.x, m.pos.y, m.pos.z = spot.x, foot, spot.z
    underside.plant(m, support, foot)

    if #upper > 0 then
        m.wall = pick_wall(upper, m)
        local facing = m.faceAngle ~= nil and m.faceAngle.y or 0
        for _, wall in ipairs(walls_to_read(upper)) do
            if ground_wall_stops(wall, facing) then
                return GROUND_STEP_HIT_WALL_CONTINUE_QSTEPS
            end
        end
    end
    return GROUND_STEP_NONE
end

function underside.air_quarter(m, spot, stepArg, hitbox)
    local upper = push_off_walls(spot, AIR_UPPER_OFFSET, AIR_UPPER_RADIUS, hitbox)
    local lower = push_off_walls(spot, AIR_LOWER_OFFSET, AIR_LOWER_RADIUS, hitbox)

    local supportHeight, support, headHeight, head =
        underside.world_at(spot.x, spot.y, spot.z)

    m.wall = nil

    local vel = m.vel
    local pos = m.pos

    if support == nil then
        pos.x, pos.y, pos.z = spot.x, spot.y, spot.z
        if head == nil then return AIR_STEP_HIT_WALL end
        return AIR_STEP_NONE
    end

    local foot = underside.foot_of(supportHeight, hitbox)

    if spot.y >= foot then
        if supportHeight - headHeight > hitbox then
            pos.x, pos.z = spot.x, spot.z
            underside.plant(m, support, foot)
        end
        pos.y = foot
        return AIR_STEP_LANDED
    end

    if spot.y <= headHeight then
        if vel.y >= 0.0 then
            vel.y = 0.0
            return AIR_STEP_NONE
        end
        if type(m.floorHeight) == "number" and spot.y >= m.floorHeight then
            pos.y = m.floorHeight
            return AIR_STEP_LANDED
        end
        pos.y = spot.y
        return AIR_STEP_HIT_WALL
    end

    pos.x, pos.y, pos.z = spot.x, spot.y, spot.z
    underside.plant(m, support, foot)

    local touched = (#upper > 0) and upper or lower
    if #touched > 0 then
        m.wall = pick_wall(touched, m)
        local facing = m.faceAngle ~= nil and m.faceAngle.y or 0
        for _, wall in ipairs(walls_to_read(touched)) do
            if SURFACE_BURNING ~= nil and wall.type == SURFACE_BURNING then
                m.wall = wall
                return AIR_STEP_HIT_LAVA_WALL
            end
            if air_wall_bonks(wall, facing) then
                m.wall = wall
                if MARIO_UNKNOWN_30 ~= nil
                    and not OF.util.has_flag(m.flags, MARIO_UNKNOWN_30) then
                    m.flags = m.flags + MARIO_UNKNOWN_30
                end
                return AIR_STEP_HIT_WALL
            end
        end
    end

    return AIR_STEP_NONE
end

local function hand_to_graphics(m)
    local obj = m.marioObj
    if obj == nil or obj.header == nil or obj.header.gfx == nil then return end
    local gfx = obj.header.gfx
    gfx.pos.x, gfx.pos.y, gfx.pos.z = m.pos.x, m.pos.y, m.pos.z
    gfx.angle.x = 0
    gfx.angle.y = m.faceAngle ~= nil and m.faceAngle.y or 0
    gfx.angle.z = 0
end

function underside.ground_step(m)
    local hitbox = hitbox_of(m)
    local result = GROUND_STEP_NONE
    local spot = { x = 0, y = 0, z = 0 }

    for _ = 1, underside.QUARTERS do

        local scale = underside.step_scale(underside.standing())

        spot.x = m.pos.x + scale * (m.vel.x / 4.0)
        spot.y = m.pos.y
        spot.z = m.pos.z + scale * (m.vel.z / 4.0)

        result = underside.ground_quarter(m, spot, hitbox)

        if result == GROUND_STEP_LEFT_GROUND
            or result == GROUND_STEP_HIT_WALL_STOP_QSTEPS then
            break
        end
    end

    m.terrainSoundAddend = mario_get_terrain_sound_addend(m)
    hand_to_graphics(m)

    if result == GROUND_STEP_HIT_WALL_CONTINUE_QSTEPS then
        result = GROUND_STEP_HIT_WALL
    end
    return result
end

local apexY = nil

function underside.forget_apex()
    apexY = nil
end

function underside.apex()
    return apexY
end

function underside.air_step(m, stepArg)
    local hitbox = hitbox_of(m)
    local result = AIR_STEP_NONE
    local spot = { x = 0, y = 0, z = 0 }

    m.wall = nil

    for _ = 1, underside.QUARTERS do

        spot.x = m.pos.x + m.vel.x / 4.0
        spot.y = m.pos.y - m.vel.y / 4.0
        spot.z = m.pos.z + m.vel.z / 4.0

        local quarter = underside.air_quarter(m, spot, stepArg, hitbox)

        if quarter ~= AIR_STEP_NONE then result = quarter end

        if quarter == AIR_STEP_LANDED or quarter == AIR_STEP_HIT_LAVA_WALL then
            break
        end
    end

    if apexY == nil or m.pos.y < apexY then apexY = m.pos.y end
    if m.vel.y >= 0.0 then apexY = m.pos.y end
    m.peakHeight = m.pos.y + (m.pos.y - apexY)

    m.terrainSoundAddend = mario_get_terrain_sound_addend(m)

    if m.action ~= ACT_FLYING and m.action ~= ACT_BUBBLED then
        underside.gravity_frame(m)
    end

    hand_to_graphics(m)
    return result
end

function underside.step_frame(m, stepType, stepArg)
    if not underside.held(m) then return nil end
    if stepType == STEP_TYPE_GROUND then
        apexY = m.pos.y
        return underside.ground_step(m)
    end
    if stepType == STEP_TYPE_AIR then return underside.air_step(m, stepArg) end

    return nil
end

function underside.swap_frame(m)
    if not underside.stand_is_on(m) then return end

    if not roofed then return end
    if type(m.action) ~= "number" then return end
    if OF.util.has_flag(m.action, ACT_FLAG_INTANGIBLE) then return end
    local instead = underside.swap_for(m.action)
    if instead == nil then return end
    set_mario_action(m, instead, 0)
end

function underside.stick_frame(m)
    if not is_mine(m) then return end
    if OF.util.menu_has_screen() then return end

    if not OF.util.asks(OF.warp, "tilt") then return end
    local roll = OF.warp.tilt()
    if type(roll) ~= "number" then return end
    if roll > -QUARTER_TURN and roll < QUARTER_TURN then return end
    local controller = m.controller
    if controller == nil then return end
    local x = controller.stickX
    if type(x) ~= "number" then return end
    controller.stickX = -x
end

hook_event(HOOK_MARIO_OVERRIDE_GEOMETRY_INPUTS, function(m)
    return underside.geometry_frame(m)
end)

hook_event(HOOK_BEFORE_PHYS_STEP, function(m, stepType, stepArg)
    return underside.step_frame(m, stepType, stepArg)
end)

hook_event(HOOK_BEFORE_MARIO_UPDATE, function(m)
    underside.swap_frame(m)
    underside.stick_frame(m)
end)

hook_event(HOOK_ON_LEVEL_INIT, function()
    underside.forget_apex()
    underside.forget_queries()

    underside.forget_standing()

    underside.forget_roof()
end)
