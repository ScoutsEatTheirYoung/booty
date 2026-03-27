local mq = require('mq')

local spellUtils = {}

-- ============================================================
-- Fizzle tracking
-- ============================================================
local FIZZLE_BACKOFF = 0.2  -- seconds to back off after a fizzle
local lastFizzleTime = 0

mq.event('SpellFizzle', '#*#Your spell fizzles#*#', function()
    lastFizzleTime = os.clock()
end)

---@return boolean
function spellUtils.justFizzled()
    return (os.clock() - lastFizzleTime) < FIZZLE_BACKOFF
end

-- ============================================================
-- Pure checks  (is* / has* / find* / get*)
-- ============================================================

--- Iterate gem slots 1-12 and return the slot number if spellName is memmed, else nil.
---@param spellName string
---@return integer|nil
function spellUtils.findGemForSpell(spellName)
    for i = 1, 12 do
        if mq.TLO.Me.Gem(i)() == spellName then
            return i
        end
    end
    return nil
end

---@param spellName string
---@return boolean
function spellUtils.isSpellMemmed(spellName)
    return spellUtils.findGemForSpell(spellName) ~= nil
end

--- True if spellName appears in any gem slot on the spell bar.
---@param spellName string
---@return boolean
function spellUtils.isOnBar(spellName)
    return spellUtils.findGemForSpell(spellName) ~= nil
end

---@param spellName string
---@return boolean
function spellUtils.isSpellReady(spellName)
    local gem = spellUtils.findGemForSpell(spellName)
    if not gem then return false end
    return mq.TLO.Me.SpellReady(gem)() == true
end

---@param spellName string
---@return boolean
function spellUtils.hasManaForSpell(spellName)
    local cost = mq.TLO.Spell(spellName).Mana() or 0
    return mq.TLO.Me.CurrentMana() >= cost
end

return spellUtils
