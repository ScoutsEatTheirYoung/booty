-- bt/core/state.lua

local State = {
    IDLE = 1,
    RUNNING = 2,
    SUCCESS = 3,
    FAILURE = 4
}

-- Lock the table so you can't accidentally overwrite a state at runtime
setmetatable(State, {
    __newindex = function(_, key, _)
        error("Attempt to modify read-only Enum bt.State: " .. tostring(key), 2)
    end
})

return State