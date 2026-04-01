local Leaf = require('booty.bot.bt.core.leaf')
local State = require('booty.bot.bt.core.state')

local action = {}

function action.returnRunning(msg)
    return Leaf:new("ReturnRunning_" .. (msg or "Trap"), function()
        -- Holds the branch open permanently until a higher priority aborts it 
        -- or a Cooldown decorator releases a sibling node.
        return State.RUNNING
    end)
end

return action