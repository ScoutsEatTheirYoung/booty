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
    local ability = mqMe.AltAbility(aaName)
    if not ability or not ability() then return false end
    return ability.Ready() == true
end

return altabilityUtils
