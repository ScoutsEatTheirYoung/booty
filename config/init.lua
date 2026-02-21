-- =========================================================================
-- booty/config/init.lua - Configuration loader and manager
-- =========================================================================
local mq = require('mq')

local config = {}

-- Store the active configuration
config._active = nil
config._user_config_path = nil

-- =========================================================================
-- Table Serialization
-- =========================================================================

-- Serialize a Lua table to a string that can be written to disk
local function serialize_value(val, indent)
    local t = type(val)
    if t == 'string' then
        return string.format('%q', val)
    elseif t == 'number' or t == 'boolean' then
        return tostring(val)
    elseif t == 'nil' then
        return 'nil'
    elseif t == 'table' then
        return serialize_table(val, indent)
    else
        return 'nil -- unsupported type: ' .. t
    end
end

function serialize_table(tbl, indent)
    indent = indent or 0
    local parts = {}
    local prefix = string.rep('    ', indent)
    local inner_prefix = string.rep('    ', indent + 1)

    table.insert(parts, '{')

    -- Sort keys for consistent output
    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    table.sort(keys, function(a, b)
        if type(a) == type(b) then
            return tostring(a) < tostring(b)
        end
        return type(a) < type(b)
    end)

    for _, k in ipairs(keys) do
        local v = tbl[k]
        local key_str
        if type(k) == 'string' and k:match('^[%a_][%w_]*$') then
            key_str = k
        else
            key_str = '[' .. serialize_value(k, indent + 1) .. ']'
        end

        local val_str = serialize_value(v, indent + 1)
        table.insert(parts, inner_prefix .. key_str .. ' = ' .. val_str .. ',')
    end

    table.insert(parts, prefix .. '}')
    return table.concat(parts, '\n')
end

-- =========================================================================
-- Deep Merge Utility
-- =========================================================================

-- Recursively merge source into target (source values override target)
local function deep_merge(target, source)
    if type(target) ~= 'table' or type(source) ~= 'table' then
        return source
    end

    local result = {}

    -- Copy all from target first
    for k, v in pairs(target) do
        if type(v) == 'table' then
            result[k] = deep_merge({}, v)
        else
            result[k] = v
        end
    end

    -- Override/add from source
    for k, v in pairs(source) do
        if type(v) == 'table' and type(result[k]) == 'table' then
            result[k] = deep_merge(result[k], v)
        else
            result[k] = v
        end
    end

    return result
end

-- =========================================================================
-- Path Resolution
-- =========================================================================

-- Get the booty plugin directory path
local function get_booty_path()
    -- mq.luaDir gives us the lua/ directory
    -- We need lua/booty/
    local lua_dir = mq.luaDir
    if lua_dir:sub(-1) ~= '/' and lua_dir:sub(-1) ~= '\\' then
        lua_dir = lua_dir .. '/'
    end
    return lua_dir .. 'booty/'
end

-- =========================================================================
-- Config Loading
-- =========================================================================

-- Load defaults (always succeeds)
local function load_defaults()
    return require('booty.config.defaults')
end

-- Try to load user config file
local function load_user_config(path)
    local f = io.open(path, 'r')
    if not f then
        return nil
    end

    local content = f:read('*all')
    f:close()

    -- Load the Lua chunk
    local chunk, err = load('return ' .. content, 'user_config', 't')
    if not chunk then
        -- Try loading as-is (might be a proper return statement)
        chunk, err = loadfile(path)
        if not chunk then
            print(string.format('\ar[Booty Config]\ax Error parsing config: %s', err))
            return nil
        end
    end

    local success, result = pcall(chunk)
    if not success then
        print(string.format('\ar[Booty Config]\ax Error executing config: %s', result))
        return nil
    end

    return result
end

-- Generate a user config file with helpful comments
local function generate_user_config(path)
    local template = [[
-- =========================================================================
-- Booty User Configuration
-- =========================================================================
-- This file contains YOUR customizations. Only add values you want to
-- override from the defaults. See config/defaults.lua for all options.
--
-- Example: To change loot distance and enable debug mode:
--
-- return {
--     general = {
--         debug = true,
--     },
--     loot = {
--         max_distance = 12,
--     },
-- }
--
-- =========================================================================

return {
    -- Add your overrides here

}
]]

    local f = io.open(path, 'w')
    if not f then
        print(string.format('\ar[Booty Config]\ax Could not create config file: %s', path))
        return false
    end

    f:write(template)
    f:close()
    return true
