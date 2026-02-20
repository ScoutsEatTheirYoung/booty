local Helpers = {}

-- Parses "10pp", "500gp", "100" into integer copper value
function Helpers.ParseMoney(str)
    local valStr, unit = string.match(str, "([%d%.]+)%s*(%a*)")
    if not valStr then return 0 end
    
    local value = tonumber(valStr)
    unit = string.lower(unit or "")

    if unit == "pp" or unit == "plat" then return value * 1000
    elseif unit == "gp" or unit == "gold" then return value * 100
    elseif unit == "sp" or unit == "silver" then return value * 10
    else return value end -- Default to copper
end

-- Checks if a file exists
function Helpers.FileExists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    else
        return false
    end
end

return Helpers