local mq = require('mq')

local movementUtils = {}

-- ============================================================
-- Pure checks
-- ============================================================

--- 2D distance from the player to an absolute world point.
---@param point Point
---@return number
function movementUtils.distanceTo(point)
    local dy = mq.TLO.Me.Y() - point.y
    local dx = mq.TLO.Me.X() - point.x
    return math.sqrt(dy * dy + dx * dx)
end

-- ============================================================
-- Actors
-- ============================================================

--- Stand up if sitting. Returns true if a stand command was issued.
---@return boolean, string
function movementUtils.standIfNeeded()
    if not mq.TLO.Me.Sitting() then return false, '' end
    mq.cmd('/stand')
    return true, 'Standing up'
end

return movementUtils
