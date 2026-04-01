local Node = require('booty.bot.bt.core.node')

---@class Decorator : Node
local Decorator = {}
setmetatable(Decorator, { __index = Node })
Decorator.__index = Decorator

---@param name? string
---@param child? Node
---@return Decorator
function Decorator:new(name, child)
    local obj = Node.new(self, name) --[[@as Decorator]]
    obj.child = child
    return obj
end

function Decorator:abort()
    if self.child then
        self.child:abort()
    end
    Node.abort(self)
end

return Decorator