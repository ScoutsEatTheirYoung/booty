-- =========================================================================
-- booty/utils.lua - Shared utility functions
-- =========================================================================
local mq = require('mq')

local utils = {}

-- =========================================================================
-- Output Formatting with MQ2 Color Codes
-- =========================================================================

-- Color codes for MQ2 output
utils.colors = {
    red = '\ay',      -- Actually yellow in MQ2, use for warnings
    green = '\ag',
    yellow = '\ay',
    blue = '\at',     -- Teal
    white = '\aw',
    reset = '\ax',
    purple = '\am',
    cyan = '\ao',     -- Orange actually
}

function utils.print(msg)
    print('\ag[Booty]\ax ' .. msg)
end

function utils.warn(msg)
    print('\ay[Booty]\ax ' .. msg)
end

function utils.error(msg)
    print('\ar[Booty]\ax ' .. msg)
end

function utils.success(msg)
    print('\ag[Booty]\ax ' .. msg)
end

function utils.info(msg)
    print('\at[Booty]\ax ' .. msg)
end

function utils.pass(msg)
    print('\ag[Booty]\ax \ag✓\ax ' .. msg)
end

function utils.fail(msg)
    print('\ar[Booty]\ax \ar✗\ax ' .. msg)
end

-- =========================================================================
-- Cursor Operations
-- =========================================================================

-- Get item currently on cursor
function utils.get_cursor_item()
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
function utils.clear_cursor()
    if mq.TLO.Cursor() then
        mq.cmd('/autoinventory')
        mq.delay(500, function() return not mq.TLO.Cursor() end)
    end
end

-- =========================================================================
-- String Utilities
-- =========================================================================

-- Trim whitespace from both ends
function utils.trim(s)
    if not s then return '' end
    return s:match('^%s*(.-)%s*$')
end

-- Split string by delimiter
function utils.split(s, delimiter)
    local result = {}
    local pattern = string.format('([^%s]+)', delimiter)
    for part in s:gmatch(pattern) do
        table.insert(result, part)
    end
    return result
end

-- Check if string starts with prefix
function utils.starts_with(s, prefix)
    return s:sub(1, #prefix) == prefix
end

-- Check if string ends with suffix
function utils.ends_with(s, suffix)
    return suffix == '' or s:sub(-#suffix) == suffix
end

-- Case-insensitive string comparison
function utils.iequals(a, b)
    return a:lower() == b:lower()
end

-- Case-insensitive contains
function utils.icontains(haystack, needle)
    return haystack:lower():find(needle:lower(), 1, true) ~= nil
end

-- =========================================================================
-- Table Utilities
-- =========================================================================

-- Check if table contains value
function utils.contains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- Check if table contains value (case-insensitive for strings)
function utils.icontains_value(tbl, value)
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
function utils.add_unique(tbl, value)
    if not utils.contains(tbl, value) then
        table.insert(tbl, value)
        return true
    end
    return false
end

-- Remove value from table
function utils.remove_value(tbl, value)
    for i = #tbl, 1, -1 do
        if tbl[i] == value then
            table.remove(tbl, i)
            return true
        end
    end
    return false
end

-- Deep copy a table
function utils.deep_copy(orig)
    local copy
    if type(orig) == 'table' then
        copy = {}
        for k, v in pairs(orig) do
            copy[utils.deep_copy(k)] = utils.deep_copy(v)
        end
    else
        copy = orig
    end
    return copy
end

-- table to string
function utils.table_to_string(tbl, indent)
    indent = indent or 0
    local result = ''
    local prefix = string.rep('  ', indent)

    for k, v in pairs(tbl) do
        if type(v) == 'table' then
            result = result .. string.format('%s%s:\n', prefix, tostring(k))
            result = result .. utils.table_to_string(v, indent + 1)
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
function utils.format_value(copper)
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
function utils.file_exists(path)
    local f = io.open(path, 'r')
    if f then
        f:close()
        return true
    end
    return false
end

-- Read entire file contents
function utils.read_file(path)
    local f = io.open(path, 'r')
    if not f then
        return nil
    end
    local content = f:read('*all')
    f:close()
    return content
end

-- Write contents to file
function utils.write_file(path, content)
    local f = io.open(path, 'w')
    if not f then
        return false
    end
    f:write(content)
    f:close()
    return true
end

-- Append line to file
function utils.append_line(path, line)
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
function utils.player_has_item(item_name)
    -- Check main inventory slots
    for i = 1, 10 do
        local slot = mq.TLO.Me.Inventory(string.format('pack%d', i))
        if slot() then
            -- Check the bag itself
            if slot.Name() and utils.iequals(slot.Name(), item_name) then
                return true
            end
            -- Check items inside bag
            local bag_slots = slot.Container() or 0
            for j = 1, bag_slots do
                local item = slot.Item(j)
                if item() and item.Name() and utils.iequals(item.Name(), item_name) then
                    return true
                end
            end
        end
    end

    -- Check worn slots
    for i = 0, 22 do
        local worn = mq.TLO.Me.Inventory(i)
        if worn() and worn.Name() and utils.iequals(worn.Name(), item_name) then
            return true
        end
    end

    return false
end

-- Helper: Runs a function and prints how long it took
-- Usage: utils.time_it(my_function, arg1, arg2)
function utils.time_it(func, ...)
    local start = os.clock()

    -- Run the function with all arguments passed to time_it
    local result = { func(...) }

    local elapsed_ms = (os.clock() - start) * 1000
    print(string.format("\27[35m[Timer] Execution: %.4f ms\27[0m", elapsed_ms))

    -- Return the actual results of the function
    return table.unpack(result)
end

-- Delay with condition
function utils.wait(ms, condition)
    mq.delay(ms, condition)
end

return utils
