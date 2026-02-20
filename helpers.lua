-- =========================================================================
-- booty/helpers.lua - Shared utility functions
-- =========================================================================
local mq = require('mq')

local helpers = {}

-- =========================================================================
-- Output Formatting with MQ2 Color Codes
-- =========================================================================

-- Color codes for MQ2 output
helpers.colors = {
    red = '\ay',      -- Actually yellow in MQ2, use for warnings
    green = '\ag',
    yellow = '\ay',
    blue = '\at',     -- Teal
    white = '\aw',
    reset = '\ax',
    purple = '\am',
    cyan = '\ao',     -- Orange actually
}

function helpers.print(msg)
    print('\ag[Booty]\ax ' .. msg)
end

function helpers.warn(msg)
    print('\ay[Booty]\ax ' .. msg)
end

function helpers.error(msg)
    print('\ar[Booty]\ax ' .. msg)
end

function helpers.success(msg)
    print('\ag[Booty]\ax ' .. msg)
end

function helpers.info(msg)
    print('\at[Booty]\ax ' .. msg)
end

-- =========================================================================
-- Cursor Operations
-- =========================================================================

-- Get item currently on cursor
function helpers.get_cursor_item()
    local cursor = mq.TLO.Cursor
    if not cursor() then
        return nil
    end

    return {
        name = cursor.Name(),
        id = cursor.ID(),
        value = cursor.Value(),           -- in copper
        stackable = cursor.Stackable(),
        lore = cursor.Lore(),
        nodrop = cursor.NoDrop(),
        magic = cursor.Magic(),
        augment = cursor.AugType() and cursor.AugType() > 0,
        stack_size = cursor.StackSize(),
    }
end

-- Clear cursor by putting item back in inventory
function helpers.clear_cursor()
    if mq.TLO.Cursor() then
        mq.cmd('/autoinventory')
        mq.delay(500, function() return not mq.TLO.Cursor() end)
    end
end

-- =========================================================================
-- String Utilities
-- =========================================================================

-- Trim whitespace from both ends
function helpers.trim(s)
    if not s then return '' end
    return s:match('^%s*(.-)%s*$')
end

-- Split string by delimiter
function helpers.split(s, delimiter)
    local result = {}
    local pattern = string.format('([^%s]+)', delimiter)
    for part in s:gmatch(pattern) do
        table.insert(result, part)
    end
    return result
end

