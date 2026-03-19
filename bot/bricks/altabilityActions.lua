local mq              = require('mq')
local altabilityUtils = require('booty.bot.bricks.altabilityUtils')

local altabilityActions = {}

local mqMe = mq.TLO.Me
local cmd  = mq.cmd

-- ============================================================
-- Actors  (cast*)
-- ============================================================

--- Activate an AA by name. Returns false if not owned or not ready.
---@param aaName string
---@return boolean, string
function altabilityActions.castAA(aaName)
    local ability = mqMe.AltAbility(aaName)
    if not ability or not ability() then
        return false, string.format("AA '%s' not owned", aaName)
    end
    if not mqMe.AltAbilityReady(aaName) then
        return true, string.format("Waiting for '%s' to recharge", aaName)
    end
    cmd(string.format('/alt activate %d', ability.ID()))
    return true, string.format("Activating '%s'", aaName)
end

return altabilityActions
