local mq = require('mq')

local fsm = {
    currentStateName = "NONE",
    currentState = {},
    states = {},
    lastReason = nil,
}

function fsm.changeState(newStateName)
    if not newStateName then return end

    local upperState = string.upper(newStateName)

    if fsm.states[upperState] then
        if fsm.currentState and fsm.currentState.onExit then
            fsm.currentState.onExit()
        end

        fsm.currentStateName = upperState
        fsm.currentState = fsm.states[upperState]
        fsm.lastReason = nil  -- Reset so the new state's first reason always prints

        if fsm.currentState.onEnter then
            fsm.currentState.onEnter()
        end

        print("\ag[FSM]\aw Transitioned to: \ay" .. upperState)
    else
        print("\ar[FSM Error]\aw Invalid state: " .. tostring(newStateName))
    end
end

-- Executes the current state. States return (consumed, reason).
-- Reason is printed only when it changes, keeping output clean.
function fsm.update()
    if fsm.currentState and fsm.currentState.execute then
        local _, reason = fsm.currentState.execute()
        if reason ~= fsm.lastReason then
            fsm.lastReason = reason
            if reason then
                print(string.format('\ag[%s]\ax %s', fsm.currentStateName, reason))
            end
        end
    end
end

function fsm.getState()
    return fsm.currentStateName
end

mq.bind('/setstate', function(newState)
    fsm.changeState(newState)
end)

return fsm
