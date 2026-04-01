local Decorator = require('booty.bot.bt.core.decorator')
local State = require('booty.bot.bt.core.state')

---@class AlwaysSucceed : Decorator
local AlwaysSucceed = {}
setmetatable(AlwaysSucceed, { __index = Decorator })
AlwaysSucceed.__index = AlwaysSucceed

---@param name? string
---@param child? Node
---@return AlwaysSucceed
function AlwaysSucceed:new(name, child)
    return Decorator.new(self, name, child) --[[@as AlwaysSucceed]]
end

function AlwaysSucceed:execute(context)
    if not self.child then return State.SUCCESS end

    local status = self.child:tick(context)
    
    if status == State.RUNNING then
        return State.RUNNING
    end
    
    return State.SUCCESS
end

return AlwaysSucceed