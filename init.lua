local mq = require('mq')

local helpers = require('booty.helpers')
local config = require('booty.config')
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
    local cfg = config.get().corpse
    local radius = tonumber(args[2]) or cfg.default_radius
    local zradius = tonumber(args[3]) or cfg.default_zradius

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
        local cfg = config.get().corpse
        loot.all(cfg.default_radius, cfg.default_zradius)
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

-- /lua run booty config [cmd]
function commands.config(args)
    if args[2] == 'dump' or args[2] == 'show' then
        config.dump()
    elseif args[2] == 'reload' then
        config.reload()
        helpers.success('Configuration reloaded')
    elseif args[2] == 'save' then
        config.save()
    elseif args[2] == 'get' then
        local path = args[3]
        if not path then
            helpers.error('Usage: /lua run booty config get <path>')
            helpers.info('Example: /lua run booty config get loot.max_distance')
            return
        end
        local value = config.value(path)
        helpers.info(string.format('%s = %s', path, tostring(value)))
    elseif args[2] == 'set' then
        local path = args[3]
        local value = args[4]
        if not path or not value then
            helpers.error('Usage: /lua run booty config set <path> <value>')
            helpers.info('Example: /lua run booty config set loot.max_distance 20')
            return
        end
        -- Try to convert to number or boolean
        if tonumber(value) then
            value = tonumber(value)
        elseif value == 'true' then
            value = true
        elseif value == 'false' then
            value = false
        end
        config.set(path, value, true) -- auto-save
        helpers.success(string.format('Set %s = %s', path, tostring(value)))
    elseif args[2] == 'path' then
        helpers.info('Config file: ' .. config.get_user_config_path())
    else
        helpers.print('Config commands:')
        helpers.info('  dump/show  - Display current configuration')
        helpers.info('  reload     - Reload configuration from disk')
        helpers.info('  save       - Save current configuration to disk')
        helpers.info('  get <path> - Get a config value (e.g., loot.max_distance)')
        helpers.info('  set <path> <value> - Set and save a config value')
        helpers.info('  path       - Show config file location')
    end
end

-- /lua run booty filter [cmd]
function commands.filter(args)
    if args[2] == 'create' then
        local filterName = args[3]
        if not filterName then
            helpers.error('Please provide a name for the filter. Usage: /lua run booty filter create [filterName]')
            return
        end
        filter.create_skeleton(filterName)
    elseif args[2] == 'gui' then
        local FilterGUI = require('booty.filter.gui')
        FilterGUI.run()
    elseif args[2] == 'test' then
        local filterName = args[3]
        if not filterName then
            helpers.error('Please provide a filter name. Usage: /lua run booty filter test [filterName]')
            return
        end
        local loadedFilter = filter.load(filterName)
        if loadedFilter then
            filter.TestInventory(loadedFilter)
        end
    else
        helpers.print('Filter commands:')
        helpers.info('  gui              - Open the filter editor GUI')
        helpers.info('  create <name>    - Create a new filter skeleton')
        helpers.info('  test <name>      - Test a filter against inventory')
    end
end

-- /lua run booty test [cmd]
-- this is mostly for me to test stuff during development
function commands.test(args)
    helpers.info('Running booty test command ' .. helpers.table_to_string(args))
    local cfg = config.get().corpse
    if args[2] == 'lootall' then
        loot.all(cfg.default_radius, cfg.default_zradius)
    elseif args[2] == 'corpses' then
        local corpses = corpse.get_all(cfg.default_radius, cfg.default_zradius)
        for _, c in ipairs(corpses) do
            print(helpers.table_to_string(c))
        end
    elseif args[2] == 'lootlistall' then
        local start_time = os.clock()
        local loot_list = loot.get_loot_list_from_all_corpses(cfg.default_radius, cfg.default_zradius)
        helpers.print(helpers.table_to_string(loot_list))
        local elapsed_ms = (os.clock() - start_time) * 1000
        print(string.format("Function took: %.2f ms", elapsed_ms))
    elseif args[2] == 'opencorpse' then
        local start_time = os.clock()
        local corpses = corpse.get_all(cfg.default_radius, cfg.default_zradius)
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
