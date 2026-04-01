local State = require('booty.bot.bt.core.state')

---@class Node
---@field name string
---@field state integer
---@field statusMsg string|nil
---@field activeChild Node|nil   set by Composite subclasses
---@field child Node|nil         set by Decorator subclasses
local Node = {}
Node.__index = Node

---@param name? string
---@return Node
function Node:new(name)
    local obj = {
        name = name or "UnnamedNode",
        state = State.IDLE
    }
    setmetatable(obj, self)
    return obj
end

-- The Engine Pipeline
function Node:tick(context)
    if self.state ~= State.RUNNING then
        self:onEnter(context)
    end

    -- 1. Capture the exact results of the execution
    local execState, execMsg = self:execute(context)

    if execState ~= State.RUNNING then
        self:onExit(context)
        -- Reset internal state for the next time this node is evaluated
        self.state = State.IDLE
        self.statusMsg = nil
        return execState, execMsg
    else
        self.state = State.RUNNING
        local childMsg = (self.activeChild and self.activeChild.statusMsg)
                      or (self.child and self.child.statusMsg)
        self.statusMsg = execMsg or childMsg or self.name
        return self.state, self.statusMsg
    end
end

-- The Cascading Interrupt (No context needed, mechanical cleanup only)
function Node:abort()
    if self.state == State.RUNNING then
        -- We explicitly do not pass context here to enforce that aborts 
        -- do not make game-state decisions. They only stop current actions.
        self:onExit(nil)
        self.state = State.IDLE
    end
end

-- Virtual Methods for inheritance
---@return integer, string?
function Node:execute(_) return State.FAILURE end ---@diagnostic disable-line: unused-local
function Node:onEnter(_) end ---@diagnostic disable-line: unused-local
function Node:onExit(_) end ---@diagnostic disable-line: unused-local

return Node