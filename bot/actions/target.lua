local mq = require('mq')

local target = {}

-- ============================================================
-- Pure checks  (get*)
-- ============================================================

--- Return the spawn that pcName is currently targeting, or nil.
---@param pcName string
---@return MQTarget|nil
function target.getPcTarget(pcName)
    local pc = mq.TLO.Spawn('pc =' .. pcName)
    if not pc() then return nil end
    local t = pc.TargetOfTarget
    if not t() then return nil end
    return t
end

-- ============================================================
-- Actors  (target*)
-- ============================================================

--- Target spawn if not already targeted.
---@param spawn MQSpawn|MQTarget|nil
---@return boolean, string
function target.targetSpawn(spawn)
    if not spawn or not spawn() then return false, 'Invalid spawn' end
    local id = spawn.ID()
    if mq.TLO.Target.ID() == id then return false, 'Already targeted' end
    mq.cmdf('/squelch /tar id %d', id)
    return true, string.format('Targeting %s', spawn.Name() or tostring(id))
end

--- Target spawn by ID if not already targeted.
---@param id integer
---@return boolean, string
function target.targetByID(id)
    if not id or id <= 0 then return false, 'Invalid spawn ID' end
    if mq.TLO.Target.ID() == id then return false, 'Already targeted' end
    mq.cmdf('/squelch /tar id %d', id)
    return true, string.format('Targeting spawn ID %d', id)
end

--- Target what pcName is targeting. Uses TargetOfTarget — no /assist command.
---@param pcName string
---@return boolean, string
function target.targetPcTarget(pcName)
    local t = target.getPcTarget(pcName)
    if not t then return false, string.format('%s has no target', pcName) end
    return target.targetSpawn(t)
end

return target
