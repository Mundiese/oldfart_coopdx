OF = OF or {}
OF.spray = OF.spray or {}

local spray = OF.spray

spray.KEY = "spray"
spray.MODEL_RADIUS = 50

spray.PATTERNS = {
    { key = "heart", geo = "of_spray_heart_geo", name = "Heart" },
    { key = "star", geo = "of_spray_star_geo", name = "Star" },
    { key = "smiley", geo = "of_spray_smiley_geo", name = "Smiley" },
    { key = "bolt", geo = "of_spray_bolt_geo", name = "Lightning" },
    { key = "crown", geo = "of_spray_crown_geo", name = "Crown" },
    { key = "flame", geo = "of_spray_flame_geo", name = "Flame" },
    { key = "arrow", geo = "of_spray_arrow_geo", name = "Arrow" },
    { key = "note", geo = "of_spray_note_geo", name = "Music note" },
    { key = "exclaim", geo = "of_spray_exclaim_geo", name = "Exclamation" },
    { key = "question", geo = "of_spray_question_geo", name = "Question mark" },
    { key = "check", geo = "of_spray_check_geo", name = "Check" },
    { key = "target", geo = "of_spray_target_geo", name = "Target" },
}

spray.SIZE = 120

spray.LIFT = 3

spray.REACH = 700

spray.WALL_REACH = 300

spray.WALL_FROM = 80

spray.LOBBY_MAX = 64
spray.SLOTS = 80

spray.GAP = 40

spray.FADE = 20

spray.ALPHA = 230

spray.HOST_REACH = 1600

spray.MARK = 0x53505200

spray.ASK = "spray_ask"
spray.ADD = "spray_add"
spray.DROP = "spray_drop"
spray.CLEAR = "spray_clear"
spray.CLEAR_ACTION = "sprayclear"
spray.WIPE_ACTION = "spraywipe"
spray.CLEAR_RANK = "spray_clear"
spray.OPTS_KEY = "ofSprayOpts"
spray.OPTS_ACTION = "sprayopt"
spray.OPTS = {
    { key = "each", name = "How many each", start = 2,
      help = "how many marks one player may have up at once",
      steps = { "four", "eight", "twelve" }, counts = { 4, 8, 12 } },
    { key = "last", name = "How long they last", start = 1,
      help = "when a mark fades by itself",
      steps = { "until pushed out", "five minutes", "one minute" },
      frames = { false, 30 * 300, 30 * 60 } },
}

spray.PATTERN_STORE = "sprayTag"
spray.BUTTON_STORE = "sprayKey"
spray.BUTTONS = {
    { name = "D-pad left", button = L_JPAD or 0x0200,
      glyph = { pad = "DPAD", padText = "<", key = "Del" } },
    { name = "X", button = X_BUTTON or 0x0040, glyph = { pad = "X", key = "I" } },
    { name = "Y", button = Y_BUTTON or 0x0080, glyph = { pad = "Y", key = "M" } },
    { name = "D-pad right", button = R_JPAD or 0x0100,
      glyph = { pad = "DPAD", padText = ">", key = "PgDn" } },
}

local SEATS = MAX_PLAYERS or 16

function spray.opt(key)
    local text = gGlobalSyncTable[spray.OPTS_KEY]
    if type(text) ~= "string" then text = "" end
    for index, row in ipairs(spray.OPTS) do
        if row.key == key then
            local step = tonumber(string.sub(text, index, index)) or row.start or 1
            if step < 1 or step > #row.steps then step = row.start or 1 end
            return step
        end
    end
    return 1
end

local function opt_rank()
    return OF.modifiers ~= nil and OF.modifiers.ROW_RANK or "speedrun"
end

function spray.set_opt(key, step, askerLocal)
    if askerLocal == nil and not OF.perms.can(opt_rank()) then
        return false, "Your rank cannot do that."
    end
    if not OF.util.is_host() then
        if OF.util.asks(OF.net, "host_does") then
            return OF.net.host_does(spray.OPTS_ACTION, tonumber(step), nil, tostring(key))
        end
        return false, "No host to ask yet - try again in a second."
    end
    local digits, found = {}, false
    for index, row in ipairs(spray.OPTS) do
        local now = spray.opt(row.key)
        if row.key == key then
            now = math.floor(tonumber(step) or row.start or 1)
            if now < 1 or now > #row.steps then now = row.start or 1 end
            found = true
        end
        digits[index] = tostring(now)
    end
    if not found then return false, "No such setting." end
    OF.util.publish(spray.OPTS_KEY, table.concat(digits))
    return true
end

function spray.each()
    local row = spray.OPTS[1]
    return math.min(row.counts[spray.opt("each")] or 8, spray.LOBBY_MAX)
end

function spray.lasts()
    local row = spray.OPTS[2]
    return row.frames[spray.opt("last")] or false
end

function spray.reset_mine()
    local moved = false
    for slot = 1, spray.WHEEL_SLOTS do
        if spray.wheel_pattern(slot) ~= slot then
            moved = spray.set_wheel_pattern(slot, slot) or moved
        end
    end
    if spray.my_pattern() ~= 1 then
        moved = (spray.set_pattern(1) ~= false) or moved
    end
    return moved
end

function spray.my_pattern()
    local n = OF.util.stored_integer(spray.PATTERN_STORE, 1) or 1
    if n < 1 or n > #spray.PATTERNS then n = 1 end
    return n
end

function spray.set_pattern(n)
    n = math.floor(tonumber(n) or 1)
    if n < 1 or n > #spray.PATTERNS then n = 1 end
    OF.util.store_integer(spray.PATTERN_STORE, n)

    spray.lastPattern = nil
    return true
