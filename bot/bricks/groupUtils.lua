local mq  = require('mq')
local bit = require('bit')

local groupUtils = {}

-- ============================================================
-- Pure checks  (is* / has*)
-- ============================================================

--- True if pcName has their weapons drawn aggressively (PlayerState bits 4 or 8).
---@param pcName string
---@return boolean
function groupUtils.isPCEngaged(pcName)
    local pc = mq.TLO.Spawn('pc =' .. pcName)
    if not pc() then return false end
    return bit.band(pc.PlayerState() or 0, 12) ~= 0
end

--- True if any mob is actively targeting a group member (via extended target list).
---@return boolean
function groupUtils.isGroupEngaged()
    for i = 1, 20 do
        local xt = mq.TLO.Me.XTarget(i)
        if xt and (xt.ID() or 0) > 0 then return true end
    end
    return false
end

--- Return the first live NPC spawn from the XTarget list, or nil.
---@return MQSpawn|nil
function groupUtils.getEngagedTarget()
    for i = 1, 20 do
        local xt = mq.TLO.Me.XTarget(i)
        if xt and (xt.ID() or 0) > 0 then
            local spawn = mq.TLO.Spawn(xt.ID())
            if spawn() and spawn.Type() == "NPC" and (spawn.PctHPs() or 0) > 0 then
                return spawn
            end
        end
    end
    return nil
end

---@return boolean
function groupUtils.isGrouped()
    return mq.TLO.Me.Grouped() == true
end

---@return boolean
function groupUtils.hasPendingInvite()
    return mq.TLO.Me.Invited() == true
end

return groupUtils
