local Node = require('booty.bot.bt.core.node')

---@class Composite : Node
---@field children Node[]
local Composite = {}
setmetatable(Composite, { __index = Node })
Composite.__index = Composite

---@param name? string
---@param children? Node[]
---@return Composite
function Composite:new(name, children)
    local obj = Node.new(self, name) --[[@as Composite]]
    obj.children = children or {}
    obj.activeChild = nil
    return obj
end

function Composite:abort()
    if self.activeChild then
        self.activeChild:abort()
        self.activeChild = nil
    end
    Node.abort(self)
end

return Composite