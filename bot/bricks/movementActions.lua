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
    mq.cmdf('/squelch /nav target distance=%d', meleeRange - 2)
    claimNav(tag)
    return false, string.format('Navigating to target (%.0f units)', target.Distance())
end

---@param pcName string
---@param meleeRange number
---@return boolean, string
function movementActions.navToPC(pcName, meleeRange)
    local pc = mq.TLO.Spawn('pc =' .. pcName)
    if not pc() then return false, string.format('%s not found in zone', pcName) end
    local tag = 'pc:' .. pcName
    if pc.Distance() <= meleeRange then navOwner = nil; return false, string.format('Already in range of %s', pcName) end
    if isMyNav(tag) then return false, string.format('Navigating to %s (%.0f units)', pcName, pc.Distance()) end
    mq.cmdf('/squelch /nav id %d distance=%d', pc.ID(), meleeRange - 2)
    claimNav(tag)
    return true, string.format('Navigating to %s (%.0f units)', pcName, pc.Distance())
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

--- Navigate to leaderName's position + offset if farther than threshold.
--- Non-blocking: returns false when nav is active so the caller can
--- still cast spells while walking.
---@param leaderName string
---@param offset Point
---@param threshold number
---@return boolean, string
function movementActions.navFanFollow(leaderName, offset, threshold)
    local leader = mq.TLO.Spawn('pc =' .. leaderName)
    if not leader() then return false, string.format('%s not found in zone', leaderName) end
    local tag = 'fanfollow:' .. leaderName
    if leader.Distance() <= threshold then navOwner = nil; return false, string.format('In follow range of %s', leaderName) end
    if isMyNav(tag) then return false, string.format('Fan-following %s (%.0f units)', leaderName, leader.Distance()) end
    local c, r = movementUtils.standIfNeeded()
    if c then return c, r end
    local destY = leader.Y() + (offset.y or 0)
    local destX = leader.X() + (offset.x or 0)
    mq.cmdf('/squelch /nav locyx %f %f', destY, destX)
    claimNav(tag)
    return true, string.format('Fan-following %s (%.0f units)', leaderName, leader.Distance())
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