end

spray.WHEEL_SLOTS = 8
spray.WHEEL_STORE = "sprayTagWheel"
spray.HOLD_FRAMES = 8
spray.WHEEL_OPEN_FRAMES = 6
spray.lastPattern = nil
spray.wheel = { tracking = false, held = 0, open = false, choice = nil, phase = 0, lit = {} }

function spray.wheel_pattern(slot)
    local n = OF.util.stored_integer(spray.WHEEL_STORE .. tostring(slot), slot) or slot
    if n < 1 or n > #spray.PATTERNS then n = ((slot - 1) % #spray.PATTERNS) + 1 end
    return n
end

function spray.set_wheel_pattern(slot, n)
    slot = math.floor(tonumber(slot) or 0)
    if slot < 1 or slot > spray.WHEEL_SLOTS then return false end
    n = math.floor(tonumber(n) or 1)
    if n < 1 or n > #spray.PATTERNS then n = 1 end
    OF.util.store_integer(spray.WHEEL_STORE .. tostring(slot), n)
    return true
end

function spray.tap_pattern()
    local n = spray.lastPattern
    if type(n) == "number" and n >= 1 and n <= #spray.PATTERNS then return n end
    return spray.my_pattern()
end

spray.STICK_DEAD = 30
function spray.sector(stickX, stickY)
    local x, y = stickX or 0, stickY or 0
    if (x * x + y * y) < (spray.STICK_DEAD * spray.STICK_DEAD) then return nil end
    local slice = 2 * math.pi / spray.WHEEL_SLOTS
    local index = math.floor((math.atan(x, y) + slice / 2) / slice) % spray.WHEEL_SLOTS
    return index + 1
end

function spray.close_wheel()
    local w = spray.wheel
    w.tracking, w.held, w.open, w.choice, w.phase = false, 0, false, nil, 0
end

function spray.step_wheel_ramps()
    local w = spray.wheel
    if w.open then
        if w.phase < spray.WHEEL_OPEN_FRAMES then w.phase = w.phase + 1 end
    elseif w.phase > 0 then
        w.phase = w.phase - 1
    end
    for slot = 1, spray.WHEEL_SLOTS do
        local at = w.lit[slot] or 0
        if w.choice == slot and w.open then at = math.min(4, at + 1) else at = math.max(0, at - 1) end
        w.lit[slot] = at
    end
end

function spray.my_button_index()
    local n = OF.util.stored_integer(spray.BUTTON_STORE, 1) or 1
    if n < 1 or n > #spray.BUTTONS then n = 1 end
    return n
end

function spray.set_button(n)
    n = math.floor(tonumber(n) or 1)
    if n < 1 or n > #spray.BUTTONS then n = 1 end
    OF.util.store_integer(spray.BUTTON_STORE, n)
    return true
end

function spray.button_taken(index)
    local entry = spray.BUTTONS[index or spray.my_button_index()]
    if entry == nil then return nil end
    if entry.name == "X" and OF.util.asks(OF.moves, "stop") then
        local stop = OF.moves.stop("dash")
        if stop ~= nil and stop.speed ~= nil then return "the air dash" end
    end
    if entry.name == "Y" and OF.util.asks(OF.ragdoll, "switched_on")
        and OF.ragdoll.switched_on() then
        return "the ragdoll"
    end
    return nil
end

function spray.may_spray()
    local modifiers = OF.modifiers
    if modifiers == nil or type(modifiers.in_force) ~= "function" then
        return false, "Spray paint is not loaded.", true
    end
    if (modifiers.in_force(spray.KEY) or 0) <= 0 then
        if OF.util.asks(OF.roundscope, "inside") and OF.roundscope.inside(0) then
            return false, "Not while a round has you.", true
        end
        return false, "Spray paint is off for you.", true
    end
    if OF.util.asks(OF.roundscope, "inside") and OF.roundscope.inside(0) then
        return false, "Not while a round has you.", true
    end
    if OF.util.asks(OF.spectate, "is_spectating") and OF.spectate.is_spectating(0) then
        return false, "Not while you are watching.", true
    end
    if not OF.perms.can("spray") then
        return false, "Your rank cannot spray."
    end
    return true
end

local function to_angle(radians)
    return math.floor(radians * 32768 / math.pi + 0.5)
end

function spray.angles(nx, ny, nz, facing)
    local h = math.sqrt(nx * nx + nz * nz)
    if h < 0.05 then
        local yaw = ((facing or 0) + 0x8000) % 0x10000
        if ny < 0 then return 0x8000, yaw end
        return 0, yaw
    end
    return to_angle(math.atan(h, ny)), to_angle(math.atan(nx, nz)) % 0x10000
end

function spray.is_wall(hit)
    if hit == nil or hit.surface == nil or hit.hitPos == nil then return false end
    local n = hit.surface.normal
    if n == nil or hit.surface.object ~= nil then return false end
    return math.abs(n.y or 0) < 0.5
end

function spray.wall_ahead(m)
    if m == nil or m.pos == nil or m.faceAngle == nil then return nil end
    local yaw = (m.faceAngle.y or 0) * math.pi / 32768
    local fx, fz = math.sin(yaw), math.cos(yaw)
    local hit = OF.util.optional("collision_find_surface_on_ray", nil,
        m.pos.x, m.pos.y + spray.WALL_FROM, m.pos.z,
        fx * spray.WALL_REACH, 0, fz * spray.WALL_REACH)
    if not spray.is_wall(hit) then return nil end
    return hit
end

