OF = OF or {}
OF.ranks = OF.ranks or {}

local ranks = OF.ranks

local RANK_PREFIX = "rank_"
local LEGACY_VIP_PREFIX = "vip_"
local RANK_END_PREFIX = "rankend_"
local RANK_NAME_PREFIX = "rankwho_"
local RANK_ALIAS_PREFIX = "ranksame_"
ranks.LENGTHS = {
    { key = "forever", name = "for good",       minutes = 0 },
    { key = "hour",    name = "for an hour",    minutes = 60 },
    { key = "evening", name = "for the session", minutes = 300 },
    { key = "round",   name = "for ten minutes", minutes = 10 },
}

function ranks.length(key)
    for _, entry in ipairs(ranks.LENGTHS) do
        if entry.key == key then return entry end
    end
    return ranks.LENGTHS[1]
end

function ranks.next_length(key)
    for i, entry in ipairs(ranks.LENGTHS) do
        if entry.key == key then
            return ranks.LENGTHS[(i % #ranks.LENGTHS) + 1].key
        end
    end
    return ranks.LENGTHS[1].key
end

function ranks.expires_at(playerId)
    if playerId == nil then return 0 end
    return mod_storage_load_integer(
        OF.util.storage_key(RANK_END_PREFIX, playerId), 0)
end

function ranks.remembered_name(playerId)
    if playerId == nil then return nil end
    local name = mod_storage_load(
        OF.util.storage_key(RANK_NAME_PREFIX, playerId), "")
    if name == "" then return nil end
    return name
end

function ranks.get(localIndex)
    return OF.perms.tier(localIndex)
end

function ranks.color(tier)
    local info = OF.perms.tier_info(tier)
    return info.r, info.g, info.b
end

function ranks.label(tier)
    return OF.perms.tier_label(tier)
end

function ranks.stored(playerId)
    if playerId == nil then return nil end

    local ends = ranks.expires_at(playerId)
    if ends > 0 then
        local now = OF.util.asks(OF.jail, "now") and OF.jail.now() or 0

        if now > 0 and ends <= now then
            mod_storage_remove(OF.util.storage_key(RANK_PREFIX, playerId))
            mod_storage_remove(OF.util.storage_key(RANK_END_PREFIX, playerId))
            return nil
        end
    end

    local stored = mod_storage_load_integer(
        OF.util.storage_key(RANK_PREFIX, playerId), -1)
    if stored >= 0 then return stored end

    if mod_storage_load_bool(
            OF.util.storage_key(LEGACY_VIP_PREFIX, playerId), false) then
        return OF.TIER.VIP
    end
    return nil
end

local function alias_of(nameId)
    if nameId == nil then return nil end
    local target = mod_storage_load(
        OF.util.storage_key(RANK_ALIAS_PREFIX, nameId), "")
    if target == "" then return nil end
    return target
end

local function alias_links()
    local links = {}
    local all = mod_storage_load_all()
    if all == nil then return links end
    for key, value in pairs(all) do
        if string.sub(key, 1, #RANK_ALIAS_PREFIX) == RANK_ALIAS_PREFIX then
            links[#links + 1] = {
                key = key,
                from = OF.util.storage_unescape(
                    string.sub(key, #RANK_ALIAS_PREFIX + 1)),
                to = tostring(value),
            }
        end
    end

    table.sort(links, function(a, b) return a.key < b.key end)
    return links
end

ranks.bound = ranks.bound or {}

local function bind_alias(localIndex, nameId, coopnetId)
    if nameId == nil or coopnetId == nil then return false end
    if ranks.bound[localIndex] == nameId then return false end

    ranks.bound[localIndex] = nameId
    if alias_of(nameId) == coopnetId then return false end
    return OF.util.store(
        OF.util.storage_key(RANK_ALIAS_PREFIX, nameId), coopnetId)
end

function ranks.identity(localIndex)
    local coopnetId, nameId = OF.util.player_identities(localIndex)
    if coopnetId == nil and nameId == nil then return nil end

    if coopnetId ~= nil then
        if ranks.stored(coopnetId) ~= nil then
            bind_alias(localIndex, nameId, coopnetId)
            return coopnetId
        end
        if nameId ~= nil and ranks.stored(nameId) ~= nil then
            local bound = alias_of(nameId)
            if bound == nil then
                bind_alias(localIndex, nameId, coopnetId)
                return nameId
            elseif bound == coopnetId then
                return nameId
            end

        end
        return coopnetId
    end

    if ranks.stored(nameId) ~= nil then return nameId end
    local bound = alias_of(nameId)
    if bound ~= nil then return bound end
    return nameId
end

local function apply_description(localIndex, tier)
    local np = gNetworkPlayers[localIndex]
    if np == nil then return end
    local info = OF.perms.tier_info(tier)
    if info.label == "" then
        network_player_set_description(np, "", 255, 255, 255, 0)
    else
        network_player_set_description(np, info.label, info.r, info.g, info.b, 255)
    end
end

ranks.published = ranks.published or {}

ranks.publishedId = ranks.publishedId or {}

ranks.slipped = ranks.slipped or 0

function ranks.wanted(localIndex)
    if OF.util.is_host_player(localIndex) then
        return OF.TIER.HOST, ranks.publishedId[localIndex]
    end

    local id = ranks.identity(localIndex)
    local tier = ranks.stored(id)
    local anchor = id

    if tier == nil then
        local held = ranks.published[localIndex]
        if held ~= nil and id ~= ranks.publishedId[localIndex] then
            tier = held
            anchor = ranks.publishedId[localIndex]
            ranks.slipped = ranks.slipped + 1
        end
    end

    if tier == nil then tier = OF.TIER.NORMAL end

    if tier >= OF.TIER.HOST then tier = OF.TIER.MOD end
    return tier, anchor
end

function ranks.refresh(localIndex)
    if not OF.util.is_host() then return end
    local np = gNetworkPlayers[localIndex]
    if np == nil or not np.connected then return end

    local tier, anchor = ranks.wanted(localIndex)
    ranks.published[localIndex] = tier
    ranks.publishedId[localIndex] = anchor
    gPlayerSyncTable[localIndex].ofTier = tier
end

ranks.forged = ranks.forged or 0

function ranks.repair(localIndex)
    if not OF.util.is_host() then return false end

    local wanted = ranks.published[localIndex]
    if wanted == nil then return false end

    local row = gPlayerSyncTable[localIndex]
    if row == nil or row.ofTier == wanted then return false end

    local claimed = row.ofTier
    row.ofTier = wanted

    if OF.wireWatch then OF.note_sync("ofTier", claimed ~= wanted) end
    ranks.forged = ranks.forged + 1

    local np = gNetworkPlayers[localIndex]
    local whose = OF.util.plain(np ~= nil and np.name or "somebody")

    OF.guard.note(OF.lang.fill("a rank in @'s row, set to @", whose,
        OF.perms.tier_name(claimed or OF.TIER.NORMAL)))

    OF.guard.tell(
        OF.lang.fill("A rank was written into @'s row. Put back - Control, Who did what, has the rest.",
            whose),
        "A rank was written into somebody's row", 8)
    return true
end

function ranks.forget(localIndex)
    ranks.published[localIndex] = nil

    ranks.publishedId[localIndex] = nil

    ranks.bound[localIndex] = nil
end

function ranks.refresh_all()
    for _, entry in ipairs(OF.util.connected_players()) do
        ranks.refresh(entry.localIndex)
    end
end

function ranks.set(localIndex, tier, minutes)
    if not OF.util.is_host() then return false, "Host only." end
    if OF.util.is_host_player(localIndex) then
        return false, "The host's own rank is fixed."
    end
    if tier >= OF.TIER.HOST then
        return false, "There can only be one host."
    end

    local id = ranks.identity(localIndex)
    if id == nil then return false, "That player has no stable id." end

    local until_ = 0
    if OF.util.asks(OF.jail, "expiry_for") then
        until_ = OF.jail.expiry_for(minutes)
    end

    if tier == OF.TIER.NORMAL then until_ = 0 end

    local rankKey = OF.util.storage_key(RANK_PREFIX, id)
    local endKey = OF.util.storage_key(RANK_END_PREFIX, id)
    local nameKey = OF.util.storage_key(RANK_NAME_PREFIX, id)

    local hadTier = mod_storage_load_integer(rankKey, -1)
    local hadEnd = mod_storage_load_integer(endKey, 0)
    local function put_back()
        if hadTier >= 0 then
            OF.util.store_integer(rankKey, hadTier)
        else
            mod_storage_remove(rankKey)
        end
        if hadEnd > 0 then
            OF.util.store_integer(endKey, hadEnd)
        else
            mod_storage_remove(endKey)
        end
    end

    if tier == OF.TIER.NORMAL then
        mod_storage_remove(rankKey)

        mod_storage_remove(nameKey)

        local _, seatName = OF.util.player_identities(localIndex)
        if seatName ~= nil then
            local link = OF.util.storage_key(RANK_ALIAS_PREFIX, seatName)
            if alias_of(seatName) == id or seatName == id then
                mod_storage_remove(link)
            end
        end
        ranks.bound[localIndex] = nil
    elseif not OF.util.store_integer(rankKey, tier) then
        return false, "The save file would not take that rank - nothing changed."
    end

    if until_ > 0 then
        if not OF.util.store_integer(endKey, until_) then
            put_back()
            return false,
                "The save file would not take how long for - nothing changed."
        end
    else
        mod_storage_remove(endKey)
    end
    mod_storage_remove(OF.util.storage_key(LEGACY_VIP_PREFIX, id))

    local np = gNetworkPlayers[localIndex]

    if tier ~= OF.TIER.NORMAL then
        OF.util.store(nameKey,
            OF.util.plain(np ~= nil and np.name or "") or "")
    end

    ranks.refresh(localIndex)

    local howLong = ""
    if until_ > 0 and OF.util.asks(OF.jail, "until_text") then
        howLong = " (" .. OF.jail.until_text(until_) .. ")"
    end
    OF.notify.send_to(network_global_index_from_local(localIndex),
        "You are now @", "good", nil, OF.perms.tier_name(tier) .. howLong)

    OF.notify.show("@ is now @", "good", 5, OF.util.plain(np.name),
        OF.perms.tier_name(tier) .. howLong)
    OF.chatlog.add_system(np.name .. " set to " .. OF.perms.tier_name(tier)
        .. howLong)
    return true
end

local EXPIRY_SWEEP_FRAMES = 30
local sweepFrames = 0

function ranks.sweep_expiries()
    if not OF.util.is_host() then return 0 end
    sweepFrames = sweepFrames + 1
    if sweepFrames < EXPIRY_SWEEP_FRAMES then return 0 end
    sweepFrames = 0

    local dropped = 0
    for _, entry in ipairs(OF.util.connected_players()) do
        local li = entry.localIndex
        local was = ranks.published[li]

        local hadEnd = ranks.expires_at(OF.util.player_id(li)) > 0

        local now = ranks.wanted(li)
        if was ~= nil and now ~= was then
            ranks.refresh(li)
        end

        if was ~= nil and now < was and hadEnd then
            dropped = dropped + 1

            OF.notify.show("@ has run out - they are @ again.", "quiet", 5,
                OF.lang.fill("@'s @", OF.util.plain(entry.np.name),
                    OF.perms.tier_name(was)),
                OF.perms.tier_name(now))
            OF.notify.send_to(network_global_index_from_local(li),
                "Your @ has run out", "info", 5, OF.perms.tier_name(was))

            OF.chatlog.add_system(OF.lang.fill("@'s rank ran out", entry.np.name),
                OF.util.asks(OF.actionlog, "auto")
                    and OF.actionlog.BY_THE_ROOM or nil)
        end
    end
    return dropped
end

hook_event(HOOK_UPDATE, function() ranks.sweep_expiries() end)

local function remembered_ids()
    local ids = {}
    local all = mod_storage_load_all()
    if all == nil then return ids end
    for key, _ in pairs(all) do
        if string.sub(key, 1, #RANK_PREFIX) == RANK_PREFIX then
            ids[#ids + 1] = OF.util.storage_unescape(
                string.sub(key, #RANK_PREFIX + 1))
        end
    end

    table.sort(ids)
    return ids
end

function ranks.remembered()
    local list = {}
    if not OF.util.is_host() then return list end
    for _, id in ipairs(remembered_ids()) do
        local tier = ranks.stored(id)
        if tier ~= nil and tier ~= OF.TIER.NORMAL then
            list[#list + 1] = {
                id = id,
                tier = tier,
                expires = ranks.expires_at(id),
                name = ranks.remembered_name(id),
            }
        end
    end
    table.sort(list, function(a, b)
        if a.tier ~= b.tier then return a.tier > b.tier end
        local aName = a.name or a.id
        local bName = b.name or b.id
        if aName ~= bName then return aName < bName end
        return a.id < b.id
    end)
    return list
end

local rememberedMemo = {}

function ranks.remembered_count()
    return OF.util.stored_count(rememberedMemo, ranks.remembered,
        function(entry) return entry.expires end)
end

function ranks.remembered_label(entry)
    if entry == nil then return "" end
    if entry.name ~= nil and entry.name ~= "" then return entry.name end
    return entry.id or ""
end

function ranks.forget_stored(playerId)
    if not OF.util.is_host() then return false, "Host only." end
    if playerId == nil or playerId == "" then
        return false, "No such record."
    end
    if ranks.stored(playerId) == nil then
        return false, "Nothing is remembered for them."
    end

    local theirs = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        if ranks.identity(entry.localIndex) == playerId then
            theirs[#theirs + 1] = entry.localIndex
        end
    end

    mod_storage_remove(OF.util.storage_key(RANK_PREFIX, playerId))
    mod_storage_remove(OF.util.storage_key(RANK_END_PREFIX, playerId))
    mod_storage_remove(OF.util.storage_key(RANK_NAME_PREFIX, playerId))
    mod_storage_remove(OF.util.storage_key(LEGACY_VIP_PREFIX, playerId))

    for _, link in ipairs(alias_links()) do
        if link.to == playerId or link.from == playerId then
            mod_storage_remove(link.key)
        end
    end

    for _, li in ipairs(theirs) do
        ranks.published[li] = nil
        ranks.publishedId[li] = nil
        ranks.bound[li] = nil
        ranks.refresh(li)
    end
    return true
end

ranks.rememberedAtLoad = 0
ranks.reclaimedAtLoad = 0

function ranks.read_the_file()
    if not OF.util.is_host() then return 0, 0 end
    local kept, reclaimed = 0, 0
    for _, id in ipairs(remembered_ids()) do
        if ranks.stored(id) ~= nil then
            kept = kept + 1
        else

            reclaimed = reclaimed + 1
            mod_storage_remove(OF.util.storage_key(RANK_NAME_PREFIX, id))
        end
    end

    for _, link in ipairs(alias_links()) do
        if ranks.stored(link.to) == nil and ranks.stored(link.from) == nil then
            reclaimed = reclaimed + 1
            mod_storage_remove(link.key)
        end
    end
    ranks.rememberedAtLoad = kept
    ranks.reclaimedAtLoad = reclaimed
    return kept, reclaimed
end

hook_event(HOOK_ON_MODS_LOADED, function()
    ranks.read_the_file()
end)

function ranks.promote(localIndex, minutes)
    return ranks.set(localIndex, OF.perms.step_tier(ranks.get(localIndex), 1),
        minutes)
end

function ranks.demote(localIndex)
    return ranks.set(localIndex, OF.perms.step_tier(ranks.get(localIndex), -1))
end

function ranks.build_who_page(panel)
    local rows = {}
    rows[#rows + 1] = panel.with_help(panel.label_row(OF.lang.t(
        "Everybody in the lobby, and the rank they are holding.")),
        OF.lang.t("a ticked name is somebody carrying a rank of their own"))

    local length = ranks.length(panel.rankLength)
    rows[#rows + 1] = panel.with_help(panel.with_right(
        panel.gated_row("ranks", OF.lang.t("A promotion lasts"),
            255, 220, 120, function()
                panel.rankLength = ranks.next_length(panel.rankLength)
            end),
        OF.lang.t(length.name)),
        OF.lang.t("how long the next one you hand out is worth"))

    rows[#rows + 1] = panel.with_walk(panel.with_help(panel.label_row(OF.lang.t(
        "Press a name to promote them. Z takes a rung back.")),
        OF.lang.t("nothing on this page changes what a press means - it is the button")))

    rows[#rows + 1] = panel.header_row(OF.lang.t("Who is here"))

    local seen = 0
    for i = 0, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[i]
        if np ~= nil and np.connected then
            seen = seen + 1
            local tier = ranks.get(i)
            local r, g, b = ranks.color(tier)
            local held = tier ~= OF.TIER.NORMAL
            local name = OF.util.plain(np.name)
            local built
            if OF.util.is_host_player(i) then
                built = panel.label_row(panel.tick(held, name), r, g, b)
            else
                built = panel.gated_row("ranks", panel.tick(held, name),
                    r, g, b, function()
                        OF.util.report(ranks.promote(i, length.minutes))
                    end)

                if built.action ~= nil then
                    built.altAction = function()
                        if not held then
                            OF.util.report(false,
                                OF.lang.t("They hold no rank to take back."))
                            return
                        end
                        OF.util.report(ranks.demote(i))
                    end
                    built.altPad = true
                    built.altLabel = "demote"
                end
            end
            built = panel.level_right(built, held,
                string.upper(OF.lang.t(OF.perms.tier_name(tier))))

            local opens = OF.perms.tier_opens(tier)

            rows[#rows + 1] = panel.with_help(built, opens ~= nil
                and OF.lang.fill("what that opens here: @", opens)
                or OF.lang.t("this rung opens nothing of its own in this lobby"))
        end
    end
    if seen == 0 then
        rows[#rows + 1] = panel.with_help(
            panel.label_row(OF.lang.t("Nobody is here.")),
            OF.lang.t("nobody is connected, so there is no rank to hand out"))
    end

    rows[#rows + 1] = panel.back_row()
    return rows
end

local function on_tier_changed(tag, oldVal, newVal)

    if ranks.repair(tag) then return end
    apply_description(tag, newVal)
end

for i = 0, MAX_PLAYERS - 1 do
    hook_on_sync_table_change(gPlayerSyncTable[i], "ofTier", i, on_tier_changed)
end
