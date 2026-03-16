local mq = require('mq')

local move = {}

-- ============================================================
-- Actors  (nav*)
-- ============================================================

-- Navigate toward the current target if outside meleeRange and not already navigating.
function move.navToTarget(meleeRange)
    if mq.TLO.Navigation.Active() then return false end
    local target = mq.TLO.Target
    if not target() then return false end
    if target.Distance() <= meleeRange then return false end
    mq.cmdf('/squelch /nav target distance=%d', meleeRange - 2)
    return true, string.format('Navigating to target (%.0f units)', target.Distance())
end

-- Navigate to leaderName's position + offset if farther than threshold.
function move.navFanFollow(leaderName, offset, threshold)
    if mq.TLO.Navigation.Active() then return false end
    local leader = mq.TLO.Spawn('pc =' .. leaderName)
    if not leader() then return false end
    if leader.Distance() <= threshold then return false end
    local destY = leader.Y() + (offset.y or 0)
    local destX = leader.X() + (offset.x or 0)
    mq.cmdf('/squelch /nav locyx %f %f', destY, destX)
    return true, string.format('Fan-following %s (%.0f units)', leaderName, leader.Distance())
end

return move
