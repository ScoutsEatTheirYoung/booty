local mq         = require('mq')
local targetUtils = require('booty.bot.bricks.targetUtils')
local utils      = require('booty.utils')

local targetActions = {}

-- this saves hash lookups later but is a bit less clear than mq.TLO.Target everywhere
local cmdf     = mq.cmdf

-- ============================================================
-- Actors  (target*)
-- ============================================================

--- Target spawn if not already targeted.
--- Uses /tar <name> for self (EQ ignores /tar id on own character).
---@param spawn MQSpawn|MQTarget|nil
---@return boolean, string
function targetActions.targetSpawn(spawn)
    if not spawn or not spawn() then return false, 'Invalid spawn' end
    local id = spawn.ID()
    local c, r = targetActions.targetByID(id)
    if c then
        return true, string.format('Targeting %s', mq.TLO.Target.Name() or tostring(id))
    end
    return false, r
end

--- Target spawn by ID if not already targeted.
---@param id integer
---@return boolean, string
function targetActions.targetByID(id)
    local target = mq.TLO.Target
    if not id or id <= 0 then return false, 'Invalid spawn ID' end
    utils.info(string.format("Attempting to target spawn ID %d", id))
    if target.ID() == id then
        utils.info(string.format("Already targeting spawn ID %d (%s)", id, target.Name()))
        utils.info(string.format("Target buffs populated: %s", tostring(target.BuffsPopulated())))
        if not target.BuffsPopulated() then
            return true, 'Targeted but buffs not populated yet'
        end
        return false, 'Already targeting'
    end
    if id == mq.TLO.Me.ID() then
        cmdf('/squelch /tar %s', mq.TLO.Me.Name())
    else
        cmdf('/squelch /tar id %d', id)
    end
    return true, string.format('Targeting spawn ID %d', id)
end

--- Target what the given PC is targeting. Uses TargetOfTarget — no /assist command.
---@param spawnID integer
---@return boolean, string
function targetActions.targetPCTarget(spawnID)
    local t = targetUtils.getPCTarget(spawnID)
    if not t then return false, string.format('Spawn %d has no target', spawnID) end
    return targetActions.targetSpawn(t)
end

return targetActions
