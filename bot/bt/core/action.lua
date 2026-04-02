local Leaf = require('booty.bot.bt.core.leaf')

---@class Action : Leaf
local Action = {}
setmetatable(Action, { __index = Leaf })
Action.__index = Action

---@param name string
---@param fns {execute: fun(self: Action, context: table): integer, string?, onEnter: (fun(self: Action, context: table))?, onExit: (fun(self: Action, context: table|nil))?}
---@return Action
function Action:new(name, fns)
    local obj = Leaf.new(self, name, fns.execute) --[[@as Action]]
    if fns.onEnter then obj.onEnter = fns.onEnter end
    if fns.onExit  then obj.onExit  = fns.onExit  end
    return obj
end

return Action
