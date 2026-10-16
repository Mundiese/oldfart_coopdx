OF = OF or {}
OF.vote = OF.vote or {}

local vote = OF.vote

vote.SECONDS = 25

local SECONDS = vote.SECONDS
local COOLDOWN_SECONDS = 45
local MIN_VOTERS = 3

local ASKER_SECONDS = 150
local SUBJECT_SECONDS = 240

local ASK_SECONDS = 3

vote.YES = "yes"
vote.NO = "no"
vote.KINDS = {
    {
        key = "jail",
        needsTarget = true,

        hold = true,
        name = "Jail",

        question = function(name) return "Jail " .. name .. "?" end,

        localize = function(name)
            if name == nil then return nil end
            return OF.lang.fill("Jail @?", name)
        end,
        pass = function(target)
            if target == nil then return end

            if not OF.util.report(OF.jail.punish(target, "timeout",
                OF.lang.t("The lobby voted for it"))) then
                return
            end

            OF.notify.send_all("The lobby voted @ into timeout", "warn", 5,
                OF.util.name_safe(gNetworkPlayers[target].name))
        end,
    },
    {
        key = "skip",
        needsTarget = false,

        roundScoped = true,
        name = "End the round",
        question = function() return "End the round that is running?" end,
        localize = function()
            return OF.lang.t("End the round that is running?")
        end,
        pass = function()
            if OF.gamemodes.is_running() or OF.gamemodes.state() == OF.gamemodes.RESULTS
                or OF.gamemodes.state() == OF.gamemodes.LOBBY then
                OF.gamemodes.stop()
            elseif OF.speedrun.state() ~= OF.speedrun.OFF then
                OF.speedrun.stop()
            end

            OF.notify.send_all("The lobby voted to move on.", "info", 4)
        end,
    },

    {
        key = "finale",
        needsTarget = false,
        noAsker = true,
        name = "The finale",

        question = function() return OF.night.finale_question() end,
        pass = function() OF.night.choose_finale(true) end,
        fail = function() OF.night.choose_finale(false) end,
    },

    {
        key = "playlist",
        needsTarget = false,
        noAsker = true,
        name = "The next round",
        question = function() return OF.playlist.question() end,
        pass = function() OF.playlist.choose(true) end,
        fail = function() OF.playlist.choose(false) end,
    },

    {
        key = "ask",
        needsTarget = false,
        freeText = true,
        name = "A question",
        question = function(_, text) return text or "" end,
        pass = function(_, text)
            if OF.util.asks(OF.chatlog, "add_system") then

                OF.chatlog.add_system(OF.lang.fill("the lobby voted yes: @",
                    tostring(text or "")),
                    OF.util.asks(OF.actionlog, "auto")
                        and OF.actionlog.BY_THE_ROOM or nil)
            end
        end,

    },
}

vote.QUESTION_MAX = 120

function vote.clean_question(text)
    text = string.gsub(tostring(text or ""), "|", "/")
    text = string.gsub(text, "%s+", " ")
    text = string.gsub(text, "^ ", "")
    text = string.gsub(text, " $", "")
    return OF.util.cut_coloured(text, vote.QUESTION_MAX)
end

function vote.kind(key)
    for _, entry in ipairs(vote.KINDS) do
        if entry.key == key then return entry end
    end
    return nil
end

function vote.current()
    local packed = gGlobalSyncTable.ofVote
    if packed == nil or packed == "" then return nil end

    local kind, target, seconds, rest =
        string.match(packed, "^([^|]*)|([^|]*)|([^|]*)|(.*)$")
    if kind == nil or vote.kind(kind) == nil then return nil end

    local need, question = string.match(rest, "^(%d+)|(.*)$")
    if need == nil then question = rest end
    need = tonumber(need)
    if need ~= nil and need <= 0 then need = nil end

    local asker = nil
    if need ~= nil then
        local who, rest2 = string.match(question, "^(%-?%d+)|(.*)$")
        if who ~= nil then
            asker = tonumber(who)
            question = rest2
            if asker ~= nil and asker < 0 then asker = nil end
        end
    end

    return {
        kind = kind,
        target = tonumber(target),
        seconds = tonumber(seconds) or 0,
        need = need,
        asker = asker,
        question = question,
    }
