local Leaf  = require('booty.bot.bt.core.leaf')
local State = require('booty.bot.bt.core.state')

-- Control flow primitives. Not sensors (they can return RUNNING) and not domain
-- actions (they issue no EQ commands). Use plain Leaf.

local control = {}

-- Holds the current branch open indefinitely. Used as the final child in a
-- Selector to park the tree while waiting for an external event (e.g. a group invite).
---@param msg? string
---@return Leaf
function control.returnRunning(msg)
    local label = msg or "Waiting..."
    return Leaf:new("[A]_Hold_" .. label, function()
        return State.RUNNING, label
    end)
end

return control
