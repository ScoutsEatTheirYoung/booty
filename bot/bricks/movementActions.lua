local mq            = require('mq')
local movementUtils = require('booty.bot.bricks.movementUtils')

local movementActions = {}

-- ============================================================
-- Nav ownership state
-- Each nav function tags itself when it issues a /nav command.
-- isMyNav(tag) returns true only if nav is active AND this
-- function started it. If nav is active but belongs to someone
-- else, the function falls through and issues its own command.
-- ============================================================
local navOwner = nil

local function isMyNav(tag)
    if not mq.TLO.Navigation.Active() then
        navOwner = nil
        return false
    end
    return navOwner == tag
end

local function claimNav(tag)
    navOwner = tag
end

-- ============================================================
-- Actors  (nav*)
-- ============================================================

--- Stop any active navigation immediately.
function movementActions.stopNav()
    mq.cmd('/squelch /nav stop')
    navOwner = nil
end

--- Navigate toward the current target if outside meleeRange.
--- Non-blocking: returns false when nav is active so the caller
--- can still cast spells while approaching.
---@param meleeRange number
---@return boolean, string
function movementActions.navToTarget(meleeRange)
    local target = mq.TLO.Target
    if not target() then return false, 'No target' end
    local tag = 'target:' .. target.ID()
    if target.Distance() <= meleeRange then navOwner = nil; return false, 'Already in range of target' end
    if isMyNav(tag) then return false, string.format('Approaching target (%.0f units)', target.Distance()) end
    local c, r = movementUtils.standIfNeeded()
    if c then return c, r end
    mq.cmdf('/squelch /nav target distance=%d', meleeRange - 1)
    claimNav(tag)
    return false, string.format('Navigating to target (%.0f units)', target.Distance())
end

--- Face current target and close to losRange if line of sight is blocked.
--- Blocking while moving (returns true); returns false once LoS is clear
--- and cancels any active nav so the caller can cast immediately.
---@param losRange number  close enough to see around obstacles
---@return boolean, string
function movementActions.navForLoS(losRange)
    local target = mq.TLO.Target
    if not target() then return false, 'No target' end
    mq.cmd('/face fast')
    if not target.LineOfSight() then
        movementActions.navToTarget(losRange)
        return true, 'Moving for line of sight'
    end
    -- LoS is clear — cancel any nav that was running for LoS recovery
    movementActions.stopNav()
    return false, 'In position'
end

---@param spawnID integer
---@param meleeRange number
---@return boolean, string
function movementActions.navToPC(spawnID, meleeRange)
    local pc = mq.TLO.Spawn(spawnID)
    if not pc() then return false, string.format('Spawn %d not found in zone', spawnID) end
    local name = pc.Name() or tostring(spawnID)
    local tag = 'pc:' .. spawnID
    if pc.Distance() <= meleeRange then navOwner = nil; return false, string.format('Already in range of %s', name) end
    if isMyNav(tag) then return false, string.format('Navigating to %s (%.0f units)', name, pc.Distance()) end
    mq.cmdf('/squelch /nav id %d distance=%d', spawnID, meleeRange - 2)
    claimNav(tag)
    return true, string.format('Navigating to %s (%.0f units)', name, pc.Distance())
end

--- Navigate to a fixed world position if farther than radius.
--- Blocking: returns true while active so the caller does nothing else.
---@param point Point  Absolute world coordinates
---@param radius number
---@return boolean, string
function movementActions.navToPoint(point, radius)
    local dist = movementUtils.distanceTo(point)
    local tag = string.format('point:%.0f,%.0f', point.y, point.x)
    if dist <= radius then navOwner = nil; return false, 'Already at destination' end
    if isMyNav(tag) then return true, string.format('Returning to camp (%.0f units)', dist) end
    mq.cmdf('/squelch /nav locyx %f %f', point.y, point.x)
    claimNav(tag)
    return true, string.format('Returning to camp (%.0f units)', dist)
end

--- Navigate to a spawn by ID if outside range.
--- Blocking: returns true while active so the caller does nothing else.
---@param spawn MQSpawn
---@param range number
---@return boolean, string
function movementActions.navToSpawn(spawn, range)
    if not spawn or not spawn() then return false, 'Spawn not found' end
    local name = spawn.Name() or 'spawn'
    local tag = 'spawn:' .. spawn.ID()
    if spawn.Distance() <= range then navOwner = nil; return false, string.format('Already in range of %s', name) end
    if isMyNav(tag) then return true, string.format('Navigating to %s (%.0f units)', name, spawn.Distance()) end
    local c, r = movementUtils.standIfNeeded()
    if c then return c, r end
    mq.cmdf('/squelch /nav id %d distance=%d', spawn.ID(), range - 2)
    claimNav(tag)
    return true, string.format('Navigating to %s (%.0f units)', name, spawn.Distance())
