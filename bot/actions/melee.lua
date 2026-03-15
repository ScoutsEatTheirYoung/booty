local mq = require('mq')
local utilActs = require('bot/actions/util')

local meleeActs = {}

function meleeActs.assistSpawn(pcName)
    local target = utilActs.getPcTarget(pcName)
    if not target or not target() then return false end
    local spawnId = target.ID()
    mq.cmd('/assist id ' .. spawnId)
    return true
end


return meleeActs