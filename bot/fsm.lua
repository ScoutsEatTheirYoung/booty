local mq = require('mq')

local FSM = {
    currentStateName = "NONE",
    currentState = {},
    states = {}
}

-- Method to handle transitioning cleanly
function FSM.changeState(newStateName)
    if not newStateName then return end
    
    local upperState = string.upper(newStateName)
    
    if FSM.states[upperState] then
        -- Run exit logic for the old state
        if FSM.currentState and FSM.currentState.onExit then
            FSM.currentState.onExit()
        end
        
        -- Swap to the new state
        FSM.currentStateName = upperState
        FSM.currentState = FSM.states[upperState]
        
        -- Run entry logic for the new state
        if FSM.currentState.onEnter then
            FSM.currentState.onEnter()
        end
        
        print("\ag[FSM]\aw Transitioned to: \ay" .. upperState)
    else
        print("\ar[FSM Error]\aw Invalid State Commanded: " .. tostring(newStateName))
    end
end

-- Method to execute the current state's main loop
function FSM.update()
    if FSM.currentState and FSM.currentState.execute then
        FSM.currentState.execute()
    end
end

-- Method to check the current state from anywhere
function FSM.getState()
    return FSM.currentStateName
end

-- The remote listener to catch Alpha's commands over DanNet
mq.bind('/setstate', function(newState)
    FSM.changeState(newState)
end)

return FSM