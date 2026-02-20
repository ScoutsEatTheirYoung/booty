local mq = require('mq')

local helpers = require('booty.helpers')
local corpse = require('booty.corpse')
local loot = require('booty.loot')
local sell = require('booty.sell')
local gui = require('booty.gui')
local filter = require('booty.filter')
local Parser = require('booty.filter.parser')

-- =========================================================================
-- Command Handlers
-- =========================================================================
local commands = {}

-- /lua run booty corpses
function commands.corpses(args)
    local radius = tonumber(args[2]) or 30
    local zradius = tonumber(args[3]) or 10

    local corpses = corpse.get_all(radius, zradius)
    if #corpses == 0 then
        helpers.print('No corpses found within radius.')
        return
    end

    print(string.format('Found %d corpses within radius %d (zradius %d):', #corpses, radius, zradius))
    for _, c in ipairs(corpses) do
        print(string.format(' - [%d] %s (%.1f units away)', c.id, c.clean_name, c.distance))
    end
end

-- /lua run booty loot
function commands.loot(args)
    
    if args[2] == 'help' then
        helpers.print('booty loot - Loot items from nearest corpse')
        return
    elseif args[2] == 'all' then
        loot.all(30, 10)
        return

    elseif args[2] == 'white' or args[2] == 'black' then
        local filterName = args[3]
        if not filterName then
            helpers.error('Please provide a name for the filter. Usage: /lua run booty loot [white|black] [filterName]')
            return
        end
        local loadedFilter = filter.load(filterName)
        if not loadedFilter then
            helpers.error('Could not load filter: ' .. filterName)
            return
        end
        
    end
end

-- /lua run booty sell
function commands.sell(args)
    if args[2] == 'bag' then
        local bag_index = tonumber(args[3]) or 1
        sell.bag_items(bag_index)
        return
    elseif args[2] == 'bags' then
        -- get the remainder of the arguments as the bag indices
        local bag_indices = {}
        for i = 3, #args do
            local bag_index = tonumber(args[i])
            if bag_index then
                table.insert(bag_indices, bag_index)
            end
        end
        sell.bags(bag_indices)
        return
    end
end

-- /lua run filter [cmd]
function commands.filter(args)
    if args[2] == 'create' then
        local filterName = args[3]
        if not filterName then
            helpers.error('Please provide a name for the filter. Usage: /lua run booty filter create [filterName]')
            return
        end
        filter.create_skeleton(filterName)
    end
end

-- /lua run booty test [cmd]
-- this is mostly for me to test stuff during development
function commands.test(args)
    helpers.info('Running booty test command ' .. helpers.table_to_string(args))
    if args[2] == 'lootall' then
        loot.all(30, 10)
    elseif args[2] == 'corpses' then
        local corpses = corpse.get_all(30, 10)
        for _, c in ipairs(corpses) do
            print(helpers.table_to_string(c))
        end
    elseif args[2] == 'lootlistall' then
        local start_time = os.clock()
        local loot_list = loot.get_loot_list_from_all_corpses(30, 10)
        helpers.print(helpers.table_to_string(loot_list))
        local elapsed_ms = (os.clock() - start_time) * 1000
        print(string.format("Function took: %.2f ms", elapsed_ms))
    elseif args[2] == 'opencorpse' then
        local start_time = os.clock()
        local corpses = corpse.get_all(30, 10)
        print(helpers.table_to_string(corpses[1]))
        local open = loot.open_corpse_by_id(corpses[1].id)
        print('Opened: ' .. tostring(open))
        local elapsed_ms = (os.clock() - start_time) * 1000
        print(string.format("Function took: %.2f ms", elapsed_ms))
    elseif args[2] == 'spyloot' then
        local wnd = mq.TLO.Window('LootWnd')

        if not wnd.Open() then
            print("\27[31mError: Open the Loot Window first!\27[0m")
        else
            print("--- Dumping Loot Window Children ---")
            -- We scan the first 40 children (usually enough to find the slots)
            for i = 1, 40 do
                local child = wnd.Child[i]
                if child() then
                    -- Print the Index and the Name
                    print(string.format("#%d: %s", i, child.Name() or "<no name>"))
                end
            end
        end
    elseif args[2] == 'filter' then
        local filterName = args[3]
        if not filterName then
            helpers.error('Please provide a name for the filter. Usage: /lua run booty filter create [filterName]')
            return
        end
        local testFilter = filter.load(filterName)
        if not testFilter then
            helpers.error('Could not load filter: ' .. filterName)
            return
        end
        helpers.info('Loaded filter: ' .. filterName)
        filter.TestInventory(testFilter)

    elseif args[2] == 'guitest' then
        gui.draw_gui()
    end
end


-- =========================================================================
-- Main Execution
-- =========================================================================

-- Parse command line arguments
local args = {...}

-- Handle table-wrapped args (when called as module)
if type(args[1]) == 'table' then
    args = args[1]
end

local command_name = args[1] or 'help'

-- Dispatch to handler
if commands[command_name] then
    commands[command_name](args)
else
    helpers.error('Unknown command: ' .. tostring(command_name))
end
