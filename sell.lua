local mq = require('mq')

local helpers = require('booty.helpers')
local corpse = require('booty.corpse')
local loot = require('booty.loot')

local sell = {}

function sell.is_sell_window_open()
    return mq.TLO.Window('MerchantWnd').Open()
end

function sell.bag_items(bag_index)

    helpers.info("Selling items from bag " .. bag_index)
    -- 1. OPEN THE SELL WINDOW IF NOT OPEN
    if not sell.is_sell_window_open() then
        helpers.error("Sell window is not open. Please open a merchant window first.")
        return
    end

    -- 2. GET THE BAG
    -- 'pack1' is your first bag slot, 'pack2' is the second, etc.
    local bag_str = 'pack' .. bag_index
    local bag = mq.TLO.Me.Inventory(bag_str)

    -- Verify you actually have a bag there
    if not bag() then
        helpers.error("No bag found in slot " .. bag_index)
        return
    end

    -- 3. THE LOOP
    -- bag.Container() returns the number of slots in that bag (e.g., 8, 10, 20)
    helpers.info("Selling from " .. bag())
    for i = 1, bag.Container() do
        local item = bag.Item(i)
        
        -- Only attempt to sell if an item exists in this slot
        if item() then
            helpers.info("  Selling: " .. item.Name())

            -- STEP A: SELECT THE ITEM
            -- Syntax: /itemnotify in <bag_name> <slot_number> leftmouseup
            mq.cmdf('/itemnotify in %s %d leftmouseup', bag_str, i)
            
            -- Wait for the item to be "Selected" (The game highlights it)
            mq.delay(200)

            -- STEP B: CLICK THE SELL BUTTON
            -- We hold 'shift' to auto-confirm stack selling (prevents quantity popup)
            mq.cmd('/notify MerchantWnd MW_Sell_Button leftmouseup')
            mq.delay(200, function() return mq.TLO.Window('QuantityWnd').Open() end)
            if mq.TLO.Window('QuantityWnd').Open() then
                -- Click "Sell" (or Accept) inside the quantity window
                mq.cmd('/notify QuantityWnd QTYW_Accept_Button leftmouseup')
            end
            
            -- STEP C: WAIT FOR IT TO VANISH
            -- We wait until that specific slot is empty
            mq.delay(1000, function() return not mq.TLO.Me.Inventory('pack'..bag_index).Item(i)() end)
            
            -- Safety delay for server sync
            mq.delay(50)
        end
    end
    
    print("Done selling bag " .. bag_index)
end

function sell.bags(bag_index_array)
    for _, bag_index in ipairs(bag_index_array) do
        sell.bag_items(bag_index)
    end
end




return sell