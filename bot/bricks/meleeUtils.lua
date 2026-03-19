local targetUtils = require('booty.bot.bricks.targetUtils')

local meleeUtils = {}

--- Return pcName's target if it is a live NPC worth assisting, else nil.
---@param pcName string
---@return MQSpawn|nil
function meleeUtils.getAssistTarget(pcName)
    local t = targetUtils.getPCTarget(pcName)
    if not t then return nil end
    if t.Type() ~= "NPC" then return nil end
    if (t.PctHPs() or 0) <= 0 then return nil end
    return t
end

return meleeUtils
