-- name: \\#FF0\\Old\\#FFF\\fart's Mod Menu \\#FF0\\v1.6.1 
-- description: The ultimate host control mod menu for insanely fun, janky or challenging lobbies\n\n\\#FF5555\\This mod is WIP - expect bugs!\n\\#8C9EFF\\Join our Discord: \\#FFFFFF\\discord.gg/y66mkUjvY \\#DCDCDC\\(or type /dc)
-- incompatible: gamemode cheats nametags
-- pausable: true
OF = OF or {}

OF.VERSION = "1.6.1"
_G.OldfartModMenu = { version = OF.VERSION, warp = function(level, area, act)
    if OF.net == nil or type(OF.net.warp_local) ~= "function" then return false end
    return OF.net.warp_local(level, area, act) ~= false
end }
OF.LOBBY_NAME = "oldfart"
OF.PREFIX = "> "
OF.GOLD = { r = 255, g = 255, b = 0 }

OF.BRAND = { r = 255, g = 255, b = 0 }

OF.settings = OF.settings or {
    showBanner     = true,
    announceJoins  = true,
    bannerSeconds  = 6,
}

OF.lang = OF.lang or {}

if OF.lang.t == nil then
    function OF.lang.t(english) return english end
end
if OF.lang.get == nil then
    function OF.lang.get(english) return english end
end

