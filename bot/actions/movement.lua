local mq = require('mq')

local move = {}

-- ============================================================
-- Actors  (nav*)
-- ============================================================

--- Navigate toward the current target if outside meleeRange and not already navigating.
---@param meleeRange number
---@return boolean, string
function move.navToTarget(meleeRange)
    if mq.TLO.Navigation.Active() then return false, 'Navigation already active' end
    local target = mq.TLO.Target
    if not target() then return false, 'No target' end
    if target.Distance() <= meleeRange then return false, 'Already in range of target' end
    if mq.TLO.Me.Sitting() then mq.cmd('/stand'); return true, 'Standing up to approach' end
    mq.cmdf('/squelch /nav target distance=%d', meleeRange - 2)
    return true, string.format('Navigating to target (%.0f units)', target.Distance())
end

---@param pcName string
---@param meleeRange number
---@return boolean, string
function move.navToPC(pcName, meleeRange)
    if mq.TLO.Navigation.Active() then return false, 'Navigation already active' end
    local pc = mq.TLO.Spawn('pc =' .. pcName)
    if not pc() then return false, string.format('%s not found in zone', pcName) end
    if pc.Distance() <= meleeRange then return false, string.format('Already in range of %s', pcName) end
    mq.cmdf('/squelch /nav id %d distance=%d', pc.ID(), meleeRange - 2)
    return true, string.format('Navigating to %s (%d) (%.0f units)', pcName, pc.ID(), pc.Distance())
end

--- Navigate to a fixed world position if farther than radius. Used to return to a camp point.
---@param point Point  Absolute world coordinates
---@param radius number
---@return boolean, string
function move.navToPoint(point, radius)
    if mq.TLO.Navigation.Active() then return false, 'Navigation already active' end
    local dy = mq.TLO.Me.Y() - point.y
    local dx = mq.TLO.Me.X() - point.x
    local dist = math.sqrt(dy * dy + dx * dx)
    if dist <= radius then return false, 'Already at destination' end
    mq.cmdf('/squelch /nav locyx %f %f', point.y, point.x)
    return true, string.format('Returning to camp (%.0f units)', dist)
end

--- Navigate to leaderName's position + offset if farther than threshold.
---@param leaderName string
---@param offset Point
---@param threshold number
---@return boolean, string
function move.navFanFollow(leaderName, offset, threshold)
    if mq.TLO.Navigation.Active() then return false, 'Navigation already active' end
    local leader = mq.TLO.Spawn('pc =' .. leaderName)
    if not leader() then return false, string.format('%s not found in zone', leaderName) end
    if leader.Distance() <= threshold then return false, string.format('In follow range of %s', leaderName) end
    if mq.TLO.Me.Sitting() then mq.cmd('/stand'); return true, 'Standing up to follow' end
    local destY = leader.Y() + (offset.y or 0)
    local destX = leader.X() + (offset.x or 0)
    mq.cmdf('/squelch /nav locyx %f %f', destY, destX)
    return true, string.format('Fan-following %s (%.0f units)', leaderName, leader.Distance())
end

return move
