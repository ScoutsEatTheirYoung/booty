local mq = require('mq')

local moveActs = {}

function moveActs.approachTarget(meleeRange)
    if mq.TLO.Navigation.Active() then return true end
    local target = mq.TLO.Target
    if not target() then return end
    if target.Distance() > meleeRange and not mq.TLO.Navigation.Active() then
        mq.cmd('/squelch /nav target distance=' .. (meleeRange - 2))
        return true
    end
    return false
end
function moveActs.fanFollow(leaderName, offset, threshold)
    if mq.TLO.Navigation.Active() then return true end
    local leader = mq.TLO.Spawn('pc =' .. leaderName)
    if not leader() then return end
    if leader.Distance() > threshold and not mq.TLO.Navigation.Active() then
        local destY = leader.Y() + (offset.y or 0)
        local destX = leader.X() + (offset.x or 0)
        mq.cmd(string.format('/squelch /nav locyx %f %f', destY, destX))
        return true
    end
    return false
end


return moveActs