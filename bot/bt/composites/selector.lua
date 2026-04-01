local Composite = require('booty.bot.bt.core.composite')
local State = require('booty.bot.bt.core.state')

---@class Selector : Composite
local Selector = {}
setmetatable(Selector, { __index = Composite })
Selector.__index = Selector

---@param name? string
---@param children? Node[]
---@return Selector
function Selector:new(name, children)
    return Composite.new(self, name, children) --[[@as Selector]]
end

function Selector:execute(context)
    for _, child in ipairs(self.children) do
        local status = child:tick(context)
        if status ~= State.FAILURE then
            if status == State.RUNNING then
                self.activeChild = child
            else -- SUCCESS: abort any child that was previously running
                if self.activeChild and self.activeChild ~= child then
                    self.activeChild:abort()
                end
                self.activeChild = nil
            end
            return status
        end
    end
    self.activeChild = nil
    return State.FAILURE
end

return Selector