end

--- Navigate to the given leader spawn's position + offset if farther than threshold.
--- Non-blocking: returns false when nav is active so the caller can
--- still cast spells while walking.
---@param leaderID integer
---@param offset Point
---@param threshold number
---@return boolean, string
function movementActions.navFanFollow(leaderID, offset, threshold)
    local leader = mq.TLO.Spawn(leaderID)
    if not leader() then return false, string.format('Leader %d not found in zone', leaderID) end
    local name = leader.Name() or tostring(leaderID)
    local tag = 'fanfollow:' .. leaderID
    if leader.Distance() <= threshold then navOwner = nil; return false, string.format('In follow range of %s', name) end
    if isMyNav(tag) then return false, string.format('Fan-following %s (%.0f units)', name, leader.Distance()) end
    local c, r = movementUtils.standIfNeeded()
    if c then return c, r end
    local destY = leader.Y() + (offset.y or 0)
    local destX = leader.X() + (offset.x or 0)
    local destZ = leader.Z()
    mq.cmdf('/squelch /nav locyxz %f %f %f', destY, destX, destZ)
    claimNav(tag)
    return true, string.format('Fan-following %s (%.0f units)', name, leader.Distance())
end

-- ============================================================
-- Actors  (face*)
-- ============================================================

--- Instantly snap to face a world point.
---@param point Point
---@return boolean, string
function movementActions.snapFacePoint(point)
    local deg = movementUtils.headingToPoint(point)
    mq.cmdf('/face heading %f fast', deg)
    return true, 'Snapping to face point'
end

--- Instantly snap to face a spawn.
---@param spawn MQSpawn
---@return boolean, string
function movementActions.snapFaceSpawn(spawn)
    if not spawn or not spawn() then return false, 'Invalid spawn' end
    mq.cmdf('/face id %d fast', spawn.ID())
    return true, string.format('Snapping to face %s', spawn.Name() or 'spawn')
end

--- Instantly snap to face the current target.
---@return boolean, string
function movementActions.snapFaceCurrentTarget()
    if not mq.TLO.Target() then return false, 'No target' end
    mq.cmd('/face fast')
    return true, 'Snapping to face target'
end

--- Turn to face a world point. Returns true while turning, false when within tolerance.
---@param point Point
---@param tolerance number  degrees of acceptable error (default 10)
---@return boolean, string
function movementActions.turnFacePoint(point, tolerance)
    tolerance = tolerance or 10
    local deg = movementUtils.headingToPoint(point)
    if movementUtils.isFacingDegrees(deg, tolerance) then
        return false, 'Facing point'
    end
    mq.cmdf('/face heading %f', deg)
    return true, 'Turning to face point'
end

--- Turn to face a spawn. Returns true while turning, false when within tolerance.
---@param spawn MQSpawn
---@param tolerance number  degrees of acceptable error (default 10)
---@return boolean, string
function movementActions.turnFaceSpawn(spawn, tolerance)
    tolerance = tolerance or 10
    if not spawn or not spawn() then return false, 'Invalid spawn' end
    local deg = movementUtils.headingToSpawn(spawn)
    if not deg then return false, 'Invalid spawn' end
    if movementUtils.isFacingDegrees(deg, tolerance) then
        return false, string.format('Facing %s', spawn.Name() or 'spawn')
    end
    mq.cmdf('/face id %d', spawn.ID())
    return true, string.format('Turning to face %s', spawn.Name() or 'spawn')
end

--- Turn to face the current target. Returns true while turning, false when within tolerance.
---@param tolerance number  degrees of acceptable error (default 10)
---@return boolean, string
function movementActions.turnFaceCurrentTarget(tolerance)
    tolerance = tolerance or 10
    local target = mq.TLO.Target
    if not target() then return false, 'No target' end
    local deg = movementUtils.headingToSpawn(target)
    if not deg then return false, 'No target' end
    if movementUtils.isFacingDegrees(deg, tolerance) then
        return false, 'Facing target'
    end
    mq.cmd('/face')
    return true, 'Turning to face target'
end

--- Navigate to the Guildhall portal in the Guild Lobby.
--- Blocking: returns true while active.
---@return boolean, string
function movementActions.navToGuildhallPort()
    local tag = 'guildhall'
    if isMyNav(tag) then return true, 'Navigating to guildhall portal' end
    mq.cmd('/squelch /nav loc -183 -87')
    claimNav(tag)
    return true, 'Navigating to guildhall portal'
end

return movementActions
