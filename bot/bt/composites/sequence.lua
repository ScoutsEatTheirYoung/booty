local Composite = require('booty.bot.bt.core.composite')
local State = require('booty.bot.bt.core.state')

---@class Sequence : Composite
local Sequence = {}
setmetatable(Sequence, { __index = Composite })
Sequence.__index = Sequence

---@param name? string
---@param children? (Node | Composite)[]
---@return Sequence
function Sequence:new(name, children)
    return Composite.new(self, name, children) --[[@as Sequence]]
end

function Sequence:execute(context)
    for _, child in ipairs(self.children) do
        local status = child:tick(context)
        if status ~= State.SUCCESS then
            if status == State.RUNNING then
                self.activeChild = child
            else -- FAILURE: abort any child that was previously running
                if self.activeChild and self.activeChild ~= child then
                    self.activeChild:abort()
                end
                self.activeChild = nil
            end
            return status
        end
    end
    self.activeChild = nil
    return State.SUCCESS
end

return Sequence