local mq  = require('mq')
local util = require('booty.bot.actions.util')

local melee = {}

-- ============================================================
-- Pure checks  (is* / has*)
-- ============================================================

---@return boolean
function melee.isInCombat()
    return mq.TLO.Me.Combat() == true
end

--- True if current target is a live NPC.
---@return boolean
function melee.hasLiveTarget()
    local t = mq.TLO.Target
    return t() ~= nil
        and t.Type() == "NPC"
        and (t.PctHPs() or 0) > 0
end

---@return boolean
function melee.hasPet()
    return (mq.TLO.Me.Pet.ID() or 0) > 0
end

--- Return pcName's target if it is a live NPC worth assisting, else nil.
---@param pcName string
---@return spawn|nil
function melee.getAssistTarget(pcName)
    local t = util.getPcTarget(pcName)
    if not t then return nil end
    if t.Type() ~= "NPC" then return nil end
    if (t.PctHPs() or 0) <= 0 then return nil end
    return t
end

-- ============================================================
-- Actors  (attack* / send* / target* / combat*)
-- ============================================================

--- Turn on auto-attack if not already in combat.
---@return boolean, string
function melee.attackOn()
    if mq.TLO.Me.Combat() then return false, 'Already in combat' end
    mq.cmd('/attack on')
    return true, 'Attack on'
end

--- Turn off auto-attack if in combat.
---@return boolean, string
function melee.attackOff()
    if not mq.TLO.Me.Combat() then return false, 'Not in combat' end
    mq.cmd('/attack off')
    return true, 'Attack off'
end

--- Turn off attack and stand down pet.
---@return boolean, string
function melee.combatOff()
    local acted = false
    if mq.TLO.Me.Combat() then
        mq.cmd('/attack off')
        acted = true
    end
    if (mq.TLO.Me.Pet.ID() or 0) > 0 then
        mq.cmd('/squelch /pet back off')
        acted = true
    end
    if acted then return true, 'Combat off' end
    return false, 'Not in combat'
end

--- Send pet to attack current target if it isn't already on it.
---@param targetID integer
---@return boolean, string
function melee.sendPet(targetID)
    if (mq.TLO.Me.Pet.ID() or 0) == 0 then return false, 'No pet' end
    if mq.TLO.Pet.Target.ID() == targetID then return false, 'Pet already on target' end
    mq.cmd('/pet attack')
    return true, 'Pet sent to attack'
end

--- Target what pcName is targeting. Uses TargetOfTarget — no /assist command.
---@param pcName string
---@return boolean, string
function melee.targetPcTarget(pcName)
    local t = util.getPcTarget(pcName)
    if not t then return false, string.format('%s has no target', pcName) end
    local c, r = util.targetSpawn(t)
    return c, r
end

return melee
