local mq    = require('mq')
local tgt   = require('booty.bot.actions.target')
local group = require('booty.bot.actions.group')

local combat = {}

-- ============================================================
-- Pure checks  (is* / has*)
-- ============================================================

---@return boolean
function combat.isInCombat()
    return mq.TLO.Me.Combat() == true
end

--- True if current target is a live NPC.
---@return boolean
function combat.hasLiveTarget()
    local t = mq.TLO.Target
    return t() ~= nil
        and t.Type() == "NPC"
        and (t.PctHPs() or 0) > 0
end

---@return boolean
function combat.hasPet()
    return (mq.TLO.Me.Pet.ID() or 0) > 0
end

-- ============================================================
-- Actors  (attack* / send* / disengage / engage*)
-- ============================================================

---@return boolean, string
function combat.attackOn()
    if mq.TLO.Me.Combat() then return false, 'Already in combat' end
    mq.cmd('/attack on')
    return true, 'Attack on'
end

---@return boolean, string
function combat.attackOff()
    if not mq.TLO.Me.Combat() then return false, 'Not in combat' end
    mq.cmd('/attack off')
    return true, 'Attack off'
end

--- Turn off attack and stand down pet if it has a target.
---@return boolean, string
function combat.disengage()
    local acted = false
    if mq.TLO.Me.Combat() then
        mq.cmd('/attack off')
        acted = true
    end
    if (mq.TLO.Me.Pet.ID() or 0) > 0 and (mq.TLO.Pet.Target.ID() or 0) > 0 then
        mq.cmd('/squelch /pet back off')
        acted = true
    end
    if acted then return true, 'Disengaged' end
    return false, 'Not in combat'
end

--- Send pet to attack targetID if it isn't already on it.
---@param targetID integer
---@return boolean, string
function combat.sendPet(targetID)
    if (mq.TLO.Me.Pet.ID() or 0) == 0 then return false, 'No pet' end
    if mq.TLO.Pet.Target.ID() == targetID then return false, 'Pet already on target' end
    mq.cmd('/pet attack')
    return true, 'Pet sent to attack'
end

--- Engage a target. Targets it if not already, then sends pet and/or turns on attack.
---@param target MQSpawn
---@param useMelee boolean
---@param usePet boolean
---@return boolean, string
function combat.engageTarget(target, useMelee, usePet)
    if not target or not target() then
        return false, 'No valid target'
    end
    local id = target.ID()
    if mq.TLO.Target.ID() ~= id then
        mq.cmdf('/squelch /tar id %d', id)
        return true, string.format('Targeting %s', target.Name() or tostring(id))
    end
    local acted = false
    if usePet then
        local c = combat.sendPet(id)
        if c then acted = true end
    end
    if useMelee then
        local c = combat.attackOn()
        if c then acted = true end
    end
    if acted then return true, 'Engaging ' .. (target.Name() or 'target') end
    return false, 'Already engaged'
end

--- Find and engage the best available target for a named PC.
--- Priority: PC's live NPC target → first XTarget NPC → nothing.
--- Stands up first if sitting. One step per tick.
---@param pcName string
---@param useMelee boolean
---@param usePet boolean
---@return boolean, string
function combat.assistPc(pcName, useMelee, usePet)
    local t = tgt.getPcTarget(pcName)
    if t and (t.Type() ~= "NPC" or (t.PctHPs() or 0) <= 0) then t = nil end
    if not t then t = group.getEngagedTarget() end
    if not t then return false, 'No target to assist' end
    if mq.TLO.Me.Sitting() then mq.cmd('/stand'); return true, 'Standing up for combat' end
    return combat.engageTarget(t, useMelee, usePet)
end

return combat
