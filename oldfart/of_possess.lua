OF = OF or {}
OF.possess = OF.possess or {}

local possess = OF.possess

local ROW_KEY = "ofPossess"
possess.ROW_KEY = ROW_KEY

local CARRIER = id_bhvStaticObject

local INVISIBLE = GRAPH_RENDER_INVISIBLE or 16
local ACTIVE = GRAPH_RENDER_ACTIVE or 1

local BILLBOARD = GRAPH_RENDER_BILLBOARD or 4
local CYLBOARD = GRAPH_RENDER_CYLBOARD or 64

function possess.catalogue()
    local costumes = OF.costumes
    if costumes == nil then return nil end
    if type(costumes.BY_KEY) ~= "table" then return nil end
    return costumes
end

function possess.available()
    if CARRIER == nil then return false end
    if spawn_non_sync_object == nil then return false end
    return possess.catalogue() ~= nil
end

local roundLayer = nil

local roundSize = nil

local roundLook = nil

function possess.set_round_layer(fn, sizeFn, look)
    roundLayer = fn
    roundSize = fn ~= nil and sizeFn or nil
    roundLook = fn ~= nil and look or nil
end

local function look_says(name, a, b)
    if roundLook == nil or type(roundLook[name]) ~= "function" then return nil end
    local ok, value = pcall(roundLook[name], a, b)
    if not ok then return nil end
    return value
end

local function model_of(key)
    local costumes = possess.catalogue()
    local entry = costumes ~= nil and costumes.BY_KEY[key] or nil
    if entry ~= nil then return entry.model end
    local model = look_says("model", key)
    if type(model) == "number" then return model end
    return nil
end

local function round_prop(localIndex)
    if roundLayer == nil then return nil end
    local ok, key = pcall(roundLayer, localIndex)
    if not ok or type(key) ~= "string" or key == "" then return nil end
    local costumes = possess.catalogue()
    if costumes == nil then return nil end
    if costumes.BY_KEY[key] == nil and type(look_says("model", key)) ~= "number" then
        return nil
    end
    return key
end

local function size_factor(localIndex, key)
    if roundSize == nil or key == nil then return 1 end
    if round_prop(localIndex) ~= key then return 1 end
    local ok, factor = pcall(roundSize, key)
    if not ok or type(factor) ~= "number" or factor <= 0 then return 1 end
    return factor
end

function possess.round_prop(localIndex)
    return round_prop(localIndex)
end

function possess.as(localIndex)
    local round = round_prop(localIndex)
    if round ~= nil then return round end
    local s = gPlayerSyncTable[localIndex]
    if s == nil then return nil end
    local key = s[ROW_KEY]
    if key == nil or key == "" then return nil end
    local costumes = possess.catalogue()
    if costumes == nil or costumes.BY_KEY[key] == nil then return nil end
    return key
end

function possess.round_hides(localIndex)
    if not OF.util.asks(OF.lockdown, "menu_stands_down") then return false end
    return OF.lockdown.menu_stands_down(localIndex)
end

local function is_watching(localIndex)
    if not OF.util.asks(OF.spectate, "is_spectating") then return false end
    return OF.spectate.is_spectating(localIndex) == true
end

function possess.shown(localIndex)
    if possess.as(localIndex) == nil then return false end
    if not possess.available() then return false end

    if round_prop(localIndex) == nil and possess.round_hides(localIndex) then
        return false
    end

    if is_watching(localIndex) then return false end

    local np = gNetworkPlayers[localIndex]
    if np == nil or not np.connected then return false end
    local m = gMarioStates[localIndex]
    if m == nil or m.marioObj == nil then return false end
    if is_player_active(m) == 0 then return false end

    local me = gNetworkPlayers[0]
    if me ~= nil and np.currAreaIndex ~= me.currAreaIndex then return false end
    if me ~= nil and np.currLevelNum ~= me.currLevelNum then return false end
    return true
end

local prop = {}
local propKey = {}

possess.props = prop

local function drop(localIndex)
    local o = prop[localIndex]
    prop[localIndex] = nil
    propKey[localIndex] = nil
    if o == nil then return false end
    if o.activeFlags ~= 0 then obj_mark_for_deletion(o) end
    return true
end

function possess.forget_all()
    for i = 0, MAX_PLAYERS - 1 do
        prop[i] = nil
        propKey[i] = nil
    end
end

local function prop_init(o)
    if o == nil then return end
    o.oInteractType = 0
    o.oIntangibleTimer = -1
    o.oCollisionDistance = 0

    o.oAnimState = 0
end

local function pin(o, m)
    o.oPosX, o.oPosY, o.oPosZ = m.pos.x, m.pos.y, m.pos.z

    local y = look_says("y", m.playerIndex, m)
    if type(y) == "number" then o.oPosY = y end

    o.oFaceAngleYaw = m.faceAngle.y

    local mGfx = m.marioObj.header.gfx
    local oGfx = o.header.gfx

    local factor = size_factor(m.playerIndex, propKey[m.playerIndex])
    oGfx.scale.x, oGfx.scale.y, oGfx.scale.z =
        mGfx.scale.x * factor, mGfx.scale.y * factor, mGfx.scale.z * factor

    if (mGfx.node.flags & ACTIVE) ~= 0 then
        oGfx.node.flags = oGfx.node.flags | ACTIVE
    else
        oGfx.node.flags = oGfx.node.flags & ~ACTIVE
    end

    local costumes = OF.costumes
    local key = propKey[m.playerIndex]
    local turns = costumes ~= nil and costumes.BILLBOARDED ~= nil
        and costumes.BILLBOARDED[key]
    if not turns and look_says("flat", key) == true then turns = true end
    if turns then
        local flat = costumes == nil or costumes.vanilla_turn == nil
            or costumes.vanilla_turn() == costumes.FACING_FLAT
        local on = flat and BILLBOARD or CYLBOARD
        local off = flat and CYLBOARD or BILLBOARD
        oGfx.node.flags = (oGfx.node.flags & ~off) | on
    end

    look_says("pose", o, m)
