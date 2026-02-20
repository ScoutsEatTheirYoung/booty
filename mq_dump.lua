local mq = require('mq')
local ImGui = require('ImGui')

local function recursive_dump()
    local folder = string.format("%s/lua/booty/", mq.TLO.MacroQuest.Path())
    local path = folder .. "mq_dump.txt"
    local f = io.open(path, "w")
    if not f then
        printf("\ar[Booty]\ax Could not create file at %s. (Does the 'filters' folder exist?)", path)
        return false
    end
    local visited = {}
    local max_depth = 3 -- Prevents crashing the game client

    local function dump(name, obj, depth)
        if depth > max_depth or visited[obj] then return end
        if type(obj) ~= "table" and type(obj) ~= "userdata" then return end
        
        visited[obj] = true
        f:write(string.format("--- %s ---\n", name))

        -- Try to get the iterable part (table or metatable)
        local target = obj
        if type(obj) == "userdata" then
            local mt = getmetatable(obj)
            target = (mt and mt.__index) and mt.__index or {}
        end

        -- Check if we can actually iterate
        local status, err = pcall(function()
            for k, v in pairs(target) do
                local vType = type(v)
                f:write(string.format("[%s] %s\n", vType, tostring(k)))
                
                -- Recurse if it's a sub-component
                if (vType == "table" or vType == "userdata") and depth < max_depth then
                    -- Filter out common circular refs and huge internal libs
                    if k ~= "_G" and k ~= "package" and k ~= "mq" and k ~= "ImGui" then
                        dump(name .. "." .. tostring(k), v, depth + 1)
                    end
                end
            end
        end)

        if not status then
            f:write(string.format("[Locked] %s: %s\n", name, err))
        end
    end

    -- Start the chain
    dump("mq", mq, 1)
    dump("ImGui", ImGui, 1)
end

recursive_dump()