if OF.lang.fill == nil then
    function OF.lang.fill(english, first, second)
        local text = tostring(english)

        local values = {}
        if first ~= nil then values[#values + 1] = first end
        if second ~= nil then values[#values + 1] = second end
        if #values == 0 then return text end

        local at = 0
        local filled = string.gsub(text, "@", function()
            at = at + 1
            local value = values[at]
            if value == nil then return "@" end
            local written
            if type(value) == "number" and value == math.floor(value) then
                written = string.format("%.0f", value)
            else
                written = tostring(value)
            end
            local last, seek = nil, 1
            while true do
                local from, to = string.find(written, "\\" .. "#%x*" .. "\\", seek)
                if from == nil then break end
                last = string.upper(string.sub(written, from, to))
                seek = to + 1
            end
            if last ~= nil and last ~= "\\#FFFFFF\\" then
                written = written .. "\\#FFFFFF\\"
            end
            return written
        end, #values)
        return filled
    end
end
if OF.lang.holes == nil then
    function OF.lang.holes(english)
        if type(english) ~= "string" then return 0 end
        local n = 0
        for _ in string.gmatch(english, "@") do n = n + 1 end
        return n
    end
end

OF.gamemodes = OF.gamemodes or {}
OF.gamemodes.OFF = OF.gamemodes.OFF or 0
if OF.gamemodes.state == nil then
    function OF.gamemodes.state() return OF.gamemodes.OFF end
end
if OF.gamemodes.is_running == nil then
    function OF.gamemodes.is_running() return false end
end

OF.sounds = OF.sounds or {}
if OF.sounds.play == nil then function OF.sounds.play() end end

if OF.sounds.ui == nil then function OF.sounds.ui() return false end end
if OF.sounds.ui_press == nil then function OF.sounds.ui_press() return false end end

OF.perms = OF.perms or {}
if OF.perms.can == nil then
    function OF.perms.can(feature)
        return feature == "panel" or feature == "round_move"
            or network_is_server()
    end
end
if OF.perms.tier_name == nil then function OF.perms.tier_name() return "HOST" end end
if OF.perms.required == nil then function OF.perms.required() return 0 end end

OF.COMMANDS = OF.COMMANDS or {}

local engine_hook_chat_command = hook_chat_command

function hook_chat_command(name, description, fn)
    table.insert(OF.COMMANDS, { name = name, description = description or "",
                                fn = fn })
    return engine_hook_chat_command(name, description, function(...)

        if OF.util == nil or OF.util.answering == nil then return fn(...) end
        return OF.util.answering(fn, ...)
    end)
end

function OF.command(name)
    for _, entry in ipairs(OF.COMMANDS) do
        if entry.name == name and entry.alias == nil then return entry end
    end
    return nil
end

OF.RANK_NORMAL = "normal"
OF.RANK_CREW   = "crew"
OF.RANK_HOST   = "host"
local REAL = OF

local function keep_namespace()
    local fixed = 0

    if OF ~= REAL then

        OF = REAL
        fixed = fixed + 1
        REAL.namespaceRestored = (REAL.namespaceRestored or 0) + 1
    end

    if type(OF.GOLD) ~= "table" or OF.GOLD.r == nil then
        OF.GOLD = { r = 255, g = 255, b = 0 }
        fixed = fixed + 1
    end
    if type(OF.BRAND) ~= "table" or OF.BRAND.r == nil then
        OF.BRAND = { r = 255, g = 255, b = 0 }
        fixed = fixed + 1
    end
    if type(OF.lang) ~= "table" or OF.lang.t == nil then

        OF.lang = OF.lang or {}
        if OF.lang.t == nil then
            function OF.lang.t(english) return english end
            function OF.lang.get(english) return english end
            function OF.lang.fill(english, first, second)
                local text = tostring(english)
                local function put(value)
                    if value == nil then return end
                    text = string.gsub(text, "@",
                        (string.gsub(tostring(value), "%%", "%%%%")), 1)
                end
                put(first)
                put(second)
                return text
            end
        end
        fixed = fixed + 1
    end

    if fixed > 0 then
        OF.coloursRestored = (OF.coloursRestored or 0) + fixed
    end
end

OF.keep_colours = keep_namespace
OF.keep_namespace = keep_namespace

hook_event(HOOK_UPDATE, function()
    keep_namespace()
    OF.updateFrames = (OF.updateFrames or 0) + 1

    if OF.wireWatch and OF.wire_roll then OF.wire_roll() end
end)

OF.hookErrors = OF.hookErrors or {}
OF.hookErrorCount = OF.hookErrorCount or 0

local engine_hook_event = hook_event

local hookCounts = {}

local hookNames = {}
for name, value in pairs(_G) do
    if type(name) == "string" and type(value) == "number"
        and string.sub(name, 1, 5) == "HOOK_" then
        hookNames[value] = name
    end
end

local HOOK_FILE_MAP = {
    HOOK_ALLOW_FORCE_WATER_ACTION = [[
of_cheats.lua of_modifiers.lua
]],
    HOOK_ALLOW_HAZARD_SURFACE = [[
of_cheats.lua of_gamemodes.lua of_modifiers.lua of_powerups.lua
]],
    HOOK_ALLOW_INTERACT = [[
of_cheats.lua of_cheats.lua of_cheats.lua of_clones.lua of_enemies.lua
of_forge.lua of_gamemodes.lua of_gamemodes.lua of_gm_manhunt.lua
of_lockdown.lua of_lockdown.lua of_lockdown.lua of_modifiers.lua
of_powerups.lua of_reserve.lua of_reserve.lua of_roundact.lua
of_roundscope.lua of_rules.lua of_rules.lua of_rules.lua of_save.lua
of_smashshield.lua of_tas.lua of_teams.lua of_together.lua of_venues.lua
of_warp.lua
]],
    HOOK_ALLOW_PVP_ATTACK = [[
of_roundact.lua of_rules.lua of_tas.lua of_teams.lua
]],
    HOOK_BEFORE_GEO_PROCESS = [[
of_ragdoll.lua of_warp.lua
]],
    HOOK_BEFORE_MARIO_UPDATE = [[
of_ball.lua of_camera.lua of_cheats.lua of_doorways.lua of_emotes.lua
of_forge.lua of_forge.lua of_gamemodes.lua of_harsh.lua of_idle.lua
of_input.lua of_jail.lua of_levelfix.lua of_levelfix.lua of_levelfix.lua
of_lobbytalk.lua of_lockdown.lua of_mapvote.lua of_modifiers.lua
of_modifiers.lua of_modifiers.lua of_modifiers.lua of_modifiers.lua
of_modifiers.lua of_modifiers.lua of_modifiers.lua of_modifiers.lua
of_outseat.lua of_panel.lua of_pause.lua of_powerups.lua of_ragdoll.lua
of_rando.lua of_roundact.lua of_rules.lua of_rules.lua of_rules.lua
of_rules.lua of_spawner.lua of_spawner.lua of_spectate.lua
of_speedrun.lua of_spray.lua of_tas.lua of_together.lua of_together.lua
of_underside.lua of_unstick.lua of_util.lua of_venues.lua of_venues.lua
of_venues.lua
]],
    HOOK_BEFORE_PHYS_STEP = [[
of_cheats.lua of_cheats.lua of_cheats.lua of_modifiers.lua
of_powerups.lua of_smb3.lua of_underside.lua of_util.lua of_warp.lua
]],
    HOOK_BEFORE_SET_MARIO_ACTION = [[
of_cheats.lua of_gamemodes.lua of_gm_blastgrid.lua of_gm_chompfever.lua
of_lockdown.lua of_modifiers.lua of_moves.lua of_rules.lua
of_smashrules.lua
]],
    HOOK_BEFORE_WARP = [[
of_reserve.lua of_shuffle.lua of_warp.lua
]],
    HOOK_CHARACTER_SOUND = [[
of_cheats.lua of_modifiers.lua
]],
    HOOK_DIALOG_SOUND = [[
of_rules.lua
]],
    HOOK_MARIO_OVERRIDE_FLOOR_CLASS = [[
of_cheats.lua of_gm_blizzard.lua of_modifiers.lua of_warp.lua
]],
    HOOK_MARIO_OVERRIDE_GEOMETRY_INPUTS = [[
of_cheats.lua of_spectate.lua of_tas.lua of_underside.lua
]],
    HOOK_MARIO_UPDATE = [[
of_ball.lua of_camera.lua of_celebrate.lua of_cheats.lua of_corpse.lua
of_costumes.lua of_costumes.lua of_doorways.lua of_emotes.lua
of_forge.lua of_gm_blastgrid.lua of_gm_booksquirm.lua
of_gm_bumperballs.lua of_gm_downhill.lua of_gm_hideseek.lua
of_gm_manhunt.lua of_gm_prophunt.lua of_gm_shellbattle.lua
of_gm_shellrace.lua of_gm_shellrace.lua of_gm_shooter.lua
of_gm_zombies.lua of_harsh.lua of_lobbytalk.lua of_modifiers.lua
of_modifiers.lua of_modifiers.lua of_modifiers.lua of_modifiers.lua
of_modifiers.lua of_modifiers.lua of_modifiers.lua of_modifiers.lua
of_moves.lua of_possess.lua of_powerups.lua of_ragdoll.lua of_replay.lua
of_rules.lua of_spawner.lua of_spectate.lua of_tas.lua of_together.lua
of_together.lua of_util.lua of_util.lua of_venues.lua of_venues.lua
of_venues.lua of_warp.lua of_zelda.lua
]],
    HOOK_MIRROR_MARIO_RENDER = [[
of_rules.lua
]],
    HOOK_OBJECT_SET_MODEL = [[
of_slots.lua
]],
    HOOK_ON_ADD_SURFACE = [[
of_ground.lua of_warp.lua
]],
    HOOK_ON_ATTACK_OBJECT = [[
of_cheats.lua of_cheats.lua of_enemies.lua of_gm_prophunt.lua
]],
    HOOK_ON_CHANGE_CAMERA_ANGLE = [[
of_modifiers.lua of_rules.lua
]],
    HOOK_ON_CHAT_MESSAGE = [[
of_chatlog.lua of_filter.lua of_gm_murder.lua of_mute.lua
]],
    HOOK_ON_CLEAR_AREAS = [[
of_ground.lua of_modifiers.lua of_warp.lua of_warp.lua
]],
    HOOK_ON_COLLIDE_LEVEL_BOUNDS = [[
of_cheats.lua of_ground.lua
]],
    HOOK_ON_DEATH = [[
of_bingo.lua of_cheats.lua of_corpse.lua of_gamemodes.lua
of_gm_bounty.lua of_gm_crown.lua of_gm_oitc.lua of_gm_rocketarena.lua
of_gm_shellbattle.lua of_gm_shellrace.lua of_gm_shooter.lua
of_gm_smash.lua of_gm_snd.lua of_harsh.lua of_spectate.lua
of_speedrun.lua of_warp.lua
]],
    HOOK_ON_DIALOG = [[
of_cheats.lua of_lockdown.lua of_rules.lua
]],
    HOOK_ON_EXIT = [[
of_actionlog.lua of_gm_flood.lua of_modifiers.lua of_modifiers.lua
of_modifiers.lua of_shuffle.lua of_texshuffle.lua of_util.lua
]],
    HOOK_ON_FIND_POISON_GAS_LEVEL = [[
of_modifiers.lua of_warp.lua
]],
    HOOK_ON_FIND_WATER_LEVEL = [[
of_gm_flood.lua of_venues.lua of_warp.lua
]],
    HOOK_ON_GEO_PROCESS = [[
of_hats.lua of_modifiers.lua of_ragdoll.lua of_warp.lua
]],
    HOOK_ON_GEO_PROCESS_CHILDREN = [[
of_ragdoll.lua of_warp.lua
]],
    HOOK_ON_HUD_RENDER = [[
main.lua of_bingo.lua of_camera.lua of_celebrate.lua of_chaos.lua
of_cheats.lua of_cheats.lua of_cheats.lua of_cheats.lua of_cheats.lua
of_cheats.lua of_cheats.lua of_cheats.lua of_corpse.lua of_doorways.lua
of_emotes.lua of_forge.lua of_forge.lua of_gamemodes.lua
of_gm_shooter.lua of_ground.lua of_ground.lua of_harsh.lua of_jail.lua
of_levelfix.lua of_lobbytalk.lua of_logic.lua of_mapvote.lua
of_markers.lua of_markers.lua of_markers.lua of_markers.lua
of_modifiers.lua of_modifiers.lua of_modifiers.lua of_night.lua
of_notify.lua of_outseat.lua of_panel.lua of_pause.lua of_pets.lua
of_powerups.lua of_reserve.lua of_rounds.lua of_scoreboard.lua
of_shuffle.lua of_sign.lua of_smb3.lua of_spawner.lua of_spectate.lua
of_speedrun.lua of_split.lua of_standings.lua of_studio.lua of_tas.lua
of_tournament.lua of_vote.lua of_warp.lua of_welcome.lua of_zelda.lua
]],
    HOOK_ON_HUD_RENDER_BEHIND = [[
of_speedrun.lua of_tags.lua of_util.lua of_venues.lua of_venues.lua
]],
    HOOK_ON_INSTANT_WARP = [[
of_net.lua of_venues.lua of_warp.lua
]],
    HOOK_ON_INTERACT = [[
of_bingo.lua of_cheats.lua of_cheats.lua of_cheats.lua of_cheats.lua
of_clones.lua of_enemies.lua of_gm_bank.lua of_gm_coinrush.lua
of_gm_course.lua of_gm_manhunt.lua of_gm_smash.lua of_harsh.lua
of_lobbytalk.lua of_modifiers.lua of_powerups.lua of_save.lua
of_smashrules.lua of_smb3.lua of_speedrun.lua of_split.lua
]],
    HOOK_ON_LEVEL_INIT = [[
of_actionlog.lua of_arena.lua of_celebrate.lua of_cheats.lua
of_cheats.lua of_corpse.lua of_costumes.lua of_doorways.lua
of_emotes.lua of_enemies.lua of_forge.lua of_forge.lua of_forge.lua
of_forge.lua of_forge.lua of_forge.lua of_gamemodes.lua of_gamemodes.lua
of_gamemodes.lua of_gamemodes.lua of_gm_blastgrid.lua of_gm_blizzard.lua
of_gm_bombsaway.lua of_gm_bombsort.lua of_gm_bombxing.lua
of_gm_booksquirm.lua of_gm_chompfever.lua of_gm_course.lua of_gm_ctf.lua
of_gm_firesweep.lua of_gm_flood.lua of_gm_flyguy.lua
of_gm_glassbridge.lua of_gm_hexagone.lua of_gm_hexheat.lua
of_gm_hotrope.lua of_gm_lavaleave.lua of_gm_line.lua of_gm_logroll.lua
of_gm_onoffclimb.lua of_gm_rabbitchase.lua of_gm_rocketarena.lua
of_gm_shooter.lua of_gm_smash.lua of_gm_snd.lua of_guard.lua
of_harsh.lua of_hats.lua of_idle.lua of_lockdown.lua of_lockdown.lua
of_logic.lua of_modifiers.lua of_modifiers.lua of_modifiers.lua
of_modifiers.lua of_modifiers.lua of_modifiers.lua of_modifiers.lua
of_modifiers.lua of_modifiers.lua of_moves.lua of_music.lua of_net.lua
of_persist.lua of_pets.lua of_possess.lua of_ragdoll.lua of_rando.lua
of_reserve.lua of_reserve.lua of_roundact.lua of_rules.lua of_rules.lua
of_rules.lua of_rules.lua of_rules.lua of_shuffle.lua of_slots.lua
of_smashitems.lua of_smashshield.lua of_smb3.lua of_smb3.lua
of_spawner.lua of_spawner.lua of_spawner.lua of_spawner.lua
of_spawner.lua of_spawner.lua of_speedrun.lua of_studio.lua of_tas.lua
of_theme.lua of_together.lua of_underside.lua of_unstick.lua of_util.lua
of_util.lua of_venues.lua of_warp.lua of_zelda.lua
]],
    HOOK_ON_MODS_LOADED = [[
main.lua main.lua main.lua of_actionlog.lua of_actionlog.lua
of_arena.lua of_bingo.lua of_chaos.lua of_chaos.lua of_chaos.lua
of_charselect.lua of_cheats.lua of_clones.lua of_corpse.lua
of_costumes.lua of_doorways.lua of_doorways.lua of_enemies.lua
of_filter.lua of_filter.lua of_forge.lua of_gamemodes.lua
of_gamemodes.lua of_harsh.lua of_hats.lua of_hats.lua of_lobbytalk.lua
of_logic.lua of_modifiers.lua of_moves.lua of_panel.lua of_panel.lua
of_panel.lua of_pass.lua of_perms.lua of_pets.lua of_pets.lua
of_pets.lua of_pets.lua of_rando.lua of_ranks.lua of_rounds.lua
of_rules.lua of_save.lua of_sign.lua of_spawner.lua of_spawner.lua
of_spectate.lua of_speedrun.lua of_spray.lua of_stats.lua of_studio.lua
of_theme.lua of_theme.lua of_together.lua of_trouble.lua of_venues.lua
of_vote.lua of_warp.lua of_waypoints.lua of_whoplays.lua
]],
    HOOK_ON_NAMETAGS_RENDER = [[
of_spectate.lua of_tags.lua
]],
    HOOK_ON_OBJECT_LOAD = [[
of_gm_hideseek.lua of_modifiers.lua of_warp.lua
]],
    HOOK_ON_OBJECT_RENDER = [[
of_clones.lua of_corpse.lua of_costumes.lua of_hats.lua of_replay.lua
of_roundscope.lua of_spray.lua
]],
    HOOK_ON_OBJECT_UNLOAD = [[
of_enemies.lua of_ground.lua of_spawner.lua of_spawner.lua
of_stretch.lua of_venues.lua
]],
    HOOK_ON_PACKET_RECEIVE = [[
of_actionlog.lua of_arena.lua of_ball.lua of_cheats.lua of_cheats.lua
of_corpse.lua of_corpse.lua of_costumes.lua of_costumes.lua
of_enemies.lua of_forge.lua of_forge.lua of_forge.lua of_forge.lua
of_forge.lua of_fresh.lua of_gamemodes.lua of_gm_assassins.lua
of_gm_football.lua of_gm_murder.lua of_gm_murder.lua of_gm_murder.lua
of_gm_murder.lua of_gm_shellbattle.lua of_gm_shellrace.lua
of_gm_volleyball.lua of_harsh.lua of_hats.lua of_hats.lua of_idle.lua
of_jail.lua of_lobbytalk.lua of_modifiers.lua of_moves.lua of_music.lua
of_mute.lua of_net.lua of_notify.lua of_pass.lua of_persist.lua
of_pets.lua of_pets.lua of_pets.lua of_possess.lua of_possess.lua
of_powerups.lua of_ragdoll.lua of_recent.lua of_replay.lua of_rules.lua
of_save.lua of_save.lua of_spawner.lua of_speedrun.lua of_speedrun.lua
of_speedrun.lua of_spray.lua of_swap.lua of_theme.lua of_together.lua
of_together.lua of_trouble.lua of_waypoints.lua of_zelda.lua
]],
    HOOK_ON_PAUSE_EXIT = [[
of_gamemodes.lua of_gm_hideseek.lua
]],
    HOOK_ON_PLAYER_CONNECTED = [[
of_arena.lua of_filter.lua of_gamemodes.lua of_idle.lua of_notes.lua
of_pass.lua of_sign.lua of_spray.lua of_trouble.lua of_util.lua
of_welcome.lua
]],
    HOOK_ON_PLAYER_DISCONNECTED = [[
of_costumes.lua of_costumes.lua of_filter.lua of_gamemodes.lua
of_hats.lua of_idle.lua of_lobbytalk.lua of_modifiers.lua of_pass.lua
of_pets.lua of_possess.lua of_teams.lua of_together.lua of_trouble.lua
of_util.lua of_util.lua of_welcome.lua
]],
    HOOK_ON_PLAY_MODE_UPDATE = [[
of_modifiers.lua of_powerups.lua of_warp.lua
]],
    HOOK_ON_PLAY_SOUND = [[
of_modifiers.lua
]],
    HOOK_ON_PVP_ATTACK = [[
of_gamemodes.lua of_gm_assassins.lua of_gm_bank.lua of_gm_coinrush.lua
of_gm_crown.lua of_gm_koth.lua of_gm_laststanding.lua of_gm_oitc.lua
of_gm_smash.lua of_modifiers.lua of_moves.lua of_rules.lua
]],
    HOOK_ON_SCREEN_TRANSITION = [[
of_cheats.lua of_rules.lua
]],
    HOOK_ON_SEQ_LOAD = [[
of_music.lua of_venues.lua
]],
    HOOK_ON_SET_CAMERA_MODE = [[
of_cheats.lua of_modifiers.lua of_rules.lua
]],
    HOOK_ON_SET_MARIO_ACTION = [[
of_bingo.lua of_gm_simon.lua of_moves.lua of_ragdoll.lua
of_smashrules.lua
]],
    HOOK_ON_SYNC_VALID = [[
of_corpse.lua of_forge.lua of_hats.lua of_net.lua of_persist.lua
of_pets.lua of_possess.lua of_presence.lua of_rules.lua of_slots.lua
]],
    HOOK_ON_WARP = [[
of_gamemodes.lua of_gm_rocketarena.lua of_gm_shooter.lua of_music.lua
of_shuffle.lua of_warp.lua
]],
    HOOK_UPDATE = [[
of_arena.lua of_ball.lua of_bingo.lua of_bingo.lua of_camera.lua
of_celebrate.lua of_chaos.lua of_chaos.lua of_chatlog.lua of_clones.lua
of_enemies.lua of_filter.lua of_forge.lua of_forge.lua of_forge.lua
of_forge.lua of_forge.lua of_forge.lua of_forge.lua of_forge.lua
of_forge.lua of_forge.lua of_forge.lua of_forge.lua of_fresh.lua
of_gamemodes.lua of_gamemodes.lua of_gamemodes.lua of_gamemodes.lua
of_gamemodes.lua of_gamemodes.lua of_gm_course.lua of_gm_hideseek.lua
of_gm_hideseek.lua of_gm_hideseek.lua of_gm_murder.lua of_gm_murder.lua
of_gm_murder.lua of_gm_murder.lua of_gm_murder.lua of_gm_shooter.lua
of_gm_shooter.lua of_ground.lua of_ground.lua of_ground.lua
of_ground.lua of_ground.lua of_guard.lua of_harsh.lua of_harsh.lua
of_hats.lua of_idle.lua of_idle.lua of_jail.lua of_lobbytalk.lua
of_lockdown.lua of_logic.lua of_mapvote.lua of_modifiers.lua
of_modifiers.lua of_modifiers.lua of_modifiers.lua of_modifiers.lua
of_modifiers.lua of_modifiers.lua of_modifiers.lua of_modifiers.lua
of_modifiers.lua of_modifiers.lua of_modifiers.lua of_modifiers.lua
of_modifiers.lua of_modifiers.lua of_modifiers.lua of_modifiers.lua
of_modifiers.lua of_modifiers.lua of_modifiers.lua of_modifiers.lua
of_modifiers.lua of_modifiers.lua of_modifiers.lua of_modifiers.lua
of_modifiers.lua of_modifiers.lua of_modifiers.lua of_modifiers.lua
of_modmenu.lua of_music.lua of_mute.lua of_mute.lua of_mute.lua
of_net.lua of_night.lua of_panel.lua of_panel.lua of_pass.lua
of_pause.lua of_pets.lua of_pets.lua of_playlist.lua of_possess.lua
of_possess.lua of_powerups.lua of_presence.lua of_rando.lua of_rando.lua
of_rando.lua of_ranks.lua of_recent.lua of_replay.lua of_reserve.lua
of_reserve.lua of_roundact.lua of_roundbrief.lua of_rounds.lua
of_roundscope.lua of_rules.lua of_rules.lua of_rules.lua of_rules.lua
of_rules.lua of_rules.lua of_rules.lua of_rules.lua of_shuffle.lua
of_sign.lua of_sign.lua of_slots.lua of_smb3.lua of_spawner.lua
of_spawner.lua of_spawner.lua of_spawner.lua of_spectate.lua
of_speedrun.lua of_speedrun.lua of_split.lua of_spray.lua of_stats.lua
of_studio.lua of_swap.lua of_swap.lua of_tags.lua of_tags.lua of_tas.lua
of_tas.lua of_teams.lua of_texshuffle.lua of_theme.lua of_theme.lua
of_together.lua of_tournament.lua of_trouble.lua of_unstick.lua
of_unstick.lua of_unstick.lua of_util.lua of_util.lua of_venues.lua
of_vote.lua of_warp.lua of_warp.lua of_warp.lua of_welcome.lua
of_welcome.lua
]],
    HOOK_USE_ACT_SELECT = [[
of_gamemodes.lua of_gm_hideseek.lua of_roundact.lua
]],
}

local hookFiles = {}
for hook, packed in pairs(HOOK_FILE_MAP) do
    local list = {}
    for name in string.gmatch(packed, "%S+") do list[#list + 1] = name end
    hookFiles[hook] = list
end

function OF.hook_file(hookType, seq)
    local list = hookFiles[hookNames[hookType] or ""]
    if list == nil then return nil end
    return list[seq]
end

function OF.hook_said(message)
    return (string.gsub(message, '%[string "[^"]*"%]:', "[...]:"))
end

local FANNED = {
    [HOOK_UPDATE] = true,
    [HOOK_MARIO_UPDATE] = true,
    [HOOK_BEFORE_MARIO_UPDATE] = true,
    [HOOK_ON_LEVEL_INIT] = true,
    [HOOK_ON_PLAYER_CONNECTED] = true,
    [HOOK_ON_PLAYER_DISCONNECTED] = true,
    [HOOK_ON_MODS_LOADED] = true,
    [HOOK_ON_PACKET_RECEIVE] = true,

    [HOOK_ON_INTERACT] = true,
    [HOOK_ON_PVP_ATTACK] = true,
    [HOOK_ON_SYNC_VALID] = true,
    [HOOK_ON_HUD_RENDER] = "reset",
    [HOOK_ON_HUD_RENDER_BEHIND] = "reset",
}

local chains = {}

local chainInfo = setmetatable({}, { __mode = "k" })

OF.LOCAL_MARIO = "local"
local LOCAL_TYPES = { [HOOK_MARIO_UPDATE] = true, [HOOK_BEFORE_MARIO_UPDATE] = true }

OF.HOOK_ERRORS_MAX = 64
OF.HOOK_ERRORS_OVERFLOW = "(more distinct errors than /ofdiag keeps)"
local function keep_error(key)
    if OF.hookErrors[key] == nil then
        if OF.hookErrorCount >= OF.HOOK_ERRORS_MAX then key = OF.HOOK_ERRORS_OVERFLOW end
        if OF.hookErrors[key] == nil then OF.hookErrorCount = OF.hookErrorCount + 1 end
    end
    OF.hookErrors[key] = (OF.hookErrors[key] or 0) + 1
end

local function record_throw(label, said)
    keep_error(label .. ": " .. OF.hook_said(tostring(said)))
end

function OF.record_fault(label, said)
    record_throw(tostring(label), said)
end

OF.QUARANTINE_AFTER = 300
OF.QUARANTINE_EVERY = 30
OF.quarantined = OF.quarantined or {}
local QUARANTINABLE = { [HOOK_UPDATE] = true, [HOOK_MARIO_UPDATE] = true,
    [HOOK_BEFORE_MARIO_UPDATE] = true, [HOOK_ON_HUD_RENDER] = true,
    [HOOK_ON_HUD_RENDER_BEHIND] = true }

local function faulted(info, said)
    record_throw(info.label, said)
    info.streak = (info.streak or 0) + 1
    if info.rest == nil and info.streak >= OF.QUARANTINE_AFTER and QUARANTINABLE[info.hookType] then
        info.rest = 0
        OF.quarantined[info.label] = true
    end
end

local function due(info)
    info.rest = info.rest + 1
    if info.rest < OF.QUARANTINE_EVERY then return false end
    info.rest = 0
    return true
end

local function healed(info)
    info.streak = nil
    if info.rest ~= nil then
        info.rest = nil
        OF.quarantined[info.label] = nil
    end
end

function OF.hook_quarantined()
    local list = {}
    for label in pairs(OF.quarantined) do list[#list + 1] = label end
    table.sort(list)
    return list
end

local hudMoved = false
local HUD_SETTERS = { "djui_hud_set_resolution", "djui_hud_set_font", "djui_hud_set_rotation",
    "djui_hud_set_rotation_interpolated", "djui_hud_set_text_alignment", "djui_hud_set_color",
    "djui_hud_set_text_color", "djui_hud_set_filter", "djui_hud_set_viewport", "djui_hud_set_scissor",
    "djui_hud_reset_color", "djui_hud_reset_text_color", "djui_hud_reset_viewport", "djui_hud_reset_scissor" }
local hudWrappers = {}
for _, name in ipairs(HUD_SETTERS) do
    local real = _ENV[name]
    if type(real) == "function" then
        local wrapper = function(...)
            hudMoved = true
            return real(...)
        end
        hudWrappers[name] = wrapper
        _ENV[name] = wrapper
    end
end
local function hud_wrappers_in_place()
    for name, wrapper in pairs(hudWrappers) do
        if _ENV[name] ~= wrapper then return false end
    end
    return true
end

function OF.hud_reset_params()
    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)
    djui_hud_set_rotation(0, _G.ROTATION_PIVOT_X_LEFT or 0, _G.ROTATION_PIVOT_Y_TOP or 0)
    local align = _G.djui_hud_set_text_alignment
    if align ~= nil then align(_G.TEXT_HALIGN_LEFT or 0, _G.TEXT_VALIGN_TOP or 0) end
    local colour = _G.djui_hud_reset_color
    if colour ~= nil then colour() else djui_hud_set_color(255, 255, 255, 255) end
    local textColour = _G.djui_hud_reset_text_color
    if textColour ~= nil then textColour() end
    djui_hud_set_filter(FILTER_NEAREST)
    local viewport = _G.djui_hud_reset_viewport
    if viewport ~= nil then viewport() end
    local scissor = _G.djui_hud_reset_scissor
    if scissor ~= nil then scissor() end
end

function OF.hook_chain(hookType)
    return chains[hookType]
end

function OF.hook_slots()
    local slots, subscribers = 0, 0
    for hookType, count in pairs(hookCounts) do
        subscribers = subscribers + count
        slots = slots + (FANNED[hookType] and 1 or count)
    end
    return slots, subscribers
end

OF.packets = OF.packets or {}
OF.packets.kinds = OF.packets.kinds or {}
OF.packets.refused = OF.packets.refused or {}
OF.packets.routed = OF.packets.routed or 0

function OF.finite(x)
    return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

function OF.packet_round()
    local seed = gGlobalSyncTable ~= nil and gGlobalSyncTable.ofGmSeed or nil
    if type(seed) ~= "number" then return 0 end
    return seed
end

function OF.packet_stamp(data)
    if type(data) == "table" then data.r = OF.packet_round() end
    return data
end

function OF.packet_kind(ofp, spec, handler)
    if type(ofp) ~= "string" or type(handler) ~= "function" then return false end
    OF.packets.kinds[ofp] = { spec = spec or {}, handler = handler }
    return true
end

function OF.packet_field_ok(kind, value)
    local optional = string.sub(kind, -1) == "?"
    if optional then kind = string.sub(kind, 1, -2) end
    if value == nil then return optional end
    if kind == "any" then return true end
    if kind == "str" then return type(value) == "string" and #value >= 1 and #value <= 256 end
    if kind == "bool" then return type(value) == "boolean" end
    if not OF.finite(value) then return false end
    if kind == "finite" then return true end
    if math.floor(value) ~= value then return false end
    if kind == "int" then return true end
    if kind == "gi" then return value >= 0 and value < (MAX_PLAYERS or 16) end
    return false
end

function OF.packet_valid(data, spec)
    if type(data) ~= "table" then return false, "not a table" end
    spec = spec or {}
    if spec.round == true and data.r ~= OF.packet_round() then
        return false, "another round"
    end
    for name, kind in pairs(spec.fields or {}) do
        if not OF.packet_field_ok(kind, data[name]) then return false, name end
    end
    return true
end

function OF.packet_route(data)
    if type(data) ~= "table" or type(data.ofp) ~= "string" then return false end
    local kind = OF.packets.kinds[data.ofp]
    if kind == nil then return false end
    local ok, why = OF.packet_valid(data, kind.spec)
    if not ok then
        local key = data.ofp .. ": " .. tostring(why)
        OF.packets.refused[key] = (OF.packets.refused[key] or 0) + 1
        return true
    end
    OF.packets.routed = OF.packets.routed + 1
    local fine, err = pcall(kind.handler, data)
    if not fine then
        local key = data.ofp .. ": threw " .. OF.hook_said(tostring(err))
        OF.packets.refused[key] = (OF.packets.refused[key] or 0) + 1
    end
    return true
end

function hook_event(hookType, fn, scope)

    if type(fn) ~= "function" then

        local seq = (hookCounts[hookType] or 0) + 1
        local named = OF.hook_file(hookType, seq)
        local key = (hookNames[hookType] or ("hook " .. tostring(hookType)))
            .. " #" .. tostring(seq)
            .. (named and (" " .. named) or "")
            .. ": registered with " .. type(fn) .. ", not a function"
        if OF.hookErrors[key] == nil then
            OF.hookErrorCount = OF.hookErrorCount + 1
        end
        OF.hookErrors[key] = (OF.hookErrors[key] or 0) + 1
        return 0
    end

    hookCounts[hookType] = (hookCounts[hookType] or 0) + 1
    local seq = hookCounts[hookType]

    local named = OF.hook_file(hookType, seq)
    local label = (hookNames[hookType] or ("hook " .. tostring(hookType)))
        .. " #" .. seq
        .. (named and (" " .. named) or "")

    local wrapped = function(...)

        if OF.costWatch then
            local began = clock_elapsed_f64 and clock_elapsed_f64() or nil
            local ok, a, b, c = pcall(fn, ...)
            if began ~= nil and clock_elapsed_f64 then
                local spent = clock_elapsed_f64() - began
                local was = OF.costOf[label]
                if was == nil or spent > was then OF.costOf[label] = spent end
            end
            if ok then return a, b, c end
            record_throw(label, a)
            return nil
        end

        local ok, a, b, c = pcall(fn, ...)
        if ok then return a, b, c end

        record_throw(label, a)
        return nil
    end

    if not FANNED[hookType] then return engine_hook_event(hookType, wrapped) end

    local chain = chains[hookType]
    if chain == nil then
        chain = {}
        chains[hookType] = chain

        if FANNED[hookType] == "reset" then

            engine_hook_event(hookType, function(...)
                local trusted = hud_wrappers_in_place()
                local watch = OF.costWatch
                hudMoved = false
                for i = 1, #chain do
                    if i > 1 and (hudMoved or not trusted) then
                        OF.hud_reset_params()
                        hudMoved = false
                    end
                    local link = chain[i]
                    local info = chainInfo[link]
                    if info == nil or watch then
                        link(...)
                    elseif info.rest == nil or due(info) then
                        local ok, said = pcall(info.fn, ...)
                        if not ok then faulted(info, said)
                        elseif info.streak ~= nil then healed(info) end
                    end
                end
            end)
        elseif LOCAL_TYPES[hookType] then

            engine_hook_event(hookType, function(m, ...)
                local remote = m ~= nil and m.playerIndex ~= 0
                local watch = OF.costWatch
                for i = 1, #chain do
                    local link = chain[i]
                    local info = chainInfo[link]
                    if info == nil or watch then
                        link(m, ...)
                    elseif not (remote and info.localOnly)
                        and (info.rest == nil or due(info)) then
                        local ok, said = pcall(info.fn, m, ...)
                        if not ok then faulted(info, said)
                        elseif info.streak ~= nil then healed(info) end
                    end
                end
            end)
        elseif hookType == HOOK_ON_PACKET_RECEIVE then

            engine_hook_event(hookType, function(data, ...)
                if OF.packet_route(data) then return end
                local watch = OF.costWatch
                for i = 1, #chain do
                    local link = chain[i]
                    local info = chainInfo[link]
                    if info == nil or watch then
                        link(data, ...)
                    else
                        local ok, said = pcall(info.fn, data, ...)
                        if not ok then record_throw(info.label, said) end
                    end
                end
            end)
        else
            engine_hook_event(hookType, function(...)
                local watch = OF.costWatch
                for i = 1, #chain do
                    local link = chain[i]
                    local info = chainInfo[link]
                    if info == nil or watch then
                        link(...)
                    elseif info.rest == nil or due(info) then
                        local ok, said = pcall(info.fn, ...)
                        if not ok then faulted(info, said)
                        elseif info.streak ~= nil then healed(info) end
                    end
                end
            end)
        end
    end
    table.insert(chain, wrapped)
    chainInfo[wrapped] = { fn = fn, label = label, hookType = hookType,
        localOnly = scope == OF.LOCAL_MARIO and LOCAL_TYPES[hookType] == true }
    return 1
end

OF.costOf = OF.costOf or {}
OF.costWatch = OF.costWatch or nil

function OF.watch_cost(on)
    OF.costWatch = (on == true) or nil
    if not OF.costWatch then return false end
    for key in pairs(OF.costOf) do OF.costOf[key] = nil end
    return true
end

function OF.hook_costs(most)
    local list = {}
    for name, seconds in pairs(OF.costOf) do
        table.insert(list, { name = name, seconds = seconds })
    end
    table.sort(list, function(x, y)
        if x.seconds ~= y.seconds then return x.seconds > y.seconds end
        return x.name < y.name
    end)
    while most ~= nil and #list > most do table.remove(list) end
    return list
end

function OF.hook_errors()
    local list = {}
    for text, count in pairs(OF.hookErrors) do
        table.insert(list, { text = text, count = count })
    end
    table.sort(list, function(x, y)
        if x.count ~= y.count then return x.count > y.count end
        return x.text < y.text
    end)
    return list
end

OF.wireWatch = OF.wireWatch or nil
OF.wireSent = OF.wireSent or {}
OF.wireTried = OF.wireTried or {}
OF.wirePosted = OF.wirePosted or {}
OF.wireWorst = OF.wireWorst or {}
OF.wireMoments = OF.wireMoments or {}

local WIRE_KEEP = 6

local wireFrameSent, wireFrameTried, wireFramePosted = 0, 0, 0
local wireLabel = nil

local wireBegan, wireFrames = nil, 0
local wireTotalSent, wireTotalTried, wireTotalPosted = 0, 0, 0

function OF.watch_wire(on)
    OF.wireWatch = (on == true) or nil
    for key in pairs(OF.wireSent) do OF.wireSent[key] = nil end
    for key in pairs(OF.wireTried) do OF.wireTried[key] = nil end
    for key in pairs(OF.wirePosted) do OF.wirePosted[key] = nil end
    for key in pairs(OF.wireMoments) do OF.wireMoments[key] = nil end
    while #OF.wireWorst > 0 do table.remove(OF.wireWorst) end
    wireFrameSent, wireFrameTried, wireFramePosted = 0, 0, 0
    wireLabel = nil
    wireFrames, wireTotalSent, wireTotalTried, wireTotalPosted = 0, 0, 0, 0
    wireBegan = OF.wireWatch and clock_elapsed_f64 ~= nil
        and clock_elapsed_f64() or nil
    return OF.wireWatch == true
end

function OF.note_sync(key, sent)
    local name = tostring(key)
    wireFrameTried = wireFrameTried + 1
    OF.wireTried[name] = (OF.wireTried[name] or 0) + 1
    if not sent then return end
    wireFrameSent = wireFrameSent + 1
    OF.wireSent[name] = (OF.wireSent[name] or 0) + 1
end

function OF.note_packet(kind)
    local name = tostring(kind or "unnamed")
    wireFramePosted = wireFramePosted + 1
    OF.wirePosted[name] = (OF.wirePosted[name] or 0) + 1
end

function OF.wire_mark(label)
    if not OF.wireWatch then return false end
    wireLabel = tostring(label)
    return true
end

local function wire_roll()
    wireFrames = wireFrames + 1
    wireTotalSent = wireTotalSent + wireFrameSent
    wireTotalTried = wireTotalTried + wireFrameTried
    wireTotalPosted = wireTotalPosted + wireFramePosted

    if wireLabel ~= nil then
        local was = OF.wireMoments[wireLabel]
        if was == nil then
            OF.wireMoments[wireLabel] = { sent = wireFrameSent,
                tried = wireFrameTried, posted = wireFramePosted, times = 1 }
        else
            was.times = was.times + 1
            if wireFrameSent + wireFramePosted > was.sent + was.posted then
                was.sent, was.tried, was.posted =
                    wireFrameSent, wireFrameTried, wireFramePosted
            end
        end
    end

    if wireFrameSent + wireFramePosted > 0 then
        table.insert(OF.wireWorst, {
            sent = wireFrameSent, tried = wireFrameTried,
            posted = wireFramePosted, label = wireLabel,
        })
        table.sort(OF.wireWorst, function(x, y)
            local a = x.sent + x.posted
            local b = y.sent + y.posted
            if a ~= b then return a > b end
            return (x.tried or 0) > (y.tried or 0)
        end)
        while #OF.wireWorst > WIRE_KEEP do table.remove(OF.wireWorst) end
    end

    wireFrameSent, wireFrameTried, wireFramePosted = 0, 0, 0
    wireLabel = nil
end

OF.wire_roll = wire_roll

function OF.wire_keys(most)
    local list = {}
    for name, sent in pairs(OF.wireSent) do
        table.insert(list, { name = name, sent = sent,
            tried = OF.wireTried[name] or sent })
    end

    for name, tried in pairs(OF.wireTried) do
        if OF.wireSent[name] == nil then
            table.insert(list, { name = name, sent = 0, tried = tried })
        end
    end
    table.sort(list, function(x, y)
        if x.sent ~= y.sent then return x.sent > y.sent end
        if x.tried ~= y.tried then return x.tried > y.tried end
        return x.name < y.name
    end)
    while most ~= nil and #list > most do table.remove(list) end
    return list
end

function OF.wire_moments()
    local list = {}
    for name, entry in pairs(OF.wireMoments) do
        table.insert(list, { name = name, sent = entry.sent,
            tried = entry.tried, posted = entry.posted, times = entry.times })
    end
    table.sort(list, function(x, y)
        local a, b = x.sent + x.posted, y.sent + y.posted
        if a ~= b then return a > b end
        return x.name < y.name
    end)
    return list
end

function OF.wire_packets(most)
    local list = {}
    for name, count in pairs(OF.wirePosted) do
        table.insert(list, { name = name, count = count })
    end
    table.sort(list, function(x, y)
        if x.count ~= y.count then return x.count > y.count end
        return x.name < y.name
    end)
    while most ~= nil and #list > most do table.remove(list) end
    return list
end

function OF.wire_rate()
    local seconds = nil
    if wireBegan ~= nil and clock_elapsed_f64 ~= nil then
        seconds = clock_elapsed_f64() - wireBegan
    end
    if seconds == nil or seconds <= 0 then seconds = nil end
    local peakSent, peakPosted = 0, 0
    for _, entry in ipairs(OF.wireWorst) do
        if entry.sent > peakSent then peakSent = entry.sent end
        if entry.posted > peakPosted then peakPosted = entry.posted end
    end
    return {
        frames = wireFrames,
        seconds = seconds,
        sent = wireTotalSent, tried = wireTotalTried, posted = wireTotalPosted,
        sentPerSecond = seconds and (wireTotalSent / seconds) or nil,
        postedPerSecond = seconds and (wireTotalPosted / seconds) or nil,
        peakSent = peakSent, peakPosted = peakPosted,
    }
end

local function sync_store(syncTable)
    if syncTable == nil then return nil end
    local inner = rawget(syncTable, "_table")
    if type(inner) == "table" then return inner end
    return nil
end

OF.sync_store = sync_store

function OF.wire_census()
    local globals, rows, empty = 0, 0, 0
    local store = sync_store(gGlobalSyncTable)
    if store ~= nil then
        for _ in pairs(store) do globals = globals + 1 end
    end
    if gPlayerSyncTable ~= nil then
        for index = 0, 15 do
            local row = sync_store(gPlayerSyncTable[index])
            if row ~= nil then
                local held = 0
                for _ in pairs(row) do held = held + 1 end
                rows = rows + held
                local np = gNetworkPlayers ~= nil and gNetworkPlayers[index] or nil
                if np == nil or not np.connected then empty = empty + held end
            end
        end
    end
    return globals, rows, empty
end

local record_throw = keep_error

local function caught(fn, label, onThrow)
    if type(fn) ~= "function" then return fn end
    return function(...)
        local ok, a, b, c = pcall(fn, ...)
        if ok then return a, b, c end
        record_throw(label .. ": " .. OF.hook_said(tostring(a)))
        return onThrow
    end
end

local engine_sync_change = hook_on_sync_table_change
function hook_on_sync_table_change(tbl, field, fallback, fn)
    return engine_sync_change(tbl, field, fallback,
        caught(fn, "sync change " .. tostring(field), nil))
end

local engine_mario_action = hook_mario_action
function hook_mario_action(action, spec, ...)
    if type(spec) == "function" then
        return engine_mario_action(action,
            caught(spec, "action " .. tostring(action), -1), ...)
    end
    if type(spec) == "table" then
        local wrapped = {}
        for name, fn in pairs(spec) do
            wrapped[name] = caught(fn,
                "action " .. tostring(action) .. " " .. tostring(name), -1)
        end
        return engine_mario_action(action, wrapped, ...)
    end
    return engine_mario_action(action, spec, ...)
end

local engine_behavior = hook_behavior
function hook_behavior(bhvId, objList, replace, initFn, loopFn, name)

    local tag = "behavior " .. tostring(name or bhvId or "unnamed")
    return engine_behavior(bhvId, objList, replace,
        caught(initFn, tag .. " init", nil),
        caught(loopFn, tag .. " loop", nil), name)
end

local PARTS = "actionlog.build_page actobjects.ready arena.build_sweep_page ball.ready bingo.forget_line camera celebrate.watch_scores courseground.ready texshuffle.ready chaos.ready charselect.restore_palette chatlog.clear cheats.build_rows clones.ready corpse.ready costumes.build_group_page "
    .. "doorways.build_rows emotes.build_page "
    .. "enemies.count filter find.ready forge.menu_rows fresh.run gamemodes.ready ground.ready guard.row_report guide.build_page "
    .. "harsh.report hats.build_group_page "
    .. "hud.reveal_cues hudmenu:hud.menu_chips idle.ready "
    .. "input.aim_layer jail.chat_appeal lang.plural ledger.build_entry_row levelfix.count lobbytalk logic.register lockdown.report "
    .. "mapvote.place_of markers.build_rows moves.count "
    .. "modifiers.build_rows modmenu:settings.set_allow_save_edits music "
    .. "mute.chat_mute net.refuses_move night.is_on notes.note_row "
    .. "notify.themed outseat.leave_hint panel.teleport_command panelskin.footer pass.ready shortcuts.forget mapgrid.render uisfx.rows pause.render perms.build_shields_page "
    .. "playlist.ready persist.ready pets.build_page possess.hides_from_world powerups.give_many "
    .. "presence.location quick.build_page ragdoll.ready rando.ready roundbrief.original_star roundscope.render_outsider ranks.build_who_page recent.build_reports_page "
    .. "replay.ready reserve.forget roommods roundact.skips_act_select rounds together.build_practice "
    .. "rules save.build_bulk_page scoreboard.ready "
    .. "shuffle.off smb3.ready sign.summary slots.ready spawner.spawn spectate.toggle speedrun.build_star_page split.tally_width spray.ready stretch.lua_restarted studio.ready swap.ready tournament.ready "
    .. "shellride.ready "
    .. "smashitems.ready smashrules.ready smashshield.ready "
    .. "standings.ready stats.ready tags.ready tas.build_page teams.draw_sides theme.build_screen_page trouble.sidelined underside.stick_frame unstick.ready util.coin_score venues.ready vote "
    .. "warp.loaded waypoints.chat_save welcome.name_the_widgets whoplays.ready zelda.ready"
local MODES = "turf football rocketarena assassins bank booksquirm bounty coinrush shooter bossrush chompfever copsandrobbers crown ctf deflect domination flood frenzy glassbridge hexagone hexheat hideseek hotpotato hotrope koth laststanding lavaleave line logroll manhunt blast bombsaway blizzard bombxing blastgrid bumperballs murder oitc prophunt greendemon shellrace silverfive simon smash spots sumo wanted rabbitchase bombsort flyguy lakitu onoffclimb megarampage zombies hideballoon sardines shellbattle downhill volleyball oneflag firesweep snd"
OF.SHIPPED_FILES = 179

OF.MODES_SHARING_A_FILE = {

}

local function is_object(value)
    local kind = type(value)
    return kind == "userdata" or kind == "table"
end

OF.is_object = is_object

function OF.own_mod()
    local mods = gActiveMods
    if not is_object(mods) then return nil end

    for index = 0, 63 do
        local mod = mods[index]
        if is_object(mod) and type(mod.name) == "string"
            and string.find(mod.name, "oldfart", 1, true) then
            return mod
        end
    end
    return nil
end

function OF.files_on_disk()
    local mod = OF.own_mod()
    if mod == nil then return nil end
    local count = mod.fileCount
    if type(count) ~= "number" or count <= 0 then return nil end
    return count
end

OF.EXPECTED_MODES = {}
for key in string.gmatch(MODES, "%S+") do
    table.insert(OF.EXPECTED_MODES, key)
end

local PART_NAMES = {}
for part in string.gmatch(PARTS, "%S+") do

    local file, rest = string.match(part, "^([%w_]+):(.+)$")
    if rest == nil then rest = part end

    local mod, fn = string.match(rest, "^([%w_]+)%.([%w_]+)$")
    if mod == nil then mod, fn = rest, "build_page" end

    if file == nil then file = mod end

    table.insert(PART_NAMES, { file = file, mod = mod, fn = fn })
end

local function part_ok(entry)
    local table_ = OF[entry.mod]
    return type(table_) == "table" and table_[entry.fn] ~= nil
end

local function mode_ok(key)
    local modes = OF.gamemodes
    local registry = type(modes) == "table" and modes.BY_KEY or nil
    return registry ~= nil and registry[key] ~= nil
end

function OF.all_parts()
    local parts = {}

    for _, entry in ipairs(PART_NAMES) do
        table.insert(parts, {
            name = entry.file, kind = "file", ok = part_ok(entry),
        })
    end

    for _, key in ipairs(OF.EXPECTED_MODES) do
        table.insert(parts, { name = key, kind = "mode", ok = mode_ok(key) })
    end

    return parts
end

function OF.missing_parts()
    local missing = {}
    for _, entry in ipairs(PART_NAMES) do
        if not part_ok(entry) then
            table.insert(missing, "of_" .. entry.file .. ".lua")
        end
    end
    for _, key in ipairs(OF.EXPECTED_MODES) do
        if not mode_ok(key) then
            table.insert(missing, "a gamemode (" .. key .. ")")
        end
    end
    return missing
end

local function say_load_report(text, role, opts)
    if OF.util ~= nil and type(OF.util.chat) == "function" then
        return OF.util.chat(text, role, opts)
    end
    local plain = text
    djui_chat_message_create(plain)
end

local function report_parts()
    local missing = OF.missing_parts()
    if #missing == 0 then return end
    say_load_report("oldfart's Lobby did not load fully: "
        .. table.concat(missing, ", "), "warn")
    say_load_report("Coop DX logged a script error for each."
        .. " Say so in the lobby - it explains what is not working.", nil, { more = true })
end

hook_event(HOOK_ON_MODS_LOADED, report_parts)

hook_event(HOOK_ON_MODS_LOADED, function()
    if not OF.util.asks(OF.util, "describe") then return end
    OF.util.describe("rando", { "start", "off" },
        "the run")
end)

hook_event(HOOK_ON_MODS_LOADED, function()
    if OF.net == nil or OF.net.register_action == nil then return end

    OF.net.register_action("queuestart", "speedrun", function(asker)
        return OF.rounds.start(asker)
    end)

    OF.net.register_action("queuestop", "end_round", function(asker)
        return OF.rounds.stop(false, asker)
    end)

    OF.net.register_action("queueadd", "speedrun", function(_, modeKey, arenaKey)
        return OF.rounds.add(modeKey ~= nil and tostring(modeKey) or nil,
            arenaKey ~= nil and tostring(arenaKey) or nil)
    end)
    OF.net.register_action("queuefill", "speedrun", function(_, arenaKey)
        return OF.rounds.fill_with_everything(
            arenaKey ~= nil and tostring(arenaKey) or nil)
    end)
    OF.net.register_action("queueclear", "speedrun", function()
        return OF.rounds.clear()
    end)
    OF.net.register_action("queuegap", "speedrun", function(_, seconds)
        return OF.rounds.set_breather(tonumber(seconds))
    end)
    OF.net.register_action("queueloop", "speedrun", function(_, on)
        return OF.rounds.set_repeating(tonumber(on) == 1)
    end)
    OF.net.register_action("votecancel", "settings", function(asker)
        return OF.vote.cancel(asker)
    end)

    OF.net.register_action("playlist", "speedrun", function(asker, on)
        return OF.playlist.set(tonumber(on) == 1, asker)
    end)

    OF.net.register_action("votestart", "vote", function(asker, kind, who, words)
        return OF.vote.start_here(asker, kind, who, words)
    end)

    OF.net.register_action("modset", "speedrun", function(asker, key, level)
        return OF.modifiers.set_level_here(asker, key, level)
    end)

    OF.net.register_action("modclear", "speedrun", function(asker)
        return OF.modifiers.clear_here(asker)
    end)

    OF.net.register_action("vision", "vision", function(asker, packed)
        return OF.modifiers.set_vision_here(asker, tostring(packed))
    end)

    OF.net.register_action("rule", "rules", function(asker, id, step)
        return OF.rules.set_here(asker, tostring(id), tonumber(step))
    end)

    OF.net.register_action("show", "vision", function(asker, key)
        return OF.theme.show_for_room(asker, tostring(key))
    end)

    OF.net.register_action("shape", "vision", function(asker, key)
        return OF.theme.shape_for_room(asker, tostring(key))
    end)

    OF.net.register_action("music", "music", function(asker, seq)
        return OF.music.set_lobby_here(asker, seq)
    end)

    OF.net.register_action("musicvol", "music", function(asker, percent)
        return OF.music.set_volume_here(asker, tonumber(percent))
    end)
    OF.net.register_action("musicround", "music", function(asker, policy)
        return OF.music.set_rounds_here(asker, tostring(policy))
    end)

    OF.net.register_action("musicask", "panel", function(asker, seq)
        return OF.music.request_here(asker, seq)
    end)

    OF.net.register_action("harsh", "rules", function(asker, key, step)
        return OF.harsh.set_here(asker, tostring(key), tonumber(step))
    end)
    OF.net.register_action("harshclear", "rules", function(asker)
        return OF.harsh.clear_here(asker)
    end)

    OF.net.register_action(OF.harsh.REPORT_ACTION, "harsh_report", function(asker, key)
        return OF.harsh.host_heard(key)
    end)

    OF.net.register_action("enemy", "speedrun", function(asker, key, step)
        return OF.enemies.set_here(asker, tostring(key), tonumber(step))
    end)
    OF.net.register_action("enemyclear", "speedrun", function(asker)
        return OF.enemies.clear_here(asker)
    end)
end)

local shippedMissingParts = OF.missing_parts
local shippedHookErrors = OF.hook_errors

local function any_part_missing()
    for _, entry in ipairs(PART_NAMES) do
        local table_ = OF[entry.mod]
        if type(table_) ~= "table" or table_[entry.fn] == nil then return true end
    end
    local modes = OF.gamemodes
    local registry = type(modes) == "table" and modes.BY_KEY or nil
    for _, key in ipairs(OF.EXPECTED_MODES) do
        if registry == nil or registry[key] == nil then return true end
    end
    return false
end

local NOTHING = {}

local function draw_missing()
    local missing
    if OF.missing_parts == shippedMissingParts and not any_part_missing() then
        missing = NOTHING
    else
        missing = OF.missing_parts and OF.missing_parts() or {}
    end
    if #missing == 0 and OF.hook_errors == shippedHookErrors
        and type(OF.hookErrors) == "table" and next(OF.hookErrors) == nil then
        return
    end
    local thrown = OF.hook_errors and OF.hook_errors() or {}

    if #missing == 0 and #thrown > 0 then
        djui_hud_set_resolution(RESOLUTION_DJUI)
        djui_hud_set_font(FONT_NORMAL)
        local width = djui_hud_get_screen_width()
        djui_hud_set_color(0, 0, 0, 170)
        djui_hud_render_rect(0, 0, width, 40)
        djui_hud_set_color(255, 90, 90, 255)
        djui_hud_print_text("oldfart's Lobby v" .. tostring(OF.VERSION)
            .. ": every file loaded, but " .. #thrown
            .. " hook(s) threw - /ofdiag names them", 8, 2, 0.7)
        djui_hud_set_color(230, 230, 230, 255)
        djui_hud_print_text(string.sub(thrown[1].text, 1, 90), 8, 20, 0.6)
        return
    end

    if #missing == 0 then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)
    local width = djui_hud_get_screen_width()

    local head = "oldfart's Lobby v" .. tostring(OF.VERSION) .. ": "
        .. #missing .. " file(s) did not load"
    local lines = {}
    local line = ""
    for index, name in ipairs(missing) do
        local piece = name .. (index < #missing and "," or "")
        if #line + #piece + 1 > 74 then
            table.insert(lines, line)
            line = piece
        else
            line = (line == "") and piece or (line .. " " .. piece)
        end
    end
    if line ~= "" then table.insert(lines, line) end

    local onDisk = OF.files_on_disk and OF.files_on_disk() or nil
    if onDisk ~= nil and OF.SHIPPED_FILES ~= nil and onDisk < OF.SHIPPED_FILES then
        table.insert(lines, "Only " .. onDisk .. " of " .. OF.SHIPPED_FILES
            .. " files are in the folder - copy the whole oldfart folder again.")
    elseif onDisk ~= nil then
        table.insert(lines, "All " .. onDisk .. " files are here but did not load"
            .. " - read the red script error above this.")
    else
        table.insert(lines, "Copy the whole oldfart folder over again - some files are missing.")
    end

    table.insert(lines, "Type /ofdiag for the full screen: every file, your rank, and what this build is missing.")

    djui_hud_set_color(0, 0, 0, 170)
    djui_hud_render_rect(0, 0, width, 22 + #lines * 16)
    djui_hud_set_color(255, 90, 90, 255)
    djui_hud_print_text(head, 8, 2, 0.7)
    djui_hud_set_color(230, 230, 230, 255)
    for index, text in ipairs(lines) do
        djui_hud_print_text(text, 8, 4 + index * 16, 0.6)
    end
end

OF.diagOpen = OF.diagOpen or false

local function ask(tbl, name, ...)
    if type(tbl) ~= "table" then return nil end
    local fn = tbl[name]
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if not ok then return nil end
    return value
end

local DIAG_MIN_COLUMNS = 4

local DIAG_MIN_COLUMN_WIDTH = 84
local DIAG_SCALE = 0.42

local DIAG_LINE = 14

local function yes_no(value)
    if value == nil then return "?" end
    return value and "yes" or "no"
end

local function diag_summary()
    local lines = {}
    local function add(label, value)
        table.insert(lines, { label = label, value = tostring(value) })
    end

    local onDisk = ask(OF, "files_on_disk")
    local parts = ask(OF, "all_parts") or {}
    local loaded = 0
    for _, part in ipairs(parts) do
        if part.ok then loaded = loaded + 1 end
    end

    add("build", "v" .. tostring(OF.VERSION))

    if onDisk ~= nil then
        add("files in the folder", onDisk .. " of " .. tostring(OF.SHIPPED_FILES or "?"))

    elseif not is_object(gActiveMods) then
        add("files in the folder", "cannot ask - this build has no gActiveMods")
    else
        local names, count = {}, 0
        for index = 0, 63 do
            local mod = gActiveMods[index]
            if is_object(mod) and type(mod.name) == "string" then
                count = count + 1
                if #names < 4 then
                    table.insert(names, mod.name .. "(" .. tostring(mod.fileCount) .. ")")
                end
            end
        end
        add("files in the folder", "not found among " .. count .. " mod(s): "
            .. table.concat(names, " ") .. (count > #names and " ..." or ""))
    end

    add("parts that answered", loaded .. " of " .. #parts)

    add("HUD frames drawn", tostring(OF.hudFrames or 0)
        .. ((OF.hudFrames or 0) == 0
            and "  <- THE HUD HOOK NEVER FIRED" or ""))

    local hitches = ask(OF.unstick, "hitch_lines") or {}
    local hitchCount = type(OF.unstick) == "table" and OF.unstick.hitchCount or 0
    local slow = "   slow frames: none over 0.1s"
    if #hitches > 0 then
        slow = "   slow frames: " .. tostring(hitchCount)
            .. " over 0.1s, worst " .. hitches[1]
    end
    add("update frames", tostring(OF.updateFrames or 0) .. slow)

    local mods, ours, names = 0, 0, {}
    if is_object(gActiveMods) then
        for index = 0, 63 do
            local mod = gActiveMods[index]
            if is_object(mod) and type(mod.name) == "string" then
                mods = mods + 1
                if string.find(mod.name, "oldfart", 1, true) then
                    ours = ours + 1
                    table.insert(names, mod.name)
                end
            end
        end
    end
    add("mods loaded here", tostring(mods))
    add("copies of this mod", tostring(ours)
        .. (ours > 1 and ("  <- TWO COPIES: " .. table.concat(names, " | ")) or ""))

    add("namespace put back", tostring(OF.namespaceRestored or 0)
        .. ((OF.namespaceRestored or 0) > 0
            and "  <- ANOTHER MOD IS REPLACING OF" or ""))
    add("values put back", tostring(OF.coloursRestored or 0))

    local thrown = OF.hook_errors and OF.hook_errors() or {}
    if #thrown == 0 then

        add("hooks that threw",
            "none since load - /ofdiag watch measures time instead")
    else
        add("hooks that threw", #thrown .. " distinct")

        local resting = OF.hook_quarantined and OF.hook_quarantined() or {}
        if #resting > 0 then
            add("quarantined", #resting .. " - " .. resting[1])
        end
        for index, entry in ipairs(thrown) do
            if index > 4 then
                add("", "+" .. (#thrown - 4) .. " more")
                break
            end
            add("  x" .. entry.count, entry.text)
        end
    end

    if OF.hook_slots ~= nil then
        local slots, subscribers = OF.hook_slots()
        add("engine hook slots", slots .. " of the lobby's 64 per type   ("
            .. subscribers .. " of ours behind them)")
    end

    if onDisk ~= nil and OF.SHIPPED_FILES ~= nil and onDisk < OF.SHIPPED_FILES then
        add("verdict", "THE FOLDER IS SHORT - copy it again")
    elseif loaded < #parts then
        add("verdict", "ALL FILES PRESENT, SOME THREW - read the script error")
    else
        add("verdict", "everything loaded")
    end

    local isHost = network_is_server ~= nil and network_is_server()

    local tidyClause = ""
    if type(OF.util) == "table" and type(OF.util.tidy_reading) == "function" then
        local okTidy, tidied = pcall(OF.util.tidy_reading)
        if okTidy and tidied ~= nil then tidyClause = "   save file tidied: " .. tidied end
    end
    add("this machine", (isHost and "the host" or "a guest") .. tidyClause)
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    add("name", np ~= nil and tostring(np.name) or "?")
    add("level / area", np ~= nil
        and (tostring(np.currLevelNum) .. " / " .. tostring(np.currAreaIndex))
        or "?")

    local tier = ask(OF.perms, "my_tier")
    add("rank", tostring(ask(OF.perms, "tier_label", tier) or "?")
        .. " (" .. tostring(tier or "?") .. ")")
    add("may open the mod menu", yes_no(ask(OF.perms, "can", "panel")))
    add("the mod menu needs", tostring(
        ask(OF.perms, "tier_label", ask(OF.perms, "required", "panel")) or "?"))
    add("the mod menu's controls threw",
        tostring(ask(OF.panel, "controller_failure") or "nothing"))

    if not isHost then
        add("shaking hands with the host", yes_no(ask(OF.pass, "settled")))
        add("the pass is stale", yes_no(ask(OF.pass, "stale")))
    end
    add("held by a sentence", yes_no(
        type(OF.jail) == "table" and OF.jail.active == true))
    add("in rounds", yes_no(ask(OF.util, "can_play", 0)))
    add("language", tostring(ask(OF.lang, "current") or "english"))

    if type(OF.music) == "table" and type(OF.music.slots_held) == "function" then
        local okSlots, held = pcall(OF.music.slots_held)
        local okPark, parked = pcall(OF.music.stream_parked)
        add("music slots held", tostring(okSlots and held or "?")
            .. "   a recording waits for the star select: "
            .. yes_no(okPark and parked ~= nil or nil))
    end

    if type(OF.tags) == "table" and type(OF.tags.answer_for) == "function" then
        local said = {}
        for i = 0, (MAX_PLAYERS or 16) - 1 do
            local np = gNetworkPlayers ~= nil and gNetworkPlayers[i] or nil
            if np ~= nil and np.connected then
                local ok, tag = pcall(OF.tags.answer_for, i)
                if ok and tag ~= nil and tag ~= np.name then
                    said[#said + 1] = tostring(np.name) .. ": "
                        .. (tag == "" and "(hidden)" or tostring(tag))
                end
            end
        end

        if #said > 0 then add("tags over heads", table.concat(said, "   ")) end
    end

    if type(OF.warp) == "table" and ((OF.warp.landShaped or 0) > 0
        or (OF.warp.landWarpsRefused or 0) > 0 or (OF.warp.seamsCarried or 0) > 0) then
        add("scaled world here", tostring(OF.warp.landShaped or 0) .. " shaped, "
            .. tostring(OF.warp.landWarpsRefused or 0) .. " seam(s) too long, "
            .. tostring(OF.warp.seamsCarried or 0) .. " carried")
    end

    local absent = type(OF.util) == "table" and OF.util.missing or nil
    if type(absent) == "table" then
        local names, count = {}, 0
        for name in pairs(absent) do
            count = count + 1
            if #names < 6 then table.insert(names, name) end
        end
        table.sort(names)
        add("engine bindings missing", count == 0 and "none"
            or (count .. ": " .. table.concat(names, " ")
                .. (count > #names and " ..." or "")))
    else
        add("engine bindings missing", "? (of_util did not load)")
    end

    local all = type(mod_storage_load_all) == "function"
        and select(2, pcall(mod_storage_load_all)) or nil
    if type(all) == "table" then
        local perms, ranks, other = {}, 0, 0
        for key, _ in pairs(all) do
            if string.sub(key, 1, 5) == "perm_" then
                table.insert(perms, string.sub(key, 6))
            elseif string.sub(key, 1, 5) == "rank_" then
                ranks = ranks + 1
            else
                other = other + 1
            end
        end
        table.sort(perms)
        add("stored permissions", #perms == 0 and "none"
            or (#perms .. ": " .. table.concat(perms, " ")))
        add("stored ranks", tostring(ranks))
        add("other stored keys", tostring(other))
    else
        add("stored permissions", "cannot ask - no mod_storage_load_all")
    end

    return lines
end

local function diag_lobby()
    local lines = {}
    local answers = type(OF.net) == "table" and OF.net.answers or nil

    for index = 0, 15 do
        local np = gNetworkPlayers ~= nil and gNetworkPlayers[index] or nil
        if is_object(np) and np.connected then
            local globalIndex = np.globalIndex
            local answer = type(answers) == "table" and answers[globalIndex] or nil
            local name = tostring(np.name or ("player " .. tostring(globalIndex)))

            if answer == nil then

                table.insert(lines, { name = name, ok = index == 0,
                    text = index == 0 and "this machine"
                        or "no answer yet - run /ofdiag there" })
            else
                local faults = {}
                if answer.panel == false then table.insert(faults, "rank cannot open the mod menu") end
                if answer.parts ~= "" then table.insert(faults, "files: " .. answer.parts) end
                if answer.bindings ~= "" then table.insert(faults, "missing: " .. answer.bindings) end
                if answer.version ~= tostring(OF.VERSION) then
                    table.insert(faults, "on v" .. answer.version)
                end

                if answer.controller ~= nil and answer.controller ~= "" then
                    table.insert(faults, "controls threw: " .. answer.controller)
                end

                if answer.drawing ~= nil and answer.drawing ~= "" then
                    table.insert(faults, "drawing threw: " .. answer.drawing)
                end
                table.insert(lines, { name = name, ok = #faults == 0,
                    text = #faults == 0 and ("everything loaded (v" .. answer.version .. ")")
                        or table.concat(faults, "; ") })
            end
        end
    end
    return lines
end

local function diag_watch()
    local lines = {}
    local function add(label, value)
        table.insert(lines, { label = label, value = value })
    end

    local rate = OF.wire_rate ~= nil and OF.wire_rate() or nil
    if rate ~= nil then
        local seconds = rate.seconds
        local since = seconds ~= nil
            and string.format("%.0f frames over %.1fs", rate.frames, seconds)
            or (rate.frames .. " frames")
        add("measuring since", since)

        local perSecond = rate.sentPerSecond ~= nil
            and string.format("  %.1f/s", rate.sentPerSecond) or ""
        add("sync writes", rate.sent .. " sent of " .. rate.tried
            .. " tried" .. perSecond
            .. "   worst frame " .. rate.peakSent)
        local packetsPerSecond = rate.postedPerSecond ~= nil
            and string.format("  %.1f/s", rate.postedPerSecond) or ""
        add("packets sent", tostring(rate.posted) .. packetsPerSecond
            .. "   worst frame " .. rate.peakPosted)
    end

    local worst = OF.wireWorst or {}
    if #worst == 0 then
        add("busiest frames", "nothing on the wire yet")
    else
        for index, entry in ipairs(worst) do
            if index > 4 then break end
            add(index == 1 and "busiest frames" or "",
                entry.sent .. " writes + " .. entry.posted .. " packets"
                .. (entry.tried > entry.sent
                    and ("  (" .. entry.tried .. " tried)") or "")
                .. "   " .. (entry.label or "no moment named"))
        end
    end

    local moments = OF.wire_moments ~= nil and OF.wire_moments() or {}
    if #moments == 0 then
        add("the named moments", "none reached yet")
    else
        for index, entry in ipairs(moments) do
            add(index == 1 and "the named moments" or "",
                entry.sent .. " writes + " .. entry.posted .. " packets"
                .. "   worst of " .. entry.times .. "x " .. entry.name)
        end
    end

    local keys = OF.wire_keys ~= nil and OF.wire_keys(3) or {}
    if #keys > 0 then
        local said = {}
        for _, entry in ipairs(keys) do
            table.insert(said, entry.name .. " x" .. entry.sent
                .. (entry.tried > entry.sent and ("/" .. entry.tried) or ""))
        end
        add("busiest keys", table.concat(said, "   "))
    end
    local posts = OF.wire_packets ~= nil and OF.wire_packets(3) or {}
    if #posts > 0 then
        local said = {}
        for _, entry in ipairs(posts) do
            table.insert(said, entry.name .. " x" .. entry.count)
        end
        add("busiest packets", table.concat(said, "   "))
    end

    if OF.wire_census ~= nil then
        local globals, rows, empty = OF.wire_census()
        add("a joiner costs the host", (globals + rows)
            .. " packets in one frame   (" .. globals .. " lobby + " .. rows
            .. " in rows, " .. empty .. " of them in rows nobody is sitting in)")
    end

    for _, line in ipairs(ask(OF.warp, "land_diag") or {}) do
        add(line.label, line.value)
    end

    local costs = OF.hook_costs ~= nil and OF.hook_costs(6) or {}
    if not OF.costWatch then
        add("worst frame per hook", "not measuring - /ofdiag watch turns it on")
    elseif #costs == 0 then
        add("worst frame per hook", "nothing measured yet")
    else
        for index, entry in ipairs(costs) do
            add(index == 1 and "worst frame per hook" or "",
                string.format("%.2f ms   %s", entry.seconds * 1000, entry.name))
        end
    end

    return lines
end

local function draw_diagnostics()
    if not OF.diagOpen then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)
    local width = djui_hud_get_screen_width()
    local height = djui_hud_get_screen_height()

    djui_hud_set_color(0, 0, 0, 235)
    djui_hud_render_rect(0, 0, width, height)

    djui_hud_set_color(255, 220, 80, 255)
    djui_hud_print_text("oldfart's Lobby - FULL DIAGNOSTIC - /ofdiag closes this",
        10, 6, 0.6)

    local row = math.max(9, math.min(14, math.floor(height / 54)))
    local valueX = math.max(120, width * 0.18)

    local y = 26
    for _, line in ipairs(diag_summary()) do
        djui_hud_set_color(150, 150, 160, 255)
        djui_hud_print_text(line.label, 12, y, DIAG_SCALE)

        if line.label == "verdict" then
            djui_hud_set_color(255, 200, 80, 255)
        else
            djui_hud_set_color(235, 235, 235, 255)
        end
        djui_hud_print_text(line.value, valueX, y, DIAG_SCALE)
        y = y + row
    end

    local lobby = diag_lobby()
    if #lobby > 0 then
        y = y + 8
        djui_hud_set_color(255, 220, 80, 255)
        djui_hud_print_text("the lobby - one line per player, from their own machine",
            10, y, 0.5)
        y = y + 16
        for _, line in ipairs(lobby) do
            djui_hud_set_color(235, 235, 235, 255)
            djui_hud_print_text(line.name, 12, y, DIAG_SCALE)
            if line.ok then
                djui_hud_set_color(120, 200, 120, 255)
            else
                djui_hud_set_color(255, 90, 90, 255)
            end
            djui_hud_print_text(line.text, valueX, y, DIAG_SCALE)
            y = y + row
        end
    end

    if OF.wireWatch then
        y = y + 8
        djui_hud_set_color(255, 220, 80, 255)
        djui_hud_print_text("what is spending the time - /ofdiag watch off puts the file grid back",
            10, y, 0.5)
        y = y + 18
        for _, line in ipairs(diag_watch()) do
            djui_hud_set_color(150, 150, 160, 255)
            djui_hud_print_text(line.label, 12, y, DIAG_SCALE)
            djui_hud_set_color(235, 235, 235, 255)
            djui_hud_print_text(line.value, valueX, y, DIAG_SCALE)
            y = y + row
        end
        return
    end

    y = y + 8
    djui_hud_set_color(255, 220, 80, 255)
    djui_hud_print_text("every part of the mod - of_<name>.lua, and the modes at the end",
        10, y, 0.5)
    y = y + 18

    local parts = ask(OF, "all_parts") or {}

    local space = height - y - 24
    local columns = DIAG_MIN_COLUMNS
    local rows = math.max(1, math.ceil(#parts / columns))
    while rows * row > space
        and (width - 24) / (columns + 1) >= DIAG_MIN_COLUMN_WIDTH do
        columns = columns + 1
        rows = math.max(1, math.ceil(#parts / columns))
    end
    local columnWidth = (width - 24) / columns

    for index, part in ipairs(parts) do
        local column = math.floor((index - 1) / rows)
        local line = (index - 1) % rows
        local x = 12 + column * columnWidth
        local lineY = y + line * row

        if part.ok then
            djui_hud_set_color(120, 200, 120, 255)
        else
            djui_hud_set_color(255, 90, 90, 255)
        end
        djui_hud_print_text((part.ok and "+ " or "X ")
            .. part.name .. (part.kind == "mode" and " *" or ""),
            x, lineY, DIAG_SCALE)
    end

    local bottom = math.min(height - 12 - DIAG_LINE, y + rows * row + 6)
    djui_hud_set_color(150, 150, 160, 255)
    djui_hud_print_text("+ answered    X did not    * is a gamemode rather than a file",
        12, bottom, 0.45)
end

hook_chat_command("ofdiag", "- the full diagnostic screen, on or off", function(rest)
    local word = type(rest) == "string" and string.lower(rest) or ""
    word = string.match(word, "^%s*(%a*)") or ""
    if word == "swatch" then
        local material = OF.forge ~= nil and type(OF.forge.build_material) == "function"
            and OF.forge.build_material() or nil
        local entry = material ~= nil and OF.util.asks(OF.spawner, "build_find")
            and OF.spawner.build_find("blk" .. material) or nil
        local name = (entry ~= nil and OF.util.asks(OF.forge, "picture_name"))
            and OF.forge.picture_name(entry) or (entry ~= nil and entry.swatch or nil)
        local said = "no block in hand"
        if name ~= nil then
            local ok, info = pcall(get_texture_info, name)
            if ok and info ~= nil then
                said = name .. ": " .. tostring(info.width) .. " x " .. tostring(info.height)
            else
                said = name .. ": nothing (" .. tostring(info) .. ")"
            end
        end
        OF.util.chat("swatch - " .. said)
        return true
    end

    if word == "watch" or word == "off" then
        local wanted = word == "watch"
        if OF.watch_wire ~= nil then OF.watch_wire(wanted) end
        if OF.watch_cost ~= nil then OF.watch_cost(wanted) end
        OF.diagOpen = wanted or OF.diagOpen
        OF.util.chat(wanted
            and "Measuring. Play until it freezes, then read this screen."
            or "Stopped measuring. /ofdiag watch starts again.")
        return true
    end

    OF.diagOpen = not OF.diagOpen
    OF.util.chat(OF.diagOpen
        and "Full diagnostic open. /ofdiag closes it."
        or "Full diagnostic closed.")
    return true
end)

local function after_the_menu(paint)
    if OF.util ~= nil and type(OF.util.menu_has_screen) == "function"
        and type(OF.util.above_menu) == "function"
        and OF.util.menu_has_screen()
        and OF.util.above_menu(paint) then
        return
    end
    pcall(paint)
end

hook_event(HOOK_ON_HUD_RENDER, function()

    OF.hudFrames = (OF.hudFrames or 0) + 1

    pcall(djui_hud_set_resolution, RESOLUTION_DJUI)
    pcall(djui_hud_set_font, FONT_NORMAL)

    pcall(keep_namespace)

    after_the_menu(draw_missing)
    after_the_menu(draw_diagnostics)
end)
