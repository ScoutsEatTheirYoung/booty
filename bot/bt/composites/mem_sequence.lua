local Composite = require('booty.bot.bt.core.composite')
local State = require('booty.bot.bt.core.state')

---@class MemSequence : Composite
---@field cursor integer
local MemSequence = {}
setmetatable(MemSequence, { __index = Composite })
MemSequence.__index = MemSequence

---@param name? string
---@param children? Node[]
---@return MemSequence
function MemSequence:new(name, children)
    local obj = Composite.new(self, name, children) --[[@as MemSequence]]
    obj.cursor = 1
    return obj
end

function MemSequence:execute(context)
    while self.cursor <= #self.children do
        local child = self.children[self.cursor]
        local status = child:tick(context)
        
        if status == State.RUNNING then
            self.activeChild = child
            return State.RUNNING
        elseif status == State.FAILURE then
            self.activeChild = nil
            self.cursor = 1 -- Reset on failure so next visit starts at 1
            return State.FAILURE
        else
            -- SUCCESS: Move to the next child
            self.cursor = self.cursor + 1
        end
    end
    
    self.activeChild = nil
    self.cursor = 1 -- Reset when the entire sequence finishes
    return State.SUCCESS
end

-- CRITICAL: Must intercept the abort command to reset the cursor
function MemSequence:abort()
    self.cursor = 1
    Composite.abort(self)
end

return MemSequence