local mq          = require('mq')
local buffActions = require('booty.bot.bricks.buffActions')

local idleActions = {}

--- Sit to med if not at full mana, then cast any buffs that need refreshing.
--- Non-blocking: returns false once sitting and medding (no spell cast this tick).
---@param buffList BuffEntry[]
---@param gemSlot integer
---@return boolean, string
function idleActions.medAndBuff(buffList, gemSlot)
    local pctMana = mq.TLO.Me.PctMana() or 100
    if not mq.TLO.Me.Sitting() and pctMana < 100 then
        mq.cmd('/sit')
        return true, 'Sitting to med'
    end
    local c, r = buffActions.castBuffList(buffList, gemSlot)
    if c then return c, r end
    return false, string.format('Medding (%d%% mana)', pctMana)
end

return idleActions
