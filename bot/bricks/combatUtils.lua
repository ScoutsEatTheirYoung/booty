local mq = require('mq')

local combatUtils = {}

-- ============================================================
-- Pure checks  (is* / has*)
-- ============================================================

---@return boolean
function combatUtils.isInCombat()
    return mq.TLO.Me.Combat() == true
end

--- True if current target is a live NPC.
---@return boolean
function combatUtils.hasLiveTarget()
    local t = mq.TLO.Target
    return t() ~= nil
        and t.Type() == "NPC"
        and (t.PctHPs() or 0) > 0
end

---@return boolean
function combatUtils.hasPet()
    return (mq.TLO.Me.Pet.ID() or 0) > 0
end

return combatUtils