function spray.aim(m)
    m = m or gMarioStates[0]
    if m == nil or m.pos == nil then return nil, "Nothing to spray from here." end
    local eye = gLakituState
    if eye == nil or eye.pos == nil or eye.focus == nil then
        return nil, "There is no camera to aim along."
    end
    local dx = eye.focus.x - eye.pos.x
    local dy = eye.focus.y - eye.pos.y
    local dz = eye.focus.z - eye.pos.z
    local length = math.sqrt(dx * dx + dy * dy + dz * dz)
    if length < 1 then return nil, "There is no camera to aim along." end
    dx, dy, dz = dx / length, dy / length, dz / length

    local ex, ey, ez = eye.pos.x - m.pos.x, eye.pos.y - m.pos.y, eye.pos.z - m.pos.z
    local far = math.sqrt(ex * ex + ey * ey + ez * ez) + spray.REACH
    local hit = OF.util.optional("collision_find_surface_on_ray", nil,
        eye.pos.x, eye.pos.y, eye.pos.z, dx * far, dy * far, dz * far)

    if not spray.is_wall(hit) then
        local ahead = spray.wall_ahead(m)
        if ahead ~= nil then hit = ahead end
    end
    if hit == nil or hit.surface == nil or hit.hitPos == nil then
        return nil, "Nothing in reach to spray on."
    end
    local hx, hy, hz = hit.hitPos.x, hit.hitPos.y, hit.hitPos.z
    local surface = hit.surface
    local n = surface.normal
    if n == nil then return nil, "Nothing in reach to spray on." end
    local nx, ny, nz = n.x or 0, n.y or 0, n.z or 0

    if surface.object ~= nil then
        return nil, "Sprays stick to the level itself, not to things that move."
    end
    local gx, gy, gz = hx - m.pos.x, hy - m.pos.y, hz - m.pos.z
    if gx * gx + gy * gy + gz * gz > spray.REACH * spray.REACH then
        return nil, "That is out of reach."
    end
    local pitch, yaw = spray.angles(nx, ny, nz, m.faceAngle ~= nil and m.faceAngle.y or 0)
    return {
        x = hx + nx * spray.LIFT, y = hy + ny * spray.LIFT, z = hz + nz * spray.LIFT,
        p = pitch, yw = yaw,
    }
end

local records = {}
local nextId = 1

local sprayedAt = -9999
local hostSprayedAt = {}

local slotUsed = {}

function spray.records()
    return records
end

function spray.count(ownerGlobal)
    local n = 0
    for _, rec in ipairs(records) do
        if rec.fading == nil and (ownerGlobal == nil or rec.o == ownerGlobal) then
            n = n + 1
        end
    end
    return n
end

local function now_frame()
    return OF.util.optional("get_global_timer", 0) or 0
end

function spray.room_key(level, area, act, world)
    return tostring(level) .. "/" .. tostring(area) .. "/" .. tostring(act)
        .. "/" .. tostring(world or "-")
end

function spray.world_code()
    if OF.util.asks(OF.warp, "code") then
        local code = OF.warp.code()
        if type(code) == "string" and code ~= "" then return code end
    end
    return "-"
end

function spray.here()
    local np = gNetworkPlayers[0]
    if np == nil then return nil end
    return spray.room_key(np.currLevelNum, np.currAreaIndex, np.currActNum,
        spray.world_code())
end

local function find(id)
    for index, rec in ipairs(records) do
        if rec.id == id then return rec, index end
    end
    return nil
end

local function free_slot()
    for slot = 0, spray.SLOTS - 1 do
        if not slotUsed[slot] then return slot end
    end
    return nil
end

local function delete_object(rec)
    local o = rec.obj
    rec.obj = nil
    if o ~= nil and o.activeFlags ~= 0 and o.oBehParams == spray.MARK + (rec.slot or -1) then
        OF.util.optional("obj_mark_for_deletion", nil, o)
    end
end

local function forget(rec, index)
    delete_object(rec)
    if rec.slot ~= nil then slotUsed[rec.slot] = nil end
    table.remove(records, index)
end

function spray.apply_add(rec, quiet)
    if type(rec) ~= "table" or tonumber(rec.id) == nil then return false end
    if find(rec.id) ~= nil then return false end
    local slot = free_slot()
    if slot == nil then

        local oldest = records[1]
        if oldest == nil then return false end
        slot = oldest.slot
        forget(oldest, 1)
    end
    rec.slot = slot
    slotUsed[slot] = true
    rec.shown = quiet and spray.FADE or 0
    rec.fading = nil
    table.insert(records, rec)
    nextId = math.max(nextId, rec.id + 1)
    if not quiet and rec.room == spray.here() then
        OF.util.optional("play_sound", nil, SOUND_GENERAL_FLAME_OUT or 0,
            { x = rec.x, y = rec.y, z = rec.z })
    end
    return true
end

function spray.apply_drop(id)
    local rec = find(tonumber(id))
    if rec == nil or rec.fading ~= nil then return false end
    rec.fading = spray.FADE
    return true
end

function spray.apply_clear(ownerGlobal)
    local n = 0
    for _, rec in ipairs(records) do
        if rec.fading == nil and (ownerGlobal == nil or rec.o == ownerGlobal) then
            rec.fading = spray.FADE
            n = n + 1
        end
    end
    return n
end

function spray.forget_all()
    for index = #records, 1, -1 do forget(records[index], index) end
    sprayedAt = -9999
    hostSprayedAt = {}
    nextId = 1
end

