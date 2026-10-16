OF = OF or {}
OF.whoplays = OF.whoplays or {}

local whoplays = OF.whoplays

whoplays.PAGE = "whoplays"
whoplays.TRUST_FRAMES = 60

whoplays.ROW_WIDTH = 678

local pressed = {}

local function held_key(globalIndex, kind)
    return tostring(globalIndex) .. ":" .. tostring(kind or "mode")
end

local function frame()
    return get_global_timer ~= nil and get_global_timer() or 0
end

function whoplays.visible()
    return OF.util.is_host() or OF.perms.is_cohost(0)
end

whoplays.SET_ACTION = "whoplays"
function whoplays.takes_part(localIndex, kind)
    kind = kind or OF.speedrun.KIND_MODE
    local np = gNetworkPlayers[localIndex]
    if np == nil or not np.connected then return false end

    if OF.speedrun.muted_out(localIndex) then return false end
    local rowOut = OF.speedrun.chose_out(localIndex, kind)
    local key = held_key(np.globalIndex, kind)
    local held = pressed[key]
    if held ~= nil then
        if held.out == rowOut or frame() - held.at > whoplays.TRUST_FRAMES then
            pressed[key] = nil
        else
            return not held.out
        end
    end
    return not rowOut
end

function whoplays.set(localIndex, takesPart, kind)
    kind = kind or OF.speedrun.KIND_MODE
    if not OF.util.is_host() and not OF.perms.is_cohost(0) then
        return false, "Only the host and a co-host pick who takes part."
    end
    local np = gNetworkPlayers[localIndex]
    if np == nil or not np.connected then
        return false, "They are not in the lobby any more."
    end
    local out = takesPart ~= true

    if OF.speedrun.muted_out(localIndex) then
        return false, OF.speedrun.MUTED_WHY
    end
    local runs = kind == OF.speedrun.KIND_RUN
    local key = held_key(np.globalIndex, kind)

    if not OF.util.is_host() and localIndex ~= 0 then
        local ok, why = OF.net.cohost_does(whoplays.SET_ACTION, np.globalIndex,
            out and 1 or 0, runs and 1 or 0)
        if not ok then return false, why end
        pressed[key] = { out = out, at = frame() }
        if OF.util.asks(OF.panel, "mark_dirty") then OF.panel.mark_dirty() end
        return true
    end

    if localIndex == 0 then
        if runs then return OF.speedrun.set_excluded(0, out, kind) end
        return OF.outseat.set_sitting_out(out)
    end

    local sent, why = OF.util.send_to_player(localIndex, {
        ofp = OF.speedrun.PACKET_SET, out = out and 1 or 0, k = runs and "r" or "m",
    })

    if not sent and why == nil then
        return false, "They are not in the lobby any more."
    end
    pressed[key] = { out = out, at = frame() }
    local said
    if runs then
        said = out and "The host has you sitting the next speedruns out"
            or "The host put you in the next speedruns"
    else
        said = out and "The host has you sitting the next rounds out"
            or "The host put you in the next rounds"
    end
    OF.notify.send_to(np.globalIndex, said, out and "info" or "good", 6)
    if OF.util.asks(OF.panel, "mark_dirty") then OF.panel.mark_dirty() end
    if not sent then return false, why end
    return true
end

function whoplays.toggle(localIndex, kind)
    return whoplays.set(localIndex, not whoplays.takes_part(localIndex, kind), kind)
end

function whoplays.reset_screen()
    local moved = next(pressed) ~= nil
    pressed = {}
    return moved
end

function whoplays.list_door(panel)
    if not whoplays.visible() then return nil end
    return panel.with_help(panel.row(OF.lang.t("Who is taking part..."),
        255, 255, 255, function() panel.go("whoplays") end),
        "tick who plays the next game modes and speedruns")
end

function whoplays.build_page(panel)
    local rows = {}
    if not whoplays.visible() then
        table.insert(rows, panel.label_row(
            OF.lang.t("Only the host and a co-host pick who takes part.")))
        table.insert(rows, panel.back_row())
        return rows
    end

    for _, entry in ipairs(OF.util.connected_players()) do
        local li = entry.localIndex
        local np = entry.np
        local muted = OF.speedrun.muted_out(li)

        local r
        local boxes = panel.tick(not muted and whoplays.takes_part(li, OF.speedrun.KIND_MODE), "")
            .. panel.tick(not muted and whoplays.takes_part(li, OF.speedrun.KIND_RUN), "")
        if muted then

            local why = "   " .. OF.lang.t("(Muted)")
            local text = OF.util.fit(boxes .. OF.util.short_name(np.name, 63), 1.0,
                whoplays.ROW_WIDTH - OF.util.width(why, 1.0)) .. why
            r = panel.with_help(panel.label_row(text),
                "muted players take no part until they are raised")
            r.locked = "muted"
        else
            local text = OF.util.fit(boxes .. OF.util.short_name(np.name, 63), 1.0,
                whoplays.ROW_WIDTH)
            r = panel.with_help(panel.row(text,
                255, 255, 255, function()
                    OF.util.report(whoplays.toggle(li, OF.speedrun.KIND_MODE))
                end),
                li == 0 and "your own line: game modes (A), speedruns (Z)"
                    or "game modes (A), speedruns (Z) - they are told")
            r.altAction = function()
                OF.util.report(whoplays.toggle(li, OF.speedrun.KIND_RUN))
            end
            r.altBox = 2
            r.actionLabel = "game modes"
            r.altLabel = "speedruns"
        end
        r.key = "whoplays\31" .. tostring(np.globalIndex)
        table.insert(rows, r)
    end
    table.insert(rows, panel.back_row())
    return rows
end

hook_event(HOOK_ON_MODS_LOADED, function()
    if not OF.util.asks(OF.net, "register_cohost_action") then return end
    OF.net.register_cohost_action(whoplays.SET_ACTION, "settings", function(_, who, out, runs)
        local li = OF.util.local_from_global(tonumber(who))
        if li == nil then return false, "They are not in the lobby any more." end
        return whoplays.set(li, tonumber(out) ~= 1,
            tonumber(runs) == 1 and OF.speedrun.KIND_RUN or OF.speedrun.KIND_MODE)
    end)
end)

function whoplays.ready()
    return true
end
