local mq          = require('mq')
local targetUtils  = require('booty.bot.bricks.targetUtils')
local groupUtils   = require('booty.bot.bricks.groupUtils')

local combatActions = {}

-- ============================================================
-- Actors  (attack* / send* / disengage / engage*)
-- ============================================================

---@return boolean, string
function combatActions.attackOn()
    if mq.TLO.Me.Combat() then return false, 'Already in combat' end
    mq.cmd('/attack on')
    return true, 'Attack on'
end

--- Stand down from combat. One command per tick: attack off first, then pet back off.
---@return boolean, string
function combatActions.disengage()
    if mq.TLO.Me.Combat() then
        mq.cmd('/attack off')
        return true, 'Disengaging'
    end
    if (mq.TLO.Me.Pet.ID() or 0) > 0 and (mq.TLO.Pet.Target.ID() or 0) > 0 then
        mq.cmd('/squelch /pet back off')
        return true, 'Calling pet back'
    end
    return false, 'Not in combat'
end

--- Send pet to attack targetID if it isn't already on it.
---@param targetID integer
---@return boolean, string
function combatActions.sendPet(targetID)
    if (mq.TLO.Me.Pet.ID() or 0) == 0 then return false, 'No pet' end
    if mq.TLO.Pet.Target.ID() == targetID then return false, 'Pet already on target' end
    mq.cmd('/pet attack')
    return true, 'Pet sent to attack'
end

--- Engage a target. One step per tick: target → sendPet → attackOn.
---@param target MQSpawn|MQTarget
---@param useMelee boolean
---@param usePet boolean
---@return boolean, string
function combatActions.engageTarget(target, useMelee, usePet)
    if not target or not target() then
        return false, 'No valid target'
    end
    local id = target.ID()
    if mq.TLO.Target.ID() ~= id then
        mq.cmdf('/squelch /tar id %d', id)
        return true, string.format('Targeting %s', target.Name() or tostring(id))
    end
    if usePet then
        local c, r = combatActions.sendPet(id)
        if c then return c, r end
    end
    if useMelee then
        local c, r = combatActions.attackOn()
        if c then return c, r end
    end
    return false, 'Already engaged'
end

--- Find and engage the best available target for a named PC.
--- Priority: PC's live NPC target → first XTarget NPC → nothing.
--- Stands up first if sitting. One step per tick.
---@param pcName string
---@param useMelee boolean
---@param usePet boolean
---@return boolean, string
function combatActions.assistPC(pcName, useMelee, usePet)
    ---@type MQTarget|MQSpawn|nil
    local t = targetUtils.getPCTarget(pcName)
    if t and (t.Type() ~= "NPC" or (t.PctHPs() or 0) <= 0) then t = nil end
    if not t then t = groupUtils.getEngagedTarget() end
    if not t then return false, 'No target to assist' end
    if mq.TLO.Window('SpellBookWnd').Open() then return true, 'Memorizing spell' end
    if mq.TLO.Me.Sitting() then mq.cmd('/stand'); return true, 'Standing up for combat' end
    return combatActions.engageTarget(t, useMelee, usePet)
end

return combatActions
