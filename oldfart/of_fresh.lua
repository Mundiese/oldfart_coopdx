OF = OF or {}
OF.fresh = OF.fresh or {}

local fresh = OF.fresh

fresh.STEPS = {
    {
        name = "the round",
        run = function()
            if OF.gamemodes == nil then return false end
            if not OF.gamemodes.is_running()
                and OF.gamemodes.state() ~= OF.gamemodes.RESULTS
                and OF.gamemodes.state() ~= OF.gamemodes.LOBBY then return false end
            OF.gamemodes.stop(true)
            return true
        end,
    },

    {
        name = "the rotation",
        run = function()
            if OF.gamemodes == nil then return false end
            if not OF.util.asks(OF.gamemodes, "nonstop") then return false end
            if not OF.gamemodes.nonstop() then return false end
            OF.gamemodes.set_nonstop(false)
            return true
        end,
    },
    {
        name = "the race",
        run = function()
            if OF.speedrun == nil or OF.speedrun.state() == OF.speedrun.OFF then
                return false
            end
            OF.speedrun.stop(true)
            return true
        end,
    },

    {
        name = "the bingo card",
        run = function()
            if not OF.util.asks(OF.bingo, "running") then return false end
            local had = OF.bingo.running()
            if had then OF.util.publish("ofBingoSeed", nil) end
            if gGlobalSyncTable.ofBingoMode ~= nil and OF.bingo.mode() ~= "mixed" then
                OF.util.publish("ofBingoMode", nil)
                had = true
            end
            return had
        end,
    },
    {
        name = "the queue",
        run = function()
            if OF.rounds == nil then return false end
            local had = OF.rounds.is_running() or OF.rounds.count() > 0
            if not had then return false end
            OF.rounds.stop(true)
            OF.rounds.clear()
            return true
        end,
    },
    {
        name = "the sides",
        run = function()
            if OF.teams == nil or not OF.teams.in_play() then return false end

            local cleared = OF.teams.clear_all()
            return cleared == true
        end,
    },
    {
        name = "the arena",
        run = function()
            if OF.arena == nil or gGlobalSyncTable.ofArenaClear ~= true then return false end
            OF.arena.close()
            return true
        end,
    },

    {
        name = "the swap timer",
        run = function()
            if not OF.util.asks(OF.swap, "stop_timer") then return false end
            return OF.swap.stop_timer() == true
        end,
    },
    {

        name = "the chaos",
        covers = "the chaos",
        run = function()
            if OF.chaos == nil or not OF.util.asks(OF.chaos, "on") then return false end
            if not OF.chaos.on() then return false end
            return OF.chaos.set(0) == true
        end,
    },

    {
        name = "the randomizer",
        run = function()
            if OF.rando == nil then return false end
            local any = false
            if OF.util.asks(OF.rando, "is_on") and OF.rando.is_on()
                and OF.util.asks(OF.rando, "set_on") then
                any = OF.rando.set_on(false) == true
            end

            local moved = false
            if OF.util.asks(OF.rando, "choice") and type(OF.rando.KNOBS) == "table" then
                for _, knob in ipairs(OF.rando.KNOBS) do
                    if OF.rando.choice(knob.key) ~= OF.rando.default(knob.key) then
                        moved = true
                        break
                    end
                end
            end
            if moved and OF.util.asks(OF.rando, "reset") then
                OF.rando.reset()
                any = true
            end
            return any
        end,
    },

    {

        name = "the painting shuffle",
        run = function()
            if not OF.util.asks(OF.shuffle, "seed") then return false end
            local seed = OF.shuffle.seed()
            if seed == nil or seed == 0 then return false end
            return OF.shuffle.off() == true
        end,
    },
    {

        name = "the carried powerups",

        personal = true,
        run = function()
            if not OF.util.asks(OF.powerups, "take_back_many") then
                return false
            end
            local targets = {}
            for _, player in ipairs(OF.util.connected_players()) do
                local globalIndex =
                    network_global_index_from_local(player.localIndex)
                if globalIndex ~= nil then
                    table.insert(targets, globalIndex)
                end
            end
            if #targets == 0 then return false end

            local hadOne = OF.powerups.any_carried()
                or next(OF.powerups.mine or {}) ~= nil
            OF.powerups.take_back_many(targets)
            return hadOne
        end,
    },
    {

        name = "the lobby's powerups",
        run = function()
            if not OF.util.is_host() then return false end
            if not OF.util.asks(OF.powerups, "room_any") then return false end

            if not OF.powerups.room_any() then return false end
            return OF.powerups.clear_room() == true
        end,
    },
    {

        name = "the modifiers",
        covers = "modifiers",
        run = function()
            if OF.modifiers == nil or not OF.modifiers.any() then return false end

            if not OF.util.asks(OF.modifiers, "clear_now") then return false end
            return OF.modifiers.clear_now() == true
        end,
    },
    {

        name = "my modifiers",
        covers = "modifiers",
        personal = true,
        run = function()
            if not OF.util.is_host() then return false end
            if not OF.util.asks(OF.modifiers, "clear_mine") then return false end

            local hadOne = OF.modifiers.mine_any()
            OF.util.tell_all({ ofp = OF.modifiers.PACKET, what = "clearmine" })
            OF.modifiers.clear_mine()
            return hadOne
        end,
    },
    {

        name = "my harsh rules",
        covers = "harsh rules",
        personal = true,
        run = function()
            if not OF.util.is_host() then return false end
            if not OF.util.asks(OF.harsh, "clear_mine") then return false end

            local hadOne = OF.harsh.mine_any()
            OF.util.tell_all({ ofp = OF.harsh.PACKET_MINE, what = "clearmine" })
            OF.harsh.clear_mine()
            return hadOne
        end,
    },
    {

        name = "the cheats",
        covers = "cheats",

        personal = true,
        run = function()

            if not OF.util.is_host() then return false end
            if OF.cheats == nil or OF.cheats.clear_local == nil then return false end

            local worn = false
            for _, held in pairs(OF.cheats.active or {}) do
                if held ~= nil and held ~= false then worn = true end
            end
            if #fresh.cheat_wearers() == 0 and not worn then

                if OF.cheats.publish_mine ~= nil then OF.cheats.publish_mine() end
                return false
            end
            OF.util.tell_all({ ofp = OF.cheats.PACKET, what = "clear" })
            OF.cheats.clear_local()
            return true
        end,
    },
    {

        name = "the lobby's cheats",
        covers = "cheats",
        run = function()
            if not OF.util.is_host() then return false end
            if not OF.util.asks(OF.cheats, "room_any") then return false end

            if not OF.cheats.room_any() then return false end
            return OF.cheats.clear_room() == true
        end,
    },
    {

        name = "the hats",
        personal = true,
        run = function()
            if not OF.util.is_host() then return false end
            if not OF.util.asks(OF.hats, "anyone_chose") then return false end
            if not OF.hats.anyone_chose() then return false end
            OF.util.tell_all({ ofp = OF.hats.PACKET_SET, clear = 1 })

            OF.hats.forget_mine()
            return true
        end,
    },
    {

        name = "the lobby's hats",
        run = function()
            if not OF.util.is_host() then return false end
            if not OF.util.asks(OF.hats, "room_any") then return false end

            local hatsOn = OF.hats.room_any()
            local fitOn = OF.util.asks(OF.hats, "room_fit_any") and OF.hats.room_fit_any()
            if not hatsOn and not fitOn then return false end
            local cleared = true
            if hatsOn then cleared = OF.hats.clear_room() == true end
            if fitOn then cleared = (OF.hats.clear_room_fit() == true) and cleared end
            return cleared
        end,
    },
    {

        name = "the costumes",
        personal = true,
        run = function()
            if not OF.util.is_host() then return false end
            if not OF.util.asks(OF.costumes, "anyone_chose") then return false end
            if not OF.costumes.anyone_chose() then return false end
            OF.util.tell_all({ ofp = OF.costumes.PACKET_SET, clear = 1 })
            OF.costumes.forget_mine()
            return true
        end,
    },
    {
        name = "the lobby's costume",
        run = function()
            if not OF.util.is_host() then return false end
            if not OF.util.asks(OF.costumes, "room_any") then return false end
            if not OF.costumes.room_any() then return false end
            return OF.costumes.clear_room() == true
        end,
    },
    {

        name = "the shapes and shows people chose",
        personal = true,
        run = function()
            if not OF.util.is_host() then return false end
            if not OF.util.asks(OF.theme, "anyone_chose") then return false end

            local had = OF.theme.anyone_chose()
            OF.util.tell_all({ ofp = OF.theme.PACKET_CLEAR })

            OF.theme.forget_shape_mine()
            OF.theme.set_show_mine(nil)
            return had
        end,
    },
    {

        name = "the lobby's light show",
        covers = "the light show",
        run = function()
            if not OF.util.is_host() then return false end
            if not OF.util.asks(OF.theme, "borrow_show") then return false end
            return OF.theme.borrow_show(OF.theme.SHOW_DEFAULT) == true
        end,
    },
    {

        name = "the lobby's shape",
        covers = "how everybody is drawn",
        run = function()
            if not OF.util.is_host() then return false end
            if not OF.util.asks(OF.theme, "borrow_shape") then return false end
            return OF.theme.borrow_shape(OF.theme.SHAPE_DEFAULT) == true
        end,
    },
    {

        name = "the moves",
        covers = "the moves",
        run = function()
            if not OF.util.is_host() then return false end
            if not OF.util.asks(OF.moves, "put_text") then return false end

            return OF.moves.put_text("") == true
        end,
    },
    {

        name = "my moves",
        covers = "the moves",
        personal = true,
        run = function()
            if not OF.util.is_host() then return false end
            if not OF.util.asks(OF.moves, "clear_mine") then return false end

            local hadOne = OF.moves.mine_any()
            OF.util.tell_all({ ofp = OF.moves.PACKET, what = "clearmine" })
            OF.moves.clear_mine()
            return hadOne
        end,
    },
    {

        name = "the pictures people built for themselves",
        personal = true,
        run = function()
            if not OF.util.is_host() then return false end
            if not OF.util.asks(OF.modifiers, "forget_vision_mine") then
                return false
            end

            local hadOne = OF.modifiers.vision_mine_any()
            OF.util.tell_all({ ofp = OF.modifiers.PACKET, what = "clearvision" })

            OF.modifiers.forget_vision_mine()
            return hadOne
        end,
    },
    {

        name = "the lobby's picture",
        covers = "the lobby's picture",
        run = function()
            if not OF.util.is_host() then return false end
            if not OF.util.asks(OF.modifiers, "borrow_vision") then
                return false
            end
            return OF.modifiers.borrow_vision("") == true
        end,
    },
    {

        name = "the enemies you chose",
        personal = true,
        run = function()
            if not OF.util.is_host() then return false end
            if not OF.util.asks(OF.enemies, "forget_mine") then return false end

            local hadOne = OF.util.asks(OF.enemies, "mine_any")
                and OF.enemies.mine_any()
            OF.util.tell_all({ ofp = OF.enemies.PACKET, what = "clear" })

            OF.enemies.forget_mine()
            return hadOne == true
        end,
    },
    {

        name = "the enemies",
        covers = "the enemies",
        run = function()
            if not OF.util.is_host() then return false end
            if not OF.util.asks(OF.enemies, "put_text") then return false end
            return OF.enemies.put_text("") == true
        end,
    },
    {

        name = "the music people chose for themselves",
        personal = true,
        run = function()
            if not OF.util.is_host() then return false end
            if not OF.util.asks(OF.music, "anyone_chose") then return false end

            local had = OF.music.anyone_chose()
            OF.util.tell_all({ ofp = OF.music.PACKET_CLEAR })

            OF.music.forget_mine()
            return had
        end,
    },
    {

        name = "the lobby's music",
        covers = "the lobby's music",
        run = function()
            if not OF.util.is_host() then return false end
            if not OF.util.asks(OF.music, "put_lobby") then return false end
            return OF.music.put_lobby(OF.music.VANILLA) == true
        end,
    },

    {
        name = "the vote",
        run = function()
            if OF.vote == nil or not OF.vote.is_open() then return false end
            return OF.vote.cancel() == true
        end,
    },
    {
        name = "the jail",
        run = function()
            if OF.jail == nil then return false end
            local freed = 0
            for _, entry in ipairs(OF.util.connected_players()) do
                if OF.jail.is_jailed(entry.localIndex) then

                    if OF.jail.release(entry.localIndex, true) then
                        freed = freed + 1
                    end
                end
            end

            if OF.util.asks(OF.jail, "forget_all_stored_sentences") then
                freed = freed + OF.jail.forget_all_stored_sentences()
            end
            return freed > 0
        end,
    },
    {
        name = "the mutes",
        run = function()
            if OF.mute == nil then return false end
            local unmuted = 0
            for _, entry in ipairs(OF.util.connected_players()) do
                if OF.mute.is_muted(entry.localIndex) then
                    OF.mute.set(entry.localIndex, false, true)
                    unmuted = unmuted + 1
                end
            end
            return unmuted > 0
        end,
    },
    {
        name = "what was built",
        run = function()
            if OF.forge == nil or #OF.forge.placed == 0 then return false end
            return OF.forge.clear() == true
        end,
    },
    {
        name = "the screen message",
        run = function()
            if gGlobalSyncTable.ofMessage == nil or gGlobalSyncTable.ofMessage == "" then
                return false
            end
            OF.util.publish("ofMessage", "")
            return true
        end,
    },

    {
        name = "every page's own options",
        run = function()

            local moved = 0
            local keys = {}
            for key, module in pairs(OF) do
                if type(module) == "table" and type(rawget(module, "OPTS_KEY")) == "string"
                    and type(rawget(module, "OPTS")) == "table" then
                    keys[#keys + 1] = key
                end
            end
            table.sort(keys)
            for _, key in ipairs(keys) do
                local syncKey = OF[key].OPTS_KEY
                if gGlobalSyncTable[syncKey] ~= nil and gGlobalSyncTable[syncKey] ~= "" then
                    OF.util.publish(syncKey, nil)
                    moved = moved + 1
                end
            end
            return fresh.reset_all("reset_options") + moved > 0
        end,
    },

    {
        name = "what each player picked on the other pages",
        personal = true,
        run = function()
            OF.util.tell_all({ ofp = fresh.MINE_PACKET,
                from = network_global_index_from_local(0) })

            return fresh.reset_all("reset_mine") > 0
        end,
    },

    {
        name = "each screen's own toggles",
        personal = true,
        run = function()
            OF.util.tell_all({ ofp = fresh.SCREEN_PACKET,
                from = network_global_index_from_local(0) })
            return fresh.reset_all("reset_screen") > 0
        end,
    },
}

fresh.MINE_PACKET = "freshmine"
fresh.SCREEN_PACKET = "freshscreen"
function fresh.reset_all(name)
    local keys = {}
    for key, module in pairs(OF) do
        if type(module) == "table" and type(rawget(module, name)) == "function" then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    local moved = 0
    for _, key in ipairs(keys) do
        local ok, did = pcall(OF[key][name])
        if ok and did == true then moved = moved + 1 end
    end
    return moved
end

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil then return end

    if data.ofp == fresh.MINE_PACKET then
        if not OF.util.from_host(data) then return end
        fresh.reset_all("reset_mine")
    elseif data.ofp == fresh.SCREEN_PACKET then
        if not OF.util.from_host(data) then return end
        fresh.reset_all("reset_screen")
    end
end)

