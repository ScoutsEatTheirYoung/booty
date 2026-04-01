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

--- Shortest angular distance between two headings in degrees (result: 0–180).
---@param a number
---@param b number
---@return number
local function headingDiff(a, b)
    return math.abs(((a - b + 180) % 360) - 180)
end

--- True if the player is facing within `tolerance` degrees of `targetDegrees`.
---@param targetDegrees number
---@param tolerance number
---@return boolean
function movementUtils.isFacingDegrees(targetDegrees, tolerance)
    local current = mq.TLO.Me.Heading.Degrees() or 0
    return headingDiff(current, targetDegrees) <= tolerance
end

--- Heading degrees from the player's position toward a world point.
---@param point Point
---@return number
function movementUtils.headingToPoint(point)
    return mq.TLO.Heading(point.y, point.x).Degrees()
end

--- Heading degrees from the player's position toward a spawn.
---@param spawn MQSpawn
---@return number|nil
function movementUtils.headingToSpawn(spawn)
    if not spawn or not spawn() then return nil end
    return spawn.HeadingTo.Degrees()
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