local function packet_of(rec, quiet)
    return {
        ofp = spray.ADD, i = rec.id, o = rec.o, k = rec.room,
        x = math.floor(rec.x + 0.5), y = math.floor(rec.y + 0.5), z = math.floor(rec.z + 0.5),
        p = rec.p, w = rec.yw, t = rec.t, r = rec.r, g = rec.g, b = rec.b,
        q = quiet and 1 or 0,
    }
end

local function record_of(data)
    local id = tonumber(data.i)
    if id == nil or type(data.k) ~= "string" then return nil end
    return {
        id = id, o = tonumber(data.o) or 0, room = data.k,
        x = tonumber(data.x) or 0, y = tonumber(data.y) or 0, z = tonumber(data.z) or 0,
        p = tonumber(data.p) or 0, yw = tonumber(data.w) or 0,
        t = math.max(1, math.min(#spray.PATTERNS, tonumber(data.t) or 1)),
        r = tonumber(data.r) or 255, g = tonumber(data.g) or 255, b = tonumber(data.b) or 255,
    }
end

local function host_drop(id)
    if not OF.util.is_host() then return false end
    if spray.apply_drop(id) then
        OF.util.tell_all({ ofp = spray.DROP, i = id })
        return true
    end
    return false
end

function spray.host_evict(ownerGlobal)
    local each = spray.each()
    while spray.count(ownerGlobal) > each do
        local victim = nil
        for _, rec in ipairs(records) do
            if rec.fading == nil and rec.o == ownerGlobal then victim = rec; break end
        end
        if victim == nil or not host_drop(victim.id) then break end
    end
    while spray.count() > spray.LOBBY_MAX do
        local victim = nil
        for _, rec in ipairs(records) do
            if rec.fading == nil then victim = rec; break end
        end
        if victim == nil or not host_drop(victim.id) then break end
    end
end

function spray.host_take(askerLocal, req)
    if not OF.util.is_host() then return false, "Only the host." end
    if type(req) ~= "table" then return false, "That spray did not arrive whole." end
    local np = gNetworkPlayers[askerLocal]
    if np == nil or not np.connected then return false, "They have left." end
    if OF.perms.tier(askerLocal) < OF.perms.required("spray", askerLocal) then
        return false, "Your rank cannot spray."
    end
    if OF.util.asks(OF.roundscope, "inside") and OF.roundscope.inside(askerLocal) then
        return false, "Not while a round has you."
    end
    local now = now_frame()
    local last = hostSprayedAt[np.globalIndex] or -9999

    if now - last < spray.GAP - 2 then return false, nil end
    local m = gMarioStates[askerLocal]
    local x, y, z = tonumber(req.x), tonumber(req.y), tonumber(req.z)
    if m == nil or x == nil or y == nil or z == nil then
        return false, "That spray did not arrive whole."
    end
    local gx, gy, gz = x - m.pos.x, y - m.pos.y, z - m.pos.z
    if gx * gx + gy * gy + gz * gz > spray.HOST_REACH * spray.HOST_REACH then
        return false, "That is out of reach."
    end
    local here = spray.room_key(np.currLevelNum, np.currAreaIndex, np.currActNum,
        spray.world_code())
    if req.k ~= here then return false, nil end
    hostSprayedAt[np.globalIndex] = now
    local rec = record_of({
        i = nextId, o = np.globalIndex, k = here, x = x, y = y, z = z,
        p = req.p, w = req.w, t = req.t, r = req.r, g = req.g, b = req.b,
    })
    rec.born = now
    spray.apply_add(rec, false)
    OF.util.tell_all(packet_of(rec, false))
    spray.host_evict(np.globalIndex)
    return true
end

function spray.host_expire()
    if not OF.util.is_host() then return 0 end
    local lasts = spray.lasts()
    if not lasts then return 0 end
    local now, n = now_frame(), 0
    for _, rec in ipairs(records) do
        if rec.fading == nil and rec.born ~= nil and now - rec.born >= lasts then
            if host_drop(rec.id) then n = n + 1 end
        end
    end
    return n
end

function spray.host_clear(ownerGlobal)
    if not OF.util.is_host() then return false, "Only the host." end
    local n = spray.apply_clear(ownerGlobal)
    OF.util.tell_all({ ofp = spray.CLEAR, o = ownerGlobal })
    if n == 0 then return true, "There were no sprays to clear." end
    return true
end

function spray.send_list(localIndex)
    if not OF.util.is_host() then return 0 end
    local n = 0

    for _, rec in ipairs(records) do
        if rec.fading == nil then
            local sent = OF.util.send_to_player(localIndex, packet_of(rec, true))
            if sent then n = n + 1 end
        end
    end
    return n
end

function spray.my_colour()
    local np = gNetworkPlayers[0]
    local palette = np ~= nil and np.overridePalette or nil
    local parts = palette ~= nil and palette.parts or nil
    local cap = parts ~= nil and parts[CAP or 1] or nil
    if cap ~= nil and type(cap.r) == "number" then return cap.r, cap.g, cap.b end
    return OF.util.player_color(0)
end

function spray.press(m, pattern)
    m = m or gMarioStates[0]
    local ok, why = spray.may_spray()
    if not ok then return false, why end
    local now = now_frame()
    if now - sprayedAt < spray.GAP then return false, nil end
    local aim, missed = spray.aim(m)
    if aim == nil then return false, missed end
    sprayedAt = now
    local r, g, b = spray.my_colour()
    local req = {
        ofp = spray.ASK, k = spray.here(),
        x = math.floor(aim.x + 0.5), y = math.floor(aim.y + 0.5), z = math.floor(aim.z + 0.5),
        p = aim.p, w = aim.yw, t = pattern or spray.tap_pattern(), r = r, g = g, b = b,
    }

    if pattern ~= nil then spray.lastPattern = pattern end
    if OF.util.is_host() then
        return spray.host_take(0, req)
    end
    if not OF.util.send_to_host(req) then
        return false, "No host to ask yet - try again in a second."
    end
    return true
end

local modelsAsked = false
local models = nil

function spray.models()
    if modelsAsked then return models end
    modelsAsked = true
    local found = {}
    for index, pattern in ipairs(spray.PATTERNS) do
        if not OF.util.optional("mod_file_exists", false,
            "actors/" .. pattern.geo .. ".bin") then return nil end
        local id = OF.util.optional("smlua_model_util_get_id", nil, pattern.geo)
        if type(id) ~= "number" or id == E_MODEL_ERROR_MODEL then return nil end
        found[index] = id
    end
    models = found
    return models
end

function spray.forget_models()
    modelsAsked = false
    models = nil
end

local slotList = {}
local slotSays = {}

local function pattern_list(index, part)
    local pattern = spray.PATTERNS[index]
    if pattern == nil then return nil end
    return OF.util.optional("gfx_get_from_name", nil, "of_spray_" .. pattern.key .. "_" .. part)
end

function spray.slot_list(rec, alpha)
    if gfx_create == nil or gfx_set_command == nil or gfx_get_command == nil then
        return nil
    end
    local slot = rec.slot
    local dl = slotList[slot]
    if dl == nil then

        local name = "of_spray_slot_" .. tostring(slot)
        dl = OF.util.optional("gfx_get_from_name", nil, name) or gfx_create(name, 5)
        if dl == nil then return nil end
        slotList[slot] = dl
    end
    local says = slotSays[slot]
    if says == nil or says.id ~= rec.id then
        local mat, tri, revert = pattern_list(rec.t, "mat"), pattern_list(rec.t, "tri"),
            pattern_list(rec.t, "revert")
        if mat == nil or tri == nil or revert == nil then return nil end
        gfx_set_command(gfx_get_command(dl, 0), "gsSPDisplayList(%g)", mat)
        gfx_set_command(gfx_get_command(dl, 2), "gsSPDisplayList(%g)", tri)
        gfx_set_command(gfx_get_command(dl, 3), "gsSPDisplayList(%g)", revert)
        gfx_set_command(gfx_get_command(dl, 4), "gsSPEndDisplayList()")
        says = { id = rec.id, alpha = -1 }
        slotSays[slot] = says
    end
    if says.alpha ~= alpha then
        gfx_set_command(gfx_get_command(dl, 1), "gsDPSetEnvColor(%i, %i, %i, %i)",
            rec.r, rec.g, rec.b, alpha)
        says.alpha = alpha
    end
    return dl
end

function spray.alpha_of(rec)
    local share = math.min(rec.shown or 0, spray.FADE) / spray.FADE
    if rec.fading ~= nil then share = math.min(share, rec.fading / spray.FADE) end
    return math.floor(spray.ALPHA * share + 0.5)
end

local function object_alive(rec)
    local o = rec.obj
    return o ~= nil and o.activeFlags ~= 0 and o.oBehParams == spray.MARK + rec.slot
end

local function place(rec, modelIds)
    local id = modelIds[rec.t]
    if id == nil then return nil end
    local scale = spray.SIZE / (2 * spray.MODEL_RADIUS)

    local spawn = OF.util.asks(OF.slots, "spawn_non_sync") and OF.slots.spawn_non_sync
        or spawn_non_sync_object
    if spawn == nil then return nil end
    local o = spawn(id_bhvStaticObject, id,
        rec.x, rec.y, rec.z, function(obj)
            obj.oFaceAnglePitch, obj.oFaceAngleYaw, obj.oFaceAngleRoll = rec.p, rec.yw, 0
            obj.oMoveAnglePitch, obj.oMoveAngleYaw = rec.p, rec.yw
            obj.oBehParams = spray.MARK + rec.slot
            obj.hookRender = 1
            OF.util.optional("obj_scale", nil, obj, scale)
        end)
    return o
end

function spray.drawn_here()
    if OF.util.asks(OF.roundscope, "about") and OF.roundscope.about(0) then return false end
    return true
end

function spray.frame()
    for index = #records, 1, -1 do
        local rec = records[index]
        rec.shown = math.min((rec.shown or 0) + 1, spray.FADE)
        if rec.fading ~= nil then
            rec.fading = rec.fading - 1
            if rec.fading <= 0 then forget(rec, index) end
        end
    end
    local here = spray.here()
    local drawn = spray.drawn_here()
    local modelIds = drawn and spray.models() or nil
    local placed = 0
    for _, rec in ipairs(records) do
        if modelIds ~= nil and rec.room == here then
            if not object_alive(rec) then rec.obj = place(rec, modelIds) end
            if rec.obj ~= nil then placed = placed + 1 end
        elseif rec.obj ~= nil then
            delete_object(rec)
        end
    end
    return placed
end

local nodeOf = {}

local function list_node(o)
    local gfx = o.header ~= nil and o.header.gfx or nil
    local root = gfx ~= nil and gfx.sharedChild or nil
    if root == nil then return nil end
    local want = GRAPH_NODE_TYPE_DISPLAY_LIST or 0x01B
    local node, depth = root, 0
    while node ~= nil and depth < 4 do
        if node.type == want then
            return OF.util.optional("cast_graph_node", nil, node)
        end
        node = node.children
        depth = depth + 1
    end
    return nil
end

function spray.on_render(o)
    if o == nil then return false end
    local slot = (o.oBehParams or 0) - spray.MARK
    if slot < 0 or slot >= spray.SLOTS then return false end
    local rec = nil
    for _, one in ipairs(records) do
        if one.slot == slot then rec = one; break end
    end
    if rec == nil then return false end
    local dl = spray.slot_list(rec, spray.alpha_of(rec))
    if dl == nil then return false end
    local key = rec.t
    local node = nodeOf[key]
    if node == nil then
        node = list_node(o)
        nodeOf[key] = node
    end
    if node == nil then return false end
    node.displayList = dl
    return true
end

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if type(data) ~= "table" then return end
    if data.ofp == spray.ASK then
        if not OF.util.is_host() then return end
        local asker, askerGlobal = OF.util.asked_by(data)
        if asker == nil then return end
        local ok, why = spray.host_take(asker, data)
        if not ok and why ~= nil then OF.util.tell_asker(askerGlobal, why) end
        return
    end
    if data.ofp == spray.ADD then
        if not OF.util.from_host_effect(data) then return end
        local rec = record_of(data)
        if rec ~= nil then spray.apply_add(rec, tonumber(data.q) == 1) end
        return
    end
    if data.ofp == spray.DROP then
        if not OF.util.from_host_effect(data) then return end
        spray.apply_drop(data.i)
        return
    end
    if data.ofp == spray.CLEAR then
        if not OF.util.from_host_effect(data) then return end
        spray.apply_clear(tonumber(data.o))
    end
end)

hook_event(HOOK_ON_PLAYER_CONNECTED, function(m)
    if m == nil or not OF.util.is_host() then return end
    spray.send_list(m.playerIndex)
end)

spray.keyArmed = true

function spray.read_button(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    local w = spray.wheel
    if OF.util.menu_has_screen() then
        spray.keyArmed = false
        spray.close_wheel()
        return false
    end
    local entry = spray.BUTTONS[spray.my_button_index()]
    local pad = m.controller
    local down = entry ~= nil and pad ~= nil and OF.util.has_flag(pad.buttonDown or 0, entry.button)
    if not spray.keyArmed then
        if not down then spray.keyArmed = true end
        return false
    end

    local _, _, quiet = spray.may_spray()
    if quiet or spray.button_taken() ~= nil or entry == nil or pad == nil then
        spray.close_wheel()
        return false
    end
    if not w.tracking then
        if not OF.util.has_flag(pad.buttonPressed or 0, entry.button) then return false end

        if OF.util.has_flag(pad.buttonDown or 0, Z_TRIG or 0x2000) then return false end
        w.tracking, w.held, w.choice = true, 0, nil
        return false
    end
    if down then

        w.held = w.held + 1

        if w.held >= spray.HOLD_FRAMES then
            if not w.open and OF.sounds ~= nil then OF.sounds.ui("wheel_open", OF.sounds.OPEN) end
            w.open = true
        end
        if w.open then
            local aimed = spray.sector(pad.stickX, pad.stickY)
            if aimed ~= nil and aimed ~= w.choice and OF.sounds ~= nil then
                OF.sounds.ui("wheel_tick", OF.sounds.MOVE)
            end
            if aimed ~= nil then w.choice = aimed end
            if OF.util.asks(OF.input, "claim") then
                local onFoot = not OF.util.has_flag(m.action or 0, ACT_FLAG_AIR or 0x00000800)
                    and not OF.util.has_flag(m.action or 0, ACT_FLAG_SWIMMING or 0x00002000)
                OF.input.claim(m, { entry.button }, onFoot and "dead" or true)
            end
        end
        return false
    end

    local wasOpen, choice = w.open, w.choice
    w.tracking, w.held, w.open = false, 0, false
    local pattern = nil
    if wasOpen and choice ~= nil then pattern = spray.wheel_pattern(choice) end
    local ok, why = spray.press(m, pattern)
    if not ok and why ~= nil and OF.util.asks(OF.notify, "show") then
        OF.notify.show(why, "warn", 3)
    end
    return ok
end

local function text_mid(hud, text, x, cy, token, c, alpha, align)
    if type(hud.text_mid) == "function" then
        return hud.text_mid(text, x, cy, token, c, alpha, align)
    end
    local _, h = hud.measure(text, token)
    return hud.text(text, x, cy - (h or 0) / 2, token, c, alpha, align)
end

local function ink_width(hud, text, token)
    if type(hud.ink_width) == "function" then return hud.ink_width(text, token) end
    return (hud.measure(text, token))
end

spray.DPAD_DIR = { ["<"] = "left", [">"] = "right", ["^"] = "up", ["v"] = "down" }
function spray.draw_dpad(hud, dir, x, y, size, alpha)
    return hud.arrow_glyph(dir, x + size / 2, y + size / 2, size, hud.C.ink, alpha, "dpad")
end

function spray.key_glyph(hud, glyph, x, y, size, alpha, measureOnly)
    local set = hud.glyph_set()
    local dir = glyph.pad == "DPAD" and spray.DPAD_DIR[glyph.padText or ""] or nil
    if set ~= "kbm" and dir ~= nil then
        if measureOnly then return size end
        return spray.draw_dpad(hud, dir, x, y, size, alpha)
    end
    if measureOnly then return hud.glyph_width(glyph, size, set) end
    return hud.glyph(glyph, x, y, size, alpha, set)
end

spray.SLOT_PAD = 16
spray.SLOT_DOT = 12
spray.SLOT_GAP = 10
spray.HUB_GLYPH = 22
spray.SLOT_SPACE = 14

function spray.wheel_radius(short, pw, ph, hubW)
    local step = 2 * math.pi / spray.WHEEL_SLOTS
    local apart = (ph + spray.SLOT_SPACE) / (1 - math.cos(step))
    local sides = pw / 2 + (hubW or 240) / 2 + spray.SLOT_SPACE
    return math.max(short * 0.30, apart, sides)
end

spray.HINT_AIMED = "Let go to spray it"
spray.HINT_AGAIN = "Let go to spray again"
function spray.draw_wheel()
    local w = spray.wheel
    if w.phase <= 0 or OF.hud == nil then return false end
    if OF.util.menu_has_screen() then return false end
    local hud = OF.hud
    local sw, sh = hud.screen()
    local short = math.min(sw, sh)
    local fade = w.phase / spray.WHEEL_OPEN_FRAMES
    local a = 255 * fade
    local cx, cy = sw / 2, sh / 2
    local accent = hud.C.gold
    local r, g, b = spray.my_colour()
    local mine = { r, g, b }
    local names, widest = {}, 0
    for slot = 1, spray.WHEEL_SLOTS do
        names[slot] = OF.lang.t(spray.PATTERNS[spray.wheel_pattern(slot)].name)
        widest = math.max(widest, ink_width(hud, names[slot], "body"))
    end
    local _, lineH = hud.measure("Ag", "body")
    local pw = spray.SLOT_DOT + spray.SLOT_GAP + widest + spray.SLOT_PAD * 2
    local ph = lineH + 18

    local entry = spray.BUTTONS[spray.my_button_index()]
    local gs = spray.HUB_GLYPH
    local gw = (entry ~= nil and entry.glyph ~= nil)
        and spray.key_glyph(hud, entry.glyph, 0, 0, gs, a, true) or 0
    local gap = gw > 0 and 8 or 0
    local titleW = ink_width(hud, OF.lang.t(spray.PATTERNS[spray.tap_pattern()].name), "heading")
    for slot = 1, spray.WHEEL_SLOTS do titleW = math.max(titleW, ink_width(hud, names[slot], "heading")) end
    local hintW = math.max(ink_width(hud, OF.lang.t(spray.HINT_AIMED), "caption"),
        ink_width(hud, OF.lang.t(spray.HINT_AGAIN), "caption"))
    local hubW = math.max(titleW, gw + gap + hintW) + 40
    local radius = spray.wheel_radius(short, pw, ph, hubW)

    local at = hud.wheel_chrome({ cx = cx, cy = cy, rx = radius, ry = radius,
        count = spray.WHEEL_SLOTS, selected = w.choice, fade = fade, open = fade,
        accent = accent, hubRadius = 56, wash = w.open == true })
    for slot = 1, spray.WHEEL_SLOTS do
        local x, y = at(slot)
        local lit = (w.lit[slot] or 0) / 4
        hud.wheel_slot(x, y, pw, ph, lit, fade, accent)
        local nw = ink_width(hud, names[slot], "body")
        local left = x - (spray.SLOT_DOT + spray.SLOT_GAP + nw) / 2
        hud.diamond(left + spray.SLOT_DOT / 2, y, spray.SLOT_DOT, mine, a)
        text_mid(hud, names[slot], left + spray.SLOT_DOT + spray.SLOT_GAP, y, "body",
            lit > 0.5 and "gold" or "ink", a, "left")
    end
    local aimed = w.choice ~= nil
    local title = OF.lang.t(spray.PATTERNS[aimed and spray.wheel_pattern(w.choice)
        or spray.tap_pattern()].name)
    local under = OF.lang.t(aimed and spray.HINT_AIMED or spray.HINT_AGAIN)
    local _, th = hud.measure(title, "heading")
    local uw = ink_width(hud, under, "caption")
    local rowW = gw + gap + uw
    local hubH = 12 + th + 8 + gs + 12
    local hx, hy = hud.wheel_hub(cx, cy, hubW, hubH, fade, aimed, accent)
    text_mid(hud, title, cx, hy + 12 + th / 2, "heading", "gold", a, "center")
    local rowY = hy + 12 + th + 8
    local left = cx - rowW / 2
    if gw > 0 then spray.key_glyph(hud, entry.glyph, left, rowY, gs, a) end
    text_mid(hud, under, left + gw + gap, rowY + gs / 2, "caption", "ink2", a, "left")
    return true
end

function spray.update()
    if (now_frame() % 30) == 0 then spray.host_expire() end
    spray.frame()
end

function spray.note()
    local n = spray.count()
    if n == 0 then return nil end
    return OF.lang.fill("@ up", tostring(n))
end

local function clear_all()

    if not OF.perms.can("spray_clear") then return false, "Your rank cannot do that.", "spray_clear" end
    if OF.util.is_host() then return spray.host_clear(nil) end
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does(spray.CLEAR_ACTION, 0, nil, nil)
    end
    return false, "No host to ask yet - try again in a second."
end
spray.clear_all = clear_all

local function wipe_mine()
    if OF.util.is_host() then
        return spray.host_clear(network_global_index_from_local(0))
    end
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does(spray.WIPE_ACTION, 0, nil, nil)
    end
    return false, "No host to ask yet - try again in a second."
end
spray.wipe_mine = wipe_mine

function spray.button_name()
    local entry = spray.BUTTONS[spray.my_button_index()]
    return entry ~= nil and entry.name or spray.BUTTONS[1].name
end

function spray.build_page(panel)
    local rows = {}
    local modifiers = OF.modifiers
    table.insert(rows, panel.label_row(OF.lang.fill(
        "Press @ to spray your mark where you aim.", spray.button_name())))
    local entry = modifiers ~= nil and modifiers.BY_KEY[spray.KEY] or nil
    if entry ~= nil then table.insert(rows, modifiers.two_box_row(panel, entry)) end
    if modifiers ~= nil and modifiers.round_holds() then
        table.insert(rows, panel.label_row(
            OF.lang.t("A round has these - sprays come back after it.")))
    end

    table.insert(rows, panel.with_help(panel.header_row(OF.lang.t("Your mark")),
        OF.lang.t("kept on this machine; the colour is your cap's")))
    local mine = spray.my_pattern()
    local patternRow = panel.row(OF.lang.t("Your pattern"), 255, 255, 255, function()
        spray.set_pattern(mine % #spray.PATTERNS + 1)
    end)
    patternRow = panel.with_right(patternRow, OF.lang.t(spray.PATTERNS[mine].name))
    patternRow = panel.with_slider(patternRow, mine - 1, #spray.PATTERNS - 1, function(wanted)
        spray.set_pattern(wanted + 1)
    end)
    table.insert(rows, panel.with_help(patternRow, OF.lang.t("a tap sprays this - hold the key for your wheel")))

    table.insert(rows, panel.with_help(panel.header_row(OF.lang.t("Your spray wheel")),
        OF.lang.t("hold the key, point with the stick, let go to spray")))
    for slot = 1, spray.WHEEL_SLOTS do
        local onSlot = spray.wheel_pattern(slot)
        local slotRow = panel.row(OF.lang.fill("Wheel slot @", tostring(slot)), 255, 255, 255,
            function() spray.set_wheel_pattern(slot, onSlot % #spray.PATTERNS + 1) end)
        slotRow = panel.with_right(slotRow, OF.lang.t(spray.PATTERNS[onSlot].name))
        slotRow = panel.with_slider(slotRow, onSlot - 1, #spray.PATTERNS - 1, function(wanted)
            spray.set_wheel_pattern(slot, wanted + 1)
        end)
        table.insert(rows, panel.with_help(slotRow, OF.lang.t("what this point of the wheel sprays")))
    end
    local button = spray.my_button_index()
    local buttonRow = panel.row(OF.lang.t("Your button"), 255, 255, 255, function()
        spray.set_button(button % #spray.BUTTONS + 1)
    end)
    buttonRow = panel.with_right(buttonRow, spray.BUTTONS[button].name)
    table.insert(rows, panel.with_help(buttonRow, OF.lang.t("which button sprays")))
    local taken = spray.button_taken()
    if taken ~= nil then
        table.insert(rows, panel.label_row(OF.lang.fill(
            "@ is taken while @ is on.", spray.button_name(), OF.lang.t(taken))))
    end
    table.insert(rows, panel.with_help(panel.row(OF.lang.t("Wipe my own sprays"),
        255, 255, 255, function() OF.util.report(wipe_mine()) end),
        OF.lang.t("every mark of yours, gone from every screen")))

    table.insert(rows, panel.with_help(panel.header_row(OF.lang.t("For the lobby")),
        OF.lang.t("how many marks each player may have up, and for how long")))
    table.insert(rows, panel.with_help(panel.with_right(
        panel.gated_confirm_row(spray.CLEAR_RANK, spray.CLEAR_ACTION,
            OF.lang.t("Clear every spray"), 255, 140, 90,
            function() OF.util.report(spray.clear_all()) end),
        tostring(spray.count())),
        OF.lang.t("every mark in the lobby, on every screen - players spray with their own key")))
    for _, row in ipairs(spray.OPTS) do
        local key = row.key
        local step = spray.opt(key)
        local built = panel.gated_row(opt_rank(), OF.lang.t(row.name), 255, 255, 255,
            function()
                OF.util.report(spray.set_opt(key, step % #row.steps + 1))
            end)
        built = panel.with_right(built, OF.lang.t(row.steps[step]))
        if panel.may(opt_rank()) then
            built = panel.with_slider(built, step - 1, #row.steps - 1, function(wanted)
                OF.util.report(spray.set_opt(key, wanted + 1))
            end)
        else
            built = panel.with_slider(built, step - 1, #row.steps - 1, nil)
        end
        table.insert(rows, panel.with_help(built, OF.lang.t(row.help)))
    end
    table.insert(rows, panel.back_row())
    return rows
end

hook_event(HOOK_ON_MODS_LOADED, function()
    if OF.util.asks(OF.net, "register_action") then
        OF.net.register_action(spray.OPTS_ACTION, opt_rank(),
            function(fromLocal, x, _, z)
                if not OF.util.is_host() then return false, "Only the host." end
                return spray.set_opt(tostring(z), tonumber(x), fromLocal)
            end)
        OF.net.register_action(spray.CLEAR_ACTION, "spray_clear", function()
            return spray.host_clear(nil)
        end)
        OF.net.register_action(spray.WIPE_ACTION, "spray", function(fromLocal)
            local np = gNetworkPlayers[fromLocal or 0]
            if np == nil then return false, "They have left." end
            return spray.host_clear(np.globalIndex)
        end)
    end
    local panel = OF.panel
    if panel ~= nil and type(panel.PAGES) == "table" and panel.PAGES.spray == nil then
        panel.PAGES.spray = {
            title = "Spray paint", tab = "room", up = "shapes",
            build = function() return spray.build_page(panel) end,
        }
    end
end)

hook_event(HOOK_UPDATE, spray.update)
hook_event(HOOK_ON_OBJECT_RENDER, spray.on_render)

hook_event(HOOK_BEFORE_MARIO_UPDATE, function(m)
    if m == nil or (m.playerIndex or 0) ~= 0 then return end
    spray.read_button(m)
    spray.step_wheel_ramps()
end, OF.LOCAL_MARIO)

function spray.ready()
    return true
end
