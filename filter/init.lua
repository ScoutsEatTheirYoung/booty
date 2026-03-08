local mq = require('mq')
local Parser = require('booty.filter.parser')
local utils = require('booty.utils')
local lfs = require('lfs')

local Filter = {}
Filter.__index = Filter

-- ============================================================================
-- CORE METHODS
-- ============================================================================

-- Create a new, empty filter object
function Filter.new(name)
    local self = setmetatable({}, Filter)
    self.name = name
    -- self.text is the raw text of the filter file, which can be edited in the GUI. It is not used for matching logic, but can be useful for display and editing purposes.
    self.text = ""
    -- self.rules is an array of functions that take an item and return TRUE if it matches the filter
    self.rules = {}
    return self
end

-- Find all filters in the default folder
function Filter.getAllFilters()
    local filters = {}
    local folder = string.format("%s/lua/booty/filters/", mq.TLO.MacroQuest.Path())

    for file in lfs.dir(folder) do
        if file:match("%.txt$") then
            table.insert(filters, (file:gsub("%.txt$", "")))
        end
    end

    return filters
end

-- Loads a filter from disk
function Filter.load(filterName)
    local instance = Filter.new(filterName)
    local path = string.format("%s/lua/booty/filters/%s.txt", mq.TLO.MacroQuest.Path(), filterName)
    
    local f = io.open(path, "r")
    if not f then
        utils.error(string.format("Filter file not found: %s", path))
        return nil
    end

    for line in f:lines() do
        instance.text = instance.text .. line .. "\n"
        local ruleFunc = Parser.parse_line(line, true)
        if ruleFunc then
            table.insert(instance.rules, ruleFunc)
        end
    end
    f:close()
    
    utils.success(string.format("Loaded filter '%s' with %d rules.", filterName, #instance.rules))
    return instance
end

-- Returns TRUE if the item matches ANY rule in the filter
function Filter:matches(item)
    if not item then return false end
    
    for _, ruleFunc in ipairs(self.rules) do
        local success, result = pcall(ruleFunc, item)
        if success and result == true then
            return true
        end
    end
    return false
end

-- ============================================================================
-- SKELETON GENERATOR
-- ============================================================================
function Filter.create_skeleton(filterName)
    local folder = string.format("%s/lua/booty/filters/", mq.TLO.MacroQuest.Path())
    local path = folder .. filterName .. ".txt"
    
    local f = io.open(path, "w")
    if not f then
        utils.error(string.format("Could not create file at %s. (Does the 'filters' folder exist?)", path))
        return false
    end

    local content = [[
# ==============================================================================
#  BOOTY FILTER: ]] .. filterName .. [[
# ==============================================================================
#
#  SYNTAX RULES:
#    - Lines starting with '#' are COMMENTS and are ignored.
#    - BLANK lines are ignored.
#    - Leading and trailing whitespace is automatically trimmed.
#
#  MATCHING LOGIC:
#    The script reads this file from TOP to BOTTOM.
#    The FIRST rule that matches an item returns "TRUE" (Match Found).
#
#  WHITELIST vs. BLACKLIST (The Consequence):
#    This file defines "What Matches". The result depends on your mode:
#
#    1. WHITELIST MODE (Inclusive):
#       "If it MATCHES, DO the action."
#       - Looting: Match = Loot it.
#       - Selling: Match = Sell it.
#
#    2. BLACKLIST MODE (Exclusive / Safety):
#       "If it MATCHES, Do NOT do the action."
#       - Looting: Match = Do NOT Loot (Ignore).
#       - Selling: Match = Do NOT Sell (Safe/Keep).
#
# ==============================================================================
#  INSTRUCTIONS:
#    Name:      Matches exact item name (Default if no prefix used)
#    Pattern:   Matches Lua Regex pattern
#    Value:     Matches sell value (pp, gp, sp, cp)
#    Flag:      Matches boolean properties (NoDrop, Lore, Magic, Aug, Quest)
#    Slot:      Matches if item fits in a specific slot (Head, Ammo, Charm)
#    AugType:   Matches specific Augment Type integer (7, 8, etc)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. SPECIAL ITEMS (Flags & Types)
# ------------------------------------------------------------------------------

# Example: Match all Quest/NoDrop items
# Flag: NoDrop

# Example: Match all Augments
# Flag: Aug

# Example: Match standard gear augs
# AugType: 7
# AugType: 8

# ------------------------------------------------------------------------------
# 2. ASCENDANT / CUSTOM SERVER PATTERNS
# ------------------------------------------------------------------------------
# For full documentation on Lua Patterns, visit:
# https://www.lua.org/manual/5.1/manual.html#5.4.1
#
# Note: % is the escape character in Lua.
# Pattern: %s matches a space. Pattern: %( matches a literal parenthesis.

# Pattern: %s%(Enhanced%)$
# Pattern: %s%(Exalted%)$
# Pattern: %s%(Ascendant%)$

# ------------------------------------------------------------------------------
# 3. VALUE THRESHOLDS
# ------------------------------------------------------------------------------

# Example: Match anything worth more than 50 Platinum
# Value: >= 50pp

# Example: Match anything worth less than 1 Gold
# Value: < 1gp

# ------------------------------------------------------------------------------
# 4. SLOT FILTERING
# ------------------------------------------------------------------------------

# Example: Match anything that goes in the Ammo slot
# Slot: Ammo

# Example: Match anything that goes in the Charm slot
# Slot: Charm

# ------------------------------------------------------------------------------
# 5. EXACT NAMES
# ------------------------------------------------------------------------------

# You can use the prefix 'Name:' or just type the name directly.
# Bone Chips
# Spider Silk
# High Quality Bear Skin
# Diamond
# Blue Diamond

# End of Filter
]]

    f:write(content)
    f:close()
    
    utils.success(string.format("Created skeleton file: \at%s\ax", path))
    return true
end

-- ============================================================================
-- FULL INVENTORY TEST
-- ============================================================================

-- Accepts a fully loaded Filter Object (not just a string name)
function Filter.TestInventory(filter)
    if not filter or type(filter.matches) ~= "function" then
        utils.error("Invalid Filter Object passed to TestInventory")
        return
    end
    
    utils.info(string.format("Running Inventory Test against filter: \at%s\ax", filter.name or "Unnamed"))

    local matchCount = 0
    local totalItems = 0

    -- Helper to check a single item
    local function CheckItem(item, locationName)
        if item() then
            totalItems = totalItems + 1
            
            if filter:matches(item) then
                matchCount = matchCount + 1
                utils.pass(string.format("\ag%s\ax — %s \aw(%.2fpp)\ax", item.Name(), locationName, item.Value()/1000))
            else
                utils.fail(string.format("\ar%s\ax — %s \aw(%.2fpp)\ax", item.Name(), locationName, item.Value()/1000))
            end
        end
    end

    -- 1. Check Cursor
    CheckItem(mq.TLO.Cursor, "Cursor")

    -- 2. Check Packs 1-10
    for i = 1, 10 do
        local pack = mq.TLO.Me.Inventory("pack" .. i)
        
        -- If the slot has a bag
        if pack() then
            -- Iterate through the bag's capacity
            local slots = pack.Container() or 0
            for j = 1, slots do
                local item = pack.Item(j)
                CheckItem(item, string.format("Bag %d Slot %d", i, j))
            end
        end
    end

    print("---------------------------------------------------")
    utils.info(string.format("Test complete. Matched \ag%d\ax of \aw%d\ax items.", matchCount, totalItems))
end

return Filter