local mq  = require('mq')
local util = require('booty.bot.actions.util')

local melee = {}

-- ============================================================
-- Pure checks  (is* / has*)
-- ============================================================

function melee.isInCombat()
    return mq.TLO.Me.Combat() == true
end

-- True if current target is a live NPC.
function melee.hasLiveTarget()
    local t = mq.TLO.Target
    return t() ~= nil
        and t.Type() == "NPC"
        and (t.PctHPs() or 0) > 0
end

function melee.hasPet()
    return (mq.TLO.Me.Pet.ID() or 0) > 0
end

-- ============================================================
-- Actors  (attack* / send* / target* / combat*)
-- ============================================================

-- Turn on auto-attack if not already in combat.
function melee.attackOn()
    if mq.TLO.Me.Combat() then return false end
    mq.cmd('/attack on')
    return true, 'Attack on'
end

-- Turn off auto-attack if in combat.
function melee.attackOff()
    if not mq.TLO.Me.Combat() then return false end
    mq.cmd('/attack off')
    return true, 'Attack off'
end

-- Turn off attack and stand down pet.
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
    return acted, acted and 'Combat off' or nil
end

-- Send pet to attack current target if it isn't already on it.
function melee.sendPet(targetID)
    if (mq.TLO.Me.Pet.ID() or 0) == 0 then return false end
    if mq.TLO.Pet.Target.ID() == targetID then return false end
    mq.cmd('/pet attack')
    return true, 'Pet sent to attack'
end

-- Target what pcName is targeting. Uses TargetOfTarget — no /assist command.
function melee.targetPcTarget(pcName)
    local t = util.getPcTarget(pcName)
    if not t then return false end
    return util.targetSpawn(t)
end

return melee
