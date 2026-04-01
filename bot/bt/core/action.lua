local Leaf = require('booty.bot.bt.core.leaf')

---@class Action : Leaf
local Action = {}
setmetatable(Action, { __index = Leaf })
Action.__index = Action

---@param name string
---@param fn fun(self: Action, context: table): integer, string?
---@return Action
function Action:new(name, fn)
    return Leaf.new(self, name, fn) --[[@as Action]]
end

return Action
