local utils = require('booty.utils')
local Parser = {}

-- Helper to safely check worn slots
-- Returns TRUE if the item fits in the requested slot name (e.g., "Head")
local function FitsInSlot(item, targetSlotName)
    local count = item.WornSlots() or 0
    if count == 0 then return false end
    
    targetSlotName = string.lower(targetSlotName)
    
    -- Loop through all slots this item can be worn in
    for i = 1, count do
        -- item.WornSlot(i) returns the slot ID. We need the name.
        -- We can just check the string representation if MQ2 supports it, 
        -- or use the "Fit" logic. 
        -- Simpler approach: bitwise check or name check.
        -- For Emu/RoF2, checking the string name of the slot is safest.
        local slotName = string.lower(item.WornSlot(i).Name() or "")
        if slotName == targetSlotName then
            return true
        end
    end
    return false
end

local function ParseMoney(str)
    local valStr, unit = string.match(str, "([%d%.]+)%s*(%a*)")
    if not valStr then return 0 end
    
    local value = tonumber(valStr)
    unit = string.lower(unit or "")

    if unit == "pp" or unit == "plat" then return value * 1000
    elseif unit == "gp" or unit == "gold" then return value * 100
    elseif unit == "sp" or unit == "silver" then return value * 10
    else return value end -- Default to copper
end

-- We can have multiple filters on a single line treated as AND
-- they will be seperated by the ampersand character (&)
function Parser.parse_line(line, verbose)
    verbose = verbose or false
    -- Trim whitespace
    line = line:match("^%s*(.-)%s*$")
    -- Ignore comments and empty lines
    if line == "" or line:match("^#") then return nil end
    local subFilters = {}
    for part in string.gmatch(line, '([^&]+)') do
        local trimmedPart = part:match("^%s*(.-)%s*$")
        local filterFunc = Parser.parse_filter(trimmedPart, verbose)
        local explainFunc = function(item)
            local result = filterFunc(item)
            if verbose then
                if result then
                    utils.pass(string.format("[Parser] \ay%s\ax => \ag%s", trimmedPart, item.Name()))
                else
                    utils.fail(string.format("[Parser] \ay%s\ax => \ar%s", trimmedPart, item.Name()))
                end
            end
            return result
        end -- Wrap the filterFunc with explainFunc for better debugging
        if filterFunc then
            table.insert(subFilters, explainFunc)
        else
            utils.error(string.format("[Parser] Malformed filter part: \ay%s", part))
            return nil
        end
    end

    -- Return a function that checks all subfilters (AND logic)
    return function(item)
        for _, filterFunc in ipairs(subFilters) do
            if not filterFunc(item) then
                return false
            end
        end
        if verbose then
            utils.pass(string.format("[Parser] '\ag%s\ax' matched line '\at%s\ax'", item.Name(), line))
        end
        return true
    end
end
function Parser.parse_filter(line, verbose)
    verbose = verbose or false
    -- Trim whitespace
    line = line:match("^%s*(.-)%s*$")

    -- Ignore comments and empty lines
    if line == "" or line:match("^#") then return nil end

    -- ========================================================
    -- TYPE 1: Value Threshold (Value: >= 10pp)
    -- ========================================================
    local op, valStr = line:match("^Value:%s*([<>=]+)%s*(.+)")
    if op and valStr then
        local threshold = ParseMoney(valStr)
        if verbose then utils.info(string.format("[Parser] Loaded \ayValue\ax filter: %s %s (%d cp)", op, valStr, threshold)) end
        return function(item)
            local itemVal = item.Value() or 0
            local result = false
            if op == ">" then result = itemVal > threshold
            elseif op == "<" then result = itemVal < threshold
            elseif op == ">=" then result = itemVal >= threshold
            elseif op == "<=" then result = itemVal <= threshold
            end
            if verbose then
                local itemPP = itemVal / 1000
                local threshPP = threshold / 1000
                if result then
                    utils.pass(string.format("[Parser] Value: '\ag%s\ax' = \ag%.2fpp\ax (%d cp) %s \ay%.2fpp\ax (%d cp)",
                        item.Name(), itemPP, itemVal, op, threshPP, threshold))
                else
                    utils.fail(string.format("[Parser] Value: '\ar%s\ax' = \ar%.2fpp\ax (%d cp) NOT %s \ay%.2fpp\ax (%d cp)",
                        item.Name(), itemPP, itemVal, op, threshPP, threshold))
                end
            end
            return result
        end
    end

    -- ========================================================
    -- TYPE 2: Boolean Flag (Flag: NoDrop)
    -- ========================================================
    local flag = line:match("^Flag:%s*(.+)")
    if flag then
        flag = string.lower(flag)
        if verbose then utils.info(string.format("[Parser] Loaded \ayFlag\ax filter: %s", flag)) end
        return function(item)
            if flag == "nodrop" then return item.NoDrop()
            elseif flag == "lore" then return item.Lore()
            elseif flag == "magic" then return item.Magic()
            elseif flag == "aug" then return (item.AugType() or 0) > 0 -- Is it an augment?
            elseif flag == "stackable" then return item.Stackable()
            end
            return false
        end
    end

    -- ========================================================
    -- TYPE 3: Worn Slot (Slot: Ammo)
    -- ========================================================
    local targetSlot = line:match("^Slot:%s*(.+)")
    if targetSlot then
        if verbose then utils.info(string.format("[Parser] Loaded \aySlot\ax filter: %s", targetSlot)) end
        return function(item)
            return FitsInSlot(item, targetSlot)
        end
    end

    -- ========================================================
    -- TYPE 4: Augment Type (AugType: 7)
    -- ========================================================
    local augTypeStr = line:match("^AugType:%s*(%d+)")
    if augTypeStr then
        local targetType = tonumber(augTypeStr)
        if verbose then utils.info(string.format("[Parser] Loaded \ayAugType\ax filter: %d", targetType)) end
        return function(item)
            -- item.AugType() returns a bitmask on some servers, or int on others.
            -- On RoF2/Emu, it usually returns the specific type integer (7, 8).
            -- If your server uses bitmasks, we might need bitwise logic here.
            -- For now, simple equality usually works for standard Types.
            return (item.AugType() or 0) == targetType
        end
    end

    -- ========================================================
    -- TYPE 5: Lua Pattern (Pattern: ^Bone Chips$)
    -- ========================================================
    local pattern = line:match("^Pattern:%s*(.+)")
    if pattern then
        if verbose then utils.info(string.format("[Parser] Loaded \ayPattern\ax filter: %s", pattern)) end
        return function(item)
            return string.find(item.Name(), pattern) ~= nil
        end
    end

    -- ========================================================
    -- TYPE 6: Exact Name Match (Default)
    -- ========================================================
    local name = line
    if line:match("^Name:%s*") then
        name = line:match("^Name:%s*(.+)")
    end
    if verbose then utils.info(string.format("[Parser] Loaded \ayName\ax filter: '%s'", name)) end
    return function(item)
        return item.Name() == name
    end
end

Parser.LINE_TYPES = { "Name", "Pattern", "Value", "Flag", "Slot", "AugType", "Comment" }

return Parser