end

function possess.keep_in_step()
    for i = 0, MAX_PLAYERS - 1 do
        local want = possess.shown(i)
        local have = prop[i]

        if have ~= nil and have.activeFlags == 0 then
            prop[i] = nil
            propKey[i] = nil
            have = nil
        end

        local key = possess.as(i)
        if have ~= nil and key ~= nil and propKey[i] ~= key then
            drop(i)
            have = nil
        end

        if want and have == nil then
            local m = gMarioStates[i]
            local o = OF.slots.spawn_non_sync(CARRIER, model_of(key),
                m.pos.x, m.pos.y, m.pos.z, prop_init)
            if o ~= nil then
                prop[i] = o
                propKey[i] = key
                pin(o, m)
            end
        elseif not want and have ~= nil then
            drop(i)
        end
    end
end

local function hold(m)
    if m == nil or m.marioObj == nil then return end
    local o = prop[m.playerIndex]
    if o == nil or o.activeFlags == 0 then return end
    if not possess.shown(m.playerIndex) then return end

    pin(o, m)

    local node = m.marioObj.header.gfx.node
    node.flags = node.flags | INVISIBLE
end

hook_event(HOOK_UPDATE, possess.keep_in_step)
hook_event(HOOK_MARIO_UPDATE, hold)

hook_event(HOOK_ON_LEVEL_INIT, possess.forget_all)
hook_event(HOOK_ON_SYNC_VALID, possess.forget_all)

hook_event(HOOK_ON_PLAYER_DISCONNECTED, function(m)
    if m == nil then return end
    drop(m.playerIndex)
    if not OF.util.is_host() then return end
    local s = gPlayerSyncTable[m.playerIndex]
    if s ~= nil then s[ROW_KEY] = "" end
end)

possess.PACKET_SET = "possset"
possess.PACKET_ASK = "possask"
local function become_locally(key)
    OF.util.publish_row(0, ROW_KEY, key or "")
end

local roundHid = false

local function watch_round()
    local hiding = possess.round_hides()
    if hiding == roundHid then return false end
    roundHid = hiding
    if not hiding then return false end
    if possess.as(0) == nil then return false end
    OF.notify.show("A round is on, so you are yourself again until it ends",
        "info", 6)
    return true
end

hook_event(HOOK_UPDATE, watch_round)

function possess.set(localIndex, key)
    if key ~= nil then
        local costumes = possess.catalogue()
        if costumes == nil then
            return false, "This build has nothing to be."
        end
        if costumes.BY_KEY[key] == nil then
            return false, "There is nothing by that name."
        end
    end

    if localIndex == 0 then

        if key ~= nil and not OF.perms.can("possess_self") then
            return false, "Your rank cannot do that.", "possess_self"
        end
        become_locally(key)
        return true
    end

    if not OF.perms.can("possess_other") then
        return false, "Your rank cannot do that.", "possess_other"
    end

    local globalIndex = network_global_index_from_local(localIndex)
    if globalIndex == nil then return false, "They are not here." end

    if not OF.util.is_host() then
        OF.util.send_to_host({
            ofp = possess.PACKET_ASK,
            who = globalIndex,

            off = (key == nil) and 1 or 0,
            key = key or "off",
        })
        return true, "Asked the host."
    end

    if not OF.util.send_to_player(localIndex, {
        ofp = possess.PACKET_SET,
        off = (key == nil) and 1 or 0,
        key = key or "off",
    }) then
        return false, "They are not here to tell."
    end
    return true
end

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil or data.ofp ~= possess.PACKET_SET then return end
    if not OF.util.from_host(data) then return end

    local key = data.key
    if data.off == 1 then key = nil end
    local costumes = possess.catalogue()
    if key ~= nil and (costumes == nil or costumes.BY_KEY[key] == nil) then return end
    become_locally(key)

    if key == nil then
        OF.notify.show("You are yourself again", "info", 5)
    else

        OF.notify.show("The host made you a @ - the world stops seeing you",
            "info", 7, costumes.BY_KEY[key].name)
    end
end)

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil or data.ofp ~= possess.PACKET_ASK then return end
    if not OF.util.is_host() then return end

    local asker, askerGlobal = OF.util.asked_by(data)
    if asker == nil then return end
    if OF.perms.tier(asker) < OF.perms.required("possess_other", asker) then
        OF.notify.send_to(askerGlobal, "Your rank cannot do that.", "bad", 5)
        return
    end

    local target = OF.util.local_from_global(data.who)
    local may, whyNot = OF.util.may_act_on(asker, target)
    if not may then
        OF.util.tell_asker(askerGlobal, whyNot)
        return
    end

    local key = data.key
    if data.off == 1 then key = nil end
    local ok, why = possess.set(target, key)
    if not ok then OF.util.tell_asker(askerGlobal, why) end
end)

function possess.hides_from_world(localIndex)
    return possess.shown(localIndex)
end
