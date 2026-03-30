local mq = require('mq')

local bt = { SUCCESS = 1, FAILURE = 2, RUNNING = 3 }


function bt.CreateNode(name, node_type, execute_func, children)
    local node = {
        name = name,
        type = node_type,
        children = children -- Can be nil for leaves
    }
    
    -- This makes the table callable, just like a standard Lua function
    return setmetatable(node, {
        __call = function() return execute_func() end
    })
end

-- Sequence (AND)
function bt.Sequence(name, nodes)
    local execute = function()
        for _, node in ipairs(nodes) do
            local status, msg, child_name = node()
            
            -- If a child is doing something, bubble it up and add our name
            if status ~= bt.SUCCESS then 
                local path = name .. " -> " .. (child_name or "Unknown")
                return status, msg, path
            end
        end
        return bt.SUCCESS, "Done", name
    end
    return bt.CreateNode(name, "Sequence", execute, nodes)
end

-- Selector (OR)
function bt.Selector(name, nodes)
    local execute = function()
        for _, node in ipairs(nodes) do
            local status, msg, child_name = node()
            
            -- If a child is working or succeeded, bubble it up
            if status ~= bt.FAILURE then 
                local path = name .. " -> " .. (child_name or "Unknown")
                return status, msg, path
            end
        end
        return bt.FAILURE, "All Failed", name
    end
    return bt.CreateNode(name, "Selector", execute, nodes)
end

function bt.MemSequence(name, nodes)
    local currentIndex = 1
    local execute = function()
        while currentIndex <= #nodes do
            local status, msg, child_name = nodes[currentIndex]()
            
            if status == bt.SUCCESS then
                currentIndex = currentIndex + 1
            elseif status == bt.FAILURE then
                currentIndex = 1
                return bt.FAILURE, msg, name .. " -> " .. (child_name or "Unknown")
            else -- RUNNING
                return bt.RUNNING, msg, name .. " -> " .. (child_name or "Unknown")
            end
        end
        currentIndex = 1
        return bt.SUCCESS, "Done", name
    end
    return bt.CreateNode(name, "MemSequence", execute, nodes)
end

function bt.AlwaysSucceed(name, childNode)
    return bt.CreateNode(name, "AlwaysSucceed", function()
        local status, msg, child_name = childNode()
        if status == bt.RUNNING then
            return bt.RUNNING, msg, name .. " -> " .. (child_name or "Unknown")
        end
        return bt.SUCCESS, "Forced Success (Original: " .. (msg or "") .. ")", name
    end, { childNode })
end

function bt.Cooldown(name, duration, childNode)
    local lastExecutionTime = 0
    return bt.CreateNode(name, "Cooldown", function()
        local now = mq.gettime()
        
        -- 1. Return FAILURE so the parent Selector can move to the next child (FollowLeader)
        if now < (lastExecutionTime + duration) then
            return bt.RUNNING, string.format("Cooling down (%d ms left)", duration - (now - lastExecutionTime)), name
        end
        
        local status, msg, child_name = childNode()
        
        -- 2. Reset the timer when the task is DONE (Success OR Failure).
        -- Do not reset if it is RUNNING (e.g., waiting for a server sync or cast bar).
        if status ~= bt.RUNNING then
            lastExecutionTime = now
        end
        
        return status, msg, name .. " -> " .. (child_name or "Unknown")
    end, { childNode })
end


function bt.Gate(name, conditionFunc, childNode)
    return bt.CreateNode(name, "Gate", function()
        if not conditionFunc() then
            return bt.FAILURE, "Gate condition not met", name
        end
        local status, msg, child_name = childNode()
        return status, msg, name .. " -> " .. (child_name or "Unknown")
    end, { childNode })
end

function bt.Leaf(name, actionFunc)
    return bt.CreateNode(name, "Leaf", function()
        local status, msg = actionFunc()
        
        -- The Safety Net: Catch functions that forget to return a status
        if status == nil then
            return bt.FAILURE, "CRITICAL: Node returned nil status", name
        end
        
        return status, msg, name
    end)
end

function bt.Wait(name, duration_seconds)
    local start_time = 0
    local is_waiting = false
    
    return bt.Leaf(name, function()
        local now = os.clock()
        
        if not is_waiting then
            start_time = now
            is_waiting = true
            return bt.RUNNING, "Starting wait...", name
        end
        
        if (now - start_time) >= duration_seconds then
            is_waiting = false -- Reset for the next time we need to wait
            return bt.SUCCESS, "Wait complete", name
        end
        
        return bt.RUNNING, string.format("Waiting... %.1fs left", duration_seconds - (now - start_time)), name
    end)
end

function bt.Inverter(name, childNode)
    return bt.CreateNode(name, "Inverter", function()
        local status, msg, child_name = childNode()
        if status == bt.SUCCESS then
            return bt.FAILURE, "Inverted: " .. msg, name .. " -> " .. (child_name or "Unknown")
        elseif status == bt.FAILURE then
            return bt.SUCCESS, "Inverted: " .. msg, name .. " -> " .. (child_name or "Unknown")
        else -- RUNNING
            return bt.RUNNING, msg, name .. " -> " .. (child_name or "Unknown")
        end
    end, { childNode })
end

function bt.PrintTree(node, depth)
    depth = depth or 0
    local indent = string.rep("  ", depth)

    -- Print the current node
    print(indent .. string.format("[%s] %s", node.type, node.name))

    -- If it has children (Sequence/Selector/MemSequence), recurse
    if node.children then
        for _, child in ipairs(node.children) do
            bt.PrintTree(child, depth + 1)
        end
    end
end

return bt