-- Check if string starts with prefix
function helpers.starts_with(s, prefix)
    return s:sub(1, #prefix) == prefix
end

-- Check if string ends with suffix
function helpers.ends_with(s, suffix)
    return suffix == '' or s:sub(-#suffix) == suffix
end

-- Case-insensitive string comparison
function helpers.iequals(a, b)
    return a:lower() == b:lower()
end

-- Case-insensitive contains
function helpers.icontains(haystack, needle)
    return haystack:lower():find(needle:lower(), 1, true) ~= nil
end

-- =========================================================================
-- Table Utilities
-- =========================================================================

-- Check if table contains value
function helpers.contains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- Check if table contains value (case-insensitive for strings)
function helpers.icontains_value(tbl, value)
    for _, v in ipairs(tbl) do
        if type(v) == 'string' and type(value) == 'string' then
            if v:lower() == value:lower() then
                return true
            end
        elseif v == value then
            return true
        end
    end
    return false
end

-- Add value to table if not already present
function helpers.add_unique(tbl, value)
    if not helpers.contains(tbl, value) then
        table.insert(tbl, value)
        return true
    end
    return false
end

-- Remove value from table
function helpers.remove_value(tbl, value)
    for i = #tbl, 1, -1 do
        if tbl[i] == value then
            table.remove(tbl, i)
            return true
        end
    end
    return false
end

-- Deep copy a table
function helpers.deep_copy(orig)
    local copy
    if type(orig) == 'table' then
        copy = {}
        for k, v in pairs(orig) do
            copy[helpers.deep_copy(k)] = helpers.deep_copy(v)
        end
    else
        copy = orig
    end
    return copy
end

-- table to string
function helpers.table_to_string(tbl, indent)
    indent = indent or 0
    local result = ''
    local prefix = string.rep('  ', indent)

    for k, v in pairs(tbl) do
        if type(v) == 'table' then
            result = result .. string.format('%s%s:\n', prefix, tostring(k))
            result = result .. helpers.table_to_string(v, indent + 1)
        else
            result = result .. string.format('%s%s: %s\n', prefix, tostring(k), tostring(v))
        end
    end

    return result
end

-- =========================================================================
-- Value Formatting
-- =========================================================================

-- Convert copper to readable format (e.g., "5pp 3gp 2sp 1cp")
function helpers.format_value(copper)
    if not copper or copper == 0 then
        return '0cp'
    end

    local pp = math.floor(copper / 1000)
    copper = copper % 1000
    local gp = math.floor(copper / 100)
    copper = copper % 100
    local sp = math.floor(copper / 10)
    local cp = copper % 10

    local parts = {}
    if pp > 0 then table.insert(parts, pp .. 'pp') end
    if gp > 0 then table.insert(parts, gp .. 'gp') end
    if sp > 0 then table.insert(parts, sp .. 'sp') end
    if cp > 0 then table.insert(parts, cp .. 'cp') end

    return table.concat(parts, ' ')
end

-- =========================================================================
-- File Utilities
-- =========================================================================

-- Check if file exists
function helpers.file_exists(path)
    local f = io.open(path, 'r')
    if f then
        f:close()
        return true
    end
    return false
end

-- Read entire file contents
function helpers.read_file(path)
    local f = io.open(path, 'r')
    if not f then
        return nil
    end
    local content = f:read('*all')
    f:close()
    return content
end

-- Write contents to file
function helpers.write_file(path, content)
    local f = io.open(path, 'w')
    if not f then
        return false
    end
    f:write(content)
    f:close()
    return true
end

-- Append line to file
function helpers.append_line(path, line)
    local f = io.open(path, 'a')
    if not f then
        return false
    end
    f:write(line .. '\n')
    f:close()
    return true
end

-- =========================================================================
-- MQ2 Helpers
-- =========================================================================

-- Check if player has item in inventory (for LORE checking)
function helpers.player_has_item(item_name)
    -- Check main inventory slots
    for i = 1, 10 do
        local slot = mq.TLO.Me.Inventory(string.format('pack%d', i))
        if slot() then
            -- Check the bag itself
            if slot.Name() and helpers.iequals(slot.Name(), item_name) then
                return true
            end
            -- Check items inside bag
            local bag_slots = slot.Container() or 0
            for j = 1, bag_slots do
                local item = slot.Item(j)
                if item() and item.Name() and helpers.iequals(item.Name(), item_name) then
                    return true
                end
            end
        end
    end

    -- Check worn slots
    for i = 0, 22 do
        local worn = mq.TLO.Me.Inventory(i)
        if worn() and worn.Name() and helpers.iequals(worn.Name(), item_name) then
            return true
        end
    end

    -- Check bank (if accessible)
    -- Note: Bank TLO may not be accessible unless at banker

    return false
end

-- Helper: Runs a function and prints how long it took
-- Usage: helpers.time_it(my_function, arg1, arg2)
function helpers.time_it(func, ...)
    local start = os.clock()
    
    -- Run the function with all arguments passed to time_it
    local result = { func(...) } 
    
    local elapsed_ms = (os.clock() - start) * 1000
    print(string.format("\27[35m[Timer] Execution: %.4f ms\27[0m", elapsed_ms))
    
    -- Return the actual results of the function
    return table.unpack(result)
end

-- Delay with condition
function helpers.wait(ms, condition)
    mq.delay(ms, condition)
end

return helpers