end

function vote.asked_by(current)
    current = current or vote.current()
    if current == nil or current.asker == nil then return nil end
    return OF.util.local_from_global(current.asker)
end

function vote.localize(current)
    if current == nil then return "" end

    local kind = vote.kind(current.kind)
    if kind ~= nil and kind.localize ~= nil then
        local name = nil
        if current.target ~= nil then
            local li = OF.util.local_from_global(current.target)
            if li ~= nil then name = OF.util.name_safe(gNetworkPlayers[li].name) end
        end
        local text = kind.localize(name)
        if text ~= nil and text ~= "" then return text end
    end
    return current.question or ""
end

function vote.is_open()
    return vote.current() ~= nil
end

local function publish(kind, targetGlobal, seconds, need, askerGlobal, question)
    OF.util.publish("ofVote", table.concat({
        kind, tostring(targetGlobal or -1), tostring(seconds),
        tostring(need or 0), tostring(askerGlobal or -1), question
    }, "|"))
end

function vote.is_away(localIndex)
    if not OF.util.asks(OF.idle, "is_idle") then return false end
    return OF.idle.is_idle(localIndex) == true
end

function vote.roll_for(targetLocal, presentLocal)
    local list = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        if entry.localIndex ~= targetLocal
            and (entry.localIndex == presentLocal
                 or not vote.is_away(entry.localIndex)) then
            table.insert(list, entry)
        end
    end
    return list
end

function vote.voters()
    local current = vote.current()
    local targetLocal = current ~= nil and current.target ~= nil
        and OF.util.local_from_global(current.target) or nil
    return vote.roll_for(targetLocal)
end

function vote.away_count()
    local n = 0
    for _, entry in ipairs(OF.util.connected_players()) do
        if vote.is_away(entry.localIndex) then n = n + 1 end
    end
    return n
end

function vote.answer_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    if row == nil or row.ofVoted == nil then return "" end
    return row.ofVoted
end

function vote.tally()
    local yes, no, waiting = 0, 0, 0
    for _, entry in ipairs(vote.voters()) do
        local answer = vote.answer_of(entry.localIndex)
        if answer == vote.YES then yes = yes + 1
        elseif answer == vote.NO then no = no + 1
        else waiting = waiting + 1 end
    end
    return yes, no, waiting
end

function vote.bar_for(count)
    count = math.max(0, math.floor(tonumber(count) or 0))
    return math.floor(count / 2) + 1
end

