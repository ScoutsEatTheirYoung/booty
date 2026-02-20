local Helpers = require('booty.filter.helpers')
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

function Parser.parse_line(line)
    -- Trim whitespace
    line = line:match("^%s*(.-)%s*$")
    
    -- Ignore comments and empty lines
    if line == "" or line:match("^#") then return nil end

    -- ========================================================
    -- TYPE 1: Value Threshold (Value: >= 10pp)
    -- ========================================================
    local op, valStr = line:match("^Value:%s*([<>=]+)%s*(.+)")
    if op and valStr then
        local threshold = Helpers.ParseMoney(valStr)
        return function(item)
            local itemVal = item.Value() or 0
            if op == ">" then return itemVal > threshold
            elseif op == "<" then return itemVal < threshold
            elseif op == ">=" then return itemVal >= threshold
            elseif op == "<=" then return itemVal <= threshold
            end
            return false
        end
    end

    -- ========================================================
    -- TYPE 2: Boolean Flag (Flag: NoDrop)
    -- ========================================================
    local flag = line:match("^Flag:%s*(.+)")
    if flag then
        flag = string.lower(flag)
        return function(item)
            if flag == "nodrop" then return item.NoDrop()
            elseif flag == "lore" then return item.Lore()
            elseif flag == "magic" then return item.Magic()
            elseif flag == "aug" then return (item.AugType() or 0) > 0 -- Is it an augment?
            end
            return false
        end
    end

    -- ========================================================
    -- TYPE 3: Worn Slot (Slot: Ammo)
    -- ========================================================
    local targetSlot = line:match("^Slot:%s*(.+)")
    if targetSlot then
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
    
    return function(item)
        return item.Name() == name
    end
end

return Parser