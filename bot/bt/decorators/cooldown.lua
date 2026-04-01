local mq = require('mq')
local Decorator = require('booty.bot.bt.core.decorator')
local State = require('booty.bot.bt.core.state')

---@class Cooldown : Decorator
---@field duration number
---@field lastExecutionTime number
local Cooldown = {}
setmetatable(Cooldown, { __index = Decorator })
Cooldown.__index = Cooldown

---@param name? string
---@param duration number
---@param child? Node
---@return Cooldown
function Cooldown:new(name, duration, child)
    local obj = Decorator.new(self, name, child) --[[@as Cooldown]]
    obj.duration = duration
    obj.lastExecutionTime = 0
    return obj
end

function Cooldown:execute(context)
    if not self.child then return State.FAILURE end

    local now = mq.gettime()

    -- If we are on cooldown, return FAILURE to let the Selector check the next branch
    if (now - self.lastExecutionTime) < self.duration then
        return State.FAILURE
    end

    local status = self.child:tick(context)
    
    -- Only reset the timer when the child actually finishes the task
    if status ~= State.RUNNING then
        self.lastExecutionTime = mq.gettime()
    end
    
    return status
end

return Cooldown