local function needed()
    local current = vote.current()
    if current ~= nil and current.need ~= nil then return current.need end
    return vote.bar_for(#vote.voters())
end

vote.needed = needed

function vote.shows_split()
    local current = vote.current()
    if current == nil then return true end
    local kind = vote.kind(current.kind)
    return not (kind ~= nil and kind.hold == true)
end

function vote.count_text()
    local yes, no, waiting = vote.tally()
    if vote.shows_split() then
        return OF.lang.fill("@ yes / @ no", yes, no)
    end
    return OF.lang.fill("@ of @ answered", yes + no, yes + no + waiting)
end

function vote.answer(value)
    if not vote.is_open() then return false, OF.lang.t("There is no vote running.") end

    local current = vote.current()
    if current.target ~= nil
        and current.target == network_global_index_from_local(0) then
        return false, OF.lang.t("This one is about you.")
    end

    local already = vote.answer_of(0)
    local away = vote.is_away(0)
    if already == value and not away then
        if value == vote.YES then
            return false, OF.lang.t("You have already voted yes.")
        end
        return false, OF.lang.t("You have already voted no.")
    end

    if away and OF.util.asks(OF.idle, "mark_back") then
        OF.idle.mark_back()
    end

    OF.util.publish_row(0, "ofVoted", value)

    if OF.util.asks(OF.notify, "show") then
        if value == vote.YES and already == vote.NO then
            OF.notify.show("Changed to yes.", "good", 3)
        elseif value == vote.YES then
            OF.notify.show("You voted yes.", "good", 3)
        elseif already == vote.YES then
            OF.notify.show("Changed to no.", "good", 3)
        else
            OF.notify.show("You voted no.", "good", 3)
        end
    end
    return true
end

local hostTimer = 0

local cooldown = 0

local asked = 0
local askedKind = nil
local askedTarget = nil

local announced = nil

local askerWait = {}
local settled = {}

local myAskerWait = 0

function vote.forget_waits()
    askerWait = {}
    settled = {}
    myAskerWait = 0
end

local function wait_left()
    return gGlobalSyncTable.ofVoteWait or 0
end

local function subject_of(kindKey, targetGlobal, text)
    local subject = tostring(kindKey or "") .. "|" .. tostring(targetGlobal or -1)
    if text ~= nil and text ~= "" then
        subject = subject .. "|" .. string.lower(text)
    end
    return subject
end

local function asker_wait(askerGlobal)
    if OF.util.is_host() then return askerWait[askerGlobal] or 0 end
    if askerGlobal ~= nil and askerGlobal == network_global_index_from_local(0) then
        return myAskerWait
    end
    return 0
end

local function round_now()
    if OF.util.asks(OF.gamemodes, "is_running")
        and (OF.gamemodes.is_running() or OF.gamemodes.is_over()) then
        return "gm:" .. tostring(gGlobalSyncTable.ofGmKey or "")
    end
    if OF.util.asks(OF.speedrun, "state")
        and OF.speedrun.state() ~= OF.speedrun.OFF then
        return "run"
    end
    return ""
end

local openedRound = ""
local function is_system(kind)
    return kind ~= nil and kind.noAsker == true
end

function vote.asking()
    if asked <= 0 then return nil end
    return askedKind
end

local function close(passed, reason, byHost, askerLocal)
    if not OF.util.is_host() then return end

    local current = vote.current()

    local yes, no, bar = 0, 0, 0
    if current ~= nil then
        yes, no = vote.tally()
        bar = needed()
    end

    OF.util.publish("ofVote", "")
    cooldown = COOLDOWN_SECONDS * 30
    OF.util.publish("ofVoteWait", COOLDOWN_SECONDS)

    if current == nil then return end

    local closedKind = vote.kind(current.kind)
    local freeText = closedKind ~= nil and closedKind.freeText == true
    if not is_system(closedKind) then
        settled[subject_of(current.kind, current.target,
            freeText and current.question or nil)] = SUBJECT_SECONDS * 30
    end

    local name = (closedKind or {}).name or current.kind
    if freeText and current.question ~= nil and current.question ~= "" then
        name = current.question
    end

    if byHost then

        local who = OF.util.presser(askerLocal)
        if passed then
            if who ~= nil then
                OF.notify.send_all("@ passed this vote over the lobby",
                    "warn", 6, who)
            else
                OF.notify.send_all("The host passed this vote over the lobby", "warn", 6)
            end
        else
            if who ~= nil then
                OF.notify.send_all("@ refused this vote over the lobby",
                    "warn", 6, who)
            else
                OF.notify.send_all("The host refused this vote over the lobby", "warn", 6)
            end
        end
        OF.notify.send_all("It stood at @ yes and @ no", "info", 5, yes, no)
        if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
            OF.notify.credit_named(askerLocal, passed
                and OF.lang.t("passed this vote over the lobby")
                or OF.lang.t("refused this vote over the lobby"))
        end
        OF.actionlog.by_hand(who, passed
            and OF.lang.t("passed a vote over the lobby")
            or OF.lang.t("refused a vote over the lobby"))
    end

    if passed then
        local kind = vote.kind(current.kind)
        local targetLocal = current.target ~= nil
            and OF.util.local_from_global(current.target) or nil
        if kind ~= nil then kind.pass(targetLocal, current.question) end

        OF.notify.send_all("Vote passed: @ - @ said yes", "good", 5, name, yes)

        if targetLocal ~= nil then
            OF.recent.note(targetLocal, OF.lang.t("the lobby voted against them"))
        end
    else

        local kind = vote.kind(current.kind)
        if kind ~= nil and kind.fail ~= nil then
            kind.fail(current.target ~= nil
                and OF.util.local_from_global(current.target) or nil,
                current.question)

            if byHost then return end
            if yes + no == 0 then
                OF.notify.send_all("Nobody answered, so the other one carries it",
                    "info", 5)
            elseif yes == no then
                OF.notify.send_all("The lobby was split, so the other one carries it",
                    "info", 5)
            else
                OF.notify.send_all("The lobby voted the other way", "good", 4)
            end
            return
        end

        if freeText and OF.util.asks(OF.chatlog, "add_system") then
            OF.chatlog.add_system(OF.lang.fill("the lobby voted no: @",
                tostring(current.question or "")),
                OF.util.asks(OF.actionlog, "auto")
                    and OF.actionlog.BY_THE_ROOM or nil)
        end

        if OF.util.asked_in_chat() then
            OF.util.chat(OF.lang.t("The vote did not pass")
                .. (reason and (" - " .. reason) or "") .. ".")
        end

        if yes + no == 0 then
            OF.notify.send_all("Nobody answered: @", "info", 4, name)
        else
            OF.notify.send_all("Vote failed: @ - it needed @", "info", 4, name, bar)
        end
    end
end

vote.close = close

local function refusal(byLocal, kindKey, targetGlobal, text)
    if vote.is_open() then return "A vote is already running." end
    if wait_left() > 0 then return "There is still a wait before the next vote." end

    local kind = vote.kind(kindKey)
    if kind == nil then return "No such vote." end

    if not is_system(kind) then
        if asker_wait(network_global_index_from_local(byLocal)) > 0 then
            return "You asked the last one - give somebody else a turn."
        end
        if (settled[subject_of(kindKey, kind.needsTarget and targetGlobal or nil,
            kind.freeText and text or nil)] or 0) > 0 then
            return "The lobby has already answered that one."
        end
    end

    if kind.freeText and (text == nil or text == "") then
        return "Say what the lobby is being asked."
    end

    local targetLocal = nil

    if kind.needsTarget then
        if targetGlobal == nil then return "That vote needs somebody to be about." end
        targetLocal = OF.util.local_from_global(targetGlobal)
        if targetLocal == nil then return "That player has left." end
        if targetLocal == byLocal then return "You cannot start a vote about yourself." end

        if OF.ranks.get(targetLocal) >= OF.ranks.get(byLocal) then
            return "You cannot start a vote about somebody ranked above you."
        end
    end

    if #OF.util.connected_players() < MIN_VOTERS then
        return "There are too few people here for a vote."
    end

    if #vote.roll_for(targetLocal, byLocal) < 2 then
        return "Too many people here are away to hold a vote."
    end

    return nil
end

function vote.start_here(asker, kindKey, targetGlobal, text)
    if not OF.util.is_host() then return false, "Only the host opens a vote." end

    asker = tonumber(asker) or 0
    kindKey = tostring(kindKey or "")
    targetGlobal = tonumber(targetGlobal)

    text = text ~= nil and vote.clean_question(text) or nil

    if OF.perms.tier(asker) < OF.perms.required("vote", asker) then
        return false, "Your rank cannot start a vote."
    end

    local no = refusal(asker, kindKey, targetGlobal, text)
    if no ~= nil then return false, no end

    local kind = vote.kind(kindKey)
    local targetLocal = targetGlobal ~= nil
        and OF.util.local_from_global(targetGlobal) or nil

    local name = targetLocal ~= nil and gNetworkPlayers[targetLocal].name or ""
    local need = vote.bar_for(#vote.roll_for(targetLocal, asker))
    local askerGlobal = network_global_index_from_local(asker)
    publish(kindKey, targetGlobal, SECONDS, need, askerGlobal,
        kind.question(name, text))
    hostTimer = 0

    if not is_system(kind) then
        askerWait[askerGlobal] = ASKER_SECONDS * 30
    end

    openedRound = round_now()

    return true
end

function vote.start(kindKey, targetGlobal, text)
    if not OF.perms.can("vote") then return false, OF.lang.t("Your rank cannot start a vote.") end

    if text ~= nil then text = vote.clean_question(text) end

    if vote.is_away(0) and OF.util.asks(OF.idle, "mark_back") then
        OF.idle.mark_back()
    end

    if wait_left() > 0 then
        return false, OF.lang.fill("Wait @s before the next vote.", wait_left())
    end

    if asked > 0 then
        return false, OF.lang.t("You are already asking the host.")
    end

    local no = refusal(0, kindKey, targetGlobal, text)
    if no ~= nil then return false, OF.lang.t(no) end

    local ok, why = OF.net.host_does("votestart", kindKey, targetGlobal, text)
    if OF.util.is_host() then return ok, why end
    if not ok then return false, why end

    asked = ASK_SECONDS * 30
    askedKind = kindKey
    askedTarget = targetGlobal
    return true, OF.lang.t("Asking the host.")
end

function vote.cancel(askerLocal)
    if not OF.perms.can("settings") then
        return false, "Your rank cannot do that.", "settings"
    end
    if not vote.is_open() then return false, OF.lang.t("There is no vote running.") end

    if not OF.util.is_host() then return OF.net.host_does("votecancel") end

    local going = vote.current()
    if going ~= nil and going.asker ~= nil
        and not is_system(vote.kind(going.kind)) then
        askerWait[going.asker] = nil
    end

    OF.util.publish("ofVote", "")
    cooldown = 0
    OF.util.publish("ofVoteWait", nil)

    local who = OF.util.presser(askerLocal)
    if who ~= nil then
        OF.notify.send_all("@ called the vote off", "warn", 5, who)
    else
        OF.notify.send_all("The host called the vote off", "warn", 5)
    end
    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
        OF.notify.credit_named(askerLocal, OF.lang.t("called the vote off"))
    end
    OF.actionlog.by_hand(who, OF.lang.t("called the vote off"))

    if OF.util.asked_in_chat() then
        OF.util.chat(OF.lang.t("The host called the vote off."))
    end
    return true
end

function vote.force(passed, askerLocal)

    if not OF.perms.can("settings") then
        return false, "Your rank cannot do that.", "settings"
    end
    if not vote.is_open() then return false, OF.lang.t("There is no vote running.") end
    if not OF.util.is_host() then
        return OF.net.host_does("voteforce", passed and 1 or 0)
    end
    close(passed and true or false, "the host decided it", true, askerLocal)
    return true
end

function vote.withdraw(why)
    if not OF.util.is_host() then return false end
    if not vote.is_open() then return false end

    local going = vote.current()
    if going ~= nil and going.asker ~= nil
        and not is_system(vote.kind(going.kind)) then
        askerWait[going.asker] = nil
    end

    OF.util.publish("ofVote", "")

    cooldown = 0
    OF.util.publish("ofVoteWait", nil)

    OF.notify.send_all("The vote was withdrawn", "warn", 5)
    OF.notify.send_all(why or "there is nothing left to decide", "info", 5)
    return true
end

local function update()

    if myAskerWait > 0 then myAskerWait = myAskerWait - 1 end

    if asked > 0 then
        asked = asked - 1
        if asked == 0 then
            askedKind, askedTarget = nil, nil

            OF.notify.show("Nobody opened that vote", "info", 4)
        end
    end

    if not OF.util.is_host() then return end

    if cooldown > 0 then
        cooldown = cooldown - 1

        local seconds = math.ceil(cooldown / 30)
        if seconds <= 0 then seconds = nil end
        if gGlobalSyncTable.ofVoteWait ~= seconds then
            OF.util.publish("ofVoteWait", seconds)
        end
    end

    for who, left in pairs(askerWait) do
        if left <= 1 then askerWait[who] = nil else askerWait[who] = left - 1 end
    end
    for what, left in pairs(settled) do
        if left <= 1 then settled[what] = nil else settled[what] = left - 1 end
    end

    local current = vote.current()
    if current == nil then return end

    local kind = vote.kind(current.kind)
    if kind ~= nil then
        if kind.needsTarget then

            if current.target == nil
                or OF.util.local_from_global(current.target) == nil then
                vote.withdraw("the player it was about has left")
                return
            end

            if current.asker ~= nil
                and OF.util.local_from_global(current.asker) == nil then
                vote.withdraw("the person who asked it has left")
                return
            end
        end

        if kind.roundScoped and round_now() ~= openedRound then
            vote.withdraw("the round it was about has ended")
            return
        end
    end

    hostTimer = hostTimer + 1

    local yes, no, waiting = vote.tally()
    local bar = needed()

    if vote.shows_split() then

        if yes >= bar then
            close(true)
            return
        end
        if no >= bar or waiting == 0 then
            close(false, "not enough of the lobby")
            return
        end
    else

        if waiting == 0 then
            if yes >= bar then close(true) else close(false, "not enough of the lobby") end
            return
        end
    end

    if hostTimer % 30 == 0 then
        local left = SECONDS - math.floor(hostTimer / 30)
        if left <= 0 then
            close(false, "the time ran out")
            return
        end

        publish(current.kind, current.target, left, current.need, current.asker,
            current.question)
    end
end

hook_event(HOOK_UPDATE, update)

hook_on_sync_table_change(gGlobalSyncTable, "ofVote", 0, function(tag, oldVal, newVal)

    if OF.util.asks(OF.guard, "repair") and OF.guard.repair("ofVote") then return end

    if newVal == oldVal then return end

    if newVal == nil or newVal == "" then

        announced = nil
        OF.util.publish_row(0, "ofVoted", "")
        return
    end

    local current = vote.current()
    if current == nil then return end

    if asked > 0 and current.kind == askedKind
        and (current.target or -1) == (askedTarget or -1) then
        asked, askedKind, askedTarget = 0, nil, nil

        if not OF.util.is_host() and kind ~= nil and not is_system(kind) then
            myAskerWait = ASKER_SECONDS * 30
        end
    end

    local id = current.kind .. "|" .. tostring(current.target) .. "|" .. current.question
    if id == announced then return end
    announced = id

    OF.notify.show("@   -   @ needed", "warn", 6, vote.localize(current), needed())
end)

hook_event(HOOK_ON_MODS_LOADED, function()

    if OF.util.asks(OF.net, "register_action") then

        OF.net.register_action("voteforce", "settings", function(asker, passed)

            return vote.force(tonumber(passed) == 1, asker)
        end)
    end

    if not OF.util.is_host() then return end
    if gGlobalSyncTable.ofVote ~= nil and gGlobalSyncTable.ofVote ~= "" then return end
    OF.util.publish("ofVote", "")
end)

local function render()
    local current = vote.current()

    if OF.util.menu_has_screen() then return end

    if current == nil then
        if asked <= 0 then return end
        djui_hud_set_resolution(RESOLUTION_DJUI)
        djui_hud_set_font(FONT_NORMAL)
        OF.util.banner(OF.lang.t("Asking the host..."), 0.9, 255, 255, 255, 255, {
            accent = OF.GOLD,
            under = { text = "the host opens it", scale = 0.7,
                      r = OF.util.gold().r, g = OF.util.gold().g,
                      b = OF.util.gold().b },
        })
        return
    end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    local mine = vote.answer_of(0)

    local line = vote.localize(current) .. "   "
        .. vote.count_text() .. "   " .. current.seconds .. "s"
    local hint
    if current.target ~= nil and current.target == network_global_index_from_local(0) then
        hint = OF.lang.t("This one is about you")
    elseif vote.is_away(0) then

        hint = OF.lang.t("You are away - answering brings you back and counts")
    elseif mine == vote.YES then
        hint = OF.lang.fill("You voted yes   -   @ needed", needed())
    elseif mine == vote.NO then
        hint = OF.lang.fill("You voted no   -   @ needed", needed())
    else
        hint = OF.lang.fill("/yes   or   /no   -   @ needed", needed())
    end

    OF.util.banner(line, 0.9, 255, 255, 255, 255, {
        accent = OF.GOLD,
        under = { text = hint, scale = 0.7,
                  r = OF.util.gold().r, g = OF.util.gold().g, b = OF.util.gold().b },
    })
end

hook_event(HOOK_ON_HUD_RENDER, render)

local function answer_row(panel, value)
    local text, r, g, b
    if value == vote.YES then
        text, r, g, b = OF.lang.t("Yes"), 120, 255, 120
    else
        text, r, g, b = OF.lang.t("No"), 255, 140, 90
    end

    local built = panel.row(text, r, g, b, function()
        OF.util.report(vote.answer(value))
    end)

    local mine = vote.answer_of(0)

    if vote.is_away(0) then
        if mine == value then
            built = panel.with_right(built, OF.lang.t("not counted"))
        end
        return panel.with_help(built, OF.lang.t(
            "you are away - pressing this brings you back and counts it"))
    end

    if mine == value then
        return panel.with_help(panel.with_right(built, OF.lang.t("your vote")),
            OF.lang.t("this is how you voted - pressing it again is refused"))
    end

    if mine == "" then
        return panel.with_help(built, OF.lang.t(
            "counts your answer - you can change it while the question is up"))
    end

    return panel.with_help(panel.with_right(built, OF.lang.t("changes it")),
        OF.lang.t("changes the answer you have already given"))
end

function vote.round_rows(panel)
    local rows = {}

    if OF.util.asks(OF.lobbytalk, "endmode_rows") then
        for _, r in ipairs(OF.lobbytalk.endmode_rows(panel)) do table.insert(rows, r) end
    end
    local current = vote.current()
    if current ~= nil then
        local door = panel.row(OF.lang.t("Answer the open vote..."),
            255, 255, 255, function() panel.go("vote") end)

        if OF.util.asks(panel, "with_pulse") then door = panel.with_pulse(door, true) end
        table.insert(rows, panel.with_help(panel.with_right(door, vote.count_text()),
            OF.lang.t("a question is open - answer it, or read who has not")))
        return rows
    end
    if vote.asking() ~= nil then
        table.insert(rows, panel.label_row(OF.lang.t("Asking the host...")))
        return rows
    end

    if wait_left() > 0 then
        table.insert(rows, panel.label_row(OF.lang.fill(
            "The lobby's wait: @s before the next question", wait_left())))
    end
    local mineLeft = asker_wait(network_global_index_from_local(0))
    if mineLeft > 0 then
        table.insert(rows, panel.label_row(OF.lang.fill(
            "Your own turn comes back in @s", math.ceil(mineLeft / 30))))
    end

    table.insert(rows, panel.label_row(
        OF.lang.t("To vote about a player, open them first.")))

    table.insert(rows, panel.label_row(OF.lang.t(
        "Anything else: type /vote and the question, in chat.")))

    table.insert(rows, panel.label_row(OF.lang.t(
        "One question at a time, never the same one twice.")))
    return rows
end

function vote.build_page(panel)
    local rows = {}
    local current = vote.current()

    if current ~= nil then
        local yes, no, waiting = vote.tally()

        local gold = OF.util.gold()
        table.insert(rows, panel.with_right(
            panel.label_row(vote.localize(current), gold.r, gold.g, gold.b),
            OF.lang.fill("@s", current.seconds)))

        if current.target ~= nil
            and current.target == network_global_index_from_local(0) then
            table.insert(rows, panel.label_row(OF.lang.t("This one is about you.")))
        else
            table.insert(rows, answer_row(panel, vote.YES))
            table.insert(rows, answer_row(panel, vote.NO))
        end

        if vote.shows_split() then
            table.insert(rows, panel.label_row(OF.lang.fill("@ yes, @ no", yes, no)))
            table.insert(rows, panel.label_row(OF.lang.fill(
                "@ yet to answer, and @ needed", waiting, needed())))
        else

            table.insert(rows, panel.label_row(vote.count_text()))
            table.insert(rows, panel.label_row(OF.lang.fill(
                "@ needed, and the split is held back until it closes", needed())))
        end

        local askerLocal = vote.asked_by(current)
        if askerLocal ~= nil then
            table.insert(rows, panel.label_row(OF.lang.fill("Asked by @",
                OF.util.name_safe(gNetworkPlayers[askerLocal].name))))
        end

        local away = vote.away_count()
        if away > 0 then
            table.insert(rows, panel.label_row(OF.lang.fill(
                "@ away, and away players were not asked", away)))
        end

        local kind = vote.kind(current.kind)
        if kind ~= nil and kind.fail ~= nil then
            table.insert(rows, panel.label_row(OF.lang.t(
                "A tie hands it to the other one - both answers pick a round.")))
        else
            table.insert(rows, panel.label_row(OF.lang.t(
                "A tie does not pass. The bar is more than half.")))
        end

        table.insert(rows, panel.gated_row("settings", OF.lang.t("Pass it now"), 120, 255, 120,

            function() OF.util.report(vote.force(true, 0)) end))
        table.insert(rows, panel.gated_row("settings", OF.lang.t("Refuse it now"), 255, 140, 90,
            function() OF.util.report(vote.force(false, 0)) end))
        table.insert(rows, panel.gated_row("settings", OF.lang.t("Call it off"), 180, 180, 180,
            function() OF.util.report(vote.cancel(0)) end))
        table.insert(rows, panel.back_row("players"))
        return rows
    end

    if vote.asking() ~= nil then
        table.insert(rows, panel.label_row(OF.lang.t("Asking the host...")))
        table.insert(rows, panel.back_row("players"))
        return rows
    end

    table.insert(rows, panel.label_row(OF.lang.t("Nothing is being voted on.")))
    for _, r in ipairs(vote.round_rows(panel)) do table.insert(rows, r) end
    table.insert(rows, panel.back_row("players"))
    return rows
end

hook_chat_command("vote", "<words> - ask the lobby anything, or endmode / skip / jail / cancel", function(msg)
    msg = msg or ""
    if msg == "" then
        local current = vote.current()
        if current == nil then
            OF.util.chat(OF.lang.t("Nothing is being voted on. Try /vote skip."))
            return true
        end

        OF.util.chat(vote.localize(current) .. "  " .. vote.count_text()
            .. "   -  " .. OF.lang.fill("@ needed", needed())
            .. "   -  " .. OF.lang.t("/yes or /no"))
        return true
    end

    if msg == "help" then
        OF.util.chat(OF.lang.t("Anything after /vote is the question the lobby is asked."))
        OF.util.chat(OF.lang.t(
            "endmode, skip, jail <name>, cancel, pass and refuse are the words that mean something else."),
            nil, { more = true })
        return true
    end

    local word, rest = string.match(msg, "^(%S+)%s*(.*)$")
    word = string.lower(word or "")

    if word == "cancel" then

        OF.util.report(vote.cancel(0))
        return true
    end

    if word == "pass" then
        OF.util.report(vote.force(true, 0))
        return true
    end

    if word == "refuse" then
        OF.util.report(vote.force(false, 0))
        return true
    end

    if word == "endmode" or (word == "skip" and OF.gamemodes ~= nil
        and OF.gamemodes.state() == OF.gamemodes.ACTIVE) then
        if OF.util.asks(OF.lobbytalk, "chat_endmode") then
            return OF.lobbytalk.chat_endmode()
        end
        return true
    end

    if word == "skip" then
        OF.util.report(vote.start("skip"))
        return true
    end

    if word == "jail" then
        local target = OF.util.find_player_by_name(rest)
        if target ~= nil then
            OF.util.report(vote.start("jail",
                network_global_index_from_local(target)))
            return true
        end
    end

    OF.util.report(vote.start("ask", nil, msg))
    return true
end)

hook_chat_command("yes", "- vote yes", function()
    OF.util.report(vote.answer(vote.YES))
    return true
end)

hook_chat_command("no", "- vote no", function()
    OF.util.report(vote.answer(vote.NO))
    return true
end)