end

-- =========================================================================
-- Public API
-- =========================================================================

-- Load or reload configuration
-- Returns the merged configuration table
function config.load()
    local defaults = load_defaults()
    local booty_path = get_booty_path()
    local user_config_path = booty_path .. 'config.lua'

    config._user_config_path = user_config_path

    -- Try to load user config
    local user_config = load_user_config(user_config_path)

    if not user_config then
        -- Check if file exists
        local f = io.open(user_config_path, 'r')
        if f then
            f:close()
            -- File exists but failed to parse - already printed error
            print('\ay[Booty Config]\ax Using defaults due to config error')
        else
            -- File doesn't exist - create it
            print('\at[Booty Config]\ax Creating default config file: config.lua')
            generate_user_config(user_config_path)
        end
        user_config = {}
    end

    -- Merge user config over defaults
    config._active = deep_merge(defaults, user_config)

    return config._active
end

-- Get the active configuration (loads if necessary)
function config.get()
    if not config._active then
        config.load()
    end
    return config._active
end

-- Get a specific config value by dot-notation path
-- Example: config.value("loot.max_distance") returns 15
function config.value(path)
    local cfg = config.get()
    local parts = {}
    for part in path:gmatch('[^.]+') do
        table.insert(parts, part)
    end

    local current = cfg
    for _, part in ipairs(parts) do
        if type(current) ~= 'table' then
            return nil
        end
        current = current[part]
    end

    return current
end

-- Reload configuration from disk
function config.reload()
    -- Clear the cached defaults module so it reloads
    package.loaded['booty.config.defaults'] = nil
    config._active = nil
    return config.load()
end

-- Print current configuration (for debugging)
function config.dump()
    local function dump_table(tbl, indent)
        indent = indent or 0
        local prefix = string.rep('  ', indent)
        for k, v in pairs(tbl) do
            if type(v) == 'table' then
                print(string.format('%s%s:', prefix, k))
                dump_table(v, indent + 1)
            else
                print(string.format('%s%s = %s', prefix, k, tostring(v)))
            end
        end
    end

    print('\ag[Booty Config]\ax Current configuration:')
    dump_table(config.get())
end

-- Get path to user config file
function config.get_user_config_path()
    if not config._user_config_path then
        config.load()
    end
    return config._user_config_path
end

-- Save current configuration to disk
-- If save_all is true, saves entire merged config
-- If false (default), only saves what differs from defaults
function config.save(save_all)
    local path = config.get_user_config_path()
    local data_to_save

    if save_all then
        data_to_save = config.get()
    else
        -- Save only user overrides (the full config for now, can add diff later)
        data_to_save = config.get()
    end

    local content = '-- Booty Configuration\n'
    content = content .. '-- Auto-generated by config.save()\n\n'
    content = content .. 'return ' .. serialize_table(data_to_save, 0) .. '\n'

    local f = io.open(path, 'w')
    if not f then
        print(string.format('\ar[Booty Config]\ax Could not write config: %s', path))
        return false
    end

    f:write(content)
    f:close()
    print(string.format('\ag[Booty Config]\ax Saved to: %s', path))
    return true
end

-- Set a config value by dot-notation path and optionally save
-- Example: config.set("loot.max_distance", 20)
function config.set(path, value, auto_save)
    local cfg = config.get()
    local parts = {}
    for part in path:gmatch('[^.]+') do
        table.insert(parts, part)
    end

    -- Navigate to parent
    local current = cfg
    for i = 1, #parts - 1 do
        if type(current[parts[i]]) ~= 'table' then
            current[parts[i]] = {}
        end
        current = current[parts[i]]
    end

    -- Set the value
    current[parts[#parts]] = value

    if auto_save then
        config.save()
    end

    return true
end

return config
