local Decorator = require('booty.bot.bt.core.decorator')
local State = require('booty.bot.bt.core.state')

---@class Invert : Decorator
local Invert = {}
setmetatable(Invert, { __index = Decorator })
Invert.__index = Invert

---@param name? string
---@param child? Node
---@return Invert
function Invert:new(name, child)
    return Decorator.new(self, name, child) --[[@as Invert]]
end

function Invert:execute(context)
    if not self.child then return State.SUCCESS end

    local state, msg = self.child:tick(context)
    if state == State.SUCCESS then return State.FAILURE, msg end
    if state == State.FAILURE then return State.SUCCESS, msg end
    return State.RUNNING, msg
end

return Invert