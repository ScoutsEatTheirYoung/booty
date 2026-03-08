local mq = require('mq')
local corpse = require('booty.corpse')
local utils = require('booty.utils')
local config = require('booty.config')

local loot = {}

-- Opens a corpse by ID and returns true if successfully
-- opened, false otherwise
function loot.open_corpse_by_id(corpse_id)
    -- Target the corpse
    if mq.TLO.Target.ID() ~= corpse_id then
        mq.cmdf('/target id %d', corpse_id)
        mq.delay(1000, function() return mq.TLO.Target.ID() == corpse_id end)
    end

    -- Check if we successfully targeted it
    if mq.TLO.Target.ID() ~= corpse_id then
        utils.error("Could not target corpse ID " .. corpse_id)
        return false
    end

    -- Distance Check: You must be within loot range to open a corpse
    if mq.TLO.Target.Distance() > config.get().loot.max_distance then
        utils.error("Too far away to loot (" .. mq.TLO.Target.Distance() .. ")")
        return false
    end

    -- Open the loot window
    mq.cmd('/loot')
    mq.delay(config.get().loot.window_open_timeout, function() return mq.TLO.Window('LootWnd').Open() end)

    -- Check if we successfully opened it
    if (mq.TLO.Target.ID() == corpse_id) and (mq.TLO.Window('LootWnd').Open()) then
        return true
    end

    return false
end


-- Vacuum function to check every item on the opened loot window
function loot.loot_from_open_window()
    local total_items = mq.TLO.Corpse.Items() or 0
    utils.info(string.format("[Loot] Scanning \ay%d\ax item(s) on corpse", total_items))
    local cfg = config.get().loot
    for i = total_items, 1, -1 do
        mq.delay(cfg.item_loot_delay)
        local item = mq.TLO.Corpse.Item(i)
        if item() and loot.check_if_should_loot_item(item) then
            utils.pass(string.format("[Loot] Looting \ag%s\ax (ID: %d, slot %d)", item.Name(), item.ID(), i))
            mq.cmdf('/notify LootWnd LW_LootSlot%d rightmouseup', i - 1)
            mq.delay(cfg.item_transfer_timeout, function() return not mq.TLO.Corpse.Item(i)() end)
        end
    end
end

function loot.check_if_should_loot_item(item)
    if(not item()) then
        utils.error("[Loot] Invalid item passed to check_if_should_loot_item")
        return false
    end

    if(loot.loot_lore_check(item) == false) then
        utils.fail(string.format("[Loot] Skip \ar%s\ax — lore item already owned", item.Name()))
        return false
    end

    return true
end

function loot.loot_lore_check(item)
    if item.Lore() then
        -- usage: FindItem['=Item Name']
        local have_in_bag = mq.TLO.FindItem('=' .. item.Name())()
        local have_in_bank = mq.TLO.FindItemBank('=' .. item.Name())()
        if have_in_bag or have_in_bank then
            return false -- Skip it
        end
    end
    return true
end

-- Closes the loot window if open
-- returns true if no loot window is open
function loot.close_loot_window()
    if mq.TLO.Window('LootWnd').Open() then
        mq.TLO.Window('LootWnd').DoClose()
        mq.delay(config.get().loot.corpse_close_timeout, function() return not mq.TLO.Window('LootWnd').Open() end)
    end

    return not mq.TLO.Window('LootWnd').Open()
end

-- Retrieves the loot list from a corpse by its ID
function loot.get_corpse_loot_by_id(corpse_id)
    local loot_list = {}

    -- open corpse
    if not loot.open_corpse_by_id(corpse_id) then
        return nil
    end

    local count = mq.TLO.Corpse.Items() or 0
    for i = 1, count do
        local item = mq.TLO.Corpse.Item(i)
        if item() then
            table.insert(loot_list, {
                name = item.Name(),
                id = item.ID(),
                slot_index = i
            })
        end
    end

    loot.close_loot_window()

    return loot_list
end

function loot.get_loot_list_from_all_corpses(radius, zradius)
    local corpses = corpse.get_all(radius, zradius)
    local loot_list = {}

    for _, c in ipairs(corpses) do
        local corpse_loot = loot.get_corpse_loot_by_id(c.id)
        if corpse_loot then
            table.insert(loot_list, corpse_loot)
        end
    end

    return loot_list
end



-- Loot all corpses within the specified radius
-- pay no respect to white or black lists
function loot.all(radius, zradius)
    local corpses = corpse.get_all(radius, zradius)
    
    for _, c in ipairs(corpses) do
        -- LIVE CHECK: verify the ID still exists in the game world
        if mq.TLO.Spawn(c.id)() then
            utils.info(string.format('[Loot] Opening corpse \ayID %d\ax...', c.id))

            if loot.open_corpse_by_id(c.id) then
                mq.delay(config.get().loot.item_loot_delay) -- Stabilize
                loot.loot_from_open_window()
            end

            loot.close_loot_window()
        end
    end
end

function loot.with_filter(filter, radius, zradius)
    local corpses = corpse.get_all(radius, zradius)
    local cfg = config.get().loot

    for _, c in ipairs(corpses) do
        -- LIVE CHECK: verify the ID still exists in the game world
        if mq.TLO.Spawn(c.id)() then
            utils.info(string.format('[Loot] Checking corpse \ayID %d\ax against filter...', c.id))

            if loot.open_corpse_by_id(c.id) then
                mq.delay(cfg.item_loot_delay) -- Stabilize

                local total_items = mq.TLO.Corpse.Items() or 0
                utils.info(string.format('[Loot] Scanning \ay%d\ax item(s) on corpse', total_items))

                for i = total_items, 1, -1 do
                    mq.delay(cfg.item_loot_delay)
                    local item = mq.TLO.Corpse.Item(i)
                    if item() then
                        local name = item.Name()
                        -- Check filter first
                        if not filter:matches(item) then
                            utils.fail(string.format('[Loot] Skip \ar%s\ax — no filter match', name))
                        -- Then lore check
                        elseif loot.loot_lore_check(item) == false then
                            utils.fail(string.format('[Loot] Skip \ar%s\ax — lore item already owned', name))
                        else
                            utils.pass(string.format('[Loot] Looting \ag%s\ax (ID: %d, slot %d)', name, item.ID(), i))
                            mq.cmdf('/notify LootWnd LW_LootSlot%d rightmouseup', i - 1)
                            mq.delay(cfg.item_transfer_timeout, function() return not mq.TLO.Corpse.Item(i)() end)
                        end
                    end
                end

                loot.close_loot_window()
            end
        end
    end
end

return loot