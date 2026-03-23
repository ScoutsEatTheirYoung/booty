local mq              = require('mq')
local altabilityUtils = require('booty.bot.bricks.altabilityUtils')

local altabilityActions = {}

local mqMe = mq.TLO.Me
local cmd  = mq.cmd

-- ============================================================
-- Actors  (cast*)
-- ============================================================

--- Activate an AA by name.
--- Returns false (no tick consumed) when not owned or on cooldown.
---@param aaName string
---@return boolean, string
function altabilityActions.castAA(aaName)
    if not altabilityUtils.hasAA(aaName) then
        return false, string.format("AA '%s' not owned", aaName)
    end
    if not altabilityUtils.isAAReady(aaName) then
        return false, string.format("'%s' recharging", aaName)
    end
    local ability = mqMe.AltAbility(aaName)
    cmd(string.format('/alt activate %d', ability.ID()))
    return true, string.format("Activating '%s'", aaName)
end

return altabilityActions
