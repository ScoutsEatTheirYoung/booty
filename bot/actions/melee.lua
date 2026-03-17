local target = require('booty.bot.actions.target')

local melee = {}

--- Return pcName's target if it is a live NPC worth assisting, else nil.
---@param pcName string
---@return MQSpawn|nil
function melee.getAssistTarget(pcName)
    local t = target.getPcTarget(pcName)
    if not t then return nil end
    if t.Type() ~= "NPC" then return nil end
    if (t.PctHPs() or 0) <= 0 then return nil end
    return t
end

return melee
