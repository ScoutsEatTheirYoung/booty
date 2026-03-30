local targetUtils = require('booty.bot.bricks.targetUtils')

local meleeUtils = {}

--- Return the given PC's target if it is a live NPC worth assisting, else nil.
---@param spawnID integer
---@return MQSpawn|nil
function meleeUtils.getAssistTarget(spawnID)
    local t = targetUtils.getPCTarget(spawnID)
    if not t then return nil end
    if t.Type() ~= "NPC" then return nil end
    if (t.PctHPs() or 0) <= 0 then return nil end
    return t
end

return meleeUtils