fresh.REGISTRIES = {
    {
        name = "modifiers",

        hold = "standsdown",

        read = function()
            if not OF.util.asks(OF.modifiers, "active") then return nil end
            local names = {}
            for key in pairs(OF.modifiers.active()) do
                local entry = OF.modifiers.BY_KEY ~= nil and OF.modifiers.BY_KEY[key] or nil
                names[#names + 1] = entry ~= nil and entry.name or key
            end
            table.sort(names)
            return names
        end,
    },
    {
        name = "cheats",

        hold = "byhand",

        read = function()
            if OF.cheats == nil or OF.cheats.cheats_of == nil then return nil end
            local names = {}
            for _, entry in ipairs(OF.util.connected_players()) do
                local said = OF.cheats.cheats_of(entry.localIndex)
                if said ~= nil and said ~= "" then names[#names + 1] = said end
            end
            return names
        end,
    },
    {
        name = "the chaos",

        hold = "standsdown",
        read = function()
            if not OF.util.asks(OF.chaos, "on") then return nil end
            if not OF.chaos.on() then return {} end
            return { "rolling" }
        end,
    },
    {
        name = "the lobby rules",

        hold = "standsdown",
        plain = function()
            if not OF.util.asks(OF.rules, "round_text") then return nil end
            return OF.rules.round_text()
        end,

        put = function(value)
            if not OF.util.asks(OF.rules, "publish_text") then return false end
            local text = value
            if type(value) == "table" then
                text = OF.rules.restore_text(value) or value.text
            end
            if type(text) ~= "string" then return false end
            if OF.rules.wire_text() == text then return false end
            OF.rules.publish_text(text)
            if OF.util.asks(OF.rules, "apply") then OF.rules.apply() end
            return true
        end,
        read = function()
            if not OF.util.asks(OF.rules, "would_change_for_round") then
                return nil
            end
            if not OF.rules.would_change_for_round() then return {} end
            return { "set to something a round would not want" }
        end,
    },

    {
        name = "the light show",

        hold = "standsdown",

        read = function()
            if not OF.util.asks(OF.theme, "show_key") then return nil end
            if OF.theme.show_key() == "off" then return {} end
            return { OF.theme.show().name }
        end,
    },
    {
        name = "how everybody is drawn",

        hold = "standsdown",

        read = function()
            if not OF.util.asks(OF.theme, "shape_key") then return nil end
            if OF.theme.shape_key() == "solid" then return {} end
            return { OF.theme.shape().name }
        end,
    },
    {
        name = "harsh rules",

        hold = "standsdown",

        plain = "",

        put = function(value)
            if not OF.util.asks(OF.harsh, "put_text") then return false end
            local disarmed = OF.util.asks(OF.harsh, "disarm") and OF.harsh.disarm() > 0
            local put = OF.harsh.put_text(value) == true
            return put or disarmed
        end,
        read = function()
            if not OF.util.asks(OF.harsh, "any_on") then return nil end
            if not OF.harsh.any_on() then return {} end
            return { OF.harsh.label() }
        end,
    },
    {
        name = "the enemies",

        hold = "standsdown",

        read = function()
            if not OF.util.asks(OF.enemies, "text") then return nil end
            if OF.enemies.text() == "" then return {} end
            return { OF.enemies.label() }
        end,
    },

    {
        name = "the painting shuffle",

        hold = "lend",
        snap = function()
            if not OF.util.asks(OF.shuffle, "seed") then return nil end
            return OF.shuffle.seed()
        end,
        plain = 0,
        put = function(value)
            if not OF.util.asks(OF.shuffle, "borrow_seed") then return false end
            return OF.shuffle.borrow_seed(value) == true
        end,
        read = function()
            if not OF.util.asks(OF.shuffle, "seed") then return nil end
            local seed = OF.shuffle.seed()
            if seed <= 0 then return {} end
            return { OF.lang.fill("castle @", seed) }
        end,
    },
    {
        name = "the doorways",

        hold = "standsdown",
        snap = function()
            if not OF.util.asks(OF.doorways, "armed") then return nil end
            return OF.doorways.armed()
        end,
        plain = false,
        put = function(value)
            if not OF.util.asks(OF.doorways, "put_armed") then return false end
            return OF.doorways.put_armed(value) == true
        end,

        read = function()
            if not OF.util.asks(OF.doorways, "armed") then return nil end
            if not OF.doorways.armed() then return {} end
            local placed = #OF.doorways.list()
            if placed == 0 then return {} end
            return { OF.lang.fill("@ open", placed) }
        end,
    },
    {
        name = "the moves",

        hold = "standsdown",

        read = function()
            if not OF.util.asks(OF.moves, "text") then return nil end
            if OF.moves.text() == "" then return {} end

            return { OF.moves.label() }
        end,
    },
    {
        name = "players together",

        hold = "lend",
        snap = function()
            if not OF.util.asks(OF.together, "snapshot") then return nil end
            return OF.together.snapshot()
        end,
        plain = {},
        put = function(value)
            if not OF.util.asks(OF.together, "restore") then return false end
            return OF.together.restore(value) > 0
        end,
        read = function()
            if not OF.util.asks(OF.together, "on_now") then return nil end
            return OF.together.on_now()
        end,
    },
    {
        name = "the lobby's music",

        hold = "standsdown",

        read = function()
            if not OF.util.asks(OF.music, "lobby_track") then return nil end
            if OF.music.lobby_track() == 0 then return {} end
            return { OF.music.track_name(OF.music.lobby_track()) }
        end,
    },
    {
        name = "the playlist",

        hold = "leavesalone",
        snap = function()
            if not OF.util.asks(OF.playlist, "is_on") then return nil end
            return OF.playlist.is_on()
        end,
        plain = false,
        put = function(value)
            if not OF.util.asks(OF.playlist, "put") then return false end
            return OF.playlist.put(value) == true
        end,
        read = function()
            if not OF.util.asks(OF.playlist, "is_on") then return nil end
            if not OF.playlist.is_on() then return {} end
            return { "the lobby picks what plays next" }
        end,
    },
    {
        name = "the lobby's picture",

        hold = "standsdown",
        read = function()
            if not OF.util.asks(OF.modifiers, "vision_is_on") then return nil end
            if not OF.modifiers.vision_is_on() then return {} end
            return { OF.lang.t("the lobby's picture") }
        end,
    },
    {
        name = "the world's size",

        hold = "lend",
        snap = function()
            if not OF.util.asks(OF.warp, "world_snapshot") then return nil end
            return OF.warp.world_snapshot()
        end,

        plain = { x = 1.0, y = 1.0, z = 1.0 },
        put = function(value)
            if not OF.util.asks(OF.warp, "borrow_world") then return false end
            return OF.warp.borrow_world(value) == true
        end,

        read = function()
            if not OF.util.asks(OF.warp, "is_on") then return nil end
            if not OF.warp.is_on() then return {} end
            return { OF.warp.summary() }
        end,
    },
    {
        name = "the standings",

        hold = "leavesalone",

        snap = function()
            if not OF.util.asks(OF.standings, "snapshot") then return nil end
            return OF.standings.snapshot()
        end,

        plain = {},
        put = function(value)
            if not OF.util.asks(OF.standings, "restore") then return false end
            return OF.standings.restore(value) == true
        end,
        read = function()
            if not OF.util.asks(OF.standings, "count") then return nil end
            local players = OF.standings.count()
            if players == 0 then return {} end
            return { OF.lang.fill("@ on the table", players) }
        end,
    },
}

for _, registry in ipairs(fresh.REGISTRIES) do
    if registry.put ~= nil and registry.plain ~= nil and registry.step ~= false then
        table.insert(fresh.STEPS, {
            name = registry.name,
            covers = registry.name,
            run = function() return fresh.put_down(registry) end,
        })
    end
end

function fresh.put_down(registry)
    if registry.put == nil then return false end
    local ok, moved = pcall(registry.put, fresh.plain_of(registry))
    return ok and moved == true
end

function fresh.plain_of(registry)
    if type(registry.plain) == "function" then
        local ok, value = pcall(registry.plain)
        return ok and value or nil
    end
    return registry.plain
end

function fresh.take_all()
    local store = {}
    if not OF.util.is_host() then return store end
    for _, registry in ipairs(fresh.REGISTRIES) do
        if registry.hold == "lend" and registry.snap ~= nil then
            local ok, was = pcall(registry.snap)

            if ok and was ~= nil then
                store[registry.name] = was
                fresh.put_down(registry)
            end
        end
    end
    return store
end

function fresh.give_back_all(store)
    if type(store) ~= "table" then return 0 end
    if not OF.util.is_host() then return 0 end
    local put = 0
    for _, registry in ipairs(fresh.REGISTRIES) do
        local was = store[registry.name]
        if was ~= nil and registry.put ~= nil then
            local ok, moved = pcall(registry.put, was)
            if ok and moved == true then put = put + 1 end
        end
    end
    return put
end

function fresh.cheat_wearers()
    local wearers = {}
    if OF.cheats == nil or OF.cheats.cheats_of == nil then return wearers end
    for _, entry in ipairs(OF.util.connected_players()) do
        local said = OF.cheats.cheats_of(entry.localIndex)
        if said ~= nil and said ~= "" then
            wearers[#wearers + 1] = entry.localIndex
        end
    end
    return wearers
end

function fresh.left_on()
    local left = {}
    for _, registry in ipairs(fresh.REGISTRIES) do
        local ok, names = pcall(registry.read)
        if ok and names ~= nil and #names > 0 then
            left[#left + 1] = { name = registry.name,
                                what = table.concat(names, ", ") }
        end
    end
    return left
end

function fresh.uncovered()
    local covered = {}
    for _, step in ipairs(fresh.STEPS) do
        if step.covers ~= nil then covered[step.covers] = true end
    end
    local open = {}
    for _, registry in ipairs(fresh.REGISTRIES) do
        if not covered[registry.name] then open[#open + 1] = registry.name end
    end
    return open
end

function fresh.here(askerLocal, keepPersonal)
    local done = {}
    for _, step in ipairs(fresh.STEPS) do
        if not (keepPersonal and step.personal) then
            local ok = step.run()
            if ok then table.insert(done, step.name) end
        end
    end

    if OF.util.asks(OF.warp, "land_pending") and OF.warp.land_pending()
        and OF.util.asks(OF.net, "reload_level") then

        if OF.net.reload_level() == true then
            table.insert(done, OF.lang.t("the map"))
        end
    end

    fresh.say_what_is_stuck(askerLocal)

    if #done == 0 then

        if askerLocal ~= nil then
            OF.notify.send_to(network_global_index_from_local(askerLocal),
                "Nothing was holding the lobby", "info", 4)
        end
        return true, done
    end

    local who = askerLocal ~= nil and gNetworkPlayers[askerLocal] or nil

    local name = who ~= nil and who.name ~= nil and who.name ~= ""
        and OF.util.plain(who.name) or nil
    if keepPersonal then
        if name == nil then
            OF.notify.send_all("The lobby was put back, everybody's own things left on",
                "info", 5)
        else
            OF.notify.send_all("@ put the lobby back, and left everybody's own things on",
                "info", 5, name)
        end
    elseif name == nil then
        OF.notify.send_all("The lobby was started fresh", "info", 5)
    else
        OF.notify.send_all("@ started the lobby fresh", "info", 5, name)
    end

    if askerLocal ~= nil then
        OF.notify.send_to(network_global_index_from_local(askerLocal),
            "Put back: @", "info", 6, table.concat(done, ", "))
    end
    return true, done
end

function fresh.say_what_is_stuck(askerLocal)
    local stuck = {}
    local open = {}
    for _, name in ipairs(fresh.uncovered()) do open[name] = true end
    for _, item in ipairs(fresh.left_on()) do
        if open[item.name] then
            stuck[#stuck + 1] = item.name .. " (" .. item.what .. ")"
        end
    end
    if #stuck == 0 then return false end

    if askerLocal == nil then return false end
    OF.notify.send_to(network_global_index_from_local(askerLocal),
        "Something is still on that the reset cannot reach: @", "warn", 8,
        table.concat(stuck, ", "))
    return true
end

local registered = false

function fresh.ready()
    if registered then return end
    if not OF.util.asks(OF.net, "register_action") then return end
    registered = true

    OF.net.register_action("fresh", "settings", function(fromLocal, keep)

        if not OF.util.is_host() then return false, "Only the host." end

        return fresh.here(fromLocal, tonumber(keep) == 1)
    end)
end

hook_event(HOOK_UPDATE, function() fresh.ready() end)

function fresh.run(keepPersonal)

    if not OF.util.is_host() then
        return OF.net.host_does("fresh", keepPersonal and 1 or 0)
    end
    if not OF.perms.can("settings") then
        return false, "Your rank cannot do that.", "settings"
    end
    return fresh.here(0, keepPersonal == true)
end
