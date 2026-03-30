local mq = require('mq')

local altabilityUtils = {}

local mqMe = mq.TLO.Me

-- ============================================================
-- Pure checks  (has* / is*)
-- ============================================================

--- True if the character has purchased this AA.
---@param aaName string
---@return boolean
function altabilityUtils.hasAA(aaName)
    local ability = mqMe.AltAbility(aaName)
    return ability ~= nil and ability() ~= nil
end

--- True if the AA exists and is ready to activate.
---@param aaName string
---@return boolean
function altabilityUtils.isAAReady(aaName)
    if not altabilityUtils.hasAA(aaName) then return false end
    return mq.TLO.Me.AltAbilityReady(aaName)() == true
end

return altabilityUtils
