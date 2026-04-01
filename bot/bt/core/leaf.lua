local Node = require('booty.bot.bt.core.node')
local State = require('booty.bot.bt.core.state')

---@class Leaf : Node
---@field actionFn (fun(self: Leaf, context: table): integer)|nil
local Leaf = {}
setmetatable(Leaf, { __index = Node })
Leaf.__index = Leaf

---@param name? string
---@param actionFn? fun(self: Leaf, context: table): integer, string?
---@return Leaf
function Leaf:new(name, actionFn)
    local obj = Node.new(self, name) --[[@as Leaf]]
    obj.actionFn = actionFn
    return obj
end

function Leaf:execute(context)
    if self.actionFn then
        -- Inject both the node instance (self) and the game state (context)
        return self.actionFn(self, context)
    end
    return State.FAILURE
end

return Leaf